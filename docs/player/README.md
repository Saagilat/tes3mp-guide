# Player guide

Guides and scripts for players setting up TES3MP.

## Installation

| OS | Guide |
|----|-------|
| 🐧 Linux | [Steam Proton setup](linux/proton/install.md) |

### Russian localization

For Russian-speaking players, a separate tool installs the Russian localization (fonts, textures, UI, voiceovers):

- [`tools/linux/localization/russian/install.sh`](../../tools/linux/localization/russian/install.sh)
- [`tools/linux/localization/russian/README.md`](../../tools/linux/localization/russian/README.md)

## Updating plugins from the server

To auto-install server plugins on your client, use `tes3mp-client-update-mods`:

| File | Description |
|------|-------------|
| [`tes3mp-client-update-mods`](../../tools/linux/tes3mp-client-update-mods) | Download script |
| [`tes3mp-client-update-mods.conf`](../../tools/linux/tes3mp-client-update-mods.conf) | Configuration template |

### Usage

```bash
# Edit the config with your paths
nano tools/linux/tes3mp-client-update-mods.conf

# Run the update
bash tools/linux/tes3mp-client-update-mods
```

## UI customization

### Fix the font

- Download the archive **TrueType fonts for OpenMW** from Nexus Mods:  
  https://www.nexusmods.com/morrowind/mods/46854
- Extract the contents into your `openmw-profile` directory
- Open `settings.cfg` inside your `openmw-profile` (appears once you change any settings in game)
- Add these lines:

```
[GUI]
ttf resolution = 120
font size = 20
scaling factor = 1.3
```

<details>
<summary>Parameter explanations</summary>

- `font size` — range is limited to 12–20
- `scaling factor` — determines the UI size
</details>

<details>
<summary>OpenMW font documentation</summary>
https://openmw.readthedocs.io/en/openmw-0.47.0_a/reference/modding/font.html
</details>