# TODO

## Not implemented

- **GPG (signed commits)** - `ee` forwards `SSH_AUTH_SOCK` only. The gpg-agent
  socket needs the same treatment, and its path differs per platform the same
  way the SSH one does.
- **Opening at the shell's working directory** - one tree is mounted at
  `/workspace` and the daemon is shared, so the directory `ee` was invoked from
  is ignored. Mounting `$HOME` covers most of it in practice, but a project
  outside `$HOME` needs `DEVMACS_WORKSPACE` and a restart.

- **Bumping the pinned tools** - Dependabot covers the actions and the base
  images, but `EMACS_VERSION`, `MISE_VERSION` and `LSP_BOOSTER_VERSION` are ARG
  values it cannot read, so they are still updated by hand.

- **Prompts block the daemon when nothing can answer them** - opening a file
  next to a `mise.toml` makes `buffer-env` ask whether it may run it, and a
  source file can make `treesit-auto` ask about a grammar. Interactively that is
  fine, but a file opened with no terminal attached - `ee --exec emacsclient -n
  ...`, say - leaves the whole daemon waiting.

## Not verified

CI runs the container checks on Linux only. Neither hosted platform can run
Linux containers - Windows has no WSL2 backend for Docker, and the arm64 macOS
runners have no nested virtualisation - so `cli` is all that runs there.

- **CI has never run** - there is no remote yet, so the workflow itself, the
  multi-arch build and the published tags are all untested.
- **Runtimes other than Docker** - `podman`, `nerdctl`, `finch`, `container`
  and `wslc` are detected but none has been exercised. `tests/run.sh` can be
  pointed at one with `RUNTIME=`, which is the cheapest way to close this.
  - Apple `container`: the command reference documents named volumes and
    `exec --user` / `--env`, so the shape should hold. `SSH_AUTH_SOCK` is the
    doubtful part, since it is unlikely to sit where Docker Desktop puts it.
    CI cannot help - `macos-26` runners are Apple silicon without nested
    virtualisation - so this needs a real machine.
  - `wslc`: its volume subcommands are absent from the official documentation,
    so named volumes may turn out to need `DEVMACS_STATE_DIR` as a fallback.
- **Windows at all** - including WezTerm there. The terminal config is meant to
  be the same on every platform but has only been used on macOS.
- **The Windows launchers, past `--help`** - CI runs `ee.bat` and `ee.ps1` on a
  Windows runner, so the delegation itself works, but that runner has no Linux
  container support and takes the Git Bash branch rather than the WSL one.
  Unresolved under WSL: the paths `ee` hands to the runtime are Linux ones,
  which Docker Desktop resolves through its WSL integration but `wslc.exe` may
  not; `$HOME` is the WSL one, so the mounted workspace and `~/.config/devmacs`
  are not those under `%USERPROFILE%`; and whether a tty survives
  `wsl.exe -- sh ...` well enough for `emacsclient -nw` is unknown.
- **OSC 52 reaching a real clipboard** - `tests/60-editor.sh` checks that the
  escape sequence is produced and well formed. Whether the text lands in the
  host clipboard depends on the terminal and cannot be asserted from inside a
  container.

## Deliberately not done

- **tree-sitter grammars in the image** - fetched at runtime instead. Baking
  them in would inflate the image for languages most projects never touch.
- **Automatic package installation at startup** - `ee --user-install` is
  explicit. Checking on every launch would slow the daemon down and undo the
  point of compiling at build time.
- **compose / devcontainer** - see "Design" in the README.
