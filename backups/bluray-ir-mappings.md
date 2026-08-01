# Blu-ray remote — original IR-blaster mappings (pre-Scalar, 2026-06-11)

Full pre-change dashboard: `backups/media-center.yaml.2026-06-11.bak`

The Blu-ray remote is an `custom:android-tv-card` in `dashboards/media-center.yaml`
(conditional `input_select.selected_remote == bluray`, was ~lines 806-1121).
Every button used `remote.send_command` on `remote.ir_blaster` with `device: television`.

## To revert
Copy the backup over the live file and push:
```
cp backups/media-center.yaml.2026-06-11.bak homeassistant/dashboards/media-center.yaml
cp homeassistant/dashboards/media-center.yaml /homeassistant/dashboards/media-center.yaml
# (then reload the dashboard; remove the rest_command/rest blocks from configuration.yaml if undoing fully)
```

## Original IR command per button (remote.ir_blaster, device: television)
| Button        | IR `command`  | android-tv `key` |
|---------------|---------------|------------------|
| power         | (script.turn_off_blu_ray_player) | POWER |
| up            | up            | Up        |
| down          | down          | Down      |
| left          | left          | Left      |
| right         | right         | Right     |
| center        | select        | Select    |
| play          | play          | Play      |
| pause         | pause         | Pause     |
| stop          | stop          | Stop      |
| fast_forward  | fforward      | fast_forward |
| rewind        | rewind        | Rewind    |
| prev          | prev          | Previous  |
| next          | next          | Next      |
| home          | home          | Home      |
| return        | return        | Return    |
| eject         | open close    | Open      |
| subtitle      | subtitle      | Subtitle  |
| audio         | audio         | Audio     |
| volume_*      | (media_player.denon_avr_x4700h) | volume_up/down |

## Changed to Scalar API (2026-06-11)
These 6 now call `rest_command.bluray_*` instead of IR:
pause, stop, fast_forward, rewind, prev, next.

Still IR (no Scalar equivalent or safer on IR):
up, down, left, right, center, **play**, home, return, eject, subtitle, audio, power, volume.
