#!/bin/bash

# install.command - Setup script for Peace Pi Video Splitter
#
# Installs ffmpeg and yt-dlp (via Homebrew or as standalone binaries),
# then copies the Quick Actions to ~/Library/Services/.
#
# Double-click this file in Finder to run, or: ./install.command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PPSPLIT_BIN="$HOME/Library/Application Support/PeacePi/bin"

# --- Remove quarantine ---
#
# When files are downloaded from the internet (e.g. a GitHub release zip),
# macOS tags them with com.apple.quarantine. Clear it from the entire project
# folder so the workflows and scripts install without Gatekeeper interference.

xattr -cr "$SCRIPT_DIR" 2>/dev/null || true

# --- Welcome ---

osascript -e 'display dialog "This will install the Peace Pi Video Splitter on your Mac.\n\nA Terminal window will open — please leave it running until it finishes." with title "Peace Pi Video Splitter" buttons {"Cancel", "Install"} default button "Install" with icon note' \
    | grep -q "Install" || { echo "User cancelled."; exit 0; }

# --- Detect installation method ---
#
# If Xcode Command Line Tools are present (git is available), use Homebrew.
# If not, offer standalone binaries (~60 MB, no Xcode tools needed).

INSTALL_CHOICE="Homebrew"

if ! command -v git &>/dev/null; then
    echo ""
    echo "  Xcode Command Line Tools not found — offering standalone install."
    STANDALONE_CHOICE=""
    if OSASCRIPT_OUT=$(osascript -e 'display dialog "Xcode Command Line Tools are not installed on this Mac. The standard Homebrew installation requires them (~1\u20132 GB download).\n\nAlternatively, Peace Pi Video Splitter can install small standalone tool binaries (~60 MB) that require no Xcode tools or Homebrew.\n\nWould you like to use the standalone install, or install Xcode tools first and use Homebrew?" with title "Peace Pi Video Splitter" buttons {"Cancel", "Install Xcode Tools", "Use Standalone"} default button "Use Standalone" with icon note' 2>/dev/null); then
        STANDALONE_CHOICE=$(echo "$OSASCRIPT_OUT" | grep -o 'Install Xcode Tools\|Use Standalone' || true)
    fi

    if [[ -z "$STANDALONE_CHOICE" ]]; then
        echo "  User cancelled."
        exit 0
    elif [[ "$STANDALONE_CHOICE" == "Install Xcode Tools" ]]; then
        osascript -e 'display dialog "Click OK, then click Install in the dialog that appears. When the Xcode tools finish installing, double-click install.command again to continue." with title "Peace Pi Video Splitter" buttons {"OK"} default button "OK" with icon caution'
        xcode-select --install 2>/dev/null || true
        exit 1
    else
        INSTALL_CHOICE="Standalone"
    fi
fi

echo ""
echo "Installation method: $INSTALL_CHOICE"

# ==========================================================
# PATH A: Homebrew
# ==========================================================

if [[ "$INSTALL_CHOICE" == "Homebrew" ]]; then

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
        BREW_VER=$(brew --version 2>/dev/null | grep "^Homebrew" | head -1 || true)
        if [[ -z "$BREW_VER" ]]; then
            echo "  Homebrew is installed but cannot run on this macOS version."
            BREW_RESPONSE=$(osascript -e 'display dialog "Homebrew is installed but is too old to run on this version of macOS. It needs to be updated before installation can continue.\n\nWould you like to update Homebrew automatically now?" with title "Peace Pi Video Splitter" buttons {"Cancel", "Update Homebrew"} default button "Update Homebrew" with icon caution')
            if ! echo "$BREW_RESPONSE" | grep -q "Update Homebrew"; then
                echo "  User cancelled."
                exit 0
            fi
            echo "  Updating Homebrew..."
            # Unshallow any shallow tap clones — a legacy state that blocks brew update
            for TAP_PATH in \
                /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core \
                /usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask \
                /opt/homebrew/Library/Taps/homebrew/homebrew-core \
                /opt/homebrew/Library/Taps/homebrew/homebrew-cask; do
                if [[ -d "$TAP_PATH/.git" ]]; then
                    echo "  Unshallowing $(basename "$TAP_PATH") (may take a few minutes)..."
                    git -C "$TAP_PATH" fetch --unshallow 2>/dev/null || true
                fi
            done
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/homebrew/install/HEAD/install.sh)"
            # Add Homebrew to PATH for Intel Macs after reinstall
            if [[ -x /usr/local/bin/brew ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            BREW_VER=$(brew --version 2>/dev/null | grep "^Homebrew" | head -1 || true)
            echo "  Homebrew updated: $BREW_VER"
        fi
        echo "  Homebrew already installed: $BREW_VER"
    fi

    # --- Fix Homebrew directory permissions (Intel Mac) ---
    #
    # On Intel Macs, various /usr/local subdirectories can end up with wrong
    # ownership, preventing Homebrew from installing packages. Check the known
    # problem leaf directories first; only run chown if one is not writable.

    if [[ -x /usr/local/bin/brew ]]; then
        NEEDS_CHOWN=false
        for _dir in \
            /usr/local/var/homebrew/locks \
            /usr/local/share/zsh/site-functions \
            /usr/local/share/fish/vendor_completions.d; do
            if [[ -d "$_dir" && ! -w "$_dir" ]]; then
                NEEDS_CHOWN=true
                break
            fi
        done

        if [[ "$NEEDS_CHOWN" == true ]]; then
            echo "  Fixing Homebrew directory ownership..."
            echo "  (Your password is needed to fix directory permissions in /usr/local)"
            sudo chown -R "$(whoami)" /usr/local/var/homebrew 2>/dev/null || true
            sudo chown -R "$(whoami)" /usr/local/Homebrew 2>/dev/null || true
            sudo chown -R "$(whoami)" /usr/local/share 2>/dev/null || true
        fi
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

# ==========================================================
# PATH B: Standalone binaries
# ==========================================================

else

    echo ""
    echo "=================================================="
    echo "  Step 1 of 3: Downloading standalone tools"
    echo "=================================================="

    ARCH=$(uname -m)
    echo "  Architecture: $ARCH"
    mkdir -p "$PPSPLIT_BIN"

    # yt-dlp — universal macOS binary, always latest from GitHub
    echo "  Downloading yt-dlp..."
    curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
        -o "$PPSPLIT_BIN/yt-dlp"
    chmod +x "$PPSPLIT_BIN/yt-dlp"
    YTDLP_VER=$("$PPSPLIT_BIN/yt-dlp" --version 2>/dev/null || echo "unknown")
    echo "  yt-dlp installed: $YTDLP_VER"

    # ffmpeg — architecture-specific static build from evermeet.cx
    echo "  Downloading ffmpeg ($ARCH)..."
    EVERMEET=$(curl -fsS "https://evermeet.cx/ffmpeg/" 2>/dev/null || true)
    FFMPEG_FILE=$(echo "$EVERMEET" | grep -o 'ffmpeg-[0-9][0-9]*\.[0-9][^"<]*\.zip' \
        | grep -v 'ffprobe\|ffplay' | head -1)

    if [[ -z "$FFMPEG_FILE" ]]; then
        echo "  Error: Could not determine latest ffmpeg version from evermeet.cx"
        osascript -e 'display dialog "Could not automatically download ffmpeg. Please check your internet connection and try again, or re-run install.command and choose Homebrew instead." with title "Peace Pi Video Splitter" buttons {"OK"} default button "OK" with icon caution'
        exit 1
    fi

    if [[ "$ARCH" == "arm64" ]]; then
        FFMPEG_URL="https://evermeet.cx/pub/ffmpeg/arm/$FFMPEG_FILE"
    else
        FFMPEG_URL="https://evermeet.cx/pub/ffmpeg/$FFMPEG_FILE"
    fi

    FFMPEG_TMP=$(mktemp -d)
    curl -fsSL "$FFMPEG_URL" -o "$FFMPEG_TMP/ffmpeg.zip"
    unzip -q "$FFMPEG_TMP/ffmpeg.zip" -d "$FFMPEG_TMP"
    cp "$FFMPEG_TMP/ffmpeg" "$PPSPLIT_BIN/ffmpeg"
    chmod +x "$PPSPLIT_BIN/ffmpeg"
    rm -rf "$FFMPEG_TMP"
    FFMPEG_VER=$("$PPSPLIT_BIN/ffmpeg" -version 2>/dev/null | head -1 | grep -o 'ffmpeg version [^ ]*' || echo "unknown")
    echo "  ffmpeg installed: $FFMPEG_VER"

    echo ""
    echo "=================================================="
    echo "  Step 2 of 3: (no Homebrew packages needed)"
    echo "=================================================="

fi

# ==========================================================
# COMMON: scripts, Quick Actions, notifications
# ==========================================================

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
        plutil -remove NSServices.0.NSBackgroundSystemColorName "$wf/Contents/Info.plist" >/dev/null 2>&1 || true
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

# --- Register notification permission ---
#
# macOS attributes osascript notifications to "Script Editor" in System Settings.
# Running this once during install registers the app in the Notifications list
# so the user can enable or adjust it there.

# --- Refresh Services registry and Finder ---

/System/Library/CoreServices/pbs -update
killall Finder

# --- Success ---

echo ""
echo "=================================================="
echo "  Installation complete."
echo "=================================================="

osascript 2>/dev/null << 'EOF'
display dialog "Installation complete!" & return & return & "One last step to make the actions appear:" & return & return & "1. In Finder, right-click any folder" & return & "2. Hover over " & quote & "Quick Actions" & quote & return & "3. Click " & quote & "Customize..." & quote & " at the bottom" & return & "4. Turn on all three Peace Pi Video Splitter items" & return & "5. Click Done" & return & return & "After that, right-click a folder for actions 1 and 2, or right-click a video file for action 3." with title "Peace Pi Video Splitter" buttons {"OK"} default button "OK" with icon note
EOF

osascript 2>/dev/null << 'EOF'
display dialog "Peace Pi Video Splitter sends desktop notifications when extraction starts and completes, and for each clip." & return & return & "The first time you run Quick Action 3, macOS will add the notification source to System Settings > Notifications automatically." & return & return & "If notifications still don't appear after your first run, open System Settings > Notifications and look for Script Editor or Automator." with title "About Notifications" buttons {"OK"} default button "OK" with icon note
EOF
