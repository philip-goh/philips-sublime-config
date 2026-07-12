#!/usr/bin/env bash
#
# bootstrap.sh — make this machine's Sublime Text 4 setup match this repo.
#
# Installs Sublime Text, Package Control, and the system runtimes the LSP
# helper packages do NOT manage themselves (clangd, rust-analyzer, python,
# node), then clones this repo into Sublime's Packages/User directory.
#
# Idempotent: safe to run repeatedly. Never deletes an existing User dir —
# it renames it to a timestamped .bak instead.

set -euo pipefail

# Override with SUBLIME_CONFIG_REPO_URL to clone from somewhere else
# (e.g. a local checkout when testing).
REPO_URL="${SUBLIME_CONFIG_REPO_URL:-https://github.com/philip-goh/philips-sublime-config.git}"
PACKAGE_CONTROL_URL="https://packagecontrol.io/Package%20Control.sublime-package"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

# --- OS detection -----------------------------------------------------------

OS="$(uname -s)"
case "$OS" in
    Linux)
        SUBLIME_DIR="$HOME/.config/sublime-text"
        ;;
    Darwin)
        SUBLIME_DIR="$HOME/Library/Application Support/Sublime Text"
        ;;
    *)
        err "Unsupported OS: $OS"
        err "This script supports Linux (Debian/Ubuntu with apt) and macOS."
        exit 1
        ;;
esac
USER_DIR="$SUBLIME_DIR/Packages/User"
INSTALLED_PACKAGES_DIR="$SUBLIME_DIR/Installed Packages"

log "Detected $OS; Sublime config dir: $SUBLIME_DIR"

# --- Sublime Text + system runtimes -----------------------------------------

install_linux() {
    if ! command -v apt-get >/dev/null 2>&1; then
        err "Linux support currently requires apt (Debian/Ubuntu)."
        exit 1
    fi

    if [ ! -f /etc/apt/keyrings/sublimehq-pub.gpg ]; then
        log "Adding Sublime Text apt repository"
        sudo install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg \
            | gpg --dearmor \
            | sudo tee /etc/apt/keyrings/sublimehq-pub.gpg >/dev/null
    else
        log "Sublime Text apt keyring already present"
    fi

    if [ ! -f /etc/apt/sources.list.d/sublime-text.list ]; then
        echo "deb [signed-by=/etc/apt/keyrings/sublimehq-pub.gpg] https://download.sublimetext.com/ apt/stable/" \
            | sudo tee /etc/apt/sources.list.d/sublime-text.list >/dev/null
    fi

    log "Installing Sublime Text and system runtimes via apt"
    sudo apt-get update -qq
    sudo apt-get install -y \
        sublime-text \
        build-essential \
        clangd \
        python3 \
        python3-pip \
        python3-venv \
        nodejs \
        npm \
        git \
        curl
}

install_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        log "Homebrew not found; installing it"
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Put brew on PATH for the rest of this run (Apple Silicon vs Intel).
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        log "Homebrew already installed"
    fi

    if [ -d "/Applications/Sublime Text.app" ]; then
        log "Sublime Text already installed"
    else
        log "Installing Sublime Text via Homebrew cask"
        brew install --cask sublime-text
    fi

    log "Installing system runtimes via Homebrew"
    brew install python node git

    # clangd ships with the Xcode Command Line Tools on macOS.
    if ! xcode-select -p >/dev/null 2>&1; then
        log "Installing Xcode Command Line Tools (provides clangd)"
        log "A GUI prompt may appear; re-run this script after it finishes."
        xcode-select --install
    else
        log "Xcode Command Line Tools already installed (provides clangd)"
    fi
}

case "$OS" in
    Linux)  install_linux ;;
    Darwin) install_macos ;;
esac

# --- Rust toolchain (rustup, never apt/brew) --------------------------------

if command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]; then
    log "rustup already installed"
else
    log "Installing Rust via rustup"
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

# Make rustup usable in this shell even on a first install.
if ! command -v rustup >/dev/null 2>&1; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

log "Ensuring rust-analyzer component is installed"
rustup component add rust-analyzer

# --- Package Control ---------------------------------------------------------

PC_PACKAGE="$INSTALLED_PACKAGES_DIR/Package Control.sublime-package"
if [ -f "$PC_PACKAGE" ]; then
    log "Package Control already installed"
else
    log "Installing Package Control"
    mkdir -p "$INSTALLED_PACKAGES_DIR"
    curl -fsSL "$PACKAGE_CONTROL_URL" -o "$PC_PACKAGE"
fi

# --- This repo as Packages/User ----------------------------------------------

if [ -d "$USER_DIR/.git" ]; then
    log "Packages/User is already a git checkout; pulling latest"
    git -C "$USER_DIR" pull --ff-only
else
    if [ -e "$USER_DIR" ]; then
        BACKUP="$USER_DIR.$(date +%Y%m%d-%H%M%S).bak"
        log "Backing up existing Packages/User to $BACKUP"
        mv "$USER_DIR" "$BACKUP"
    fi
    log "Cloning $REPO_URL into Packages/User"
    mkdir -p "$SUBLIME_DIR/Packages"
    git clone "$REPO_URL" "$USER_DIR"
fi

log "Done. Launch Sublime Text — Package Control will install the packages"
log "listed in 'Package Control.sublime-settings' on first start."
