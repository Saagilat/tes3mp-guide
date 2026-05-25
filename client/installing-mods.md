# Installing Mods from the Server

If the server provides a ready-made mod pack (as described in the [server admin guide](../server/modding.md)), this guide explains how to download and install it.

> **Prerequisites**: You must have TES3MP installed and configured.

## 1. Download and extract mods

The server may expose a download endpoint (typically `http://{SERVER_ADDRESS}:{PORT}/get-mods`) that serves a mod archive.  
**Note:** The server administrator may disable this endpoint — if it doesn't work, ask the admin to enable it.

Download the archive using your browser or any download tool, then extract its contents into the game's `Data Files` folder.

## 2. Enable mods in OpenMW config

Locate your `openmw.cfg` file — it is **not** in the game folder, but in your user profile:

| Platform | Typical path |
|----------|-------------|
| Linux    | `~/.config/openmw/openmw.cfg` or `~/openmw-profile/openmw.cfg` |
| Windows  | `%USERPROFILE%\Documents\My Games\OpenMW\openmw.cfg` |

Open this file and add the following line at the end:

```
include = mods.cfg
```

> **Important**: Do **not** wrap filenames in quotes, even if they contain spaces. For example, `content=Dark Brotherhood Attacks Once - Delayed Attacks.ESP` is correct — **no** quotes around the path.

## 3. How to update mods

Download and extract the archive again — the new files will overwrite the old ones. No changes to `openmw.cfg` are needed.

## 4. How to remove the mod pack

Delete the extracted mod files, then open `openmw.cfg` and remove the `include = mods.cfg` line you added earlier.