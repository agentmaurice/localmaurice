#!/usr/bin/env bash
set -euo pipefail

GITHUB_OWNER="agentmaurice"
GITHUB_REPO="localmaurice"
BIN_NAME="localmaurice"
INSTALL_DIR=""
VERSION=""
VERIFY="0"

usage() {
  cat <<EOF
Install or update ${BIN_NAME} from GitHub Releases.

Usage:
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/scripts/install_localmaurice.sh | bash

Options (as env or args):
  -v, --version <tag>   Install specific tag (e.g. v1.2.3). Default: latest
  -b, --bin-dir <dir>   Install directory. Default: /usr/local/bin or ~/.local/bin
  --verify              Verify sha256 checksum if available
  -h, --help            Show help
EOF
}

dl() {
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$2" "$1"
  else
    echo "Error: curl or wget is required" >&2
    exit 1
  fi
}

detect_os_arch() {
  uname_s=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$uname_s" in
    linux) os=linux ;;
    darwin) os=darwin ;;
    *) echo "Unsupported OS: $uname_s" >&2; exit 1 ;;
  esac
  uname_m=$(uname -m)
  case "$uname_m" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported arch: $uname_m" >&2; exit 1 ;;
  esac
  echo "$os" "$arch"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -v|--version) VERSION="$2"; shift 2 ;;
      -b|--bin-dir) INSTALL_DIR="$2"; shift 2 ;;
      --verify) VERIFY="1"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
    esac
  done
}

ensure_dir() {
  dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
}

main() {
  parse_args "$@"
  read -r os arch < <(detect_os_arch)

  asset="${BIN_NAME}_${os}_${arch}"
  ext=".tar.gz"

  if [ -z "$VERSION" ]; then
    VERSION=$(dl "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest" /dev/stdout | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -n1)
    if [ -z "$VERSION" ]; then echo "Error: cannot determine latest release tag" >&2; exit 1; fi
  fi

  base="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VERSION}"
  url_asset="${base}/${asset}${ext}"
  url_sums="${base}/sha256sums.txt"

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  echo "Downloading ${url_asset}"
  dl "$url_asset" "$tmpdir/pkg${ext}"

  if [ "$VERIFY" = "1" ]; then
    echo "Downloading checksums"
    dl "$url_sums" "$tmpdir/sha256sums.txt" || true
    if [ -f "$tmpdir/sha256sums.txt" ]; then
      (cd "$tmpdir" && sha256sum -c --ignore-missing sha256sums.txt)
    else
      echo "Warning: checksums not available"
    fi
  fi

  tar -xzf "$tmpdir/pkg${ext}" -C "$tmpdir"
  src="$tmpdir/${BIN_NAME}"

  # Verify binary was extracted
  if [ ! -f "$src" ]; then
    echo "Error: binary '$BIN_NAME' not found in archive" >&2
    exit 1
  fi

  if [ -z "$INSTALL_DIR" ]; then
    if [ -w /usr/local/bin ]; then
      INSTALL_DIR="/usr/local/bin"
    else
      INSTALL_DIR="$HOME/.local/bin"
    fi
  fi

  ensure_dir "$INSTALL_DIR"
  install -m 0755 "$src" "$INSTALL_DIR/${BIN_NAME}"
  echo "Installed to $INSTALL_DIR/${BIN_NAME}"
  echo "Ensure $INSTALL_DIR is in your PATH."
  "$INSTALL_DIR/${BIN_NAME}" --help || true
}

main "$@"
