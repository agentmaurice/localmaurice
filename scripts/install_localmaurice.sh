#!/usr/bin/env bash
set -euo pipefail

GITHUB_OWNER="agentmaurice"
GITHUB_REPO="localmaurice"
BIN_NAME="localmaurice"
ENDPOINT="${LOCALMAURICE_UPDATE_ENDPOINT:-https://get.agentmaurice.app/products/localmaurice/latest.json}"
CHANNEL="${LOCALMAURICE_UPDATE_CHANNEL:-stable}"
INSTALL_DIR=""
VERSION=""

usage() {
  cat <<EOF
Install or update ${BIN_NAME} (AgentMaurice Edge).

Usage:
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/scripts/install_localmaurice.sh | bash

Options:
  -v, --version <tag>   Install a specific release tag (e.g. v1.12.0). Default: latest
  -b, --bin-dir <dir>   Install directory. Default: /usr/local/bin or ~/.local/bin
  -c, --channel <name>  Update channel when using the gateway. Default: stable
  -h, --help            Show help
EOF
}

dl() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -A "localmaurice-installer" "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget --user-agent="localmaurice-installer" -O "$2" "$1"
  else
    echo "Error: curl or wget is required" >&2
    exit 1
  fi
}

manifest_url() {
  case "$ENDPOINT" in
    *\?*) printf '%s&channel=%s' "$ENDPOINT" "$CHANNEL" ;;
    *) printf '%s?channel=%s' "$ENDPOINT" "$CHANNEL" ;;
  esac
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
      -c|--channel) CHANNEL="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
    esac
  done
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

find_binary() {
  extract="$1"
  os="$2"
  arch="$3"
  find "$extract" -type f \( \
    -name "$BIN_NAME" -o \
    -name "${BIN_NAME}.exe" -o \
    -name "${BIN_NAME}_${os}_${arch}" -o \
    -name "${BIN_NAME}_${os}_${arch}.exe" \
  \) -print -quit
}

expected_sha_from_sums() {
  sums="$1"
  filename="$2"
  awk -v f="$filename" '
    $2 == f || $2 == ("*" f) { print $1; exit }
  ' "$sums"
}

install_binary() {
  src="$1"
  installed_version="$2"
  if [ -z "$INSTALL_DIR" ]; then
    if [ -w /usr/local/bin ]; then
      INSTALL_DIR="/usr/local/bin"
    else
      INSTALL_DIR="$HOME/.local/bin"
    fi
  fi
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "$src" "$INSTALL_DIR/${BIN_NAME}"
  echo "Installed ${BIN_NAME} ${installed_version} to $INSTALL_DIR/${BIN_NAME}"
  echo "Ensure $INSTALL_DIR is in your PATH."
}

install_from_github() {
  os="$1"
  arch="$2"
  tmpdir="$3"
  asset="${BIN_NAME}_${os}_${arch}"
  if [ -z "$VERSION" ]; then
    tmpjson="$tmpdir/latest-release.json"
    echo "Fetching latest GitHub release"
    dl "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest" "$tmpjson"
    if command -v jq >/dev/null 2>&1; then
      VERSION=$(jq -r '.tag_name // empty' "$tmpjson")
    else
      VERSION=$(grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$tmpjson" | head -n1 | sed 's/.*"\([^"]*\)".*/\1/')
    fi
  fi
  if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    echo "Error: cannot determine latest release tag" >&2
    exit 1
  fi

  archive_name="${asset}.tar.gz"
  url="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VERSION}/${archive_name}"
  sums_url="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VERSION}/sha256sums.txt"
  echo "Downloading ${url}"
  dl "$url" "$tmpdir/pkg.tar.gz"
  dl "$sums_url" "$tmpdir/sha256sums.txt"
  expected_sha="$(expected_sha_from_sums "$tmpdir/sha256sums.txt" "$archive_name")"
  if [ -z "$expected_sha" ]; then
    echo "Error: checksum not found for ${archive_name}" >&2
    exit 1
  fi
  actual_sha="$(sha256_file "$tmpdir/pkg.tar.gz")"
  if [ "$actual_sha" != "$expected_sha" ]; then
    echo "Error: checksum mismatch" >&2
    exit 1
  fi

  extract="$tmpdir/extract"
  mkdir -p "$extract"
  tar -xzf "$tmpdir/pkg.tar.gz" -C "$extract"
  src="$(find_binary "$extract" "$os" "$arch")"
  if [ -z "$src" ]; then
    echo "Error: binary not found in archive" >&2
    exit 1
  fi
  chmod 0755 "$src"
  install_binary "$src" "$VERSION"
}

install_from_gateway() {
  os="$1"
  arch="$2"
  tmpdir="$3"
  key="${os}/${arch}"
  manifest="$tmpdir/latest.json"
  url="$(manifest_url)"
  echo "Fetching manifest ${url}"
  if ! dl "$url" "$manifest"; then
    return 1
  fi

  latest_version=$(jq -r '.version // empty' "$manifest")
  if [ -z "$latest_version" ]; then
    echo "Error: manifest missing version" >&2
    return 1
  fi
  if [ -n "$VERSION" ] && [ "$VERSION" != "$latest_version" ]; then
    echo "Gateway latest is ${latest_version}, requested ${VERSION}; using GitHub." >&2
    return 1
  fi

  archive_url=$(jq -r --arg key "$key" '.assets[$key].source_url // .assets[$key].download_url // empty' "$manifest")
  expected_sha=$(jq -r --arg key "$key" '.assets[$key].sha256 // empty' "$manifest")
  binary_name=$(jq -r --arg key "$key" '.assets[$key].binary_name // empty' "$manifest")
  format=$(jq -r --arg key "$key" '.assets[$key].format // empty' "$manifest")
  if [ -z "$archive_url" ] || [ -z "$expected_sha" ]; then
    echo "Error: manifest has no complete asset for ${key}" >&2
    return 1
  fi

  archive="$tmpdir/package"
  echo "Downloading ${archive_url}"
  dl "$archive_url" "$archive"
  actual_sha="$(sha256_file "$archive")"
  if [ "$actual_sha" != "$expected_sha" ]; then
    echo "Error: checksum mismatch" >&2
    exit 1
  fi

  extract="$tmpdir/extract"
  mkdir -p "$extract"
  case "$format" in
    tar.gz|tgz|"") tar -xzf "$archive" -C "$extract" ;;
    zip) unzip -q "$archive" -d "$extract" ;;
    *) echo "Error: unsupported format ${format}" >&2; exit 1 ;;
  esac

  src=""
  if [ -n "$binary_name" ]; then
    src="$(find "$extract" -type f -name "$binary_name" -print -quit)"
  fi
  if [ -z "$src" ]; then
    src="$(find_binary "$extract" "$os" "$arch")"
  fi
  if [ -z "$src" ]; then
    echo "Error: binary not found in archive" >&2
    exit 1
  fi
  chmod 0755 "$src"
  install_binary "$src" "$latest_version"
}

main() {
  parse_args "$@"
  read -r os arch < <(detect_os_arch)

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  if command -v jq >/dev/null 2>&1; then
    if install_from_gateway "$os" "$arch" "$tmpdir"; then
      return
    fi
    echo "Gateway install unavailable; falling back to GitHub Releases." >&2
  fi
  install_from_github "$os" "$arch" "$tmpdir"
}

main "$@"
