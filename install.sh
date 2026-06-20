#!/usr/bin/env bash
# install.sh — One-line installer for framework-llm on macOS / Linux
#
# Usage:
#   curl -fsSL https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.sh | bash
#
# Este script descarga los binarios desde el repo PÚBLICO de releases
# (TP202610017/framework-llm-releases), que aloja solo artefactos
# compilados. El código fuente del framework vive en un repo separado
# y privado — NO es accesible desde aquí ni queda expuesto al usuario.
#
# Lo que hace:
#   1. Detecta OS (linux/darwin) y arquitectura (x86_64/arm64).
#   2. Resuelve la última release vía GitHub API.
#   3. Descarga el .tar.gz que matchea.
#   4. Extrae isw a ~/.local/bin/isw (crea el dir si hace falta).
#   5. Hint al usuario si ~/.local/bin no está en PATH.
#   6. Verifica `isw version`.

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────
# Repo PÚBLICO de releases. El código fuente está en otro repo
# privado, fuera del alcance de este script.
REPO="TP202610017/framework-llm-releases"
BINARY="isw"
INSTALL_DIR="${ISW_INSTALL_DIR:-$HOME/.local/bin}"

# ── Pretty output ────────────────────────────────────────────────────
c_blue=$'\033[36m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'
c_red=$'\033[31m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
step() { printf "${c_blue}▶  %s${c_reset}\n" "$*"; }
ok()   { printf "${c_green}✓  %s${c_reset}\n" "$*"; }
warn() { printf "${c_yellow}⚠  %s${c_reset}\n" "$*"; }
die()  { printf "${c_red}✗  %s${c_reset}\n" "$*" >&2; exit 1; }

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

# ── 2. Required tools ────────────────────────────────────────────────
for cmd in curl tar; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required tool not found: $cmd"
done

# ── 3. Resolve latest release ────────────────────────────────────────
step "Fetching latest release info"
LATEST_JSON="$(curl -fsSL -H "User-Agent: isw-installer" \
                "https://api.github.com/repos/${REPO}/releases/latest")" \
  || die "Could not reach GitHub API"

VERSION="$(printf "%s" "$LATEST_JSON" | grep -E '"tag_name"' | head -1 | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')"
[ -n "$VERSION" ] || die "Could not parse tag_name from API response"
ok "latest=$VERSION"

# ── 4. Find asset URL ────────────────────────────────────────────────
ASSET_URL="$(printf "%s" "$LATEST_JSON" \
  | grep -E '"browser_download_url"' \
  | grep -E "${OS}.*${ARCH}\.tar\.gz" \
  | head -1 \
  | sed -E 's/.*"(https:[^"]+)".*/\1/')"

[ -n "$ASSET_URL" ] || die "No release asset matches ${OS}/${ARCH} in $VERSION"
ok "asset=$(basename "$ASSET_URL")"

# ── 5. Download + extract ────────────────────────────────────────────
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

step "Downloading"
curl -fsSL "$ASSET_URL" -o "$TMP/isw.tar.gz"

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
