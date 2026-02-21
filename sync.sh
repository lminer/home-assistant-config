#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HA_DIR="/homeassistant"
REPO_HA="$REPO_DIR/homeassistant"

# Files to sync (relative to homeassistant/)
YAML_FILES=(
  configuration.yaml
  automations.yaml
  scripts.yaml
  scenes.yaml
  scratch.yaml
  dashboards/media-center.yaml
  dashboards/climate.yaml
  dashboards/lights.yaml
)

STORAGE_FILES=(
  .storage/lovelace.dashboard_test
  .storage/lovelace_dashboards
  .storage/lovelace_resources
  .storage/input_boolean
  .storage/input_select
)

THEME_DIRS=(
  themes/catppuccin
  themes/ios-themes
  themes/flow
)

usage() {
  echo "Usage: $0 {pull|push|diff}"
  echo ""
  echo "  pull   Copy from live HA config into this repo"
  echo "  push   Copy from this repo into live HA config (restarts HA)"
  echo "  diff   Show differences between repo and live HA config"
  exit 1
}

sync_file() {
  local src="$1" dst="$2"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  $src -> $dst"
  else
    echo "  SKIP (not found): $src"
  fi
}

sync_dir() {
  local src="$1" dst="$2"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
    echo "  $src/ -> $dst/"
  else
    echo "  SKIP (not found): $src/"
  fi
}

do_pull() {
  echo "Pulling from HA ($HA_DIR) into repo ($REPO_HA)..."
  echo ""

  echo "YAML configs:"
  for f in "${YAML_FILES[@]}"; do
    sync_file "$HA_DIR/$f" "$REPO_HA/$f"
  done

  echo ""
  echo "Storage files:"
  for f in "${STORAGE_FILES[@]}"; do
    sync_file "$HA_DIR/$f" "$REPO_HA/$f"
  done

  echo ""
  echo "Themes:"
  for d in "${THEME_DIRS[@]}"; do
    sync_dir "$HA_DIR/$d" "$REPO_HA/$d"
  done

  echo ""
  echo "Done. Review changes with: cd $REPO_DIR && git diff"
}

do_push() {
  echo "Pushing from repo ($REPO_HA) into HA ($HA_DIR)..."
  echo ""

  echo "YAML configs:"
  for f in "${YAML_FILES[@]}"; do
    sync_file "$REPO_HA/$f" "$HA_DIR/$f"
  done

  echo ""
  echo "Storage files:"
  for f in "${STORAGE_FILES[@]}"; do
    sync_file "$REPO_HA/$f" "$HA_DIR/$f"
  done

  echo ""
  echo "Themes:"
  for d in "${THEME_DIRS[@]}"; do
    sync_dir "$REPO_HA/$d" "$HA_DIR/$d"
  done

  echo ""
  read -p "Restart Home Assistant to apply changes? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Restarting Home Assistant..."
    ha core restart
    echo "Restart initiated."
  else
    echo "Skipped restart. Changes will apply on next restart."
  fi
}

do_diff() {
  echo "Differences between repo and live HA config:"
  echo "(< = repo, > = live HA)"
  echo ""

  local has_diff=false

  for f in "${YAML_FILES[@]}" "${STORAGE_FILES[@]}"; do
    if [ -f "$REPO_HA/$f" ] && [ -f "$HA_DIR/$f" ]; then
      if ! diff -q "$REPO_HA/$f" "$HA_DIR/$f" > /dev/null 2>&1; then
        echo "=== $f ==="
        diff "$REPO_HA/$f" "$HA_DIR/$f" || true
        echo ""
        has_diff=true
      fi
    elif [ -f "$HA_DIR/$f" ] && [ ! -f "$REPO_HA/$f" ]; then
      echo "=== $f (only in HA, not in repo) ==="
      has_diff=true
    elif [ -f "$REPO_HA/$f" ] && [ ! -f "$HA_DIR/$f" ]; then
      echo "=== $f (only in repo, not in HA) ==="
      has_diff=true
    fi
  done

  if [ "$has_diff" = false ]; then
    echo "No differences found."
  fi
}

case "${1:-}" in
  pull) do_pull ;;
  push) do_push ;;
  diff) do_diff ;;
  *) usage ;;
esac
