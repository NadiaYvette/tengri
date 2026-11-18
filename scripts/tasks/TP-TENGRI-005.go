package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func findSeed(name string) string {
	candidates := []string{
		filepath.Join("seeds", name),
		filepath.Join(os.Getenv("HOME"), "src/plans/seeds", name),
		filepath.Join("..", "seeds", name),
		filepath.Join("/home/nyc/src/plans/seeds", name),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return filepath.Join("seeds", name)
}

func main() {
	fmt.Println("=== [TP-TENGRI-005 Task Runner (Go)] ===")

	// 1. Copy Tengri/Smirk.hs
	srcSmirk := findSeed("TP-TENGRI-005-Smirk.hs")
	dstSmirk := "packages/tengri/src/Tengri/Smirk.hs"
	if err := copyFile(srcSmirk, dstSmirk); err != nil {
		fmt.Fprintf(os.Stderr, "failed to copy %s -> %s: %v\n", srcSmirk, dstSmirk, err)
		os.Exit(1)
	}
	fmt.Printf("  [+] Mounted %s\n", dstSmirk)

	// 2. Copy SmirkSpec.hs
	srcSpec := findSeed("TP-TENGRI-005-SmirkSpec.hs")
	dstSpec := "packages/tengri/test/SmirkSpec.hs"
	if err := copyFile(srcSpec, dstSpec); err != nil {
		fmt.Fprintf(os.Stderr, "failed to copy %s -> %s: %v\n", srcSpec, dstSpec, err)
		os.Exit(1)
	}
	fmt.Printf("  [+] Mounted %s\n", dstSpec)

	// 3. Update packages/tengri/tengri.cabal
	cabalPath := "packages/tengri/tengri.cabal"
	cabalBytes, err := os.ReadFile(cabalPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read %s: %v\n", cabalPath, err)
		os.Exit(1)
	}
	cabalStr := string(cabalBytes)
	if !strings.Contains(cabalStr, "Tengri.Smirk") {
		cabalStr = strings.Replace(cabalStr,
			"    Tengri.CLI\n",
			"    Tengri.CLI\n    Tengri.Smirk\n", 1)
	}
	if !strings.Contains(cabalStr, "smirk,") && strings.Contains(cabalStr, "tengri-darkhan\n") {
		cabalStr = strings.Replace(cabalStr,
			"    tengri-darkhan\n",
			"    tengri-darkhan,\n    smirk,\n    smirk-penelope\n", 1)
	}
	if !strings.Contains(cabalStr, "other-modules:\n    SmirkSpec") && strings.Contains(cabalStr, "test-suite tests") {
		cabalStr = strings.Replace(cabalStr,
			"  hs-source-dirs: test\n",
			"  hs-source-dirs: test\n  other-modules:\n    SmirkSpec\n", 1)
	}
	if !strings.Contains(cabalStr, "hspec >= 2.10 && < 2.12,\n    smirk") && strings.Contains(cabalStr, "hspec >= 2.10 && < 2.12\n") {
		cabalStr = strings.Replace(cabalStr,
			"    hspec >= 2.10 && < 2.12\n",
			"    hspec >= 2.10 && < 2.12,\n    smirk,\n    smirk-penelope\n", 1)
	}
	if err := os.WriteFile(cabalPath, []byte(cabalStr), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write %s: %v\n", cabalPath, err)
		os.Exit(1)
	}
	fmt.Println("  [+] Updated packages/tengri/tengri.cabal")

	// 4. Update packages/tengri/src/Tengri.hs to re-export Tengri.Smirk
	tengriHsPath := "packages/tengri/src/Tengri.hs"
	tengriBytes, err := os.ReadFile(tengriHsPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read %s: %v\n", tengriHsPath, err)
		os.Exit(1)
	}
	tengriStr := string(tengriBytes)
	if !strings.Contains(tengriStr, "module Tengri.Smirk") {
		tengriStr = strings.Replace(tengriStr,
			"  , module Tengri.CLI\n  )",
			"  , module Tengri.CLI\n    -- * Smirk & Penelope Bridge Re-exports\n  , module Tengri.Smirk\n  )", 1)
		tengriStr = strings.Replace(tengriStr,
			"import Tengri.CLI\n",
			"import Tengri.CLI\nimport Tengri.Smirk\n", 1)
		if err := os.WriteFile(tengriHsPath, []byte(tengriStr), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "failed to write %s: %v\n", tengriHsPath, err)
			os.Exit(1)
		}
		fmt.Println("  [+] Updated packages/tengri/src/Tengri.hs")
	}

	// 5. Update packages/tengri/test/Main.hs to include SmirkSpec
	testMainPath := "packages/tengri/test/Main.hs"
	testBytes, err := os.ReadFile(testMainPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read %s: %v\n", testMainPath, err)
		os.Exit(1)
	}
	testStr := string(testBytes)
	if !strings.Contains(testStr, "import qualified SmirkSpec") {
		testStr = strings.Replace(testStr,
			"import Test.Hspec\n",
			"import Test.Hspec\nimport qualified SmirkSpec\n", 1)
		testStr = strings.Replace(testStr,
			"main = hspec $ parallel $ do\n",
			"main = hspec $ parallel $ do\n  SmirkSpec.spec\n", 1)
		if err := os.WriteFile(testMainPath, []byte(testStr), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "failed to write %s: %v\n", testMainPath, err)
			os.Exit(1)
		}
		fmt.Println("  [+] Updated packages/tengri/test/Main.hs")
	}

	fmt.Println("=== [TP-TENGRI-005 Task Runner Completed Successfully] ===")
}
