#!/usr/bin/env bash
set -euo pipefail

echo "=== [Gate 1/2] Verifying tengri-darkhan test suite ==="
cabal v2-test tengri-darkhan:test:tests -j20 --semaphore --test-show-details=direct

echo "=== [Gate 2/2] Running full tengri quality gates ==="
./bin/tengri-verify
