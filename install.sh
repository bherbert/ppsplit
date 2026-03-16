#!/bin/bash

# install.sh - Setup script for Peace Pi Video Splitter
#
# Installs Homebrew (if missing) and all required packages.
# Also installs the Quick Actions into ~/Library/Services/.
#
# Usage: ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Homebrew ---

if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for the rest of this script (Apple Silicon)
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed: $(brew --version | head -1)"
fi

# --- Required packages ---

PACKAGES=(
    ffmpeg  # Video cutting and re-encoding
    yt-dlp  # YouTube video downloader (used by Quick Action 1)
)

echo ""
echo "Installing required packages..."
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
    echo "WARNING: /usr/bin/bc not found. bc is required by ppsplit.sh for"
    echo "  timestamp arithmetic. It ships with macOS but appears to be missing."
    echo "  Run: xcode-select --install  (or reinstall macOS Command Line Tools)"
fi

# --- Make scripts executable ---

chmod +x "$SCRIPT_DIR/ppsplit.sh"
echo "Made ppsplit.sh executable."

# --- Quick Actions ---

SERVICES_SRC="$SCRIPT_DIR/services"
SERVICES_DST="$HOME/Library/Services"

if [[ -d "$SERVICES_SRC" ]]; then
    echo ""
    echo "Installing Quick Actions to ~/Library/Services/..."
    mkdir -p "$SERVICES_DST"
    cp -R "$SERVICES_SRC/"*.workflow "$SERVICES_DST/"
    echo "  Installed:"
    for wf in "$SERVICES_SRC/"*.workflow; do
        echo "    ✓ $(basename "$wf")"
    done
else
    echo "Services folder not found — skipping Quick Actions install."
fi

# --- Summary ---

echo ""
echo "=================================================="
echo "  Installation complete."
echo ""
echo "  ffmpeg path: $(brew --prefix ffmpeg)/bin/ffmpeg"
echo ""
echo "  ppsplit.sh auto-detects your Mac architecture and will use"
echo "  the correct ffmpeg path for Intel or Apple Silicon."
echo "=================================================="
