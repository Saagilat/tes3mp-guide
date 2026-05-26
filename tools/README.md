# Tools

This directory contains platform-specific utilities for managing TES3MP.

## Linux

| Path | Description |
|------|-------------|
| [linux/modding/](linux/modding/) | Scripts for mod management (`tes3mp-upload-mods`, `tes3mp-download-mods`) |
| [linux/localization/russian/](linux/localization/russian/) | Russian language pack install script |

### modding/

- `tes3mp-upload-mods` — admin tool: sync local mods folder to the server and run `update_mods.sh` (see [server/modding.md](../server/modding.md))
- `tes3mp-download-mods` — player tool: download server mods and install to `Data Files`, update `openmw.cfg` (see [client/installing-mods.md](../client/installing-mods.md))
- `admin.conf` — config template for `tes3mp-upload-mods`
- `client.conf` — config template for `tes3mp-download-mods`