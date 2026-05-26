# Admin Mods Upload

Script for uploading mods to a TES3MP server.

## Setup

### 1. Edit the config

```bash
nano admin/linux/utilities/tes3mp-mods-upload.conf
```

### 2. Configure SSH (so that `ssh tes3mp-server` works)

Add to `~/.ssh/config` (substitute your IP):

```
Host tes3mp-server
    HostName <server-ip>
    User <server-username>
```

Set up a key (the server password will be required):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" && ssh-copy-id tes3mp-server
```

### 3. Run

```bash
./admin/linux/utilities/tes3mp-mods-upload
```

## Config variables

| Variable   | Description                    | Example                   |
|------------|--------------------------------|---------------------------|
| `SSH_HOST` | SSH host (alias or user@ip)    | `tes3mp-server`           |
| `MODS_DIR` | Path to local mods directory   | `/home/user/tes3mp-mods`  |
