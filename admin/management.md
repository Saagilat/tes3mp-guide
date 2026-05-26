# Managing the TES3MP server (Docker)

All commands are run as root on the VPS from /opt/tes3mp.

| Action | Command | Details |
|--------|---------|---------|
| Start | `cd /opt/tes3mp && docker compose up -d` | Use `--build` only after changing server scripts or the Docker image |
| Restart | `cd /opt/tes3mp && docker compose restart` | Sends SIGTERM to TES3MP; with `stop_grace_period: 30s` the server saves before exit |
| Rebuild (server scripts) | `cd /opt/tes3mp && docker compose up -d --build` | Only when you need to pick up changes to server scripts or the Docker image |
| View live logs | `cd /opt/tes3mp && docker compose logs -f` | |
| Stop | `cd /opt/tes3mp && docker compose down` | |
| Edit config | `nano /opt/tes3mp/config/tes3mp-server-default.cfg` | Afterwards, run **Restart** to apply changes |
| Edit Lua config | `nano /opt/tes3mp/config/server/scripts/config.lua` | Afterwards, run **Restart** to apply changes |
| Edit ban list | `nano /opt/tes3mp/config/server/data/banlist.json` | Afterwards, run **Restart** to apply changes |

## Configuration (bind mounts)

Config files are now stored on the host filesystem at `/opt/tes3mp/config/` and bind-mounted into the container. This means you can edit them with any text editor and changes take effect after a **Restart** (no rebuild needed).

| Host path | Container path |
|-----------|----------------|
| `/opt/tes3mp/config/tes3mp-server-default.cfg` | `/tes3mp/tes3mp-server-default.cfg` |
| `/opt/tes3mp/config/server/scripts/config.lua` | `/tes3mp/server/scripts/config.lua` |
| `/opt/tes3mp/config/server/data/banlist.json` | `/tes3mp/server/data/banlist.json` |
| `/opt/tes3mp/data/requiredDataFiles.json` | `/tes3mp/server/data/requiredDataFiles.json` |

Why `config/` and not `data/`? Because `data/` is reserved for TES3MP runtime data (players, cells). Putting config files there would cause them to be overwritten on server shutdown. The separate `config/` directory keeps configuration cleanly separated from runtime data.

After editing any config file, run:

```bash
cd /opt/tes3mp && docker compose restart
```

> **Note:** Config bind mounts are read-only inside the container. To make persistent changes, edit the host files. If you delete a config file from the host, the container will use the defaults bundled in the image.

## Data persistence

Player progress (characters, inventory, cells) is stored in bind mounts on the host filesystem:

| Inside container | On host |
|-----------------|---------|
| `/tes3mp/server/data/player/` | `/opt/tes3mp/data/players/` |
| `/tes3mp/server/data/cell/` | `/opt/tes3mp/data/cells/` |
| `/tes3mp/data/` (mods & assets) | `/opt/tes3mp/data/` |

Why `/tes3mp/server/data/player` and not `/tes3mp/players`? Because TES3MP's config sets `home = ./server`, and by default it writes player data to `./data/player` relative to that home directory. The bind mounts mirror exactly where TES3MP writes.

Unlike named volumes, bind mounts are never automatically removed by Docker — data survives rebuilds, container crashes, and even `docker compose down -v`.

### How saving works

TES3MP saves player data in three ways:

1. **On disconnect** — when a player leaves, `OnPlayerDisconnect` fires and calls `SaveToDrive()`
2. **Auto-save interval** — by default every **300 seconds (5 minutes)**, all players, world, and record stores are serialized to disk
3. **On server shutdown** — when the server receives SIGTERM (e.g. `docker compose restart` or `docker compose down`), it calls `OnServerExit` which triggers a final save

The auto-save interval (`config.autoSaveInterval` in `config.lua`) is your safety net — even if the server crashes, you lose at most 5 minutes of progress.

---

## Enabling endpoints: /get-mods, /get-world, /get-characters

All three endpoints are **disabled by default**. Enabling them is **recommended** — they allow players to easily download mods, and give access to world/character data for debugging, backups, or community tools.

### Available endpoints

| Endpoint | Description | Archive |
|----------|-------------|---------|
| `/get-mods` | Download all server mods (`.esp`/`.esm` files) | `mods.zip` |
| `/get-world` | Download world state (all cell JSON files) | `world_state.tar.gz` |
| `/get-characters` | Download all character data | `characters.tar.gz` |

### Before enabling — understand the implications

Enabling `/get-world` and `/get-characters` makes your server's data **publicly readable**:
- **Character data**: anyone with the server IP can download all characters — their inventories, skills, spells, quest progress, etc.
- **World state**: anyone can download every cell, every placed item, every modified object.
- **This can affect gameplay** — players could inspect each other's progress, bases, or hidden stashes.

Consider whether this fits your server's vision. For a co-op or roleplay server it can be a **valuable feature** (transparency, backups, community analytics). For a competitive server you may want to keep character data private.

### To enable

1. **Uncomment the desired location blocks** in `/opt/tes3mp/nginx.conf`.
2. For `/get-world` and `/get-characters` you also need to **uncomment the `export` service** in `/opt/tes3mp/docker-compose.yml`.
3. Uncomment the **`nginx` service** in docker-compose.yml (required for all endpoints).
4. Rebuild and restart:
   ```bash
   cd /opt/tes3mp && docker compose up -d --build
   ```

### To disable

Reverse the steps above and rebuild.

### Notes

- Rate limit: each endpoint has its own configurable limit (default: **5 requests per minute** per IP). Archive is cached for 10 minutes.
- When enabled, endpoints are available at:
  - `http://<server-IP>:8085/get-mods`
  - `http://<server-IP>:8085/get-world`
  - `http://<server-IP>:8085/get-characters`

See [tes3mp_settings.md](tes3mp_settings.md) for the full config.lua reference.

