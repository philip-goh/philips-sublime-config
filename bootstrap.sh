#!/usr/bin/env bash
#
# bootstrap.sh — make this machine's Sublime Text 4 setup match this repo.
#
# Installs Sublime Text, Package Control, and the system runtimes the LSP
# helper packages do NOT manage themselves (clangd, rust-analyzer, python,
# node, shellcheck, shfmt), plus SQLFluff via pipx for the SQL build system.
# Then clones this repo into Sublime's Packages/User directory and prunes
# packages this repo has dropped.
#
# Idempotent: safe to run repeatedly. Present components are left alone,
# missing ones are installed, outdated ones are upgraded, and Package
# Control's runtime drift is recovered from a backup rather than clobbered.
# Never deletes an existing User dir — it renames it to a timestamped .bak.

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
        pipx \
        git \
        curl \
        shellcheck \
        shfmt
}

install_macos() {
    # Put an existing Homebrew on PATH even when this shell lacks it
    # (GUI-launched shells often do), so re-runs don't try to reinstall it.
    load_brew() {
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    }

    if ! command -v brew >/dev/null 2>&1; then
        load_brew
    fi

    if ! command -v brew >/dev/null 2>&1; then
        log "Homebrew not found; installing it"
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        load_brew
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
    brew install python node git shellcheck shfmt pipx

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

# --- SQLFluff (SQL linting + formatting) -------------------------------------
# Used by SQLFluff.sublime-build. Installed with pipx because distro and
# Homebrew Python are PEP 668 "externally managed" and refuse plain pip
# installs into the system interpreter. `pipx upgrade` is a no-op when the
# app is already current, so re-runs converge instead of piling up versions.

if ! command -v pipx >/dev/null 2>&1; then
    err "pipx not found; skipping SQLFluff (SQL lint/format will be unavailable)"
elif [ -d "$HOME/.local/share/pipx/venvs/sqlfluff" ]; then
    log "Upgrading SQLFluff via pipx if outdated"
    pipx upgrade sqlfluff
elif command -v sqlfluff >/dev/null 2>&1 || [ -x "$HOME/.local/bin/sqlfluff" ]; then
    log "SQLFluff already installed (not managed by pipx); leaving it alone"
else
    log "Installing SQLFluff via pipx"
    pipx install sqlfluff
fi

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

# Package Control rewrites its settings file while Sublime runs, which makes
# `git pull --ff-only` refuse to fast-forward when the incoming commits touch
# that file. When that is the only obstacle, save the runtime state aside and
# retry once; everything else is left untouched for the user to resolve (see
# README "Runtime drift is normal"). A clean up-to-date checkout pulls with
# no changes at all.
sync_user_dir() {
    local manifest="Package Control.sublime-settings"
    local dirty=0
    git -C "$USER_DIR" diff --quiet -- "$manifest" || dirty=1
    git -C "$USER_DIR" diff --cached --quiet -- "$manifest" || dirty=1

    if ! git -C "$USER_DIR" pull --ff-only; then
        if [ "$dirty" -eq 0 ]; then
            return 1
        fi
        local backup
        backup="$USER_DIR/${manifest}.$(date +%Y%m%d-%H%M%S).bak"
        log "Backing up runtime-modified manifest to $(basename "$backup")"
        cp "$USER_DIR/$manifest" "$backup"
        git -C "$USER_DIR" checkout HEAD -- "$manifest"
        git -C "$USER_DIR" pull --ff-only
    fi
}

if [ -d "$USER_DIR/.git" ]; then
    log "Packages/User is already a git checkout; syncing latest"
    if ! sync_user_dir; then
        err "Could not fast-forward $USER_DIR."
        err "Commit or discard local changes (or fix your network) and re-run."
        err "See README 'Runtime drift is normal' for the manual fix."
        exit 1
    fi
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

# --- Prune packages this repo has dropped ------------------------------------
# Package Control auto-installs packages that appear in the manifest but never
# removes ones that disappear from it, so unmaintained packages would linger
# on machines that were set up before they were dropped. Keep this list in
# sync with the "removed" table in the README.

PRUNED_PACKAGES=("AutoFileName" "CSV" "SqlBeautifier" "requirementstxt")
for pkg in "${PRUNED_PACKAGES[@]}"; do
    if [ -f "$INSTALLED_PACKAGES_DIR/$pkg.sublime-package" ]; then
        rm -f "$INSTALLED_PACKAGES_DIR/$pkg.sublime-package"
        log "Pruned unmaintained package: $pkg"
    fi
    if [ -d "$SUBLIME_DIR/Packages/$pkg" ]; then
        rm -rf "$SUBLIME_DIR/Packages/$pkg"
        log "Pruned unmaintained unpacked package: $pkg"
    fi
done

log "Done. Launch Sublime Text — Package Control will install the packages"
log "listed in 'Package Control.sublime-settings' on first start."
