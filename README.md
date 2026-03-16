# PeacePi Video Splitter

A macOS Finder workflow for downloading Peace Pi Traveling Medicine Show live streams from YouTube and splitting them into individual titled clips — all driven from right-click Quick Actions.

See [QUICKSTART.md](QUICKSTART.md) for a quick reference.

## Table of Contents

- [The Workflow](#the-workflow)
- [Setup](#setup)
- [YouTube URL Format](#youtube-url-format)
- [CSV Format](#csv-format)
- [Fade Transitions](#fade-transitions)
- [Project Structure](#project-structure)
- [Technical Reference](#technical-reference)

## The Workflow

Everything is operated from Finder using three Quick Actions. Right-click a session folder or video file and run them in order:

A **session** represents one video — typically a single live stream recording. Each session has its own folder containing the downloaded source video, the `snippets.csv.txt` timestamp file, the extracted clip files, and the processing log. Sessions are independent of each other and can be organized under any parent folder (e.g., `runs/`) — one per show, date, or recording.

**Step 0 — Create a session folder:**

Create a new folder to hold the video and all its extracted clips. Name it by date or show name (e.g., `2025-09-21/`). The source video, `snippets.csv.txt`, extracted clips, and log file for this session will all live here.

**Step 1 — Right-click the session folder itself:**

Right-click the session folder (not a file inside it) to access these two initialization actions:

1. **Peace Pi Video Splitter - 1) Fetch YouTube video** — prompts for a YouTube URL and downloads the video into the selected folder using `yt-dlp`
2. **Peace Pi Video Splitter - 2) Create snippets CSV file** — creates a `snippets.csv.txt` template in the selected folder and opens it in TextEdit for editing

**Step 2 — Identify timestamps and fill in `snippets.csv.txt`:**

Before filling in the snippets CSV, scrub the video to identify each clip. Open the downloaded video in **QuickLook** (select the file in Finder and press Space) or **QuickTime Player** (double-click). Scrub through the timeline to locate the beginning of a desired clip and note the timestamp shown in the playback position — then do the same for the end of the clip. Also decide on a title for the clip, which will become the output filename. Repeat for each clip you want to extract.

Quick Action 2 (from Step 1) automatically opens `snippets.csv.txt` in TextEdit — enter a line for each clip using the timestamps and titles you identified (see [CSV Format](#csv-format) below).

**Step 3 — Right-click the downloaded `.mp4` file itself:**

At this point, the previous two steps have prepared everything needed for processing: the video file has been downloaded into the session folder (Step 1), and the `snippets.csv.txt` file has been filled in with the timestamps and titles for each clip (Step 2). This step now processes the video file using that metadata and extracts the individual video snippets.

Right-click the video file (not the session folder) to access this action:

3. **Peace Pi Video Splitter - 3) Extract snippets from video** — reads `snippets.csv.txt` from the same folder, extracts each clip using FFmpeg, and saves them as individual `.mp4` files. At startup, a dialog prompts whether to enable **fade transitions** (see [Fade Transitions](#fade-transitions)).

A sound plays and a desktop notification appears when extraction starts and completes, and for each individual segment as it begins. A log file (`ppsplit.log`) is written to the session folder.

## Setup

Double-click `install.command` once to install all dependencies and register the Quick Actions.

This installs Homebrew (if needed), `ffmpeg`, `yt-dlp`, makes `ppsplit.sh` executable, and copies the Quick Actions to `~/Library/Services/`.

## YouTube URL Format

Quick Action 1 accepts all common YouTube URL formats and automatically extracts the video ID:

| Format | Example |
|--------|---------|
| Standard | `https://www.youtube.com/watch?v=DRNqPRj8wcw` |
| With playlist | `https://www.youtube.com/watch?v=DRNqPRj8wcw&list=PL...` |
| With timestamp | `https://www.youtube.com/watch?v=DRNqPRj8wcw&t=120s` |
| Shortened | `https://youtu.be/DRNqPRj8wcw` |
| Embed | `https://www.youtube.com/embed/DRNqPRj8wcw` |

Paste the URL as-is — extra parameters are stripped automatically. Use the **Share → Copy Link** option on the YouTube video page.

## CSV Format

Edit `snippets.csv.txt` in your session folder to define the clips:

```
# start-timestamp, end-timestamp, video-name
7:58,19:55,Opening Set
27:00,29:00,Closing Song
```

Lines beginning with `#` are treated as comments and ignored.

Avoid commas in titles — commas are the field delimiter, so a comma in a title will produce unexpected results. Use a dash or other character instead.

If two clips share the same title, the output files are automatically renamed with a numeric suffix: `title_1.mp4`, `title_2.mp4`, etc.

**Supported timestamp formats:**

| Format | Example |
|--------|---------|
| `MM:SS` | `7:58` |
| `HH:MM:SS` | `1:07:58` |
| `MM:SS.mmm` | `7:58.500` |
| `HH:MM:SS.mmm` | `1:07:58.500` |

## Fade Transitions

Quick Action 3 prompts at startup:

> **"Enable fade in/out transitions?"** — Yes / No (default: No)

When enabled, each extracted segment receives a 1-second **fade-in from black** at the start and a 1-second **fade-out to black** at the end.

To ensure the fade covers only the intended content boundaries, the extraction window is automatically expanded by 1 second on each side:

| | Without transitions | With transitions |
|---|---|---|
| Extraction start | `start_time` | `start_time − 1s` |
| Extraction end | `end_time` | `end_time + 1s` |
| Fade-in | — | frames 0–1s of extracted clip |
| Fade-out | — | final 1s of extracted clip |

**Example:** a segment defined as `13:00 → 14:50` is extracted from `12:59 → 14:51`. The fade-in covers `12:59–13:00` and the fade-out covers `14:50–14:51`. The content at full brightness is still exactly `13:00–14:50`.

If the segment starts within 1 second of the beginning of the source video, the adjusted start is clamped to `0`.

The `-t` flag can also enable transitions when running `ppsplit.sh` directly from the command line (see below).

## Project Structure

```
ppsplit/
├── services/                           # macOS Quick Actions (Automator workflows)
│   ├── Peace Pi Video Splitter - 1) Fetch YouTube video.workflow
│   ├── Peace Pi Video Splitter - 2) Create snippets CSV file.workflow
│   └── Peace Pi Video Splitter - 3) Extract snippets from video.workflow
├── runs/                               # Per-session working folders
│   └── SampleRun/                      # Example session (ready to use)
│       ├── url.txt                     # YouTube URL for this session
│       ├── snippets.csv.txt            # Timestamp definitions for this session
│       └── README.md                   # Step-by-step guide for this session
├── tests/                              # Automated test suites
│   ├── run_all_tests.sh                # Runs all suites
│   ├── test_url_parser.sh              # Layer 1: URL parsing
│   ├── test_ppsplit_debug.sh           # Layer 2: CSV/extraction logic
│   ├── COVERAGE.md                     # Test coverage report
│   └── fixtures/                       # Test input files
│       ├── test_video.mp4              # Synthetic test video (generated once)
│       ├── happy_path.csv.txt
│       ├── overlapping.csv.txt
│       ├── invalid_timestamps.csv.txt
│       ├── start_gte_end.csv.txt
│       ├── duplicate_titles.csv.txt
│       ├── comments_only.csv.txt
│       ├── windows_line_endings.csv.txt
│       ├── special_chars.csv.txt
│       ├── transitions_normal.csv.txt
│       └── transitions_zero_start.csv.txt
├── install.command                     # One-time setup script (double-click to run)
├── ppsplit.sh                          # Extraction engine (called by Quick Action 3)
├── .gitignore
├── QUICKSTART.md                       # Quick reference for experienced users
└── README.md
```

## Technical Reference

### Dependencies

| Tool | Source | Purpose |
|------|--------|---------|
| `ffmpeg` | Homebrew (`brew install ffmpeg`) | Video cutting and re-encoding |
| `yt-dlp` | Homebrew (`brew install yt-dlp`) | YouTube video downloader (Quick Action 1) |
| `bc` | macOS built-in | Floating-point timestamp comparison |
| `awk` | macOS built-in | CSV parsing and script generation |
| `sort` | macOS built-in | Chronological ordering of snippets |
| `afplay` | macOS built-in | Audio cue on start/finish |
| `osascript` | macOS built-in | Desktop notification on start/finish |

### Tool Paths

| Tool | Value |
|------|-------|
| FFmpeg | Auto-detected via `brew --prefix` (works on any Homebrew installation) |
| bc | `/usr/bin/bc` |

### Direct Script Usage

`ppsplit.sh` can also be run directly from the command line:

```bash
./ppsplit.sh <video_file>          # normal run
./ppsplit.sh -d <video_file>       # debug mode (prints commands, no execution)
./ppsplit.sh -t <video_file>       # enable fade in/out transitions
./ppsplit.sh -d -t <video_file>    # debug mode with transitions
./ppsplit.sh -h                    # help
```

### Help Output

```
$ ./ppsplit.sh -h
Usage: ppsplit.sh [-d] [-t] <video_file>
  -d: Debug mode (show commands without executing)
  -t: Enable fade in/out transitions on each segment
See script header for file format details.
```

### Tech Stack

- **Language**: Bash 3.2+ (stock macOS — no Homebrew bash required)
- **Runtime**: macOS only (`afplay`, `osascript`)

## Testing

Test scripts are provided in `tests/`. No YouTube download is required. See [tests/COVERAGE.md](tests/COVERAGE.md) for the full coverage report.

### Run All Tests

```bash
./tests/run_all_tests.sh
```

Runs both suites in sequence and prints a combined pass/fail summary. If the test video is missing, Layer 2 is skipped with instructions to generate it.

### Layer 1 — URL Parser (no setup needed)

```bash
./tests/test_url_parser.sh
```

Tests all supported YouTube URL formats against the video ID extraction logic. 13 cases covering standard, playlist, timestamp, shortened, embed, and invalid inputs.

### Layer 2 — ppsplit.sh Debug Mode

Requires a synthetic test video generated once:

```bash
ffmpeg -f lavfi -i color=c=blue:s=1280x720:r=30 \
       -f lavfi -i sine=frequency=440 \
       -t 300 -c:v libx264 -c:a aac \
       tests/fixtures/test_video.mp4
```

Then run:

```bash
./tests/test_ppsplit_debug.sh
```

Runs 12 CSV fixture scenarios through `ppsplit.sh -d` (debug mode — prints FFmpeg commands without executing):

| Fixture | What it tests |
|---------|--------------|
| `happy_path.csv.txt` | Valid entries across all 4 timestamp formats |
| `overlapping.csv.txt` | Auto-adjustment of overlapping clip boundaries |
| `invalid_timestamps.csv.txt` | Graceful skip of malformed timestamps |
| `start_gte_end.csv.txt` | Entries where start ≥ end are skipped and reported |
| `duplicate_titles.csv.txt` | All clips attempted (live dedup requires real execution) |
| `comments_only.csv.txt` | Zero extractions with clean exit |
| `windows_line_endings.csv.txt` | CRLF line endings handled correctly |
| `special_chars.csv.txt` | Titles with `:`, `/`, `&`, `"` sanitized to safe filenames |
| `transitions_normal.csv.txt` | `-t` flag injects fade filters; extraction window shifted back 1 second |
| `transitions_zero_start.csv.txt` | `-t` flag with `0:00` start — adjusted start clamped to `00:00:00` (not negative) |
| `titles_with_commas.csv.txt` | Commas in titles (unsupported — commas are the CSV delimiter); clips still extract but behavior is undefined |
