#!/bin/bash

# test_ppsplit_debug.sh - Runs ppsplit.sh in debug mode against all CSV fixtures
#
# Requires a test video at tests/fixtures/test_video.mp4
# Generate one with:
#   ffmpeg -f lavfi -i color=c=blue:s=1280x720:r=30 \
#          -f lavfi -i sine=frequency=440 \
#          -t 300 -c:v libx264 -c:a aac \
#          tests/fixtures/test_video.mp4
#
# Usage: ./tests/test_ppsplit_debug.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
PPSPLIT="$PROJECT_DIR/bin/ppsplit.sh"
TEST_VIDEO="$FIXTURES_DIR/test_video.mp4"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

# --- Preflight checks ---

if [[ ! -f "$PPSPLIT" ]]; then
    echo -e "${RED}ERROR:${NC} ppsplit.sh not found at $PPSPLIT"
    exit 1
fi

if [[ ! -f "$TEST_VIDEO" ]]; then
    echo ""
    echo -e "${YELLOW}No test video found.${NC} Generate one with:"
    echo ""
    echo "  ffmpeg -f lavfi -i color=c=blue:s=1280x720:r=30 \\"
    echo "         -f lavfi -i sine=frequency=440 \\"
    echo "         -t 300 -c:v libx264 -c:a aac \\"
    echo "         tests/fixtures/test_video.mp4"
    echo ""
    exit 1
fi

# --- Test runner ---

run_fixture() {
    local fixture_name="$1"
    local fixture_file="$FIXTURES_DIR/$fixture_name"
    local description="$2"

    if [[ ! -f "$fixture_file" ]]; then
        echo -e "  ${RED}SKIP${NC}  $description (fixture not found: $fixture_name)"
        return
    fi

    # ppsplit.sh expects snippets.csv.txt alongside the video file
    cp "$fixture_file" "$FIXTURES_DIR/snippets.csv.txt"

    local output
    output=$(bash "$PPSPLIT" -d "$TEST_VIDEO" 2>&1)
    local exit_code=$?

    # Clean up
    rm -f "$FIXTURES_DIR/snippets.csv.txt"
    rm -f "$FIXTURES_DIR/ppsplit.log"

    if [[ $exit_code -eq 0 ]]; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $description (exit code $exit_code)"
        echo "$output" | sed 's/^/        /'
        ((FAIL++))
    fi
}

run_fixture_expect_summary() {
    local fixture_name="$1"
    local description="$2"
    local expect_pattern="$3"   # grep pattern that must appear in output

    local fixture_file="$FIXTURES_DIR/$fixture_name"

    cp "$fixture_file" "$FIXTURES_DIR/snippets.csv.txt"

    local output
    output=$(bash "$PPSPLIT" -d "$TEST_VIDEO" 2>&1)
    local exit_code=$?

    rm -f "$FIXTURES_DIR/snippets.csv.txt"
    rm -f "$FIXTURES_DIR/ppsplit.log"

    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "$expect_pattern"; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $description"
        echo "        Expected pattern: '$expect_pattern'"
        echo "$output" | sed 's/^/        /'
        ((FAIL++))
    fi
}

run_fixture_with_flags_expect_pattern() {
    local fixture_name="$1"
    local description="$2"
    local extra_flags="$3"      # additional flags to pass to ppsplit.sh (e.g. "-t")
    local expect_pattern="$4"   # grep pattern that must appear in output

    local fixture_file="$FIXTURES_DIR/$fixture_name"

    if [[ ! -f "$fixture_file" ]]; then
        echo -e "  ${RED}SKIP${NC}  $description (fixture not found: $fixture_name)"
        return
    fi

    cp "$fixture_file" "$FIXTURES_DIR/snippets.csv.txt"

    local output
    output=$(bash "$PPSPLIT" -d $extra_flags "$TEST_VIDEO" 2>&1)
    local exit_code=$?

    rm -f "$FIXTURES_DIR/snippets.csv.txt"
    rm -f "$FIXTURES_DIR/ppsplit.log"

    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "$expect_pattern"; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $description"
        echo "        Expected pattern: '$expect_pattern'"
        echo "$output" | sed 's/^/        /'
        ((FAIL++))
    fi
}

# --- Test cases ---

echo ""
echo "=== ppsplit.sh Debug Mode Tests ==="
echo "    Video: $TEST_VIDEO"
echo ""

run_fixture \
    "happy_path.csv.txt" \
    "Happy path — valid timestamps, multiple formats"

run_fixture_expect_summary \
    "overlapping.csv.txt" \
    "Overlapping clips — auto-adjustment applied" \
    "Fixed overlap"

run_fixture_expect_summary \
    "invalid_timestamps.csv.txt" \
    "Invalid timestamp formats — skipped with WARN" \
    "SKIPPED ENTRIES"

run_fixture_expect_summary \
    "start_gte_end.csv.txt" \
    "Start >= End — skipped entries tracked (bug fix check)" \
    "Start time >= End time"

run_fixture_expect_summary \
    "duplicate_titles.csv.txt" \
    "Duplicate titles — all 5 clips attempted (dedup requires live mode)" \
    "CREATED SNIPPETS (5)"

run_fixture_expect_summary \
    "comments_only.csv.txt" \
    "Comments-only CSV — zero extractions, clean exit" \
    "CREATED SNIPPETS (0)"

run_fixture \
    "windows_line_endings.csv.txt" \
    "Windows CRLF line endings — parsed cleanly"

run_fixture_expect_summary \
    "special_chars.csv.txt" \
    "Special chars in titles (colons, slashes, quotes) — sanitized correctly" \
    "CREATED SNIPPETS (4)"

run_fixture_with_flags_expect_pattern \
    "transitions_normal.csv.txt" \
    "Transitions (-t) — fade filter present in ffmpeg command" \
    "-t" \
    "fade=t=in"

run_fixture_with_flags_expect_pattern \
    "transitions_normal.csv.txt" \
    "Transitions (-t) — extraction start shifted back 1 second (1:00 → 00:00:59)" \
    "-t" \
    "\-ss 00:00:59"

run_fixture_with_flags_expect_pattern \
    "transitions_zero_start.csv.txt" \
    "Transitions (-t) — zero start clamped to 00:00:00 (not negative)" \
    "-t" \
    "\-ss 00:00:00"

run_fixture_expect_summary \
    "titles_with_commas.csv.txt" \
    "Commas in titles — clips still extract (bash read puts remainder in last field; officially unsupported)" \
    "CREATED SNIPPETS (3)"

# --- Summary ---

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
