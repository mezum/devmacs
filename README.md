# devmacs

A portable Emacs (nox) development environment in a container.

The same environment comes up the same way on macOS and Windows: no heavy
editor process, no polluted home directory, and no modifier keys that shift
when you switch operating systems.

```
ee                 # open Emacs
ee path/to/file    # open a file
ee --shell         # a shell in the container
ee --status        # what is set up right now
```

## Getting started

```sh
# 1. pull the image
docker pull ghcr.io/mezum/devmacs:base

# 2. put ee on PATH
ln -s "$PWD/ee" ~/.local/bin/ee

# 3. install the WezTerm config
#    macOS / Linux
ln -s "$PWD/wezterm/wezterm.lua" ~/.config/wezterm/wezterm.lua
#    Windows
#    copy wezterm\wezterm.lua %USERPROFILE%\.wezterm.lua

# 4. open it
ee
```

`$HOME/repo` is mounted at `/workspace`; change it with `DEVMACS_WORKSPACE`.

Use `ee --native` for projects that build C/C++ or native extensions.

To add your own Emacs settings, copy `config/devmacs/` to `~/.config/devmacs/`
and edit it there. See [Your own config](#your-own-config).

## Working in a project

Runtimes come from the project's `mise.toml`, not from the image.

```
M-x devmacs-mise-install     # run mise install
M-x devmacs-mise-trust       # when mise does not trust the config yet
```

Anything installed stays on the shared volume, so the same language at the same
version is instant next time. On first use `buffer-env` asks whether it may run
the script; answering `!` (always) records it and it stops asking.

Language servers do not start on their own, because a warning on every file
visit in a project without a server is worse than typing `C-c l l`
(`M-x eglot`). Projects that always want one can put `eglot-ensure` in
`.dir-locals.el`.

## Keys

| Key | Action |
|---|---|
| `C-x g` | magit |
| `C-x b` | consult-buffer |
| `M-s r` | consult-ripgrep |
| `M-s l` | consult-line |
| `M-y` | consult-yank-pop |
| `C-c l l` | start eglot |
| `C-c l r` / `a` / `f` | rename / code action / format |

Copying reaches the host clipboard over OSC 52 automatically. Paste with the
terminal's own binding (`Cmd+V` or `Ctrl+Shift+V`).

## ee

```
ee [options] [file...]

  --shell           open a bash shell in the container
  --exec CMD...     run a command in the container
  --user-install    install the packages your own config declares
  --native          use the native tag
  --image IMAGE     use a specific image
  --pull            fetch the image again
  --restart         recreate the container
  --stop            stop the container
  --status          show what is currently set up
```

| Variable | Default |
|---|---|
| `DEVMACS_IMAGE` | `ghcr.io/mezum/devmacs:base` |
| `DEVMACS_NAME` | `devmacs` |
| `DEVMACS_WORKSPACE` | `$HOME/repo` → `/workspace` |
| `DEVMACS_STATE_DIR` | `~/.local/share/devmacs` |
| `DEVMACS_USER_CONFIG` | `~/.config/devmacs` |
| `DEVMACS_RUNTIME` | autodetected |

## Layout

```
Dockerfile          image definition
ee                  launcher
docker/             everything baked into the image
  emacs/            the base Emacs configuration
  entrypoint.sh
config/             files that belong on the host
  wezterm/          -> ~/.config/wezterm/
  devmacs/          -> ~/.config/devmacs/   (template for your own config)
```

## Why it is built this way

**Terminal Emacs, not GUI.** Cmd never reaches Emacs - the terminal emulator
keeps it - so both platforms are left with Ctrl and Meta. The
`mac-command-modifier` split disappears. The only setup needed is on the
terminal side, in [`wezterm/wezterm.lua`](wezterm/wezterm.lua).

**CI builds the images, not your machine.** apt resolves differently over time,
so building locally would produce different environments on different machines.
CI builds each architecture on a native runner and joins them into one manifest
list. `eln-cache` is architecture specific, so this also means no machine waits
for native compilation on first start.

**Config read-only, state on a volume.** `--init-directory` moves all of
`user-emacs-directory`, so mounting a config repository directly would leave
`elpa/` and `eln-cache/` inside it. Config lives in the image; only state goes
to `$HOME/.emacs.d`.

**Split by apt layer, not by language.** Per-language images explode
combinatorially and cannot be composed. Languages live in
[mise](https://mise.jdx.dev/) on a shared volume instead, which is what lets
one container and one daemon serve projects that mix languages.

**A resident daemon.** Recreating the container each time would mean paying for
native compilation and LSP indexing again on every start, so `emacs --fg-daemon`
stays resident and `ee` attaches with `emacsclient`. `buffer-env` swaps
`process-environment` and `exec-path` per buffer so that one daemon still picks
the right language server for each project.

## Runtimes

`ee` looks for `docker`, then `podman`, `container` (Apple), then `wslc`. The
image runs anywhere; what differs is the arguments to `run`, and `ee` absorbs
that.

- **named volumes** are used only on docker and podman; Apple `container` and
  `wslc` get directories under `DEVMACS_STATE_DIR`
- **uid/gid** are fixed up by the entrypoint. Docker Desktop on macOS hides the
  difference with VirtioFS, but Apple `container`, Linux and WSL do not
- **the SSH agent** is at a fixed path of its own on Docker Desktop for macOS

Neither `devcontainer` nor `compose` is used: adopting a VSCode-derived format
when the point is leaving VSCode makes little sense, and Apple `container` has
no compose equivalent, so both would restrict which runtimes work.

## Your own config

The base configuration ships inside the image, so your own settings live
outside it and are layered on top. Nothing here is lost when the image is
updated, and the directory can be a repository of its own.

```sh
cp -r config/devmacs ~/.config/devmacs
```

`ee` mounts that directory read-only and loads it after the base config, so
anything you set wins.

```
~/.config/devmacs/
├── init.el       loaded after the base config
├── packages.el   optional; packages you want on top
└── user-lisp/    optional; added to load-path
```

Packages are installed on demand rather than at startup, because checking on
every launch would slow the daemon down:

```sh
ee --user-install     # or M-x devmacs-user-install from inside Emacs
ee --restart          # to load them
```

They are written to the state volume, so they only have to be installed once.

Point `DEVMACS_USER_CONFIG` elsewhere if you would rather keep it somewhere
other than `~/.config/devmacs`.

### Changing the base config

Editing `docker/emacs/` and rebuilding through CI is the intended path. For a
local experiment it can be mounted over instead:

```sh
docker run ... --volume "$PWD/docker/emacs:/opt/devmacs/config:ro" ...
```

The compiled files baked into the image no longer match, so run
`M-x devmacs-recompile` inside Emacs.

The `user-lisp/` auto-compilation added in Emacs 31 only covers directories
under `user-emacs-directory`, and devmacs keeps its config elsewhere;
`docker/emacs/bootstrap.el` handles that at build time and `devmacs-recompile`
at runtime.

## Bumping versions

Edit the `ARG` values in the `Dockerfile` and push; CI rebuilds.

```
EMACS_VERSION / EMACS_SHA256    # always together
MISE_VERSION
LSP_BOOSTER_VERSION
```

Get the checksum with:

```sh
curl -sL https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz | shasum -a 256
```

The runtime library list in the `base` stage also deserves a look when the
Debian release changes, since some package names carry a version.

## What is verified

Checked on macOS (Apple Silicon, Docker Desktop) with the `base` image:

- Emacs 31.1 starts and is reachable through `emacsclient`
- packages and their compiled `.eln` files unpack from the seed, so there is no
  native compilation wait on any machine
- the entrypoint matches uid/gid to the host and `/workspace` files show the
  right owner
- starting `eglot` enables `eglot-booster` automatically
- a runtime installed with `mise install` is visible to Emacs per buffer -
  `exec-path` starts with the mise shims via `buffer-env`

OSC 52 is wired into `interprogram-cut-function`, but actually landing text in
the host clipboard needs a real terminal and has not been checked.

## Not there yet

- **GPG (signed commits)** - `ee` forwards `SSH_AUTH_SOCK` only; the gpg-agent
  socket is not handled
- **Apple `container`** - untested, in particular how `SSH_AUTH_SOCK` behaves
  and whether its `exec` accepts `--env`
- **tree-sitter grammars** - fetched at runtime, since baking them in would
  inflate the image for languages most projects never touch
