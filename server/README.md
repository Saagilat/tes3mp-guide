# Server

This directory contains documentation and files for setting up and managing a TES3MP server via Docker.

## Documentation

| File | Description |
|------|-------------|
| [install.md](install.md) | Quick install script (recommended) |
| [management.md](management.md) | Daily server management (start, stop, logs, config, endpoints) |
| [tes3mp_settings.md](tes3mp_settings.md) | Full `config.lua` reference with all settings |

## Files

- [docker/](docker/) — Docker files (compose, Dockerfiles, nginx config, export script)
- [scripts/](scripts/) — Shell scripts (`install.sh`, `update_mods.sh`)
- [linux/](linux/) — OS-specific files

## Modding

To add mods to your TES3MP server, download the appropriate script for your OS and follow the steps below.

| OS | Script | Config |
|----|--------|--------|
| 🐧 Linux | [`upload`](linux/mods/upload) | [`admin.conf`](linux/mods/admin.conf) |