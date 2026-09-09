#!/bin/bash
#
# Turns curve-test-results.txt (key=VALUE lines, key = <lang>_<curve>) into a
# markdown pass/fail matrix written to the job summary, and fails the job if
# any language/curve combination didn't PASS.
set -euo pipefail

RESULTS_FILE="${1:-curve-test-results.txt}"
LANGUAGES=(go python ruby nodejs java rust dart csharp cpp)
CURVES=(p256 p384 p521)
declare -A LABELS=(
    [go]="Go" [python]="Python" [ruby]="Ruby" [nodejs]="Node.js"
    [java]="Java" [rust]="Rust" [dart]="Dart" [csharp]="C#" [cpp]="C++"
)

[ -f "$RESULTS_FILE" ] || { echo "::error::Results file not found: $RESULTS_FILE"; exit 1; }

declare -A RESULTS
while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    RESULTS["$key"]="$value"
done < "$RESULTS_FILE"

{
    echo "### gRPC EC Curve Compatibility Matrix"
    echo ""
    echo "Full 9-language proof against grpc/grpc#42086 (\`feature/ec-curve-fix\`), all 3 curves, patched build."
    echo ""
    echo "| Language | P-256 | P-384 | P-521 |"
    echo "|---|---|---|---|"
    for lang in "${LANGUAGES[@]}"; do
        row="| ${LABELS[$lang]} |"
        for curve in "${CURVES[@]}"; do
            result="${RESULTS[${lang}_${curve}]:-MISSING}"
            if [ "$result" = "PASS" ]; then
                row="$row ✅ PASS |"
            else
                row="$row ❌ $result |"
            fi
        done
        echo "$row"
    done
} >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"

failures=0
for lang in "${LANGUAGES[@]}"; do
    for curve in "${CURVES[@]}"; do
        result="${RESULTS[${lang}_${curve}]:-MISSING}"
        if [ "$result" != "PASS" ]; then
            echo "::error::$lang / $curve => $result"
            failures=$((failures + 1))
        fi
    done
done

if [ "$failures" -gt 0 ]; then
    echo "$failures combination(s) failed." >&2
    exit 1
fi

echo "All language/curve combinations passed."
