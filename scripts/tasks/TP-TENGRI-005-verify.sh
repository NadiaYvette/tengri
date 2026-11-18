#!/usr/bin/env bash
set -euo pipefail

echo "=== [Gate 1/2] Verifying test suites for tengri, tengri-toli, and tengri-savdag ==="
cabal v2-test tengri:test:tests tengri-toli:test:tests tengri-savdag:test:tests -j20 --semaphore --test-show-details=direct

echo "=== [Gate 2/2] Running full tengri quality gates ==="
./bin/tengri-verify
