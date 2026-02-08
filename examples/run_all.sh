#!/bin/bash
# Run all EvalEx examples
#
# Usage: ./examples/run_all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "=============================================="
echo "Running all EvalEx examples"
echo "=============================================="
echo ""

# Track results
PASSED=0
FAILED=0
TOTAL=0

# Run each .exs file in the examples directory
for example in "$SCRIPT_DIR"/*.exs; do
    if [ -f "$example" ]; then
        TOTAL=$((TOTAL + 1))
        name=$(basename "$example")
        echo "Running: $name"
        echo "----------------------------------------------"

        if mix run "$example"; then
            echo ""
            echo "PASSED: $name"
            PASSED=$((PASSED + 1))
        else
            echo ""
            echo "FAILED: $name"
            FAILED=$((FAILED + 1))
        fi
        echo ""
    fi
done

# Summary
echo "=============================================="
echo "Summary"
echo "=============================================="
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "All examples passed!"
    exit 0
else
    echo ""
    echo "Some examples failed!"
    exit 1
fi
