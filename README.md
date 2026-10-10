# philips-sublime-config

My Sublime Text 4 configuration, made reproducible across Linux and macOS.

It is built for full-stack work — Python, React/TypeScript, SQL, Rust, C++ —
plus in-editor data exploration with Jupyter kernels.

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
Control, the system runtimes the LSP packages need, Rust via rustup, SQLFluff
via pipx, the .NET SDK for Unity/Godot C# (Microsoft's user-local installer),
then clones this repo into `Packages/User` and git-clones the packages that
live outside Package Control (Godot Tools). It also prunes packages this repo
has dropped (see "Packages removed" below), because Package Control installs
additions but never removes anything on its own.

It is idempotent — re-running it pulls the latest config instead of
re-installing, and upgrades SQLFluff if pipx has it installed. If Sublime
left tracked settings files dirty while it was running, the script backs up
exactly the files the incoming commits would overwrite and retries the pull
once (see "Runtime drift is normal"). If a `Packages/User` directory already
exists, it is renamed to a timestamped `.bak`, never deleted.

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
   (+ pip, venv), `nodejs`/`npm`, `git`, `curl`, `shellcheck`, `shfmt`,
   `pipx`.
3. Install Rust via [rustup](https://rustup.rs) (not apt/brew), then
   `rustup component add rust-analyzer`.
4. `pipx install sqlfluff` (SQL linting/formatting; pipx avoids PEP 668
   "externally managed environment" errors).
5. Install the .NET SDK into `~/.dotnet` for LSP-OmniSharp (Unity/Godot C#):
   `curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS`.
6. Download [Package Control](https://packagecontrol.io/Package%20Control.sublime-package)
   into Sublime's `Installed Packages/` directory.
7. Back up any existing `Packages/User`, then clone this repo in its place.
8. Launch Sublime Text.

## What's in the box

Language intelligence and tooling:

| Area       | Packages / tools                                   | Server binary from     |
|------------|----------------------------------------------------|------------------------|
| Python     | LSP-pyright (types), LSP-ruff (lint/format)        | self-managed           |
| Rust       | LSP-rust-analyzer, Rust Enhanced (cargo builds)    | rustup component       |
| JS/TS/React| LSP-typescript, LSP-eslint                         | self-managed (Node; ESLint runs from the project) |
| C/C++      | LSP-clangd                                         | system clangd          |
| Bash       | LSP-bash (uses system `shellcheck`/`shfmt`)        | self-managed           |
| YAML/k8s   | LSP-yaml (kubernetes + GitHub Actions schemas)     | self-managed           |
| JSON       | LSP-json, Pretty JSON (format/minify/query)        | self-managed           |
| Docker     | LSP-dockerfile, Dockerfile Syntax Highlighting     | self-managed           |
| SQL        | built-in SQL syntax + SQLFluff build system        | pipx (`sqlfluff`)      |
| CSV/data   | rainbow_csv (column highlighting, RBQL queries)    | —                      |
| Jupyter    | Helium (run cells, inspect DataFrames in-editor)   | your Python `ipykernel`|
| TOML       | built into Sublime Text ≥ 4200                     | —                      |
| Markdown   | MarkdownEditing                                    | —                      |
| Games      | Unreal, Godot, and Unity — see [Game development](#game-development) | mixed |

Editor quality of life: BracketHighlighter, GitGutter, FileSystem
Autocompletion (path completion, replacing the abandoned AutoFileName),
SideBarEnhancements, A File Icon, Terminus (terminal in the editor),
PackageDev (syntax + completions for the `.sublime-settings` files in this
very repo), and OpenAI completion (configured in
[`openAI.sublime-settings`](openAI.sublime-settings) against a local model
server).

## Working with data

**CSV and tabular data** — [rainbow_csv](https://github.com/mechatroner/sublime_rainbow_csv)
highlights columns by position and ships RBQL, which runs SQL-like queries
against CSV using Python or JavaScript expressions:

```sql
select a1, a2 order by a3 desc limit 10
```

Use `Rainbow CSV: RBQL` from the command palette.

**Jupyter kernels** — [Helium](https://github.com/kaste/Helium) executes
`# %%` cells against a Jupyter kernel and shows results inline, which beats
re-scanning a notebook when exploring a codebase. Register a project
virtualenv as a kernel once:

```sh
python3 -m venv .venv
.venv/bin/pip install ipykernel pandas   # plus your analysis stack
.venv/bin/python -m ipykernel install --user --name myproject
```

Then run `Helium: Connect Kernel`, pick **New kernel → myproject**.

**SQL** — [SQLFluff](https://sqlfluff.com) lints and formats with
`Ctrl+B`/`Cmd+B` (lint) and `Ctrl+Shift+B`/`Cmd+Shift+B` (variants: Fix,
Format). SQLFluff needs to know your dialect — add a `.sqlfluff` file at the
project root:

```ini
[sqlfluff]
dialect = postgres
```

(`sqlfluff dialects` lists ~30 options; the build system's first run without
a config prints the list.)

## Game development

The engines themselves are installed outside this repo (Unity Hub, the Epic
Games Launcher or a UE source build, [godotengine.org](https://godotengine.org)
or `brew install --cask godot`). On the Sublime side this config covers their
code, shader, config, and project files:

| Engine | Files                                       | Syntax highlighting                        | Tooling |
|--------|---------------------------------------------|--------------------------------------------|---------|
| Unreal | C++ `.h`/`.cpp`/`.inl`                      | built into Sublime                        | LSP-clangd against a UBT-generated `compile_commands.json` |
|        | shaders `.usf`/`.ush`                       | `Unreal Shader` (repo wrapper)             | —       |
|        | configs `.ini`                              | INI package                               | —       |
|        | project `.uproject`                         | `Unreal Project` (repo wrapper)            | —       |
| Godot  | GDScript `.gd`, scenes `.tscn`, `project.godot` | Godot Tools (git-installed, MIT)        | run/open commands + Godot's built-in LSP |
|        | shaders `.gdshader`                         | `Godot Shader` (repo wrapper)              | —       |
|        | C#                                          | built into Sublime                        | LSP-OmniSharp |
| Unity  | C#                                          | built into Sublime                        | LSP-OmniSharp against the generated `.sln` |
|        | shaders/compute `.shader`/`.cginc`/`.hlsl`  | Unity Shader package                      | completions, format, goto-definition from that package |

### Unreal Engine

Unreal's C++ support is the strongest part: `LSP-clangd` (already configured)
gives completions, diagnostics, and go-to-definition once clangd has a
compilation database. Generate one from your project root with UnrealBuildTool's
`GenerateClangDatabase` mode:

```sh
# macOS (installed engine), from the project root. On Linux use
# Engine/Build/BatchFiles/Linux/Build.sh with platform "Linux".
"$UE_ROOT/Engine/Build/BatchFiles/Mac/Build.sh" -Mode=GenerateClangDatabase \
    MyGameEditor Mac Development -Project="$PWD/MyGame.uproject"
```

clangd picks up the resulting `compile_commands.json` from the project root
(regenerate after adding source files; UBT re-creates the whole file each
time). If clangd chokes on a UE-specific flag, a `.clangd` file in the project
root can strip it with `CompileFlags: { Remove: [...] }`.

### Godot

[Godot Tools](https://github.com/pbedn/godot-tools) is not on Package Control,
so `bootstrap.sh` git-clones it into `Packages/GodotTools` and pulls updates
on re-run. It adds syntax for `.gd`, `.tscn`, and `.godot` files plus commands:

- `Godot: Open Project`, `Godot: Run Project`, `Godot: Run Current Scene`
  (set `godot_executable` in its settings if auto-detection misses your
  binary — e.g. the Homebrew cask app).
- `Godot: Setup LSP For Current Project` starts the editor with Godot's
  built-in language server on TCP 6005. The `godot-lsp` client in
  [`LSP.sublime-settings`](LSP.sublime-settings) is already enabled, so
  GDScript gets completions, hover, and diagnostics as soon as that server is
  up (set `"enabled": false` there if you edit `.gd` files without Godot
  running).

### Unity

Open the project root — the folder with `Assets/` and the `.sln` Unity
generates — so OmniSharp can load the solution. The Unity Shader package
adds `.shader`/`.cginc`/`.hlsl` highlighting, completions, formatting, and
goto-definition for built-in shader symbols. `.asmdef` files are highlighted
as JSON by a repo wrapper.

### Repo-maintained syntax wrappers

`Unreal Shader`, `Godot Shader`, `Unreal Project`, and
`Unity Assembly Definition` are tiny `.sublime-syntax` files at this repo's
root. They exist because no maintained package claims those formats, and they
only `extends` the shipped C++/JSON syntaxes — there are no regexes of our
own to maintain, and CI parses them. Delete a wrapper if a maintained package
for that format ever appears (the audit is the reminder to look).

## Keeping this config up to speed

Three layers, so nothing silently rots:

1. **Package Control** upgrades installed packages automatically when Sublime
   starts (`auto_upgrade` is on by default).
2. **Package maintenance audit** — `python3 scripts/check_packages.py`
   downloads Package Control's channel index and reports the newest release
   of every package in the manifest:

   ```
   STATUS   PACKAGE                            LATEST RELEASE     AGE
   OK       LSP-ruff                           2026-10-08          2d
   WARN     Helium                             2024-08-05        796d
   ```

   `WARN` means older than two years (revisit eventually); `STALE` (three
   years) or `MISSING` (typo, or delisted from Package Control) makes the
   script exit non-zero. The same run checks the GitHub repositories of the
   git-installed packages (Godot Tools): an archived upstream or no push for
   three years also fails. The
   [`package-audit` workflow](.github/workflows/package-audit.yml) runs it
   weekly and on demand, and a failed scheduled run notifies via GitHub, so
   an abandoned dependency surfaces even if you never look.
3. **`bootstrap.sh`** is idempotent: re-run it to pull the latest config,
   upgrade SQLFluff, and prune packages this repo has dropped (Package
   Control itself never uninstalls anything). On a clean, current machine it
   changes nothing.

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
| `Ctrl+B` / `Cmd+B`                  | SQLFluff lint (SQL files)    |
| `Ctrl+Shift+B` / `Cmd+Shift+B`      | SQLFluff Fix / Format        |
| `Alt+`` `                           | Toggle Terminus terminal     |

(`Ctrl+`` ` is left alone — that's Sublime's own console; `Ctrl+B` is
Sublime's standard build key, which the SQLFluff build system claims only
for SQL files.)

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

### Removing a package

Removing works in reverse — `Package Control: Remove Package`, then commit
the shrunken manifest — but note Package Control **never uninstalls anything
by itself** when a name disappears from the list. To make removals propagate
to machines that already have the package:

1. Add the name to `PRUNED_PACKAGES` in `bootstrap.sh`.
2. Re-run `bootstrap.sh` on those machines (or remove it manually via
   `Package Control: Remove Package`).

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
package); `git diff` before committing. Re-running `bootstrap.sh` handles
this automatically: for the files the incoming commits would overwrite, it
backs up the runtime versions to timestamped `.bak` files, restores the
committed ones, and retries the pull.

## LSP servers: self-managed vs. system

Most `LSP-*` helper packages download and update their own language server —
you install nothing:

- **LSP-pyright, LSP-ruff, LSP-typescript, LSP-eslint, LSP-json, LSP-yaml,
  LSP-bash, LSP-dockerfile** — self-managed (they use the Node runtime /
  their own bundled tooling). LSP-eslint additionally runs the ESLint from
  your project so it uses your config and plugins. LSP-bash picks up the
  system `shellcheck` and `shfmt` (installed by `bootstrap.sh`) for linting
  and formatting.
- **LSP-OmniSharp** downloads OmniSharp itself but needs a .NET runtime on
  the machine — `bootstrap.sh` installs the SDK into `~/.dotnet`, and the
  client config in `LSP.sublime-settings` puts that directory on the
  server's `PATH` (GUI-launched Sublime does not see a login shell's PATH).
- **SQLFluff** is not an LSP package: it is an external, actively maintained
  tool installed with `pipx` and driven by `SQLFluff.sublime-build`.
- **Godot's language server** is not a package either: the Godot editor
  serves it on TCP 6005, the git-installed Godot Tools package starts it,
  and the `godot-lsp` client in `LSP.sublime-settings` connects to it.

Two come from the **system** and are installed by `bootstrap.sh`:

- **clangd** (for LSP-clangd) — `clangd` apt package on Linux, Xcode Command
  Line Tools on macOS.
- **rust-analyzer** (for LSP-rust-analyzer) — installed as a rustup component
  so it always matches the active toolchain.

## CI

Every push runs [a workflow](.github/workflows/ci.yml) that parses all
`*.sublime-settings` / `*.sublime-keymap` / `*.sublime-project` /
`*.sublime-build` files (Sublime's JSON-with-comments dialect) and — with
PyYAML installed in CI — the `.sublime-syntax` wrappers, byte-compiles the
check scripts, and shellchecks `bootstrap.sh` — a typo in a settings file
otherwise fails silently inside Sublime. Run it locally with:

```sh
python3 scripts/check_settings.py
python3 scripts/check_packages.py   # needs network
```

The second workflow, [`package-audit`](.github/workflows/package-audit.yml),
runs the maintenance audit on a weekly schedule.

(The check scripts live in `scripts/` because Sublime loads any *top-level*
`.py` in `Packages/User` as an editor plugin; subdirectories are ignored.)

## Per-project overrides

Global format-on-save is deliberately off (shared codebases). Copy
[`project-template.sublime-project`](project-template.sublime-project) into a
project to get a virtualenv-aware pyright, strict type checking, and
format-on-save with Ruff code actions — scoped to that project only. SQL
dialect and Helium kernel registration are per-project too (see "Working with
data" above).

## Packages removed from this config

The maintenance audit flagged these as abandoned; they were replaced with
actively maintained tools:

| Dropped                | Last release | Replaced by                          |
|------------------------|--------------|--------------------------------------|
| AutoFileName           | 2014         | FileSystem Autocompletion            |
| CSV                    | 2016         | rainbow_csv                          |
| SqlBeautifier          | 2014         | SQLFluff build system                |
| requirementstxt        | 2016         | — no maintained alternative; `requirements.txt` opens as plain text |

A handful of remaining packages move slowly but are still maintained; the
audit prints a `WARN` for them, which is the reminder to revisit: Dockerfile
Syntax Highlighting, Helium, INI, Pretty JSON, and Unity Shader.
