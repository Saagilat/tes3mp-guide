#!/bin/bash
#
# update_mods.sh — automatic mod & script updater for TES3MP server
#
# What it does:
#   1. Creates backups of mods+scripts and world before making any changes
#   2. Removes all .esp/.esm/.omwaddon/.omwscripts/.omwgame from server/data/
#      except original ones (Morrowind, Tribunal, Bloodmoon)
#   3. Copies all .esp/.esm/.omwaddon/.omwscripts/.omwgame from plugins/ to server/data/
#   4. Synchronises .lua scripts from server-scripts/ to server/scripts/custom/ (removes stale scripts)
#   5. Generates server/scripts/customScripts.lua with script names
#   6. Computes CRC32 for all mod files in server/data/
#   7. Generates server/data/requiredDataFiles.json (for TES3MP)
#   8. Creates mods.tar.gz at container-data/mods.tar.gz with:
#      plugins/ + scripts/ + requiredDataFiles.json (for /get-mods endpoint)
#   9. Restarts the Docker container
#
# Usage:
#   Place .esp/.esm/.omwaddon/.omwscripts/.omwgame files in plugins/
#   Place .lua files in server-scripts/ (server scripts)
#   Run: bash update_mods.sh
#
# Removing a mod/script:
#   Delete the file from plugins/ or scripts/ and run the script again
#
# Requirements: bash, rhash, rsync, tar, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/container-data"
PLUGINS_DIR="$SCRIPT_DIR/plugins"
SERVER_SCRIPTS_DIR_LOCAL="$SCRIPT_DIR/server-scripts"

# TES3MP paths inside the container (data/ is mounted at /tes3mp)
# TES3MP runs with home=./server, so it looks for plugins in server/data/
SERVER_DATA_DIR="$DATA_DIR/server/data"
SERVER_SCRIPTS_DIR="$DATA_DIR/server/scripts"

# Original Morrowind files — NOT touched or deleted
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

# Backup directory
BACKUPS_DIR="$DATA_DIR/backups"

# --- Source the shared packaging library ---
# Sets up: check_disk_space(), package_mods_and_scripts(), package_world()
export PLUGINS_DIR
export SERVER_SCRIPTS_DIR="$SERVER_SCRIPTS_DIR_LOCAL"
export PLAYER_DIR="$SERVER_DATA_DIR/player"
export CELL_DIR="$SERVER_DATA_DIR/cell"
export ORIGINAL_FILES

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Mod & Script Updater ==="
echo "Data directory:          $DATA_DIR"
echo "Server data:             $SERVER_DATA_DIR"
echo "Plugins directory:       $PLUGINS_DIR"
echo "Server scripts:          $SERVER_SCRIPTS_DIR_LOCAL"
echo "Backups directory:       $BACKUPS_DIR"
echo ""

# --- Dependency check ---
for cmd in rhash rsync tar docker; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Ensure required directories exist ---
mkdir -p "$SERVER_DATA_DIR" "$BACKUPS_DIR"

TIMESTAMP=$(date +%F_%H-%M-%S)

# --- Step 0a: Check disk space for backup ---
echo "[0/9] Checking disk space for backup..."
check_disk_space "$BACKUPS_DIR"

# --- Step 0b: Backup mods, scripts, and world ---
echo ""
echo "[1/9] Backing up current mods, scripts, and world..."

package_mods_and_scripts "$BACKUPS_DIR/mods_scripts_${TIMESTAMP}.tar.gz"
package_world "$BACKUPS_DIR/world_${TIMESTAMP}.tar.gz"

echo "  Backups saved to: $BACKUPS_DIR"

# --- Step 1: Remove old plugins from server/data/ (keep only originals) ---
echo ""
echo "[2/9] Removing old plugins from server/data/..."
for file in "$SERVER_DATA_DIR"/*.esp "$SERVER_DATA_DIR"/*.ESP "$SERVER_DATA_DIR"/*.esm "$SERVER_DATA_DIR"/*.ESM \
            "$SERVER_DATA_DIR"/*.omwaddon "$SERVER_DATA_DIR"/*.OMWADDON \
            "$SERVER_DATA_DIR"/*.omwscripts "$SERVER_DATA_DIR"/*.OMWSCRIPTS \
            "$SERVER_DATA_DIR"/*.omwgame "$SERVER_DATA_DIR"/*.OMWGAME; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"

    # Skip original files
    skip=0
    for orig in "${ORIGINAL_FILES[@]}"; do
        if [ "$basename" = "$orig" ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 1 ]; then
        echo "  - Preserved: $basename"
    else
        rm -f "$file"
        echo "  - Removed: $basename"
    fi
done

# --- Step 2: Copy mods to server/data/ ---
echo ""
echo "[3/9] Copying plugins from plugins/ to server/data/..."
if [ ! -d "$PLUGINS_DIR" ]; then
    echo "  plugins/ directory does not exist. Creating..."
    mkdir -p "$PLUGINS_DIR"
fi

copied=0
for file in "$PLUGINS_DIR"/*.esp "$PLUGINS_DIR"/*.ESp "$PLUGINS_DIR"/*.esm "$PLUGINS_DIR"/*.ESM "$PLUGINS_DIR"/*.ESP "$PLUGINS_DIR"/*.EsM \
            "$PLUGINS_DIR"/*.omwaddon "$PLUGINS_DIR"/*.OMWADDON "$PLUGINS_DIR"/*.Omwaddon "$PLUGINS_DIR"/*.oMwAddon \
            "$PLUGINS_DIR"/*.omwscripts "$PLUGINS_DIR"/*.OMWSCRIPTS \
            "$PLUGINS_DIR"/*.omwgame "$PLUGINS_DIR"/*.OMWGAME; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"

    # Check if we're trying to copy a mod with an original file name
    skip=0
    for orig in "${ORIGINAL_FILES[@]}"; do
        if [ "${basename,,}" = "${orig,,}" ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 1 ]; then
        echo "  - Skipped (matches original): $basename"
        continue
    fi

    cp "$file" "$SERVER_DATA_DIR/"
    echo "  - Copied: $basename"
    ((copied++)) || true
done

if [ "$copied" -eq 0 ]; then
    echo "  (no plugins to copy)"
fi

# --- Step 3: Sync server scripts ---
echo ""
echo "[4/9] Syncing server scripts to server/scripts/custom/..."
CUSTOM_SCRIPTS_DIR="$SERVER_SCRIPTS_DIR/custom"
mkdir -p "$CUSTOM_SCRIPTS_DIR"

# Remove all existing custom scripts (clean sync)
rm -f "$CUSTOM_SCRIPTS_DIR"/*.lua

script_copied=0
if [ -d "$SERVER_SCRIPTS_DIR_LOCAL" ]; then
    for file in "$SERVER_SCRIPTS_DIR_LOCAL"/*.lua "$SERVER_SCRIPTS_DIR_LOCAL"/*.LUA; do
        [ -f "$file" ] || continue
        cp "$file" "$CUSTOM_SCRIPTS_DIR/"
        echo "  - Copied: $(basename "$file")"
        ((script_copied++)) || true
    done
fi

if [ "$script_copied" -eq 0 ]; then
    echo "  (no server scripts to copy)"
fi

# --- Step 4: Generate customScripts.lua ---
echo ""
echo "[5/9] Generating customScripts.lua..."

CUSTOM_SCRIPTS_LUA="$SERVER_SCRIPTS_DIR/customScripts.lua"

# Generate customScripts.lua that requires each custom script
echo "-- This file is auto-generated by update_mods.sh" > "$CUSTOM_SCRIPTS_LUA"
echo "-- Do not edit manually — changes will be overwritten" >> "$CUSTOM_SCRIPTS_LUA"

for file in "$CUSTOM_SCRIPTS_DIR"/*.lua; do
    [ -f "$file" ] || continue
    basename="$(basename "$file" .lua)"
    echo "require(\"custom.$basename\")" >> "$CUSTOM_SCRIPTS_LUA"
done

echo "  Generated: $(basename "$CUSTOM_SCRIPTS_LUA") ($(ls -1 "$CUSTOM_SCRIPTS_DIR"/*.lua 2>/dev/null | wc -l) scripts)"

# --- Step 5: Generate requiredDataFiles.json ---
echo ""
echo "[6/9] Generating requiredDataFiles.json..."

REQ_JSON="$SERVER_DATA_DIR/requiredDataFiles.json"

# Start JSON array
printf "[\n" > "$REQ_JSON"

# Add original master files with empty CRC (allows Steam + GOG + any edition)
for orig in "${ORIGINAL_FILES[@]}"; do
    printf '  {\n    "%s": []\n  },\n' "$orig" >> "$REQ_JSON"
done

# Collect and sort mod files from server/data/
mod_files=()
for pattern in *.esp *.ESP *.esm *.ESM \
               *.omwaddon *.OMWADDON \
               *.omwscripts *.OMWSCRIPTS \
               *.omwgame *.OMWGAME; do
    for file in "$SERVER_DATA_DIR"/$pattern; do
        [ -f "$file" ] || continue
        basename="$(basename "$file")"

        # Skip originals
        skip=0
        for orig in "${ORIGINAL_FILES[@]}"; do
            if [ "$basename" = "$orig" ]; then
                skip=1
                break
            fi
        done
        [ "$skip" -eq 1 ] && continue

        mod_files+=("$file")
    done
done

# Sort by filename
IFS=$'\n' mod_files=($(sort <<<"${mod_files[*]}"))
unset IFS

for filepath in "${mod_files[@]}"; do
    basename="$(basename "$filepath")"
    crc=$(rhash --crc32 --simple "$filepath" | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
    printf '  {\n    "%s": ["0x%s"]\n  },\n' "$basename" "$crc" >> "$REQ_JSON"
done

# Remove trailing comma from last entry and close JSON array
sed -i '$ s/,$//' "$REQ_JSON"
printf "]\n" >> "$REQ_JSON"

echo "  Generated: $REQ_JSON (for TES3MP)"
echo "  Records: $(( ${#ORIGINAL_FILES[@]} + ${#mod_files[@]} ))"

# --- Step 6: Check serverCore.lua (ensure customScripts is loaded) ---
echo ""
echo "[7/9] Checking serverCore.lua..."

SERVER_CORE_LUA="$SERVER_SCRIPTS_DIR/serverCore.lua"

if [ ! -f "$SERVER_CORE_LUA" ]; then
    echo "  Warning: serverCore.lua not found at $SERVER_CORE_LUA"
    echo "  customScripts.lua will be available but not auto-loaded."
    echo "  Make sure your serverCore.lua contains:"
    echo "    require(\"customScripts\")"
else
    if grep -q "^require(\"customScripts\")" "$SERVER_CORE_LUA" 2>/dev/null; then
        echo "  serverCore.lua already has require(\"customScripts\") — no changes needed"
    else
        echo "  Note: require(\"customScripts\") is missing from serverCore.lua"
        echo "  customScripts.lua will not be auto-loaded."
    fi

    # Remove legacy clientScriptsLoader require if present (from broken previous version)
    if grep -q "clientScriptsLoader" "$SERVER_CORE_LUA" 2>/dev/null; then
        sed -i '/clientScriptsLoader/d' "$SERVER_CORE_LUA"
        echo "  Cleaned up: removed legacy require(\"clientScriptsLoader\") from serverCore.lua"
    fi
fi

# --- Step 7: Create mods.tar.gz for distribution ---
echo ""
echo "[8/9] Creating mods.tar.gz for distribution to players..."

rm -f "$DATA_DIR/mods.tar.gz"
package_mods_and_scripts "$DATA_DIR/mods.tar.gz"

if [ ! -f "$DATA_DIR/mods.tar.gz" ]; then
    echo "  No mod files to archive"
fi

# Remove old artifacts (cleanup from previous versions)
rm -f "$DATA_DIR/plugins.zip"
rm -f "$DATA_DIR/server-scripts.zip"
rm -f "$DATA_DIR/client-scripts.zip"

echo ""
echo "[9/9] Restarting Docker container..."

if command -v docker &>/dev/null && [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cd "$SCRIPT_DIR"
    docker compose restart
    echo ""
    echo "=== Done! ==="
else
    echo ""
    echo "=== Done! ==="
    echo "Restart the Docker container manually:"
    echo "  cd $SCRIPT_DIR && docker compose restart"
fi