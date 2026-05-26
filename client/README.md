# Client

Guides and scripts for players setting up TES3MP.

## Installation

| OS | Guide |
|----|-------|
| 🐧 Linux | [Steam Proton setup](linux/proton/install.md) |

## Modding

To auto-install server mods on your client, download the appropriate script for your OS and follow the steps below.

| OS | Script | Config |
|----|--------|--------|
| 🐧 Linux | [`tes3mp-mods-download`](linux/utilities/tes3mp-mods-download) | [`tes3mp-mods-download.conf`](linux/utilities/tes3mp-mods-download.conf) |

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