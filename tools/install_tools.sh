#!/usr/bin/env bash
# Installs Lune and luau-lsp from their GitHub releases (CI on Linux, or the Mac; needs `gh`).
# Pin versions with LUNE_TAG / LUAU_LSP_TAG, or leave them empty for latest.
set -euo pipefail
trap 'echo "::error title=install_tools failed::line $LINENO: $BASH_COMMAND"' ERR
BIN="${BIN:-$HOME/.local/bin}"
mkdir -p "$BIN"
LUNE_TAG="${LUNE_TAG:-v0.11.0}"
LUAU_LSP_TAG="${LUAU_LSP_TAG:-}"

# release asset names: lune-X-macos-aarch64.zip, luau-lsp-macos.zip (universal), *-linux-x86_64.zip
case "$(uname -s)" in
  Darwin) OS_RE='macos' ;;
  *) OS_RE='linux' ;;
esac
case "$(uname -m)" in
  arm64 | aarch64) ARCH_RE='aarch64|arm64|macos\.zip' ;;
  *) ARCH_RE='x86_64|macos\.zip' ;;
esac

fetch() {
  local repo="$1" name="$2" tag="$3" dir
  dir="$(mktemp -d)"
  if [ -n "$tag" ] && ! gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
    echo "tag $tag not found for $repo, using latest"
    tag=""
  fi
  [ -z "$tag" ] && tag="$(gh release view --repo "$repo" --json tagName -q .tagName)"
  local asset
  asset="$(gh release view "$tag" --repo "$repo" --json assets -q '.assets[].name' \
    | grep -iE "$OS_RE" | grep -iE '\.zip$' | grep -iE "$ARCH_RE" | head -1)"
  [ -n "$asset" ] || { echo "no $OS_RE/$ARCH_RE asset for $repo $tag"; exit 1; }
  gh release download "$tag" --repo "$repo" --pattern "$asset" --dir "$dir" --clobber
  unzip -oq "$dir/$asset" -d "$dir/x"
  install -m755 "$(find "$dir/x" -type f -name "$name" | head -1)" "$BIN/$name"
  echo "installed $name $tag"
}

fetch lune-org/lune lune "$LUNE_TAG"
fetch JohnnyMorganz/luau-lsp luau-lsp "$LUAU_LSP_TAG"
[ -n "${GITHUB_PATH:-}" ] && echo "$BIN" >> "$GITHUB_PATH"
"$BIN/lune" --version || true
