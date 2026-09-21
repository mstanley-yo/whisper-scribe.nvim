#!/usr/bin/env bash
# Idempotent, pinned dependency installer for whisper-scribe.nvim.
#
# - ffmpeg: installed via Homebrew (Homebrew doesn't support real version
#   pinning without fighting its dependency model - see README). Self-heals
#   the class of dylib-version-skew breakage Homebrew can produce by
#   detecting a broken ffmpeg and running `brew reinstall`.
# - whisper-cli: built from a pinned whisper.cpp git tag, fully reproducible.
# - model: downloaded from a pinned URL and verified against a pinned SHA256.
set -euo pipefail

WHISPER_CPP_TAG="v1.9.4"
MODEL_NAME="ggml-base.en.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_NAME}"
MODEL_SHA256="a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"

INSTALL_DIR="${WHISPER_SCRIBE_HOME:-$HOME/.local/share/whisper-scribe}"
WHISPER_CPP_SRC="$INSTALL_DIR/whisper.cpp"
BIN_DIR="$INSTALL_DIR/bin"
MODEL_DIR="$INSTALL_DIR/models"
WHISPER_CLI="$BIN_DIR/whisper-cli"
VERSION_FILE="$BIN_DIR/.whisper-cli.version"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

log() { printf '==> %s\n' "$1"; }
die() { printf 'error: %s\n' "$1" >&2; exit 1; }

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

ensure_ffmpeg() {
  command -v brew >/dev/null 2>&1 || die "Homebrew is required for ffmpeg. Install from https://brew.sh"

  if ! brew list ffmpeg >/dev/null 2>&1; then
    log "installing ffmpeg via Homebrew..."
    brew install ffmpeg
  fi

  if ! ffmpeg -version >/dev/null 2>&1; then
    log "ffmpeg looks broken (likely a Homebrew dylib version mismatch) - reinstalling..."
    brew reinstall ffmpeg
  fi

  ffmpeg -version >/dev/null 2>&1 || die "ffmpeg still not working after reinstall - inspect 'ffmpeg -version' output manually."
  log "ffmpeg OK: $(command -v ffmpeg)"
}

ensure_whisper_cli() {
  if [[ -x "$WHISPER_CLI" && -f "$VERSION_FILE" && "$(cat "$VERSION_FILE")" == "$WHISPER_CPP_TAG" ]]; then
    log "whisper-cli $WHISPER_CPP_TAG already installed at $WHISPER_CLI"
    return
  fi

  command -v cmake >/dev/null 2>&1 || die "cmake is required to build whisper-cli. Install via 'brew install cmake'."

  mkdir -p "$BIN_DIR"

  if [[ -d "$WHISPER_CPP_SRC/.git" ]]; then
    log "fetching whisper.cpp tags..."
    git -C "$WHISPER_CPP_SRC" fetch --tags origin
  else
    log "cloning whisper.cpp..."
    git clone https://github.com/ggml-org/whisper.cpp.git "$WHISPER_CPP_SRC"
  fi

  git -C "$WHISPER_CPP_SRC" checkout "$WHISPER_CPP_TAG"

  log "building whisper-cli at $WHISPER_CPP_TAG (this can take a few minutes)..."
  cmake -S "$WHISPER_CPP_SRC" -B "$WHISPER_CPP_SRC/build" >/dev/null
  cmake --build "$WHISPER_CPP_SRC/build" -j --config Release

  local built_binary="$WHISPER_CPP_SRC/build/bin/whisper-cli"
  [[ -x "$built_binary" ]] || die "build finished but $built_binary was not produced."

  cp "$built_binary" "$WHISPER_CLI"
  echo "$WHISPER_CPP_TAG" > "$VERSION_FILE"
  log "built whisper-cli $WHISPER_CPP_TAG -> $WHISPER_CLI"
}

ensure_model() {
  mkdir -p "$MODEL_DIR"

  if [[ -f "$MODEL_PATH" ]] && [[ "$(sha256_of "$MODEL_PATH")" == "$MODEL_SHA256" ]]; then
    log "model already present and verified: $MODEL_PATH"
    return
  fi

  log "downloading $MODEL_NAME..."
  local tmp_path="$MODEL_PATH.tmp"
  curl -L --fail -o "$tmp_path" "$MODEL_URL"

  local actual_sha256
  actual_sha256="$(sha256_of "$tmp_path")"
  if [[ "$actual_sha256" != "$MODEL_SHA256" ]]; then
    rm -f "$tmp_path"
    die "checksum mismatch for $MODEL_NAME (expected $MODEL_SHA256, got $actual_sha256) - download aborted."
  fi

  mv "$tmp_path" "$MODEL_PATH"
  log "model downloaded and verified: $MODEL_PATH"
}

main() {
  ensure_ffmpeg
  ensure_whisper_cli
  ensure_model

  echo
  log "setup complete. Suggested lazy.nvim opts:"
  cat <<EOF

  opts = {
    audio_device_index = 0, -- see device list below, this is a placeholder
    model_path = "$MODEL_PATH",
    ffmpeg_path = "ffmpeg",
    whisper_cli_path = "$WHISPER_CLI",
  }

EOF

  log "your avfoundation audio devices (find your microphone's index below):"
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n '/AVFoundation/,$p' || true
}

main "$@"
