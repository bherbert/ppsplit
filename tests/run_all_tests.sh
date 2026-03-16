#!/bin/bash

# run_all_tests.sh - Runs all PeacePi Video Splitter test suites
#
# Usage: ./tests/run_all_tests.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_SUITES=0
PASSED_SUITES=0

run_suite() {
    local name="$1"
    local script="$2"
    ((++TOTAL_SUITES))

    echo ""
    echo -e "${BOLD}──────────────────────────────────────────${NC}"
    echo -e "${BOLD}Suite: $name${NC}"
    echo -e "${BOLD}──────────────────────────────────────────${NC}"

    bash "$script"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}Suite passed.${NC}"
        ((++PASSED_SUITES))
    else
        echo -e "${RED}Suite failed (exit $exit_code).${NC}"
    fi
}

echo ""
echo -e "${BOLD}=========================================="
echo -e "  PeacePi Video Splitter — Test Runner"
echo -e "==========================================${NC}"

# Check for test video before running Layer 2
TEST_VIDEO="$SCRIPT_DIR/fixtures/test_video.mp4"
if [[ ! -f "$TEST_VIDEO" ]]; then
    echo ""
    echo -e "${YELLOW}Warning:${NC} tests/fixtures/test_video.mp4 not found."
    echo "  Layer 2 (ppsplit debug) tests will be skipped."
    echo "  Generate it with:"
    echo ""
    echo "    ffmpeg -f lavfi -i color=c=blue:s=1280x720:r=30 \\"
    echo "           -f lavfi -i sine=frequency=440 \\"
    echo "           -t 300 -c:v libx264 -c:a aac \\"
    echo "           tests/fixtures/test_video.mp4"
    SKIP_LAYER2=true
else
    SKIP_LAYER2=false
fi

run_suite "Layer 1 — URL Parser" "$SCRIPT_DIR/test_url_parser.sh"
LAYER1_PASSED=$PASSED_SUITES

if [[ "$SKIP_LAYER2" == true ]]; then
    : # already warned above
elif [[ $LAYER1_PASSED -eq 0 ]]; then
    echo ""
    echo -e "${YELLOW}Skipping Layer 2:${NC} Layer 1 failed — fix URL parser tests first."
else
    run_suite "Layer 2 — ppsplit Debug Mode" "$SCRIPT_DIR/test_ppsplit_debug.sh"
fi

echo ""
echo -e "${BOLD}=========================================="
FAILED_SUITES=$((TOTAL_SUITES - PASSED_SUITES))
if [[ $FAILED_SUITES -eq 0 ]]; then
    echo -e "  ${GREEN}All $PASSED_SUITES/$TOTAL_SUITES suites passed.${NC}"
else
    echo -e "  ${RED}$FAILED_SUITES/$TOTAL_SUITES suites failed.${NC}"
fi
echo -e "${BOLD}==========================================${NC}"
echo ""

[[ $FAILED_SUITES -eq 0 ]] && exit 0 || exit 1
