# Client Mods Download

Script for automatically downloading and installing mods from a TES3MP server.

## Setup

### 1. Edit the config

```bash
nano client/linux/utilities/tes3mp-mods-download.conf
```

Set the correct paths for your system:

| Variable         | Description                                                           | Example                                       |
|------------------|-----------------------------------------------------------------------|-----------------------------------------------|
| `CLIENT_DEFAULT` | Path to `tes3mp-client-default.cfg` (server hostname is read from it) | `/home/user/Games/tes3mp/tes3mp-client-default.cfg` |
| `DATA_FILES`     | Path to the OpenMW Data Files folder                                  | `/home/user/Games/OpenMW/Data Files`          |
| `OPENMW_CFG`     | Path to `openmw.cfg`                                                  | `/home/user/.config/openmw/openmw.cfg`        |

### 2. Run

```bash
./client/linux/utilities/tes3mp-mods-download
```
