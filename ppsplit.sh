#!/bin/bash

# ppsplit.sh - Advanced Video Snippet Extractor for Peace Pi
#
# This script extracts video snippets from a source video file based on
# timestamps defined in a CSV file.
#
# Features include:
# - Automatic handling of overlapping/invalid timestamps
# - Chronological sorting of snippets
# - Duplicate title handling with auto-renaming
# - Millisecond timestamp support
# - Robust extraction using awk-to-source method (fixes line-reading bugs)
#
# Usage: ppsplit.sh [-d] [-t] <video_file>
#   -d: Debug mode (echo commands without executing)
#   -t: Enable fade in/out transitions on each segment
#
# Requirements:
# - macOS with stock Bash 3.2+ (no Bash 4 required)
# - snippets.csv.txt file in same directory as video file
# - ffmpeg and bc installed and accessible
#
# CSV Format: starting-timestamp,ending-timestamp,video-title
# Timestamp formats supported: HH:MM:SS, MM:SS, or HH:MM:SS.mmm, MM:SS.mmm
# Lines beginning with # are ignored (comments)

set -euo pipefail

# --- 1. CONFIGURATION AND GLOBALS ---

DEBUG_MODE=false
TRANSITIONS=false
VIDEO_FILE=""
CSV_FILE=""
LOG_FILE=""
TEMP_CSV=""
TEMP_SCRIPT=""
VIDEO_DIR=""

# External Tool Paths
for BREW_PATH in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$BREW_PATH" ]] && { FFMPEG="$("$BREW_PATH" --prefix)/bin/ffmpeg"; break; }
done
BC="/usr/bin/bc"

# Arrays for tracking results
declare -a CREATED_SNIPPETS=()
declare -a FAILED_SNIPPETS=()
declare -a SKIPPED_SNIPPETS=()
declare -a REMOVED_FILES=()


# --- 2. UTILITY FUNCTIONS ---

# Function: log_message
# Purpose: Logs messages to both standard output (console) and the dedicated log file ($LOG_FILE).
# Parameters:
#   $1 (string): The log level (e.g., "INFO", "WARN", "ERROR").
#   $2 (string): The message content.
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Function: usage
# Purpose: Prints the correct usage syntax of the script and exits.
# Parameters: None
usage() {
    echo "Usage: $0 [-d] [-t] <video_file>"
    echo "  -d: Debug mode (show commands without executing)"
    echo "  -t: Enable fade in/out transitions on each segment"
    echo "See script header for file format details."
    exit 1
}

# Function: timestamp_to_seconds
# Purpose: Converts a video timestamp (HH:MM:SS, MM:SS, with optional .mmm milliseconds)
#          into a total floating-point seconds representation for mathematical comparison.
# Parameters:
#   $1 (string): The timestamp string.
# Returns: The total seconds as a string (e.g., "323.000" for 5:23) or "INVALID" on failure.
timestamp_to_seconds() {
    local timestamp="$1"
    local hours minutes seconds milliseconds
    
    if [[ $timestamp =~ ^([0-9]+):([0-9]+):([0-9]+)\.([0-9]+)$ ]]; then
        hours=${BASH_REMATCH[1]}; minutes=${BASH_REMATCH[2]}; seconds=${BASH_REMATCH[3]}
        milliseconds=$(printf "%03d" "${BASH_REMATCH[4]}")
        echo "$((hours * 3600 + minutes * 60 + seconds)).${milliseconds}"
    elif [[ $timestamp =~ ^([0-9]+):([0-9]+)\.([0-9]+)$ ]]; then
        minutes=${BASH_REMATCH[1]}; seconds=${BASH_REMATCH[2]}
        milliseconds=$(printf "%03d" "${BASH_REMATCH[3]}")
        echo "$((minutes * 60 + seconds)).${milliseconds}"
    elif [[ $timestamp =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        hours=${BASH_REMATCH[1]}; minutes=${BASH_REMATCH[2]}; seconds=${BASH_REMATCH[3]}
        echo "$((hours * 3600 + minutes * 60 + seconds))"
    elif [[ $timestamp =~ ^([0-9]+):([0-9]+)$ ]]; then
        minutes=${BASH_REMATCH[1]}; seconds=${BASH_REMATCH[2]}
        echo "$((minutes * 60 + seconds))"
    else
        echo "INVALID"
    fi
}

# Function: seconds_to_timestamp
# Purpose: Converts a floating-point total seconds value back into an HH:MM:SS.mmm timestamp format.
# Parameters:
#   $1 (string): The total seconds value (e.g., "323.500").
# Returns: The formatted timestamp string (e.g., "00:05:23.500").
seconds_to_timestamp() {
    local total_seconds="$1"
    local int_seconds milliseconds
    
    if [[ $total_seconds =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        int_seconds=${BASH_REMATCH[1]}
        milliseconds=$(printf "%.3s" "${BASH_REMATCH[2]}000")
    else
        int_seconds="$total_seconds"
        milliseconds="000"
    fi
    
    local hours=$((int_seconds / 3600))
    local minutes=$(((int_seconds % 3600) / 60))
    local seconds=$((int_seconds % 60))
    
    if [ "$milliseconds" != "000" ]; then
        printf "%02d:%02d:%02d.%s" "$hours" "$minutes" "$seconds" "$milliseconds"
    else
        printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
    fi
}

# Function: sanitize_filename
# Purpose: Cleans a raw title string to make it safe for use as a file name,
#          replacing illegal characters with underscores and trimming whitespace/dots.
# Parameters:
#   $1 (string): The raw video title.
# Returns: The sanitized filename string.
sanitize_filename() {
    local filename="$1"
    filename=$(echo "$filename" | sed 's/[<>:"/\\|?*]/_/g')
    filename=$(echo "$filename" | sed 's/^[. ]*//;s/[. ]*$//')
    [ -z "$filename" ] && filename="unnamed_snippet"
    echo "$filename"
}

# Function: get_unique_filename
# Purpose: Takes a base name, checks for existing files with that name in the target directory,
#          and returns a guaranteed unique path by appending an incremental counter (e.g., "title_1.mp4").
# Parameters:
#   $1 (string): The desired base filename (already sanitized).
# Returns: The unique, full file path string.
get_unique_filename() {
    local base_name="$1"
    local extension=".mp4"
    local counter=1
    local filename="${VIDEO_DIR}/${base_name}${extension}"
    
    while [ -f "$filename" ]; do
        filename="${VIDEO_DIR}/${base_name}_${counter}${extension}"
        ((counter++))
    done
    
    echo "$filename"
}


# --- 3. CORE PROCESSING FUNCTIONS ---

# Function: process_csv
# Purpose: Reads the raw CSV file, validates the timestamp formats, checks for start_time > end_time errors,
#          and creates a temporary CSV file ($TEMP_CSV) sorted chronologically by start time in seconds.
# Parameters:
#   $1 (string): The path to the raw input CSV file.
process_csv() {
    local csv_file="$1"
    log_message "INFO" "Processing and sorting CSV file..."
    > "$TEMP_CSV"
    
    local line_num=0
    local comment_count=0
    
    # Read CSV, removing carriage returns on the fly
    while IFS=',' read -r start_time end_time title || [ -n "$start_time" ]; do
        ((++line_num))
        [ -z "$start_time" ] && continue
        [[ "$start_time" =~ ^[[:space:]]*# ]] && { ((++comment_count)); continue; }
        
        # Trim whitespace
        start_time=$(echo "$start_time" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        end_time=$(echo "$end_time" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        local start_sec=$(timestamp_to_seconds "$start_time")
        local end_sec=$(timestamp_to_seconds "$end_time")
        
        if [ "$start_sec" = "INVALID" ] || [ "$end_sec" = "INVALID" ]; then
            log_message "WARN" "Line $line_num: Invalid timestamp format - skipping"
            SKIPPED_SNIPPETS+=("Line $line_num: Invalid timestamps ($start_time - $end_time)")
            continue
        fi
        
        if (( $(echo "$start_sec >= $end_sec" | bc -l) )); then
            log_message "WARN" "Line $line_num: Start time >= End time - skipping"
            SKIPPED_SNIPPETS+=("Line $line_num: Start time >= End time ($start_time >= $end_time)")
            continue
        fi
        
        # Format: start_sec,start_time,end_time,title
        echo "$start_sec,$start_time,$end_time,$title" >> "$TEMP_CSV"
        
    done < <(tr -d '\r' < "$csv_file")
   
    # Sort by start time (column 1) numerically
    sort -n -t',' -k1 "$TEMP_CSV" > "${TEMP_CSV}.sorted"
    mv "${TEMP_CSV}.sorted" "$TEMP_CSV"
    
    log_message "INFO" "CSV processing complete - ignored $comment_count comment lines"
}

# Function: fix_overlapping_snippets
# Purpose: Checks the temporally sorted list of snippets and adjusts the start time
#          of any snippet that begins before the previous snippet has ended. This 
#          ensures adjacent video clips are non-overlapping to prevent encoding errors
#          or unexpected content. If a snippet is entirely contained within the previous
#          one after adjustment, it is skipped. The cleaned list is written back to $TEMP_CSV.
# Parameters: None (operates on $TEMP_CSV)
fix_overlapping_snippets() {
    log_message "INFO" "Checking for overlapping snippets..."
    
    local temp_fixed="$VIDEO_DIR/temp_snippets_fixed.csv"
    > "$temp_fixed"
    
    local prev_end_sec=0
    local fixed_count=0
    
    while IFS=',' read -r start_sec start_time end_time title; do
        local end_sec=$(timestamp_to_seconds "$end_time")
        
        if (( $(echo "$start_sec < $prev_end_sec" | bc -l) )); then
            local new_start_sec="$prev_end_sec"
            local new_start_time=$(seconds_to_timestamp "$new_start_sec")
            log_message "WARN" "Fixed overlap: Adjusted start time from $start_time to $new_start_time for '$title'"
            start_time="$new_start_time"
            start_sec="$new_start_sec"
            ((++fixed_count))
        fi

        if (( $(echo "$start_sec < $end_sec" | bc -l) )); then
            echo "$start_sec,$start_time,$end_time,$title" >> "$temp_fixed"
            prev_end_sec="$end_sec"
        else
            log_message "WARN" "Skipping snippet '$title' - invalid after overlap fix"
            SKIPPED_SNIPPETS+=("'$title': Invalid after overlap fix")
        fi
        
    done < "$TEMP_CSV"
    
    mv "$temp_fixed" "$TEMP_CSV"
    log_message "INFO" "Fixed $fixed_count overlapping snippets"
}


# --- 4. EXTRACTION AND SUMMARY FUNCTIONS ---

# Function: extract_snippet
# Purpose: Executes the FFmpeg command to cut a video snippet using the provided timestamps,
#          ensures the output filename is unique, and logs the result.
# Parameters:
#   $1 (string): The start timestamp string (e.g., "00:05:23").
#   $2 (string): The end timestamp string (e.g., "00:10:15").
#   $3 (string): The video title used for the output filename.
extract_snippet() {
    local start_time="$1"
    local end_time="$2"
    local title="$3"
    
    local safe_title=$(sanitize_filename "$title")
    local output_file=$(get_unique_filename "$safe_title")
    
    local ffmpeg_cmd
    if [ "$TRANSITIONS" = true ]; then
        local start_sec end_sec adj_start_sec adj_end_sec adj_start_time adj_end_time duration fade_out_start
        start_sec=$(timestamp_to_seconds "$start_time")
        end_sec=$(timestamp_to_seconds "$end_time")
        adj_start_sec=$(echo "$start_sec - 1" | "$BC")
        adj_end_sec=$(echo "$end_sec + 1" | "$BC")
        if [ "$(echo "$adj_start_sec < 0" | "$BC")" = "1" ]; then adj_start_sec=0; fi
        adj_start_time=$(seconds_to_timestamp "$adj_start_sec")
        adj_end_time=$(seconds_to_timestamp "$adj_end_sec")
        duration=$(echo "$adj_end_sec - $adj_start_sec" | "$BC")
        fade_out_start=$(echo "$duration - 1" | "$BC")
        ffmpeg_cmd="$FFMPEG -y -ss $adj_start_time -to $adj_end_time -i \"$VIDEO_FILE\" \
    -vf \"fade=t=in:st=0:d=1,fade=t=out:st=${fade_out_start}:d=1\" \
    -af \"afade=t=in:st=0:d=1,afade=t=out:st=${fade_out_start}:d=1\" \
    -c:v libx264 -c:a aac -hide_banner -loglevel error -nostats \"$output_file\""
    else
        ffmpeg_cmd="$FFMPEG -y -ss $start_time -to $end_time -i \"$VIDEO_FILE\" \
    -c:v libx264 -c:a aac -hide_banner -loglevel error -nostats \"$output_file\""
    fi
    
    if [ "$DEBUG_MODE" = true ]; then
        echo "[DEBUG] Would execute: $ffmpeg_cmd"
        CREATED_SNIPPETS+=("$(basename "$output_file") (DEBUG MODE)")
    else
        log_message "INFO" "Extracting: $(basename "$output_file") ($start_time to $end_time)"
        
        if eval "$ffmpeg_cmd" 2>>"$LOG_FILE"; then
            CREATED_SNIPPETS+=("$(basename "$output_file")")
            log_message "INFO" "Successfully created: $(basename "$output_file")"
        else
            FAILED_SNIPPETS+=("$(basename "$output_file")")
            log_message "ERROR" "Failed to create: $(basename "$output_file")"
        fi
    fi
}

# Function: dump_temp_csv
# Purpose: Logs the current contents of the temporary, processed CSV file ($TEMP_CSV).
#          Useful for debugging and verifying the processing and overlap fixes.
# Parameters: None
dump_temp_csv() {
    log_message "INFO" "--- Contents of $TEMP_CSV (Start time in seconds, Start time, End time, Title) ---"
    
    if [ ! -f "$TEMP_CSV" ]; then
        log_message "INFO" "Temporary CSV file not found: $TEMP_CSV"
        return
    fi
    
    while IFS= read -r line; do
        log_message "INFO" "CSV LINE: $line"
    done < "$TEMP_CSV"
    
    log_message "INFO" "----------------------------------------------------------------------------------"
}

# Function: display_summary
# Purpose: Compiles and logs a final summary of the extraction process, including
#          successful, failed, and skipped snippets, as well as any removed files.
#          All output uses the log_message "INFO" function.
# Parameters: None
display_summary() {
    log_message "INFO" ""
    log_message "INFO" "=================================================="
    log_message "INFO" "           EXTRACTION SUMMARY"
    log_message "INFO" "=================================================="
    log_message "INFO" "Input video: $VIDEO_FILE"
    log_message "INFO" "Video directory: $VIDEO_DIR"
    log_message "INFO" "CSV file: $CSV_FILE"
    log_message "INFO" "Debug mode: $DEBUG_MODE"
    log_message "INFO" ""
    
    log_message "INFO" "CREATED SNIPPETS (${#CREATED_SNIPPETS[@]}):"
    if [ ${#CREATED_SNIPPETS[@]} -eq 0 ]; then
        log_message "INFO" "  None"
    else
        for snippet in "${CREATED_SNIPPETS[@]}"; do
            log_message "INFO" "  ✓ $snippet"
        done
    fi
    log_message "INFO" ""
    
    if [ ${#FAILED_SNIPPETS[@]} -gt 0 ]; then
        log_message "INFO" "FAILED SNIPPETS (${#FAILED_SNIPPETS[@]}):"
        for snippet in "${FAILED_SNIPPETS[@]}"; do
            log_message "INFO" "  ✗ $snippet"
        done
        log_message "INFO" ""
    fi
    
    if [ ${#SKIPPED_SNIPPETS[@]} -gt 0 ]; then
        log_message "INFO" "SKIPPED ENTRIES (${#SKIPPED_SNIPPETS[@]}):"
        for snippet in "${SKIPPED_SNIPPETS[@]}"; do
            log_message "INFO" "  ⚠ $snippet"
        done
        log_message "INFO" ""
    fi
    
    if [ ${#REMOVED_FILES[@]} -gt 0 ]; then
        log_message "INFO" "REMOVED FILES (${#REMOVED_FILES[@]}):"
        for file in "${REMOVED_FILES[@]}"; do
            log_message "INFO" "  🗑 $file"
        done
        log_message "INFO" ""
    fi
    
    log_message "INFO" "Log file: $LOG_FILE"
    log_message "INFO" "=================================================="
}

# Function: cleanup_existing_videos
# Purpose: Removes existing .mp4 files in the video directory, excluding the main source video,
#          to ensure a clean slate before extraction runs.
# Parameters:
#   $1 (string): The path to the main source video file (to be kept).
cleanup_existing_videos() {
    local keep_file="$1"
    local keep_basename=$(basename "$keep_file")
    local removed_count=0
    
    log_message "INFO" "Cleaning up existing video files in $VIDEO_DIR (keeping $keep_basename)..."
    
    for file in "$VIDEO_DIR"/*.mp4; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "$keep_basename" ]; then
            rm -f "$file"
            REMOVED_FILES+=("$(basename "$file")")
            ((++removed_count))
        fi
    done
    log_message "INFO" "Removed $removed_count existing video files"
}

# Function: cleanup
# Purpose: Cleans up all temporary files created during script execution ($TEMP_CSV, $TEMP_SCRIPT).
# Parameters: None
cleanup() {
    rm -f "$TEMP_CSV" "$TEMP_CSV.sorted" "$VIDEO_DIR/temp_snippets_fixed.csv" "$TEMP_SCRIPT"
}


# --- 5. MAIN EXECUTION ---

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug) DEBUG_MODE=true; shift ;;
        -t|--transitions) TRANSITIONS=true; shift ;;
        -h|--help) usage ;;
        *)
            if [ -z "$VIDEO_FILE" ]; then
                VIDEO_FILE="$1"
            else
                echo "Error: Multiple video files specified"; usage
            fi
            shift ;;
    esac
done

# Validation and Setup
if [ -z "$VIDEO_FILE" ] || [ ! -f "$VIDEO_FILE" ]; then
    echo "Error: Video file not specified or not found."
    usage
fi

VIDEO_FILE=$(realpath "$VIDEO_FILE")
VIDEO_DIR=$(dirname "$VIDEO_FILE")
CSV_FILE="$VIDEO_DIR/snippets.csv.txt"
LOG_FILE="$VIDEO_DIR/ppsplit.log"
TEMP_CSV="$VIDEO_DIR/temp_snippets_sorted.csv"
TEMP_SCRIPT="$VIDEO_DIR/temp_extract_script.sh"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file 'snippets.csv.txt' not found in $VIDEO_DIR"
    exit 1
fi

if { [ ! -x "$FFMPEG" ] || [ ! -x "$BC" ]; } && [ "$DEBUG_MODE" = false ]; then
    echo "Error: Required tool(s) (ffmpeg at $FFMPEG or bc at $BC) not found."
    exit 1
fi

afplay /System/Library/Sounds/Funk.aiff
osascript -e 'display notification "Video extraction process started..." with title "Peace Pi Video Splitter"'

# Initialize log file and start logging
> "$LOG_FILE"
log_message "INFO" "Starting ppsplit.sh - Advanced Video Snippet Extractor"
log_message "INFO" "Video file: $VIDEO_FILE"
log_message "INFO" "Debug mode: $DEBUG_MODE"

# 1. Cleanup and Process
cleanup_existing_videos "$VIDEO_FILE"
process_csv "$CSV_FILE"
dump_temp_csv # Show the initial sorted state

# 2. Fix and Finalize
fix_overlapping_snippets
dump_temp_csv # Show the state after fixing overlaps

# 3. Extract Snippets (Using Awk-to-Source)
log_message "INFO" "Starting snippet extraction (Awk-to-Source method)..."

# Generate the script containing function calls
awk -F',' '{
    # Fields: $1=start_sec, $2=start_time, $3=end_time, $4=title
    printf "extract_snippet \"%s\" \"%s\" \"%s\"\n", $2, $3, $4
}' "$TEMP_CSV" > "$TEMP_SCRIPT"

# Execute the generated script
. "$TEMP_SCRIPT"

# 4. Summary
display_summary

log_message "INFO" "Extraction process completed"

afplay /System/Library/Sounds/Glass.aiff
osascript -e 'display notification "Video extraction process completed." with title "Peace Pi Video Splitter"'

exit 0