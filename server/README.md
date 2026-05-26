# Server

This directory contains documentation and files for setting up and managing a TES3MP server via Docker.

## Documentation

| File | Description |
|------|-------------|
| [install.md](install.md) | Quick install script (recommended) |
| [management.md](management.md) | Daily server management (start, stop, logs, config, endpoints) |
| [modding.md](modding.md) | Adding mods to the server (quick upload via `tes3mp-upload-mods`) |
| [tes3mp_settings.md](tes3mp_settings.md) | Full `config.lua` reference with all settings |

## Files

- [files/docker/](files/docker/) — Docker files (compose, Dockerfiles, nginx config, export script)
- [files/scripts/](files/scripts/) — Shell scripts (`install.sh`, `update_mods.sh`)