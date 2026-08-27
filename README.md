# devmacs

A portable Emacs (nox) development environment in a container.

The same environment comes up the same way on macOS and Windows: no heavy
editor process, no polluted home directory, and no modifier keys that shift
when you switch operating systems.

## Requirements

A container runtime. Any of these works:

| Runtime | Notes |
|---|---|
| `docker` | Docker Desktop, Colima, OrbStack, Rancher Desktop |
| `podman` | |
| `nerdctl` / `finch` | containerd-based |
| `container` | macOS 26 Tahoe, Apple silicon only |
| `wslc` | Windows 11, WSL 2.9.3 or newer (`wsl --update --pre-release`) |

A terminal that supports OSC 52 and modifyOtherKeys. [WezTerm][wezterm] is what
the bundled config targets, and it is the same config on every platform.

On Windows, `ee.bat` and `ee.ps1` hand off to that same POSIX script through
WSL or Git Bash, so nothing beyond one of those is needed.

## Getting started

```sh
# Put ee on your PATH
ln -s "$PWD/ee" ~/.local/bin/ee                                        # macOS / Linux
# on Windows, add this directory to PATH and call ee.bat

# Install the terminal config
ln -s "$PWD/config/wezterm/wezterm.lua" ~/.config/wezterm/wezterm.lua  # macOS / Linux
copy config\wezterm\wezterm.lua %USERPROFILE%\.wezterm.lua             # Windows

# Fetch the image
ee --pull

# Open it. $HOME is mounted at /workspace
ee
```

## Usage

```sh
# Open a file
ee path/to/file

# Get a shell in the container
ee --shell

# See what is currently set up
ee --status

# Update, or switch to the slim variant that drops the C/C++ toolchain.
# A new image only takes effect once the container is recreated, and both
# commands have to see the same value, so export it rather than prefixing one
export DEVMACS_IMAGE=ghcr.io/mezum/devmacs:slim   # optional
ee --pull && ee --restart

# Every action and variable
ee --help
```

Copying reaches the host clipboard automatically. Paste with the terminal's own
binding (`Cmd+V` or `Ctrl+Shift+V`).

## Toolchains

```
;; Runtimes come from the project's mise.toml, not from the image.
;; Installed once, then shared by every project afterwards.
M-x devmacs-mise-install

;; When mise does not trust the config yet
M-x devmacs-mise-trust

;; Start a language server. Not automatic, because a project without one
;; would warn on every file visit. Put eglot-ensure in .dir-locals.el for
;; projects that always want it.
C-c l l
```

## Configuration

```sh
# Your settings live outside the image, so updates never touch them
cp -r config/devmacs ~/.config/devmacs

# ~/.config/devmacs/
#   init.el       loaded after the base config, so your settings win
#   packages.el   optional; packages you want on top
#   user-lisp/    optional; added to load-path

# Install what packages.el declares. A one-off: they land on the state volume
ee --user-install && ee --restart
```

## Keybindings

| Key | Action |
|---|---|
| `C-x g` | magit |
| `C-x b` | switch buffer |
| `M-s r` | ripgrep |
| `M-s l` | search in buffer |
| `M-y` | yank ring |
| `C-c l l` | start eglot |
| `C-c l r` / `a` / `f` | rename / code action / format |

## Design

**Terminal Emacs, not GUI.** Cmd never reaches Emacs - the terminal keeps it -
so both platforms are left with Ctrl and Meta, and the `mac-command-modifier`
split disappears. Setup for that lives in [the terminal config][wezterm-config].

**CI builds the images, not your machine.** apt resolves differently over time,
so building locally would drift between machines. `eln-cache` is architecture
specific, so each one is built on a native runner and joined into a manifest
list - which also means no machine waits for native compilation on first start.

**Config read-only, state on a volume.** `--init-directory` moves all of
`user-emacs-directory`, so mounting a config repository directly would leave
`elpa/` and `eln-cache/` inside it.

**Split by apt layer, not by language.** Per-language images explode
combinatorially and cannot be composed. Languages live in [mise][mise] on a
shared volume, which is what lets one daemon serve projects that mix them.

**A resident daemon.** Recreating the container each time would repeat native
compilation and LSP indexing. `buffer-env` swaps `exec-path` per buffer so that
one daemon still picks the right language server for each project.

**No compose, no devcontainer.** Adopting a VSCode-derived format when the
point is leaving VSCode makes little sense, and Apple `container` has no
compose equivalent - both would restrict which runtimes work.

## Development

```sh
# Layout
#   Dockerfile    image definition
#   ee            launcher
#   docker/       baked into the image (emacs/ is the base configuration)
#   config/       belongs on the host (wezterm/, devmacs/)
#   tests/        checks, run by CI and locally

# Build and test. CI runs the same script
docker build --target base -t devmacs:test .
tests/run.sh

# One area only, or the slim variant
tests/run.sh 40-mise.sh
DEVMACS_TEST_VARIANT=slim tests/run.sh

# Try a config change without rebuilding, then M-x devmacs-recompile
# because the compiled files in the image no longer match
docker run ... --volume "$PWD/docker/emacs:/opt/devmacs/config:ro" ...

# Bump a version through the ARG values in the Dockerfile.
# EMACS_VERSION and EMACS_SHA256 always go together
curl -sL https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz | shasum -a 256
```

The runtime library list in the `slim` stage needs a look when the Debian
release changes, since some package names carry a version.

What is missing or unverified is tracked in [TODO.md](TODO.md).

[wezterm]: https://wezterm.org/
[wezterm-config]: config/wezterm/wezterm.lua
[mise]: https://mise.jdx.dev/
