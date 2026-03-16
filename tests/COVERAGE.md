# Test Coverage Summary

## How to Run

- `run_all_tests.sh`
- `test_url_parser.sh`
- `test_ppsplit_debug.sh`

---

## Layer 1 — URL Parser (`test_url_parser.sh`)

Tests the video ID extraction logic from Quick Action 1. No network access or video file required.

| # | Test Case | URL Format | Expected ID |
|---|-----------|-----------|-------------|
| 1 | Standard URL | `watch?v=ID` | `DRNqPRj8wcw` |
| 2 | Standard + playlist param | `watch?v=ID&list=...` | `DRNqPRj8wcw` |
| 3 | Standard + timestamp param | `watch?v=ID&t=120s` | `DRNqPRj8wcw` |
| 4 | Standard + multiple extra params | `watch?v=ID&list=...&index=3&t=45s` | `DRNqPRj8wcw` |
| 5 | v= param not first | `watch?list=...&v=ID` | `DRNqPRj8wcw` |
| 6 | Shortened youtu.be | `youtu.be/ID` | `DRNqPRj8wcw` |
| 7 | Shortened + timestamp | `youtu.be/ID?t=120s` | `DRNqPRj8wcw` |
| 8 | Embed URL | `youtube.com/embed/ID` | `DRNqPRj8wcw` |
| 9 | Embed + params | `youtube.com/embed/ID?autoplay=1` | `DRNqPRj8wcw` |
| 10 | Channel URL | `youtube.com/channel/...` | _(empty — error path)_ |
| 11 | Playlist-only URL | `youtube.com/playlist?list=...` | _(empty — error path)_ |
| 12 | Empty string | `""` | _(empty — error path)_ |
| 13 | Garbage input | `not-a-url` | _(empty — error path)_ |

**Total: 13 cases (9 valid formats, 4 invalid/error paths)**

---

## Layer 2 — ppsplit.sh Debug Mode (`test_ppsplit_debug.sh`)

Tests the CSV parsing, validation, and extraction logic in `ppsplit.sh` using `-d` (debug) mode. FFmpeg commands are printed but not executed.

Requires: `tests/fixtures/test_video.mp4` (5-minute synthetic video, generated once via `ffmpeg`).

| # | Fixture | Scenario | What's Verified |
|---|---------|----------|-----------------|
| 1 | `happy_path.csv.txt` | Valid entries in all 4 timestamp formats | Script exits 0; all clips generated in debug output |
| 2 | `overlapping.csv.txt` | Clips with overlapping time ranges | `Fixed overlap` appears in log; adjusted start times |
| 3 | `invalid_timestamps.csv.txt` | Malformed timestamp strings | `SKIPPED ENTRIES` appears in summary |
| 4 | `start_gte_end.csv.txt` | Start time ≥ end time entries | `Start time >= End time` appears in log (validates bug fix) |
| 5 | `duplicate_titles.csv.txt` | 5 clips all titled "Song" | `CREATED SNIPPETS (5)` — all attempted; live dedup requires real execution |
| 6 | `comments_only.csv.txt` | CSV with only comment lines | `CREATED SNIPPETS (0)` — clean exit with zero extractions |
| 7 | `windows_line_endings.csv.txt` | CRLF line endings (`\r\n`) | Script exits 0; `tr -d '\r'` strips correctly |
| 8 | `special_chars.csv.txt` | Titles with `:`, `/`, `&`, `"` | `CREATED SNIPPETS (4)` — sanitize_filename handles all |
| 9 | `transitions_normal.csv.txt` | `-t` flag — fade filter injected into ffmpeg command | `fade=t=in` present in debug output |
| 10 | `transitions_normal.csv.txt` | `-t` flag — extraction window shifted back 1 second | `-ss 00:00:59` present (segment `1:00` → adjusted to `0:59`) |
| 11 | `transitions_zero_start.csv.txt` | `-t` flag — segment starting at `0:00`, adjusted start clamped | `-ss 00:00:00` present (not negative) |
| 12 | `titles_with_commas.csv.txt` | Titles containing commas (unsupported — commas are the delimiter) | `CREATED SNIPPETS (3)` — clips still extract due to bash `read` semantics; behavior is undefined |

**Total: 12 fixture scenarios**

**Recent additions / changes covered:**
- `export LC_NUMERIC=C` — timestamp arithmetic via `bc` is exercised on every fixture run; any locale-sensitive decimal failure would surface here
- `[DEBUG] Output file:` line — visible in debug output for all fixtures that produce clips
- FFMPEG guard (Homebrew path detection + early exit) — exercised implicitly on every test run; the test suite would abort if the guard misfired

---

## What Is NOT Covered by Automated Tests

| Scenario | Reason | How to Test |
|----------|--------|-------------|
| Duplicate filename deduplication (`_1`, `_2`) | `get_unique_filename` checks disk; debug mode never writes files | Run live extraction with duplicate_titles fixture |
| Actual FFmpeg video cutting | Requires real execution | Layer 4: live extraction against test_video.mp4 |
| Quick Action 1 yt-dlp download | Requires network + YouTube | Manual test with a real URL |
| Quick Action 2 CSV template creation | Automator UI | Manual test in Finder |
| Quick Action 3 missing CSV dialog | Automator UI + osascript | Manual test: run QA3 without snippets.csv.txt present |
| Apple Silicon FFmpeg path (`/opt/homebrew/bin`) | Test machine is Intel | Run tests on Apple Silicon Mac |
