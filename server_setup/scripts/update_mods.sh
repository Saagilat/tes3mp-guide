#!/bin/bash
#
# update_mods.sh — automatic mod & script updater for TES3MP server
#
# What it does:
#   1. Removes all .esp/.esm/.omwaddon/.omwscripts/.omwgame from server/data/
#      except original ones (Morrowind, Tribunal, Bloodmoon)
#   2. Copies all .esp/.esm/.omwaddon/.omwscripts/.omwgame from plugins/ to server/data/
#   3. Synchronises .lua scripts from server-scripts/ to server/scripts/custom/ (removes stale scripts)
#   4. Generates server/scripts/customScripts.lua with script names
#   5. Computes CRC32 for all mod files in server/data/
#   6. Generates server/data/requiredDataFiles.json (for TES3MP)
#   7. Creates mods.zip at data/mods.zip with: plugins + requiredDataFiles.json for /get-mods
#   8. Restarts the Docker container
#
# Usage:
#   Place .esp/.esm/.omwaddon/.omwscripts/.omwgame files in plugins/
#   Place .lua files in server-scripts/ (server scripts)
#   Run: bash update_mods.sh
#
# Removing a mod/script:
#   Delete the file from plugins/ or scripts/ and run the script again
#
# Requirements: bash, rhash, rsync, zip, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
PLUGINS_DIR="$SCRIPT_DIR/plugins"
SERVER_SCRIPTS_DIR_LOCAL="$SCRIPT_DIR/server-scripts"

# TES3MP paths inside the container (data/ is mounted at /tes3mp)
# TES3MP runs with home=./server, so it looks for plugins in server/data/
SERVER_DATA_DIR="$DATA_DIR/server/data"
SERVER_SCRIPTS_DIR="$DATA_DIR/server/scripts"

# Original Morrowind files — NOT touched or deleted
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

echo "=== TES3MP Mod & Script Updater ==="
echo "Data directory:          $DATA_DIR"
echo "Server data:             $SERVER_DATA_DIR"
echo "Plugins directory:       $PLUGINS_DIR"
echo "Server scripts:          $SERVER_SCRIPTS_DIR_LOCAL"
echo "Client scripts:          $SCRIPT_DIR/client-scripts"
echo ""

# --- Dependency check ---
for cmd in rhash rsync zip docker; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Ensure server/data/ exists ---
mkdir -p "$SERVER_DATA_DIR"

# --- Step 1: Remove mods from server/data/ (keep only originals) ---
echo "[1/8] Removing old plugins from server/data/..."
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
echo "[2/8] Copying plugins from plugins/ to server/data/..."
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
echo "[3/8] Syncing server scripts to server/scripts/custom/..."
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
echo "[4/8] Generating customScripts.lua..."

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
echo "[5/8] Generating requiredDataFiles.json..."

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
echo "[6/8] Checking serverCore.lua..."

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

    # Remove legacy clientScriptsLoader require if present
    if grep -q "clientScriptsLoader" "$SERVER_CORE_LUA" 2>/dev/null; then
        sed -i '/clientScriptsLoader/d' "$SERVER_CORE_LUA"
        echo "  Cleaned up: removed legacy require(\"clientScriptsLoader\") from serverCore.lua"
    fi
fi

# --- Step 7: Create mods.zip for distribution ---
echo ""
echo "[7/8] Creating mods.zip for distribution to players..."

# Collect plugins from server/data/
mods_to_zip=()
for file in "$SERVER_DATA_DIR"/*.esp "$SERVER_DATA_DIR"/*.ESP "$SERVER_DATA_DIR"/*.esm "$SERVER_DATA_DIR"/*.ESM \
            "$SERVER_DATA_DIR"/*.omwaddon "$SERVER_DATA_DIR"/*.OMWADDON \
            "$SERVER_DATA_DIR"/*.omwscripts "$SERVER_DATA_DIR"/*.OMWSCRIPTS \
            "$SERVER_DATA_DIR"/*.omwgame "$SERVER_DATA_DIR"/*.OMWGAME; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"

    skip=0
    for orig in "${ORIGINAL_FILES[@]}"; do
        if [ "$basename" = "$orig" ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 0 ]; then
        mods_to_zip+=("$file")
    fi
done

rm -f "$DATA_DIR/mods.zip"

# Create a staging directory for the archive
STAGE_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR"' EXIT

# Copy plugins to staging
for f in "${mods_to_zip[@]}"; do
    cp "$f" "$STAGE_DIR/"
done

# Copy requiredDataFiles.json to staging
if [ -f "$REQ_JSON" ]; then
    cp "$REQ_JSON" "$STAGE_DIR/requiredDataFiles.json"
fi

# Create the archive
staging_files=("$STAGE_DIR"/*)
if [ ${#staging_files[@]} -gt 0 ] && [ "$(ls -A "$STAGE_DIR")" ]; then
    cd "$STAGE_DIR"
    zip -q "$DATA_DIR/mods.zip" -- *
    cd "$SCRIPT_DIR"
    echo "  Created: $DATA_DIR/mods.zip"
    echo "  Contents: ${#mods_to_zip[@]} plugins, 1 requiredDataFiles.json"
fi

if [ ! -f "$DATA_DIR/mods.zip" ]; then
    echo "  No mod files to archive"
fi

# Remove old artifacts (cleanup from previous versions)
rm -f "$DATA_DIR/plugins.zip"
rm -f "$DATA_DIR/server-scripts.zip"
rm -f "$DATA_DIR/client-scripts.zip"

echo ""
echo "=== All done. Restarting Docker container... ==="

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