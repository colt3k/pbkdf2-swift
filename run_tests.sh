#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

usage() {
    echo "Usage: $0 [options]"
    echo "  -c, --config <debug|release>   Build configuration (default: release)"
    echo "  -f, --filter <regex>           Run only tests whose identifier matches the regex"
    echo "                                 (e.g. 'oneIteration', 'multiBlock|truncation')"
    echo "  -l, --list                     List available tests without running"
    echo "  -h, --help                     Show this help"
}

CONFIG="release"
FILTER=""
LIST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG="${2:?missing value for $1}"
            shift 2
            ;;
        -f|--filter)
            FILTER="${2:?missing value for $1}"
            shift 2
            ;;
        -l|--list)
            LIST=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ "$LIST" -eq 1 ]]; then
    swift test list
    exit 0
fi

# -enable-testing is required so tests can `@testable import PBKDF2Swift`
# (swift test does this implicitly; swift build does not).
swift build -c "$CONFIG" --build-tests -Xswiftc -enable-testing

BUNDLE="$(ls -d .build/"$CONFIG"/*.xctest 2>/dev/null | head -1)"
if [[ -z "$BUNDLE" ]]; then
    echo "Test bundle not found under .build/$CONFIG" >&2
    exit 1
fi
MACHO="$BUNDLE/Contents/MacOS/$(basename "$BUNDLE" .xctest)"

# These tests use swift-testing, not XCTest: `xcrun xctest` only runs XCTest
# cases (zero here), so instead use the same helper SwiftPM itself uses
# (swiftpm-testing-helper). Like xcrun xctest it inherits stdout directly, so
# nothing gets truncated the way `swift test`'s piped output can.
DEV_DIR="$(xcode-select -p)"
HELPER="$DEV_DIR/Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper"
if [[ ! -x "$HELPER" ]]; then
    echo "swiftpm-testing-helper not found at $HELPER" >&2
    exit 1
fi
# The bundle links @rpath/Testing.framework, which lives in the macOS
# platform's framework directory.
export DYLD_FRAMEWORK_PATH="$DEV_DIR/Platforms/MacOSX.platform/Developer/Library/Frameworks"

ARGS=()
if [[ -n "$FILTER" ]]; then
    ARGS+=(--filter "$FILTER")
fi

echo "Running tests (config: $CONFIG${FILTER:+, filter: $FILTER}) via swiftpm-testing-helper..."
START=$(date +%s)
set +e
"$HELPER" --test-bundle-path "$MACHO" "$MACHO" --testing-library swift-testing "${ARGS[@]+"${ARGS[@]}"}"
STATUS=$?
set -e
ELAPSED=$(( $(date +%s) - START ))

if [[ $STATUS -eq 69 ]]; then
    echo "No tests match filter: $FILTER" >&2
    exit 1
fi
if [[ $STATUS -ne 0 ]]; then
    echo "Tests failed after ${ELAPSED}s." >&2
    exit "$STATUS"
fi
echo "Tests passed in ${ELAPSED}s."