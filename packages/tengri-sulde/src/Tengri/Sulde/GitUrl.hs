{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Module: Tengri.Sulde.GitUrl
-- Description: Robust Git URL manipulation, SSH conversion, and .gitconfig rewriting
--
-- This module provides functions for parsing, normalizing, and rewriting
-- Git repository URLs. It handles conversion between HTTPS and SSH formats,
-- strips browser path suffixes (such as tree, blob, or pull paths),
-- extracts local checkout directory names, and honors Git @url.*.insteadOf@
-- rewriting rules configured in @~/.gitconfig@ or ambient environment.
--
-- = Architectural Context
--
-- Per Note [Core Architecture] [ref:note-core-architecture], this module provides
-- foundational repository address resolution for Tengri's shell exploration and
-- automation conduits.
--
-- == Invariants & Guarantees
--
-- 1. __Browser Suffix Stripping:__ All URL rewriting operations safely prune
--    ephemeral web browser paths (@/tree/...@, @/blob/...@, @/-/tree/...@) to ensure
--    the returned URL points to a valid cloneable Git repository root.
-- 2. __Total Operations:__ URL parsing and transformation never throw runtime
--    exceptions; unparseable strings are preserved safely.
-- 3. __Git Config Compliance:__ When multiple @insteadOf@ rules match, the longest
--    matching prefix takes precedence in accordance with Git specification.
--
-- = Worked Example
--
-- >>> toSshUrl "https://github.com/NadiaYvette/tengri/tree/master/packages"
-- "git@github.com:NadiaYvette/tengri.git"
--
-- >>> repoDirName "https://github.com/NadiaYvette/tengri.git"
-- "tengri"
module Tengri.Sulde.GitUrl
  ( -- * Core URL Transformations
    toSshUrl
  , repoDirName
  , stripBrowserSuffix

    -- * Git Config Rewriting
  , applyGitInsteadOf
  , applyGitInsteadOfRules
  , loadGitInsteadOfRules
  , parseGitConfigContent
  ) where

import Control.Exception (SomeException, catch)
import Data.List (sortBy)
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (doesFileExist, getHomeDirectory)
import System.Exit (ExitCode (ExitSuccess))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

-- | Strips web browser navigation path suffixes from a Git URL.
--
-- Prunes path components such as @/tree/...@, @/blob/...@, @/raw/...@,
-- @/commits/...@, @/pull/...@, @/issues/...@, and GitLab-style @/-/tree/...@
-- navigation segments, along with URL query parameters and fragments.
--
-- >>> stripBrowserSuffix "https://github.com/owner/repo/tree/master/src"
-- "https://github.com/owner/repo"
--
-- >>> stripBrowserSuffix "https://gitlab.com/group/repo/-/blob/main/README.md"
-- "https://gitlab.com/group/repo"
stripBrowserSuffix :: Text -> Text
stripBrowserSuffix rawUrl =
  let -- Strip query parameters and fragments first
      noQuery = fst (T.breakOn "?" (fst (T.breakOn "#" rawUrl)))
      -- Strip browser segment markers
      pruned = foldl pruneMarker noQuery browserMarkers
      -- Strip trailing slash
      clean = if T.isSuffixOf "/" pruned && T.length pruned > 1
                then T.dropEnd 1 pruned
                else pruned
  in clean
  where
    browserMarkers :: [Text]
    browserMarkers =
      [ "/-/tree/"
      , "/-/blob/"
      , "/-/raw/"
      , "/-/commits/"
      , "/-/issues/"
      , "/-/merge_requests/"
      , "/tree/"
      , "/blob/"
      , "/raw/"
      , "/commits/"
      , "/commit/"
      , "/pull/"
      , "/pulls/"
      , "/issues/"
      , "/releases/"
      , "/src/"
      ]

    pruneMarker :: Text -> Text -> Text
    pruneMarker acc marker =
      case T.breakOn marker acc of
        (prefix, suffix)
          | not (T.null suffix) -> prefix
          | otherwise           -> acc

-- | Extracts the canonical local directory name from a Git URL or repository path.
--
-- Strips browser navigation suffixes, drops any terminal @.git@ extension, and
-- returns the trailing repository path component suitable for directory creation.
--
-- >>> repoDirName "https://github.com/NadiaYvette/tengri.git"
-- "tengri"
--
-- >>> repoDirName "git@github.com:owner/my-tool/tree/main"
-- "my-tool"
repoDirName :: Text -> Text
repoDirName rawUrl =
  let clean = stripBrowserSuffix rawUrl
      -- Split by slash and colon to isolate the terminal segment
      tokens = filter (not . T.null) (T.split (\c -> c == '/' || c == ':') clean)
  in case reverse tokens of
       [] -> clean
       (lastSegment : _) ->
         if ".git" `T.isSuffixOf` lastSegment && T.length lastSegment > 4
           then T.dropEnd 4 lastSegment
           else lastSegment

-- | Converts an HTTP, HTTPS, or Git URL into an SCP-style SSH URL.
--
-- Strips browser navigation suffixes and normalizes the URL to the standard
-- @git\@<host>:<path>.git@ format.
--
-- >>> toSshUrl "https://github.com/NadiaYvette/tengri"
-- "git@github.com:NadiaYvette/tengri.git"
--
-- >>> toSshUrl "git@github.com:NadiaYvette/tengri.git"
-- "git@github.com:NadiaYvette/tengri.git"
toSshUrl :: Text -> Text
toSshUrl rawUrl =
  let clean = stripBrowserSuffix rawUrl
  in if "git@" `T.isPrefixOf` clean
       then ensureDotGit clean
       else if "ssh://git@" `T.isPrefixOf` clean
              then
                -- ssh://git@github.com/owner/repo -> git@github.com:owner/repo.git
                let rest = T.drop 10 clean
                    (host, pathWithSlash) = T.breakOn "/" rest
                    path = T.dropWhile (== '/') pathWithSlash
                in ensureDotGit ("git@" <> host <> ":" <> path)
              else if "https://" `T.isPrefixOf` clean
                     then convertScheme 8 clean
                     else if "http://" `T.isPrefixOf` clean
                            then convertScheme 7 clean
                            else if "git://" `T.isPrefixOf` clean
                                   then convertScheme 6 clean
                                   else clean
  where
    convertScheme :: Int -> Text -> Text
    convertScheme dropLen url =
      let rest = T.drop dropLen url
          (host, pathWithSlash) = T.breakOn "/" rest
          path = T.dropWhile (== '/') pathWithSlash
      in if T.null path
           then url
           else ensureDotGit ("git@" <> host <> ":" <> path)

    ensureDotGit :: Text -> Text
    ensureDotGit url =
      if ".git" `T.isSuffixOf` url
        then url
        else url <> ".git"

-- | Applies a list of @url.<base>.insteadOf <prefix>@ rewrite rules to a Git URL.
--
-- In accordance with Git behavior, rules are evaluated by longest matching prefix first.
-- If an input URL begins with @prefix@, that prefix is replaced by @base@.
--
-- >>> let rules = [("git@github.com:", "https://github.com/")]
-- >>> applyGitInsteadOfRules rules "https://github.com/owner/repo"
-- "git@github.com:owner/repo"
applyGitInsteadOfRules :: [(Text, Text)] -> Text -> Text
applyGitInsteadOfRules rules rawUrl =
  let clean = stripBrowserSuffix rawUrl
      -- Sort rules by descending length of the matched prefix so longest match wins
      sortedRules = sortBy (comparing (Down . T.length . snd)) rules
  in case findMatch sortedRules clean of
       Just (base, prefix) -> base <> T.drop (T.length prefix) clean
       Nothing             -> clean
  where
    findMatch :: [(Text, Text)] -> Text -> Maybe (Text, Text)
    findMatch [] _ = Nothing
    findMatch ((base, prefix) : rest) url
      | prefix `T.isPrefixOf` url = Just (base, prefix)
      | otherwise                 = findMatch rest url

-- | Purely parses Git configuration content extracting @url.<base>.insteadOf@ pairs.
--
-- Understands both INI section syntax (@[url "base"] insteadOf = prefix@) and
-- @git config --get-regexp@ output format (@url.base.insteadof prefix@).
parseGitConfigContent :: Text -> [(Text, Text)]
parseGitConfigContent content =
  parseLines Nothing (T.lines content)
  where
    parseLines :: Maybe Text -> [Text] -> [(Text, Text)]
    parseLines _ [] = []
    parseLines curBase (l : ls) =
      let trimmed = T.strip l
      in if T.null trimmed || "#" `T.isPrefixOf` trimmed || ";" `T.isPrefixOf` trimmed
           then parseLines curBase ls
           else if "[" `T.isPrefixOf` trimmed && "]" `T.isSuffixOf` trimmed
                  then
                    let header = T.drop 1 (T.dropEnd 1 trimmed)
                    in if "url " `T.isPrefixOf` header || "url\t" `T.isPrefixOf` header
                         then
                           let rawSection = T.strip (T.drop 4 header)
                               base = T.dropAround (\c -> c == '"' || c == '\'') rawSection
                           in parseLines (Just base) ls
                         else parseLines Nothing ls
                  else case curBase of
                         Just base ->
                           let (k, v) = T.breakOn "=" trimmed
                           in if T.toLower (T.strip k) == "insteadof"
                                then
                                  let val = T.strip (T.drop 1 v)
                                      cleanVal = T.dropAround (\c -> c == '"' || c == '\'') val
                                  in (base, cleanVal) : parseLines curBase ls
                                else parseLines curBase ls
                         Nothing ->
                           -- Check for git config flat output: url.<base>.insteadof <prefix>
                           case parseFlatGitConfigLine trimmed of
                             Just pair -> pair : parseLines Nothing ls
                             Nothing   -> parseLines Nothing ls

    parseFlatGitConfigLine :: Text -> Maybe (Text, Text)
    parseFlatGitConfigLine line =
      let lower = T.toLower line
      in if "url." `T.isPrefixOf` lower
           then case T.breakOn ".insteadof" lower of
                  (prefixPart, rest)
                    | not (T.null rest) ->
                        let baseLen = T.length prefixPart - 4
                            base = T.take baseLen (T.drop 4 line)
                            rawVal = T.drop (T.length ".insteadof") (T.drop (T.length prefixPart) line)
                            val = T.strip (T.dropAround (== '=') (T.strip rawVal))
                        in if T.null base || T.null val
                             then Nothing
                             else Just (base, val)
                  _ -> Nothing
           else Nothing

-- | Loads active Git @url.*.insteadOf@ rules from the local environment.
--
-- First attempts to invoke @git config --get-regexp@ to capture all system,
-- global, and repository-level rewrite rules. If the @git@ executable is not
-- found or returns an error, safely falls back to parsing @~/.gitconfig@ directly.
loadGitInsteadOfRules :: IO [(Text, Text)]
loadGitInsteadOfRules =
  loadFromGitProcess `catch` \(_ :: SomeException) -> loadFromFileFallback
  where
    loadFromGitProcess :: IO [(Text, Text)]
    loadFromGitProcess = do
      (exitCode, stdout, _stderr) <-
        readProcessWithExitCode "git" ["config", "--get-regexp", "^url\\..*\\.insteadof"] ""
      case exitCode of
        ExitSuccess | not (null stdout) ->
          pure (parseGitConfigContent (T.pack stdout))
        _ -> loadFromFileFallback

    loadFromFileFallback :: IO [(Text, Text)]
    loadFromFileFallback = do
      home <- getHomeDirectory
      let globalConfig = home </> ".gitconfig"
      exists <- doesFileExist globalConfig
      if exists
        then do
          content <- TIO.readFile globalConfig
          pure (parseGitConfigContent content)
        else pure []

-- | Rewrites a Git URL honoring configured @url.*.insteadOf@ rules from @.gitconfig@.
--
-- Automatically strips browser navigation suffixes and applies the highest-precedence
-- (longest-matching) @insteadOf@ rule found in active Git configuration.
--
-- >>> applyGitInsteadOf "https://github.com/owner/repo"
-- -- Result depends on ambient .gitconfig rules
applyGitInsteadOf :: Text -> IO Text
applyGitInsteadOf rawUrl = do
  rules <- loadGitInsteadOfRules
  pure (applyGitInsteadOfRules rules rawUrl)
