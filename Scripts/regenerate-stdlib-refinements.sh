#!/usr/bin/env bash
#
# Regenerate Lint.Rule.Idiom.RedundantRefinement's stdlib refinement table.
#
# This script runs the symbol-graph-conformance-oracle experiment against
# Swift stdlib's symbol graph (extracted via `swift symbolgraph-extract`)
# and copies the resulting auto-generated Swift source into
# `Sources/Linter Rule Idiom/Lint.Rule.Idiom.RedundantRefinement.StdlibRefinementsTable.swift`.
#
# Run this after every Swift toolchain upgrade. The script is idempotent —
# rerunning against the same toolchain produces an identical Swift source
# file (`git diff` will show nothing if the toolchain's stdlib hasn't
# changed).
#
# Recipe overview:
#   1. `swift symbolgraph-extract -module-name Swift` against the active SDK.
#   2. `swift run symbol-graph-conformance-oracle` on the extracted graph.
#   3. Copy `Outputs/StdlibRefinementsTable.swift` into the rule package.
#
# Dependencies:
#   - macOS host with `xcrun` (or LINUX-equivalent SDK path resolution).
#   - swift-json experiment package at the path resolved below.
#   - Swift toolchain matching the experiment package's tools-version.

set -euo pipefail

# Repo root resolution: script lives at <repo-root>/Scripts/regenerate-…sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINTER_RULES_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# The experiment package lives at swift-foundations/swift-json/Experiments/.
# Resolve via sibling-package convention.
WORKSPACE_ROOT="$(cd "${LINTER_RULES_ROOT}/../.." && pwd)"
EXPERIMENT_DIR="${WORKSPACE_ROOT}/swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle"

if [[ ! -d "${EXPERIMENT_DIR}" ]]; then
    echo "error: experiment package not found at ${EXPERIMENT_DIR}" >&2
    echo "       expected sibling-package layout under swift-foundations/" >&2
    exit 1
fi

DEST_FILE="${LINTER_RULES_ROOT}/Sources/Linter Rule Idiom/Lint.Rule.Idiom.RedundantRefinement.StdlibRefinementsTable.swift"

echo "=== Regenerating stdlib refinements table ==="
echo "Experiment dir: ${EXPERIMENT_DIR}"
echo "Destination:    ${DEST_FILE}"
echo ""

cd "${EXPERIMENT_DIR}"

# Step 1: Extract Swift stdlib's symbol graph for the active SDK.
SDK="$(xcrun --show-sdk-path)"
TARGET="$(uname -m)-apple-macosx26.0"
echo "Step 1/3: extracting Swift stdlib symbol graph"
echo "  SDK:    ${SDK}"
echo "  Target: ${TARGET}"
mkdir -p Outputs/swift-stdlib
swift symbolgraph-extract \
    -module-name Swift \
    -sdk "${SDK}" \
    -target "${TARGET}" \
    -output-dir Outputs/swift-stdlib \
    -pretty-print \
    -minimum-access-level public
echo "  done."
echo ""

# Step 2: Run the reducer against the extracted graph.
echo "Step 2/3: running symbol-graph-conformance-oracle reducer"
echo "  (typically 1–3 min wall-clock — swift-json text-parser bottleneck)"
swift run symbol-graph-conformance-oracle Outputs/swift-stdlib/Swift.symbols.json
echo ""

# Step 3: Copy the generated Swift source into the rule package.
GENERATED="${EXPERIMENT_DIR}/Outputs/StdlibRefinementsTable.swift"
if [[ ! -f "${GENERATED}" ]]; then
    echo "error: generated table not produced at ${GENERATED}" >&2
    exit 2
fi
echo "Step 3/3: copying generated table into rule package"
cp "${GENERATED}" "${DEST_FILE}"
echo "  wrote: ${DEST_FILE}"
echo ""

echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  - Review diff: git -C ${LINTER_RULES_ROOT} diff"
echo "  - Run tests:   swift test --filter \"redundant refinement\""
echo "  - Commit if the diff looks intentional"
