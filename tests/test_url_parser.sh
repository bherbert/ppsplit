#!/bin/bash

# test_url_parser.sh - Unit tests for YouTube URL parsing logic
#
# Tests the video ID extraction from all supported URL formats.
# No network access required.
#
# Usage: ./tests/test_url_parser.sh

PASS=0
FAIL=0

# --- URL parsing function (mirrors Quick Action 1 logic) ---
# Note: regex patterns stored in variables to avoid bash 3.2 parser issues with & in [[ =~ ]]

RE_WATCH='[?&]v=([^&]+)'
RE_SHORT='youtu\.be/([^?&]+)'
RE_EMBED='youtube\.com/embed/([^?&]+)'

extract_video_id() {
    local URL="$1"
    local VIDEO_ID=""

    if [[ "$URL" =~ $RE_WATCH ]]; then
        VIDEO_ID="${BASH_REMATCH[1]}"
    elif [[ "$URL" =~ $RE_SHORT ]]; then
        VIDEO_ID="${BASH_REMATCH[1]}"
    elif [[ "$URL" =~ $RE_EMBED ]]; then
        VIDEO_ID="${BASH_REMATCH[1]}"
    fi

    echo "$VIDEO_ID"
}

# --- Test runner ---

assert_id() {
    local description="$1"
    local url="$2"
    local expected_id="$3"

    local actual_id
    actual_id=$(extract_video_id "$url")

    if [[ "$actual_id" == "$expected_id" ]]; then
        echo "  PASS  $description"
        ((PASS++))
    else
        echo "  FAIL  $description"
        echo "        URL:      $url"
        echo "        Expected: '$expected_id'"
        echo "        Got:      '$actual_id'"
        ((FAIL++))
    fi
}

# --- Test cases ---

echo ""
echo "=== URL Parser Tests ==="
echo ""

# Happy path — each supported format
assert_id "Standard URL" \
    "https://www.youtube.com/watch?v=DRNqPRj8wcw" \
    "DRNqPRj8wcw"

assert_id "Standard URL with playlist param" \
    "https://www.youtube.com/watch?v=DRNqPRj8wcw&list=PLxxxxx" \
    "DRNqPRj8wcw"

assert_id "Standard URL with timestamp param" \
    "https://www.youtube.com/watch?v=DRNqPRj8wcw&t=120s" \
    "DRNqPRj8wcw"

assert_id "Standard URL with multiple extra params" \
    "https://www.youtube.com/watch?v=DRNqPRj8wcw&list=PLxxxxx&index=3&t=45s" \
    "DRNqPRj8wcw"

assert_id "v= param not first (list before v)" \
    "https://www.youtube.com/watch?list=PLxxxxx&v=DRNqPRj8wcw" \
    "DRNqPRj8wcw"

assert_id "Shortened youtu.be URL" \
    "https://youtu.be/DRNqPRj8wcw" \
    "DRNqPRj8wcw"

assert_id "Shortened youtu.be URL with timestamp" \
    "https://youtu.be/DRNqPRj8wcw?t=120s" \
    "DRNqPRj8wcw"

assert_id "Embed URL" \
    "https://www.youtube.com/embed/DRNqPRj8wcw" \
    "DRNqPRj8wcw"

assert_id "Embed URL with params" \
    "https://www.youtube.com/embed/DRNqPRj8wcw?autoplay=1" \
    "DRNqPRj8wcw"

# Error cases — should return empty string
assert_id "Channel URL (no video ID)" \
    "https://www.youtube.com/channel/UCxxxxx" \
    ""

assert_id "Playlist-only URL (no video ID)" \
    "https://www.youtube.com/playlist?list=PLxxxxx" \
    ""

assert_id "Empty string" \
    "" \
    ""

assert_id "Garbage input" \
    "not-a-url" \
    ""

# --- Summary ---

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
