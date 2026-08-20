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

## Bootstrap a clean machine

One-liner (needs only `git` and `curl`):

```sh
curl -fsSL https://raw.githubusercontent.com/philip-goh/philips-sublime-config/main/bootstrap.sh | bash
```

> **Note:** the one-liner relies on this repo being **public**. If it is
> ever made private again, the raw download 404s without auth and
> `git clone` prompts for credentials — authenticate first (e.g.
> `gh auth login`, a PAT, or SSH keys) and use the manual steps below.

It installs Sublime Text (apt repo on Linux, Homebrew cask on macOS), Package
Control, the system runtimes the LSP packages need, Rust via rustup, and then
clones this repo into `Packages/User`. It is idempotent — re-running it pulls
the latest config instead of re-installing. If a `Packages/User` directory
already exists, it is renamed to a timestamped `.bak`, never deleted.

### Manual steps (if you don't trust piped curl)

```sh
git clone https://github.com/philip-goh/philips-sublime-config.git
cd philips-sublime-config
less bootstrap.sh   # read it first
./bootstrap.sh
```

Or do what the script does by hand:

1. Install Sublime Text 4 ([official instructions](https://www.sublimetext.com/docs/linux_repositories.html)
   for Linux, `brew install --cask sublime-text` on macOS).
2. Install system runtimes: `build-essential`/Xcode CLT, `clangd`, `python3`
   (+ pip, venv), `nodejs`/`npm`, `git`, `curl`, `shellcheck`, `shfmt`.
3. Install Rust via [rustup](https://rustup.rs) (not apt/brew), then
   `rustup component add rust-analyzer`.
4. Download [Package Control](https://packagecontrol.io/Package%20Control.sublime-package)
   into Sublime's `Installed Packages/` directory.
5. Back up any existing `Packages/User`, then clone this repo in its place.
6. Launch Sublime Text.

## What's in the box

Language intelligence (all via [LSP](https://lsp.sublimetext.io/)):

| Language   | Packages                                | Server binary from |
|------------|-----------------------------------------|--------------------|
| Python     | LSP-pyright (types), LSP-ruff (lint/format) | self-managed   |
| Rust       | LSP-rust-analyzer, Rust Enhanced (cargo builds, syntax) | rustup component |
| JS/TS      | LSP-typescript                          | self-managed       |
| C/C++      | LSP-clangd                              | system clangd      |
| Bash       | LSP-bash (uses system `shellcheck`/`shfmt`) | self-managed   |
| YAML/k8s   | LSP-yaml (kubernetes + GitHub Actions schemas) | self-managed |
| JSON       | LSP-json, Pretty JSON (format/minify/query) | self-managed   |
| Docker     | LSP-dockerfile, Dockerfile Syntax Highlighting | self-managed |
| SQL        | SqlBeautifier                           | —                  |
| TOML       | built into Sublime Text ≥ 4200 (no package; Package Control silently skips packages that shadow shipped ones) | — |
| CSV        | CSV (column highlighting/editing)       | —                  |
| Markdown   | MarkdownEditing                         | —                  |
| requirements.txt | requirementstxt                   | —                  |

Editor quality of life: BracketHighlighter, GitGutter, AutoFileName,
SideBarEnhancements, A File Icon, Terminus (terminal in the editor), and
PackageDev (syntax + completions for editing the `.sublime-settings` files
in this very repo).

## Key bindings

The LSP package ships its commands **unbound**, so the keymaps in this repo
bind the essentials. Every LSP binding is capability-gated: it only fires
when the current file has a language server that supports the feature, and
falls back to Sublime's built-in behavior otherwise.

| Key (Linux / macOS)                 | Action                       |
|-------------------------------------|------------------------------|
| `F12`                               | Goto definition (LSP)        |
| `Shift+F12`                         | Find references              |
| `F2`                                | Rename symbol                |
| `Ctrl+.` / `Cmd+.`                  | Code actions                 |
| `Ctrl+Alt+F` / `Cmd+Opt+F`          | Format document              |
| `Ctrl+K Ctrl+I` / `Cmd+K Cmd+I`     | Hover docs at caret          |
| `Alt+`` `                           | Toggle Terminus terminal     |

(`Ctrl+`` ` is left alone — that's Sublime's own console.)

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

- **LSP-pyright, LSP-ruff, LSP-typescript, LSP-json, LSP-yaml, LSP-bash,
  LSP-dockerfile** — self-managed (they use the Node runtime / their own
  bundled tooling). LSP-bash additionally picks up the system `shellcheck`
  and `shfmt` (installed by `bootstrap.sh`) for linting and formatting.

Two come from the **system** and are installed by `bootstrap.sh`:

- **clangd** (for LSP-clangd) — `clangd` apt package on Linux, Xcode Command
  Line Tools on macOS.
- **rust-analyzer** (for LSP-rust-analyzer) — installed as a rustup component
  so it always matches the active toolchain.

## CI

Every push runs [a small workflow](.github/workflows/ci.yml) that parses all
`*.sublime-settings` / `*.sublime-keymap` / `*.sublime-project` files
(Sublime's JSON-with-comments dialect) and shellchecks `bootstrap.sh` — a
typo in a settings file otherwise fails silently inside Sublime. Run it
locally with:

```sh
python3 scripts/check_settings.py
```

(The script lives in `scripts/` because Sublime loads any *top-level* `.py`
in `Packages/User` as an editor plugin; subdirectories are ignored.)

## Per-project overrides

Global format-on-save is deliberately off (shared codebases). Copy
[`project-template.sublime-project`](project-template.sublime-project) into a
project to get a virtualenv-aware pyright, strict type checking, and
format-on-save with Ruff code actions — scoped to that project only.
