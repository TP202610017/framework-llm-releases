#!/usr/bin/env bash
# install.sh — One-line installer for framework-llm on macOS / Linux
#
# Usage:
#   curl -fsSL https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.sh | bash
#
# Offline (no internet), from a release tarball copied to this machine:
#   bash install.sh --local /path/to/isw_<version>_linux_x86_64.tar.gz
#   (or: ISW_LOCAL_PACKAGE=/path/to/the.tar.gz bash install.sh)
#
# Este script descarga los binarios desde el repo PÚBLICO de releases
# (TP202610017/framework-llm-releases), que aloja solo artefactos
# compilados. El código fuente del framework vive en un repo separado
# y privado — NO es accesible desde aquí ni queda expuesto al usuario.
#
# Lo que hace:
#   0. Verifica la versión mínima del sistema (macOS 10.15+, Linux 2.6.32+).
#   1. Detecta OS (linux/darwin) y arquitectura (x86_64/arm64).
#   2. Resuelve la última release vía GitHub API (o usa el paquete local).
#   3. Descarga el .tar.gz que matchea.
#   4. Extrae isw a ~/.local/bin/isw (crea el dir si hace falta).
#   5. Hint al usuario si ~/.local/bin no está en PATH.
#   6. Verifica `isw version`.

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────
# Repo PÚBLICO de releases. El código fuente está en otro repo
# privado, fuera del alcance de este script.
REPO="TP202610017/framework-llm-releases"
RELEASES_URL="https://github.com/${REPO}/releases/latest"
BINARY="isw"
INSTALL_DIR="${ISW_INSTALL_DIR:-$HOME/.local/bin}"
LOCAL_PACKAGE="${ISW_LOCAL_PACKAGE:-}"

# Minimum platform required by the Go 1.22 runtime inside the binary.
MIN_MACOS="10.15"
MIN_LINUX_KERNEL="2.6.32"

while [ $# -gt 0 ]; do
  case "$1" in
    --local)   LOCAL_PACKAGE="${2:-}"; shift 2 ;;
    --local=*) LOCAL_PACKAGE="${1#--local=}"; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" 2>/dev/null || true
      exit 0 ;;
    *) printf "unknown option: %s\n" "$1" >&2; exit 2 ;;
  esac
done

# ── Pretty output ────────────────────────────────────────────────────
c_blue=$'\033[36m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'
c_red=$'\033[31m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
step() { printf "${c_blue}▶  %s${c_reset}\n" "$*"; }
ok()   { printf "${c_green}✓  %s${c_reset}\n" "$*"; }
warn() { printf "${c_yellow}⚠  %s${c_reset}\n" "$*"; }
die()  { printf "${c_red}✗  %s${c_reset}\n" "$*" >&2; exit 1; }

# die_network explains how to install offline instead of leaving the user
# with a bare network error.
die_network() {
  printf "${c_red}✗  Network error while trying to %s.${c_reset}\n" "$1" >&2
  cat >&2 <<EOF

   ${c_yellow}No internet? Install offline from a local package:${c_reset}
     1. On a machine with internet, download isw_<version>_${OS}_${ARCH}.tar.gz from
        ${RELEASES_URL}
     2. Copy it to this machine and run:
        bash install.sh --local /path/to/isw_<version>_${OS}_${ARCH}.tar.gz
        (or: ISW_LOCAL_PACKAGE=/path/to/the.tar.gz bash install.sh)
EOF
  exit 1
}

# version_ge A B → true when dotted version A >= B.
version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$2" ]
}

# ── 1. Detect OS / arch ──────────────────────────────────────────────
step "Detecting platform"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  linux)  ;;
  darwin) ;;
  *)      die "Unsupported OS: $OS (expected linux or darwin)" ;;
esac

ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64)   ARCH="x86_64" ;;
  arm64|aarch64)  ARCH="arm64" ;;
  *)              die "Unsupported architecture: $ARCH_RAW" ;;
esac
ok "os=$OS arch=$ARCH"

# ── 0. Minimum version check ─────────────────────────────────────────
step "Checking minimum requirements"
if [ "$OS" = "darwin" ]; then
  OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 0)"
  version_ge "$OS_VERSION" "$MIN_MACOS" \
    || die "isw requires macOS ${MIN_MACOS} or later (this Mac runs ${OS_VERSION}). Installation aborted."
else
  OS_VERSION="$(uname -r | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')"
  version_ge "$OS_VERSION" "$MIN_LINUX_KERNEL" \
    || die "isw requires Linux kernel ${MIN_LINUX_KERNEL} or later (found ${OS_VERSION}). Installation aborted."
fi
ok "${OS} ${OS_VERSION}"

# ── 2. Required tools ────────────────────────────────────────────────
for cmd in tar; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required tool not found: $cmd"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -n "$LOCAL_PACKAGE" ]; then
  # ── 3-5 (offline). Use the local package ──────────────────────────
  [ -f "$LOCAL_PACKAGE" ] || die "Local package not found: $LOCAL_PACKAGE"
  case "$LOCAL_PACKAGE" in
    *.tar.gz|*.tgz) ;;
    *) die "Local package must be the isw_*_${OS}_${ARCH}.tar.gz release archive: $LOCAL_PACKAGE" ;;
  esac
  ok "offline install from $LOCAL_PACKAGE"
  cp "$LOCAL_PACKAGE" "$TMP/isw.tar.gz"
else
  command -v curl >/dev/null 2>&1 || die "Required tool not found: curl (or use --local for an offline install)"

  # ── 3. Resolve latest release ──────────────────────────────────────
  step "Fetching latest release info"
  LATEST_JSON="$(curl -fsSL -H "User-Agent: isw-installer" \
                  "https://api.github.com/repos/${REPO}/releases/latest")" \
    || die_network "reach the GitHub API"

  VERSION="$(printf "%s" "$LATEST_JSON" | grep -E '"tag_name"' | head -1 | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')"
  [ -n "$VERSION" ] || die "Could not parse tag_name from API response"
  ok "latest=$VERSION"

  # ── 4. Find asset URL ──────────────────────────────────────────────
  ASSET_URL="$(printf "%s" "$LATEST_JSON" \
    | grep -E '"browser_download_url"' \
    | grep -E "${OS}.*${ARCH}\.tar\.gz" \
    | head -1 \
    | sed -E 's/.*"(https:[^"]+)".*/\1/')"

  [ -n "$ASSET_URL" ] || die "No release asset matches ${OS}/${ARCH} in $VERSION"
  ok "asset=$(basename "$ASSET_URL")"

  # ── 5. Download ────────────────────────────────────────────────────
  step "Downloading"
  curl -fsSL "$ASSET_URL" -o "$TMP/isw.tar.gz" || die_network "download $(basename "$ASSET_URL")"
fi

step "Extracting to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMP/isw.tar.gz" -C "$TMP"
EXTRACTED="$(find "$TMP" -type f -name "$BINARY" -perm -u+x | head -1 \
              || find "$TMP" -type f -name "$BINARY" | head -1)"
[ -n "$EXTRACTED" ] || die "Could not find binary '$BINARY' inside the archive"
install -m 0755 "$EXTRACTED" "$INSTALL_DIR/$BINARY"
ok "binary placed at $INSTALL_DIR/$BINARY"

# ── 6. PATH hint ─────────────────────────────────────────────────────
case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    ok "PATH already contains $INSTALL_DIR"
    ;;
  *)
    warn "$INSTALL_DIR is NOT in your PATH"
    cat <<EOF

   Add this to your shell rc (~/.bashrc, ~/.zshrc, …):

       export PATH="\$HOME/.local/bin:\$PATH"

   Then either restart the shell or run: source ~/.bashrc
EOF
    ;;
esac

# ── 7. Verify ────────────────────────────────────────────────────────
step "Verifying installation"
"$INSTALL_DIR/$BINARY" version || warn "Installed, but \`isw version\` failed"

cat <<EOF

${c_green}✦ Done.${c_reset} Run ${c_blue}isw${c_reset} (or open a new shell first).

EOF
