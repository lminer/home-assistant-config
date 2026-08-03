# Recovery Runbook

How to rebuild this Home Assistant instance from scratch.

**This repo is not sufficient on its own, by design.** It holds configuration; it
deliberately does not hold credentials. A full rebuild needs two inputs:

1. **A Home Assistant supervisor backup tar** — credentials, integration setups, IR codes.
2. **This git repo** — YAML config, dashboards, themes, icons, registries.

Read the "Before you need it" section now, not after the disk dies.

---

## Before you need it

### 1. Your backups are encrypted. Save the key offline.

Automatic backups are encrypted with the emergency-kit password stored in
`.storage/backup` (`data.config.create_backup.password`). That file lives on the same
disk as the backups. **If the disk dies, the tars are unreadable even if you have a
copy of them.**

The password is deliberately not in this repo. Go to
**Settings → System → Backups → three-dot menu → Emergency kit** and store it somewhere
that is not this machine — a password manager, printed, whatever. Do this first.

### 2. Backups are local-only. Add an offsite target.

Current state as of the last audit:

| | |
|---|---|
| Schedule | Daily |
| Agents | `hassio.local` only |
| Retention | 3 copies |
| Location | `/backup` on the HA disk |
| Size | ~48 MB each |
| Contents | All addons, database included |

One agent, one disk. To fix:

1. **Settings → Add-ons → Add-on Store**, install a backup-location addon. Common
   choices: *Home Assistant Google Drive Backup*, a *Samba/NFS* share on a NAS, or an
   S3-compatible target via *Backup to S3*.
2. **Settings → System → Backups → Backup settings**, add the new location under
   *Locations* so it is checked alongside `hassio.local`. Both should be selected — you
   want a local copy for fast restores and a remote copy for disasters.
3. Set retention. Local 3 copies is fine; give the remote more (30 days is a reasonable
   default) since remote storage is cheap and it protects against a corruption you don't
   notice for a week.
4. ~~Add a failure alarm.~~ **Done 2026-08-02.** `automations.yaml` now has
   `backup_failure_alert`, which raises a persistent notification on either signal:
   `event.backup_automatic_backup` reporting `event_type: failed`, or
   `sensor.backup_backup_manager_state` sitting at `blocked` for 15 minutes. It is tracked
   here, so a rebuild restores it.

   Steps 1–3 above are **still outstanding.** The alarm tells you a backup broke; it does
   nothing about the fact that every copy is on one disk.

### 3. Keep the repo pushed

`./sync.sh pull && git commit && git push`. The GitHub copy is the only part of this
that survives the house burning down.

---

## What lives where

### In this repo (restored by `./sync.sh push`)

- `configuration.yaml`, `automations.yaml`, `scripts.yaml`, `scenes.yaml`
  (**not** `scratch.yaml` — nothing includes it, so HA never loads it; dropped from `sync.sh`
  on 2026-08-02, though the live file and the git history both still have it)
- `dashboards/` — the Media Center, Climate, and Lights YAML dashboards
- `themes/` — all six theme directories
- `custom_icons/` — 31 SVGs
- `www/custom-icons.js` and `www/images/`
- `.storage/lovelace_dashboards`, `.storage/lovelace_resources`
- `.storage/input_boolean`, `.storage/input_select`
- `.storage/energy` — Energy dashboard sources (which sensor is grid/solar/battery). UI-only
  config with no YAML equivalent, so this file is the only reproducible record of it.
- `.storage/core.area_registry`, `core.floor_registry`, `core.device_registry`,
  `core.entity_registry`

### Only in the supervisor backup tar

Nothing below is in git, and none of it can be reconstructed by hand without pain:

| Item | Why it matters |
|---|---|
| `.storage/core.config_entries` | Every integration's setup **and its credentials** — Ecobee OAuth, mobile_app secrets, Bravia/Sony keys, MQTT login. Excluded from git on purpose. |
| `secrets.yaml` | Referenced by `configuration.yaml`. Gitignored; see `secrets.yaml.example` for shape. Holds `franklinwh_password` — without it the FranklinWH sensors do not load. |
| `.storage/broadlink_remote_*_codes` | **Learned IR codes.** Lose these and you re-learn every button on every remote by hand. The single most annoying thing to lose. |
| `kumo_cache.json` (config root) | **Mitsubishi local credentials — currently irreplaceable.** See the section below. |
| `.storage/auth`, `.storage/auth_provider.homeassistant` | User accounts, long-lived tokens, refresh tokens. |
| `homekit.*`, `homekit_controller-entity-map` | HomeKit bridge pairing state. Without it, re-pair every accessory. |
| `lutron_caseta-*.pem` | Lutron bridge cert/key/pem at the config root. |
| `sony/` | Hand-rolled 9-file Sony integration. Not in HACS, not in this repo. |
| `androidtv_remote_*.pem` | Android TV remote pairing. |

---

## Rebuild procedure

### Step 1 — Fresh HAOS

Install Home Assistant OS. Match the version this config was known-good against
(**2026.7.4**, see `hacs_manifest.txt`) or newer. Do **not** complete onboarding —
choose "restore from backup" on the onboarding screen if you have the tar handy.

### Step 2 — Restore the supervisor tar

Restore the most recent `Automatic_backup_*.tar`. You will be prompted for the
emergency-kit password from "Before you need it" above.

This brings back credentials, integrations, IR codes, auth, and HomeKit pairings. At
this point HA should largely work already — the tar is a full backup, not a partial.

**If you have no tar**, HA comes up empty and you must re-add all 28 integrations by
hand through the UI, re-learn the Broadlink IR codes, and re-pair HomeKit. Steps 3–5
still apply and will save you the dashboard and theme work.

### Step 3 — Install HACS and its content

Install HACS (https://hacs.xyz), restart, then work through `hacs_manifest.txt`. Note
`lutron_lip` must be added as a custom repository before it appears in search.

Restart Home Assistant.

### Step 4 — Push this repo over the top

```bash
git clone git@github.com:lminer/home-assistant-config.git
cd home-assistant-config
./sync.sh diff    # see what the tar restored vs. what git has
./sync.sh push    # answer 'y' to restart
```

Run `diff` first. If the tar is newer than the last `git push`, the tar wins on some
files and you want to know which before overwriting them.

### Step 5 — Recreate what neither source holds

- `secrets.yaml` — copy `secrets.yaml.example` and fill in real values (only
  `some_password` is currently used).
- `sony/` — re-fetch from wherever it originally came from, if the tar did not restore it.

### Step 6 — Verify

```bash
ha core check          # config validates
./sync.sh diff         # should print "No differences found."
```

Then in the UI: confirm all six themes appear in the theme picker, the three YAML
dashboards load (Media Center / Climate / Lights), rooms and floors are populated
(13 areas across 3 floors), and the Broadlink IR buttons on the media dashboard
actually fire.

---

## Notes

### `kumo_cache.json` cannot currently be regenerated

The Mitsubishi Office heat pump is driven by `dlarrick/hass-kumo`, which talks to the
adapter directly on the LAN using a per-unit `password` and `cryptoSerial`. Those are
normally fetched once from Mitsubishi's cloud at setup.

**Since roughly 2026-07-28 the V3 API stops returning them.** Login still works, sites and
zones enumerate, `adapter_update` events still fire — but `password` and `cryptoSerial`
appear in no response, at any depth, from any endpoint. Reproduced independently on
separate accounts; see [pykumo#78](https://github.com/dlarrick/pykumo/issues/78) and
[hass-kumo#230](https://github.com/dlarrick/hass-kumo/issues/230). The official core
`mitsubishi_comfort` integration fails the same way, so switching integrations is not a
workaround. Power-cycling the units does not help.

The only surviving copy of those credentials for this house is `kumo_cache.json` at the
config root, which predates the change. It is **not in git** — it holds the units' local
passwords and the WiFi PSK — and it is not in `sync.sh`. It is in supervisor backups.
**Keep an offline copy.** If it is lost, there is no local control until Mitsubishi
restores the API, and a factory reset of the adapter would invalidate it regardless.

Setup depends on it in a way that needs a temporary patch. `__init__.py` passes the cache
to pykumo at runtime, but `config_flow.py` does not, so a fresh install reaches for the
dead cloud API and fails with a misleading "invalid credentials". To re-add the
integration while the API is broken, edit `custom_components/kumo/config_flow.py`, in
`validate_input()`:

```python
    cached_dict = None
    cache_path = hass.config.path(KUMO_CONFIG_CACHE)
    if prefer_cache and os.path.exists(cache_path):
        cached_dict = await hass.async_add_executor_job(load_json, cache_path)

    account = KumoCloudAccount(
        data["username"], data["password"], kumo_dict=cached_dict
    )
```

replacing the bare `KumoCloudAccount(data["username"], data["password"])`. All the imports
it needs are already at the top of the file. Restart, run the flow with **`prefer_cache`
ticked**, then revert the patch — only the setup path needs it, and HACS updates overwrite
it anyway. Check whether upstream has fixed this before bothering.

#### The second property's units were removed from the cache on 2026-08-02

The Comfort account also covers a second property — `Middle unit` (`9Z34P008D100060F`,
`10.0.0.8`) and `South unit` (`9Z34P008D100061F`, `10.0.0.9`). They arrived with the cache
and were deleted from it. **Their `password` and `cryptoSerial` now exist only in backups**,
and since the V3 API no longer returns those fields, no backup means no local control of
that property, ever. They are in:

- `/homeassistant/kumo_cache.json.bak-20260802-vlan` (same disk — not a real backup)
- every supervisor backup tar taken before 2026-08-02

**Get one of those off this machine.** That is the whole safety net.

Why they were removed rather than disabled: **disabling the devices in HA does not stop
them being polled.** `__init__.py` builds a `KumoDataUpdateCoordinator` for every unit
`make_pykumos()` returns, before any entity exists and without consulting the entity
registry. The coordinators kept hammering two unreachable addresses forever — ~11 timeout
warnings a minute and a failed refresh per unit per cycle. Worse, the cost scales with
`connect_timeout`, so raising that to 5s to rescue the Office unit made each dead attempt
four times slower.

Do not repeat this dead end: pointing them at `127.0.0.1` so connections refuse instantly
(via **Kumo → Configure → Unit Settings**) does fix the *time* cost — 27 ms instead of a
full timeout — but it makes the log **worse**, not better. Failing fast lets pykumo get
all the way through ~30 per-field queries per unit instead of giving up early, measured at
72 log lines a minute versus 9. Deleting the units is the only thing that actually stops
it. After removal, steady-state kumo logging is zero lines.

Removing them leaves orphaned rows in `core.device_registry` and `core.entity_registry`
(2 devices, 13 entities), which are tracked here. Delete the devices in the UI to clear
them; HA does not do it automatically.

### The 2026-08-02 VLAN move

Most of the house moved from `192.168.1.x` to `192.168.55.x`. Devices generally kept their
last octet. Integrations that store an IP rather than rediscovering it need re-pointing by
hand; mDNS-based ones sorted themselves out after a reload.

| Device | Result |
|---|---|
| Sonos Study / Media Room / Living Room | Fine after an integration reload — `.122`, `.130`, `.198` |
| Apple TV Duncan | **Still on `192.168.1.202`** and working. Deliberately not moved. |
| Sony UBP-X800 | Moved to `192.168.55.9`. Three entries (`songpal`, `dlna_dmr`, `dlna_dms`) held the old `192.168.1.9` and retried every 3m10s until they were deleted and rediscovered. Songpal has no reconfigure flow, so delete-and-re-add is the only route. Nothing references `media_player.ubp_x800`, so this is safe; the `source: UBP-X800` lines in `scripts.yaml` are the Denon input name, not the player. |
| Mitsubishi Office Kumo | `kumo_cache.json` hardcodes the address, so it must be edited by hand. Give the adapter (MAC `c4:ac:59:8f:35:c7`) a DHCP reservation — the cache cannot follow a lease change. |

### Leftover `.bak` files

In-place edits leave `.bak` copies scattered through the config root. Seventeen were deleted
on 2026-08-02, including four copies of `core.config_entries` that held live OAuth tokens and
passwords in plaintext — the exact thing this repo is careful never to track. `.gitignore` now
carries `*.bak`, `*.bak-*`, and `*.bak.*` so none can ever be committed.

If you make one, delete it when you are done. The registry and YAML files are all recoverable
from git; `core.config_entries` is only in the supervisor tars, so a stale copy of it is pure
liability with no upside.

### Registry files churn

`.storage/core.device_registry` and `core.entity_registry` rewrite `modified_at`
timestamps on nearly every HA restart. Expect `./sync.sh pull` to show them as changed
constantly, with no meaningful content difference. This is noise, not drift — commit it
or don't, but don't go hunting for what changed.

### `sync.sh` never deletes

`pull` and `push` both copy only. A file deleted on one side lingers on the other until
you remove it by hand. If something is gone from live HA and should be gone from the
repo, `git rm` it explicitly.

### What is deliberately excluded from git

`core.config_entries` is the one registry left untracked, because it is the only one
containing credentials. The other four were checked and contain no token, password,
secret, API key, or PSK fields. If you ever add `config_entries` to `sync.sh`, the
GitHub repo must be private and you should treat every credential in it as exposed.
