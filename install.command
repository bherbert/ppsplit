#!/bin/bash

# install.command - Setup script for Peace Pi Video Splitter
#
# Installs Homebrew (if missing) and all required packages.
# Also installs the Quick Actions into ~/Library/Services/.
#
# Double-click this file in Finder to run, or: ./install.command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Welcome ---

osascript -e 'display dialog "This will install the Peace Pi Video Splitter on your Mac.\n\nYour Mac password may be required during installation. A Terminal window will open — please leave it running until it finishes." with title "Peace Pi Video Splitter" buttons {"Cancel", "Install"} default button "Install" with icon note' \
    | grep -q "Install" || { echo "User cancelled."; exit 0; }

# --- Homebrew ---

echo ""
echo "=================================================="
echo "  Step 1 of 3: Checking Homebrew"
echo "=================================================="

if ! command -v brew &>/dev/null; then
    echo "  Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for the rest of this script (Apple Silicon)
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "  Homebrew already installed: $(brew --version | head -1)"
fi

# --- Required packages ---

echo ""
echo "=================================================="
echo "  Step 2 of 3: Installing required packages"
echo "=================================================="

PACKAGES=(
    ffmpeg  # Video cutting and re-encoding
    yt-dlp  # YouTube video downloader (used by Quick Action 1)
)

for pkg in "${PACKAGES[@]}"; do
    if brew list --formula "$pkg" &>/dev/null; then
        echo "  $pkg already installed"
    else
        echo "  Installing $pkg..."
        brew install "$pkg"
    fi
done

# --- Verify bc (built-in macOS utility, not a Homebrew package) ---

if [[ -x /usr/bin/bc ]]; then
    echo "  bc already available: /usr/bin/bc"
else
    echo ""
    echo "  WARNING: /usr/bin/bc not found. bc is required by ppsplit.sh for"
    echo "    timestamp arithmetic. It ships with macOS but appears to be missing."
    echo "    Run: xcode-select --install  (or reinstall macOS Command Line Tools)"
fi

# --- Make scripts executable ---

chmod +x "$SCRIPT_DIR/ppsplit.sh"

# --- Quick Actions ---

echo ""
echo "=================================================="
echo "  Step 3 of 3: Installing Quick Actions"
echo "=================================================="

SERVICES_SRC="$SCRIPT_DIR/services"
SERVICES_DST="$HOME/Library/Services"

if [[ -d "$SERVICES_SRC" ]]; then
    mkdir -p "$SERVICES_DST"
    cp -R "$SERVICES_SRC/"*.workflow "$SERVICES_DST/"
    # Strip iCloud and other inherited extended attributes that can
    # interfere with service discovery on macOS
    for wf in "$SERVICES_DST/"Peace\ Pi\ Video\ Splitter\ -\ *.workflow; do
        chmod -R 755 "$wf"
        xattr -cr "$wf"
        # NSTouchBarMore is a Touch Bar icon removed in macOS 26+; use NSActionTemplate instead
        plutil -replace NSServices.0.NSIconName -string "NSActionTemplate" "$wf/Contents/Info.plist"
        plutil -remove NSServices.0.NSBackgroundSystemColorName "$wf/Contents/Info.plist" 2>/dev/null || true
        # On macOS 26+, NSRequiredContext prevents Quick Actions from appearing;
        # NSSendFileTypes alone handles file type filtering so the key is not needed.
        # On older macOS the key is kept to preserve Finder-only scoping.
        if [[ $(sw_vers -productVersion | cut -d. -f1) -ge 26 ]]; then
            plutil -remove NSServices.0.NSRequiredContext "$wf/Contents/Info.plist" 2>/dev/null || true
        fi
    done
    echo "  Installed:"
    for wf in "$SERVICES_SRC/"*.workflow; do
        echo "    ✓ $(basename "$wf")"
    done
else
    echo "  Services folder not found — skipping Quick Actions install."
fi

# --- Refresh Services registry and Finder ---

/System/Library/CoreServices/pbs -update
killall Finder

# --- Success ---

echo ""
echo "=================================================="
echo "  Installation complete."
echo "=================================================="

osascript -e 'display dialog "Installation complete!\n\nOne last step to make the actions appear:\n\n1. In Finder, right-click any folder\n2. Hover over \"Quick Actions\"\n3. Click \"Customize…\" at the bottom\n4. Turn on all three Peace Pi Video Splitter items\n5. Click Done\n\nAfter that, right-click a folder for actions 1 and 2, or right-click a video file for action 3." with title "Peace Pi Video Splitter" buttons {"OK"} default button "OK" with icon note'
