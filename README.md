# PeacePi Video Splitter (ppsplit)

## Overview

`ppsplit.sh` is a macOS bash script that extracts named video snippets from a source video file using timestamps defined in a CSV file. It was created to split recorded live streams (specifically Peace Pi Traveling Medicine Show performances) into individual titled clips.

## Tech Stack

- **Language**: Bash (requires Bash 4+ for associative arrays)
- **Framework**: None
- **Runtime**: macOS (uses `afplay` and `osascript` for audio/notification feedback)

## Prerequisites

The following programs must be installed and accessible before running the script:

- **FFmpeg** — video processing tool, expected at `/usr/local/bin/ffmpeg`
  - Install via Homebrew: `brew install ffmpeg`
- **bc** — arbitrary-precision calculator for timestamp math, expected at `/usr/bin/bc`
  - Included with macOS by default
- **macOS** — the script uses `afplay` (audio cue) and `osascript` (desktop notifications), which are macOS-only
- **Bash 4+** — macOS ships with Bash 3 by default; upgrade via Homebrew if needed: `brew install bash`

## Installation

Run the included setup script to install Homebrew (if needed), all required packages, and the Quick Actions:

```bash
chmod +x install.sh
./install.sh
```

Then copy `ppsplit.sh.txt` to your working directory and make it executable:

```bash
cp Resources/ppsplit.sh.txt ppsplit.sh
chmod +x ppsplit.sh
```

## Usage

Place the script, your source video file, and the `snippets.csv.txt` file in the **same directory**, then run:

```bash
./ppsplit.sh <video_file>
```

**Debug mode** (prints commands without executing them):

```bash
./ppsplit.sh -d <video_file>
```

**Help:**

```bash
./ppsplit.sh -h
```

### What it does

1. Reads `snippets.csv.txt` from the same directory as the video
2. Validates and sorts snippets chronologically
3. Detects and fixes overlapping timestamp ranges
4. Removes any previously extracted `.mp4` files in the directory (keeps the source video)
5. Extracts each snippet using FFmpeg (`libx264` video, `aac` audio)
6. Writes a log file (`ppsplit_errors.log`) and displays a summary
7. Plays a system sound and sends a desktop notification on start and completion

## CSV Format

Create a file named `snippets.csv.txt` in the same folder as your video:

```
# start-timestamp, end-timestamp, video-name
27:00,29:00,Clip Title Here
7:58,19:55,Another Clip
```

**Supported timestamp formats:**

| Format | Example |
|--------|---------|
| `MM:SS` | `7:58` |
| `HH:MM:SS` | `1:07:58` |
| `MM:SS.mmm` | `7:58.500` |
| `HH:MM:SS.mmm` | `1:07:58.500` |

Lines beginning with `#` are treated as comments and ignored.

## Project Structure

```
PeacePi/
├── Resources/
│   ├── ppsplit.sh.txt          # Main script source
│   ├── url.txt                 # YouTube source video URL
│   └── ppsplit_errors.log      # Runtime log (generated)
├── Services/                   # macOS Quick Actions (Automator workflows)
├── 2025-09-21/                 # Example session folder
│   ├── *.mp4                   # Source video for that session
│   └── snippets.csv.txt        # Timestamp definitions for that session
├── PeacePiVideoExtractor.mp4   # Demo/walkthrough video
├── install.sh                  # Setup script (Homebrew, packages, Quick Actions)
└── README.md
```

## Quick Actions (macOS Services)

The `Services/` folder contains macOS Quick Actions (Automator `.workflow` files). To install them:

1. Copy the `.workflow` files from the `Services/` folder to `~/Library/Services/`
2. The actions will immediately appear in Finder's right-click context menu and the **Services** menu

## Dependencies

This script has no package manager dependencies. It relies entirely on system tools:

| Tool | Source | Purpose |
|------|--------|---------|
| `ffmpeg` | Homebrew (`brew install ffmpeg`) | Video cutting and re-encoding |
| `bc` | macOS built-in | Floating-point timestamp comparison |
| `awk` | macOS built-in | CSV parsing and script generation |
| `sort` | macOS built-in | Chronological ordering of snippets |
| `afplay` | macOS built-in | Audio cue on start/finish |
| `osascript` | macOS built-in | Desktop notification on start/finish |

## Environment Variables

Not configured. All paths are hardcoded or derived from the input video file path.

| Setting | Location | Default |
|---------|----------|---------|
| FFmpeg path | Line 39 in script | `/usr/local/bin/ffmpeg` |
| bc path | Line 40 in script | `/usr/bin/bc` |

> **Note:** If FFmpeg is installed via Homebrew on Apple Silicon, it may be at `/opt/homebrew/bin/ffmpeg`. Update line 39 of the script accordingly.

## Testing

Not configured. Test manually using debug mode (`-d` flag), which prints all FFmpeg commands without executing them.

## License

Not specified.
