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
- Scripts in `homeassistant/scripts.yaml` focus on AV control (LG webOS TV, Denon
  receiver, Panasonic DP-UB820 Blu-ray). Source switching is all network calls; the
  Blu-ray is the one hybrid — its buttons are Broadlink IR (`device: bluray`) because
  a stock UB820 rejects network control commands without a player key, while the
  `panasonic_bluray` integration supplies playback state. The scripts guard the IR
  power toggle on that state, which is what keeps it idempotent.
- That guard depends on **Quick Start being off on the player**. `cCMD_GET_STATUS`
  fails authentication on a UB820, so the integration cannot distinguish standby from
  stopped and reports `idle` whenever the player is reachable; the only power signal
  left is the network request timing out when the player drops off the LAN. Turn Quick
  Start on and `turn_on_blu_ray_player` silently stops powering the player on. Do not
  "fix" this by removing the guard — it is what stops the toggle desyncing.
  Two things there are string-matched and have no validation: the Denon's input names
  (`Apple TV`, `Switch 2`, `Mac Mini`, `UBP-X800`, `TV Audio`) and the LG's source names
  (`AVR-X4700H` for the receiver, `Sony DVD Player` for the PS5). Rename an input on
  either box and the matching script silently stops working.
- Two of those names are misleading and both are correct as written. The Denon's
  `UBP-X800` input is named after the Sony player replaced in Aug 2026; the Panasonic
  is on that input now. The LG reports the PS5's HDMI port as `Sony DVD Player` — a
  stale CEC label on the physical HDMI 3 port. Note the LG is also inconsistent about
  spacing (`HDMI 1` but `HDMI4`), so always read `source_list` off the live entity
  rather than assuming a format.
- The PS5 is wired straight into the LG, not through the Denon; its audio returns over
  eARC. So `turn_on_ps5` selects a TV input and puts the Denon on `TV Audio`, unlike the
  other sources which select a Denon input.
- No CI/CD, linting, or test tooling exists — validation is manual via `sync.sh diff` and HA config check
- `.storage/core.config_entries` is **deliberately never tracked** — it is the only registry
  holding live credentials. The other four registries were audited and are credential-free.
- `sync.sh` copies but never deletes. A file removed on one side lingers on the other until
  it is removed by hand.
- `core.device_registry` and `core.entity_registry` rewrite `modified_at` on most HA
  restarts, so `sync.sh pull` shows them as changed constantly. That churn is noise.
