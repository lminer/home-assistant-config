# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A version-controlled Home Assistant configuration repo that syncs between a git repo and the live HA instance. The repo lives inside the HA config directory at `/homeassistant/home-assistant-config/` so it persists across HAOS image reboots (unlike `/root/` which gets wiped).

## Sync Workflow

The `sync.sh` script is the primary tool for moving config between the repo and live HA:

```bash
./sync.sh pull   # Live HA → repo (before committing)
./sync.sh push   # Repo → live HA (optionally restarts HA)
./sync.sh diff   # Show differences between repo and live
```

Key paths:
- **Live HA config**: `/homeassistant/` (the actual mount; `/root/homeassistant` and `/config` are symlinks to it)
- **Repo copy of HA files**: `homeassistant/` subdirectory in this repo
- **Repo root**: `/homeassistant/home-assistant-config/`

The repo tracks a specific subset of HA files — YAML configs, select `.storage/` files, and theme directories. See the arrays at the top of `sync.sh` for the exact list.

## Repo Structure

- `homeassistant/` — Tracked copy of live HA config files, mirroring the live layout:
  - YAML configs, `dashboards/`, `www/`
  - `themes/` — all six theme directories
  - `custom_icons/` — the 31 SVGs served by the `custom_icons` integration (same content
    as `flow/custom_icons/`, but at the path HA actually loads from)
  - `.storage/` — Lovelace dashboards/resources, input helpers, and the four
    credential-free registries (area, floor, device, entity)
- `flow/` — Custom Lovelace UI components for the "Flow" theme:
  - `card-yaml/` — Reusable card definitions (nav bars, remote controls, page layouts)
  - `custom_icons/` — 31 SVG icons used by cards (referenced via `fapro:` and `local:` prefixes)
  - `complete-yaml` — Full merged Lovelace config (~30K lines)
  - `flow-theme.yaml` — Dark iOS-inspired theme definition
- `hacs_manifest.txt` — Everything installed via HACS, by `owner/repo` slug
- `RECOVERY.md` — Rebuild runbook: what's in git vs. what's only in a supervisor backup
- `secrets.yaml.example` — Template for HA secrets (actual `secrets.yaml` is gitignored)

## Key Conventions

- Lovelace runs in **storage mode** — dashboard JSON lives in `.storage/` files, YAML dashboards are declared in `configuration.yaml`
- Custom frontend relies heavily on **Mushroom cards**, **card-mod** (CSS), **button-card**, and **layout-card** from HACS
- The setup targets a media-center/kiosk use case (kiosk-mode plugin, Apple TV remote card, media scripts)
- Scripts in `homeassistant/scripts.yaml` focus on AV control (Sony TV, Denon receiver, HDMI source switching via IR blaster)
- No CI/CD, linting, or test tooling exists — validation is manual via `sync.sh diff` and HA config check
- `.storage/core.config_entries` is **deliberately never tracked** — it is the only registry
  holding live credentials. The other four registries were audited and are credential-free.
- `sync.sh` copies but never deletes. A file removed on one side lingers on the other until
  it is removed by hand.
- `core.device_registry` and `core.entity_registry` rewrite `modified_at` on most HA
  restarts, so `sync.sh pull` shows them as changed constantly. That churn is noise.
