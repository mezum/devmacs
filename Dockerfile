# syntax=docker/dockerfile:1.7
#
# devmacs - a portable Emacs (nox) development environment in a container.
#
# Images are split by apt layer, not by language. Languages live in mise on a
# shared volume, so one container and one Emacs daemon can serve projects that
# mix languages, and the tag count stays at two instead of exploding.
#
#   base   the default; everything below plus a C/C++ toolchain
#   slim   Emacs, mise and the common CLI tools only

ARG DEBIAN_RELEASE=trixie

########################################################################
# Emacs is built from source with AOT native compilation, so that no machine
# has to sit through JIT on first start. eln-cache is architecture specific,
# which is why CI builds one image per architecture rather than emulating.
########################################################################
FROM debian:${DEBIAN_RELEASE}-slim AS emacs-build

ARG EMACS_VERSION=31.1
# Replace this whenever EMACS_VERSION changes; see "Bumping versions" in README.
ARG EMACS_SHA256=1da5790d9580c81932b5bf700633114468da7b3412d69faa767daebf974f4586

SHELL ["/bin/sh", "-eux", "-c"]

RUN apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential autoconf automake texinfo pkg-config \
      ca-certificates curl xz-utils \
      libgnutls28-dev libncurses-dev libxml2-dev libsqlite3-dev \
      libtree-sitter-dev zlib1g-dev; \
    # libgccjit has to match the gcc major version, so ask gcc rather than
    # hardcoding a number that goes stale on the next Debian release.
    apt-get install -y --no-install-recommends "libgccjit-$(gcc -dumpversion)-dev"; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build
RUN curl -fsSL -o emacs.tar.xz \
      "https://ftp.gnu.org/gnu/emacs/emacs-${EMACS_VERSION}.tar.xz"; \
    echo "${EMACS_SHA256}  emacs.tar.xz" | sha256sum -c -; \
    tar -xf emacs.tar.xz --strip-components=1; \
    rm emacs.tar.xz

RUN ./configure \
      --prefix=/usr/local \
      --with-native-compilation=aot \
      --with-tree-sitter \
      --with-gnutls \
      --with-sqlite3 \
      --with-xml2 \
      --with-zlib \
      --with-modules \
      --without-x \
      --without-sound \
      --without-dbus \
      --without-gsettings \
      --without-selinux \
      --without-compress-install

RUN make -j"$(nproc)"; \
    make install DESTDIR=/opt/emacs-root; \
    # Manuals are dead weight in a runtime image.
    rm -rf /opt/emacs-root/usr/local/share/man \
           /opt/emacs-root/usr/local/share/info

########################################################################
# emacs-lsp-booster turns LSP JSON into elisp bytecode before Emacs sees it,
# which removes the multi-second freezes that chatty servers cause. Building
# it here means Rust never has to be installed on the host.
########################################################################
FROM rust:1-slim-bookworm AS booster-build

ARG LSP_BOOSTER_VERSION=0.2.1

RUN cargo install emacs-lsp-booster \
      --locked --version "${LSP_BOOSTER_VERSION}" --root /opt/booster

########################################################################
# slim - no compiler toolchain. Smaller, but native extensions will not build.
########################################################################
FROM debian:${DEBIAN_RELEASE}-slim AS slim

ARG MISE_VERSION=2026.8.14
ARG TARGETARCH

SHELL ["/bin/sh", "-eux", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY --from=emacs-build /opt/emacs-root/usr/local /usr/local
COPY --from=booster-build /opt/booster/bin/emacs-lsp-booster /usr/local/bin/

RUN apt-get update; \
    apt-get install -y --no-install-recommends \
      # Some of these carry a version in the package name, so this list needs
      # a look whenever the Debian release is bumped.
      libgnutls30t64 libncursesw6 libxml2 libsqlite3-0 libtree-sitter0.22 zlib1g \
      # native-comp still shells out to libgccjit and as/ld at runtime to
      # compile packages the user installs later, so AOT does not remove these.
      libgccjit0 gcc binutils \
      ncurses-term \
      git ripgrep fd-find curl ca-certificates less openssh-client gnupg \
      procps tzdata locales gosu \
      # mise needs these to unpack what it downloads.
      unzip xz-utils bzip2; \
    rm -rf /var/lib/apt/lists/*; \
    # Debian ships fd under a different name to avoid a clash.
    ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    # Fail the build here rather than shipping an Emacs that cannot start.
    emacs --version

RUN arch="${TARGETARCH}"; \
    case "${arch}" in \
      amd64) mise_arch=x64 ;; \
      arm64) mise_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/mise.tar.gz \
      "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${mise_arch}.tar.gz"; \
    tar -xzf /tmp/mise.tar.gz -C /tmp; \
    install -m 0755 /tmp/mise/bin/mise /usr/local/bin/mise; \
    rm -rf /tmp/mise /tmp/mise.tar.gz; \
    mise --version

# These ids are placeholders; the entrypoint rewrites them at startup to match
# whoever is running the container.
RUN groupadd -g 1000 dev; \
    useradd -u 1000 -g 1000 -m -s /bin/bash dev; \
    install -d -o dev -g dev /workspace

# Config stays read-only inside the image and state goes to a volume, because
# --init-directory would otherwise drop elpa, eln-cache and history straight
# into the config repository.
COPY --chown=dev:dev docker/emacs /opt/devmacs/config
ENV DEVMACS_CONFIG=/opt/devmacs/config

# Where ee mounts the user's own config. Keeping it outside the image is what
# lets it survive image updates.
ENV DEVMACS_USER_CONFIG=/opt/devmacs/user

# Packages are installed and natively compiled here rather than on first run.
#
# This has to happen at the very path the daemon will use later. An .eln file
# name embeds a hash of the source file's absolute path, so compiling under any
# other directory yields files that are silently ignored at runtime and rebuilt
# by JIT - which is exactly the wait this is meant to avoid. The result is then
# moved aside, because the state volume mounted over $HOME/.emacs.d at runtime
# would otherwise hide it.
RUN gosu dev env HOME=/home/dev \
      emacs --batch --init-directory=/home/dev/.emacs.d \
            -l /opt/devmacs/config/bootstrap.el; \
    mv /home/dev/.emacs.d /opt/devmacs/seed; \
    install -d -o dev -g dev /home/dev/.emacs.d

COPY docker/entrypoint.sh /usr/local/bin/devmacs-entrypoint
RUN chmod 0755 /usr/local/bin/devmacs-entrypoint

ENV HOME=/home/dev \
    MISE_DATA_DIR=/home/dev/.local/share/mise \
    EDITOR=emacsclient \
    PATH=/home/dev/.local/share/mise/shims:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/devmacs-entrypoint"]
CMD ["emacs", "--fg-daemon", "--init-directory=/home/dev/.emacs.d"]

########################################################################
# base - the default. Plenty of language runtimes build native extensions on
# install, so a toolchain being missing is a worse surprise than a larger image.
#
# Only the apt layer differs from slim. Anything mise can install belongs in
# mise.toml, not in a third image.
########################################################################
FROM slim AS base

# No USER here: the entrypoint needs root to fix up uid/gid before it drops
# to dev with gosu.
RUN apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential clang lld make cmake pkg-config \
      libssl-dev libffi-dev libreadline-dev libyaml-dev \
      libncurses-dev zlib1g-dev libbz2-dev liblzma-dev libsqlite3-dev; \
    rm -rf /var/lib/apt/lists/*
