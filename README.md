# philips-sublime-config

My Sublime Text 4 configuration, made reproducible across Linux and macOS.

This repo **is** Sublime's `Packages/User` directory. Clone it into place and
Sublime picks up every setting; Package Control reads the committed manifest
and installs every package. Installed packages themselves are never committed
— only the list of their names.

| OS    | `Packages/User` location                                      |
|-------|---------------------------------------------------------------|
| Linux | `~/.config/sublime-text/Packages/User`                        |
| macOS | `~/Library/Application Support/Sublime Text/Packages/User`    |

> **TODO:** `bootstrap.sh` and the command below use the placeholder
> `git@github.com:REPLACE_ME/sublime-config.git`. Replace `REPLACE_ME` with
> the real GitHub owner/repo before using.

## Bootstrap a clean machine

One-liner (needs only `git` and `curl`):

```sh
curl -fsSL https://raw.githubusercontent.com/REPLACE_ME/sublime-config/main/bootstrap.sh | bash
```

It installs Sublime Text (apt repo on Linux, Homebrew cask on macOS), Package
Control, the system runtimes the LSP packages need, Rust via rustup, and then
clones this repo into `Packages/User`. It is idempotent — re-running it pulls
the latest config instead of re-installing. If a `Packages/User` directory
already exists, it is renamed to a timestamped `.bak`, never deleted.

### Manual steps (if you don't trust piped curl)

```sh
git clone git@github.com:REPLACE_ME/sublime-config.git
cd sublime-config
less bootstrap.sh   # read it first
./bootstrap.sh
```

Or do what the script does by hand:

1. Install Sublime Text 4 ([official instructions](https://www.sublimetext.com/docs/linux_repositories.html)
   for Linux, `brew install --cask sublime-text` on macOS).
2. Install system runtimes: `build-essential`/Xcode CLT, `clangd`, `python3`
   (+ pip, venv), `nodejs`/`npm`, `git`, `curl`.
3. Install Rust via [rustup](https://rustup.rs) (not apt/brew), then
   `rustup component add rust-analyzer`.
4. Download [Package Control](https://packagecontrol.io/Package%20Control.sublime-package)
   into Sublime's `Installed Packages/` directory.
5. Back up any existing `Packages/User`, then clone this repo in its place.
6. Launch Sublime Text.

## How the package manifest sync works

[`Package Control.sublime-settings`](Package%20Control.sublime-settings)
contains an `installed_packages` list. On first launch, Package Control
compares that list against what is actually installed and **installs anything
missing automatically**. That is the entire sync mechanism — no snapshots, no
submodules.

### Adding a new package

1. Install it normally (`Package Control: Install Package`).
2. Package Control appends it to `installed_packages` in
   `Package Control.sublime-settings` — the manifest updates itself.
3. `git diff` to confirm, then commit. Other machines pick it up on their
   next `git pull` + Sublime restart.

Removing works the same way in reverse: `Package Control: Remove Package`,
then commit the shrunken manifest.

### Runtime drift is normal

Sublime and Package Control write to files in this directory while running:
Package Control reformats its settings file (trailing commas, an
`in_process_packages` key, resorted entries), and generated files like
Terminus color schemes appear (gitignored). This means `git pull` inside
`Packages/User` can refuse to merge. When that happens, discard the runtime
noise and pull again — with Sublime closed, ideally:

```sh
cd <Packages/User>
git checkout -- "Package Control.sublime-settings"
git pull --ff-only
```

Only commit manifest changes you made deliberately (installing/removing a
package); `git diff` before committing.

## LSP servers: self-managed vs. system

Most `LSP-*` helper packages download and update their own language server —
you install nothing:

- **LSP-pyright, LSP-ruff, LSP-typescript, LSP-json, LSP-yaml, LSP-bash** —
  self-managed (they use the Node runtime / their own bundled tooling).

Two come from the **system** and are installed by `bootstrap.sh`:

- **clangd** (for LSP-clangd) — `clangd` apt package on Linux, Xcode Command
  Line Tools on macOS.
- **rust-analyzer** (for LSP-rust-analyzer) — installed as a rustup component
  so it always matches the active toolchain.

## Per-project overrides

Global format-on-save is deliberately off (shared codebases). Copy
[`project-template.sublime-project`](project-template.sublime-project) into a
project to get a virtualenv-aware pyright, strict type checking, and
format-on-save with Ruff code actions — scoped to that project only.
