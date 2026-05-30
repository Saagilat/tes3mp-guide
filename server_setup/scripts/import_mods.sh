#!/bin/bash
#
# import_mods.sh — Import mods and scripts from a mods.tar.gz archive
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-mods/mods.tar.gz
#   2. Validates requiredDataFiles.json inside the archive (CRC32)
#   3. Backs up current mods+scripts and world via package.sh
#   4. Deploys plugins/ → server/data/ (with protection of originals)
#   5. Deploys scripts/ → server/scripts/custom/
#   6. Generates customScripts.lua
#   7. Generates server/data/requiredDataFiles.json (for TES3MP)
#   8. Creates mods.tar.gz for HTTP distribution
#   9. Restarts Docker container
#   10. Cleans up import directory
#
# Usage:
#   Place mods.tar.gz in /tes3mp-easy/import-mods/
#   Run: bash import_mods.sh
#
# Requirements: bash, rhash, tar, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BASE_DIR/container-data"

IMPORT_DIR="$BASE_DIR/import-mods"
ARCHIVE="$IMPORT_DIR/mods.tar.gz"

PLUGINS_DIR="$BASE_DIR/plugins"
SERVER_SCRIPTS_DIR="$BASE_DIR/server-scripts"

# TES3MP paths inside the container (data/ is mounted at /tes3mp)
# TES3MP runs with home=./server, so it looks for plugins in server/data/
SERVER_DATA_DIR="$DATA_DIR/server/data"
SERVER_SCRIPTS_DIR_TARGET="$DATA_DIR/server/scripts"
CUSTOM_SCRIPTS_DIR="$SERVER_SCRIPTS_DIR_TARGET/custom"

# Original Morrowind files — NOT touched or deleted
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

# Backup directory
BACKUPS_DIR="$DATA_DIR/backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

# --- Source the shared packaging library ---
export PLUGINS_DIR
export SERVER_SCRIPTS_DIR
export PLAYER_DIR="$SERVER_DATA_DIR/player"
export CELL_DIR="$SERVER_DATA_DIR/cell"
export ORIGINAL_FILES

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Import Mods ==="
echo "Archive:                 $ARCHIVE"
echo "Data directory:          $DATA_DIR"
echo "Server data:             $SERVER_DATA_DIR"
echo "Server scripts:          $SERVER_SCRIPTS_DIR_TARGET"
echo ""

# --- Dependency check ---
for cmd in rhash tar docker; do
    if ! command -v "$cmd" &>/dev/null; then
        err "'$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Step 1: Check archive ---
echo "[1/10] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place mods.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Extract and validate requiredDataFiles.json ---
echo ""
echo "[2/10] Validating requiredDataFiles.json..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

tar xzf "$ARCHIVE" -C "$TMP_DIR"

REQ_JSON="$TMP_DIR/plugins/requiredDataFiles.json"

if [ ! -f "$REQ_JSON" ]; then
    err "requiredDataFiles.json not found in archive (expected at plugins/requiredDataFiles.json)"
    exit 1
fi

# Validate each plugin listed in requiredDataFiles.json exists and CRC32 matches
VALIDATION_FAILED=0

# Read JSON and validate using python3 or fallback
if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys, os, subprocess

with open('$REQ_JSON') as f:
    data = json.load(f)

for entry in data:
    for name, crc_list in entry.items():
        filepath = os.path.join('$TMP_DIR/plugins', name)
        if not os.path.exists(filepath):
            print(f'ERROR: Plugin \"{name}\" listed in requiredDataFiles.json but not found in archive')
            sys.exit(1)
        if crc_list:
            expected_crc = crc_list[0].upper()
            try:
                result = subprocess.run(
                    ['rhash', '--crc32', '--simple', filepath],
                    capture_output=True, text=True, check=True
                )
                actual_crc = result.stdout.split()[0].upper()
                expected_clean = expected_crc.replace('0X', '')
                if actual_crc != expected_clean:
                    print(f'ERROR: CRC32 mismatch for \"{name}\": expected {expected_crc}, got 0x{actual_crc}')
                    sys.exit(1)
            except subprocess.CalledProcessError:
                print(f'ERROR: Failed to compute CRC32 for \"{name}\"')
                sys.exit(1)
print('All plugins validated successfully')
" || VALIDATION_FAILED=1
else
    # Fallback: basic validation without CRC (just check files exist)
    warn "python3 not found — skipping CRC32 validation (file existence only)"
    grep -oP '"([^"]+\.(esp|esm|omwaddon|omwscripts|omwgame))"' "$REQ_JSON" | tr -d '"' | while read -r name; do
        if [ ! -f "$TMP_DIR/plugins/$name" ]; then
            err "Plugin \"$name\" listed in requiredDataFiles.json but not found in archive"
            VALIDATION_FAILED=1
        fi
    done
fi

if [ "$VALIDATION_FAILED" -ne 0 ]; then
    err "Validation failed — aborting"
    exit 1
fi
ok "All plugins validated"

# --- Step 3: Ensure directories exist ---
echo ""
echo "[3/10] Ensuring directories exist..."
mkdir -p "$SERVER_DATA_DIR" "$BACKUPS_DIR" "$CUSTOM_SCRIPTS_DIR"
ok "Directories ready"

TIMESTAMP=$(date +%F_%H-%M-%S)

# --- Step 4: Backup current mods and world ---
echo ""
echo "[4/10] Backing up current mods, scripts, and world..."

package_mods_and_scripts "$BACKUPS_DIR/mods_scripts_${TIMESTAMP}.tar.gz"
package_world "$BACKUPS_DIR/world_${TIMESTAMP}.tar.gz"

ok "Backups saved to: $BACKUPS_DIR"

# --- Step 5: Remove old plugins from server/data/ (keep originals) ---
echo ""
echo "[5/10] Removing old plugins from server/data/..."
for file in "$SERVER_DATA_DIR"/*.esp "$SERVER_DATA_DIR"/*.ESP \
            "$SERVER_DATA_DIR"/*.esm "$SERVER_DATA_DIR"/*.ESM \
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

    if [ "$skip" -eq 1 ]; then
        echo "  - Preserved: $basename"
    else
        rm -f "$file"
        echo "  - Removed: $basename"
    fi
done

# --- Step 6: Deploy plugins ---
echo ""
echo "[6/10] Deploying plugins to server/data/..."

if [ -d "$TMP_DIR/plugins" ]; then
    copied=0
    for file in "$TMP_DIR/plugins"/*; do
        [ -f "$file" ] || continue
        basename="$(basename "$file")"

        # Skip requiredDataFiles.json — it goes to its own location
        if [ "$basename" = "requiredDataFiles.json" ]; then
            continue
        fi

        # Skip original files
        skip=0
        for orig in "${ORIGINAL_FILES[@]}"; do
            if [ "${basename,,}" = "${orig,,}" ]; then
                skip=1
                break
            fi
        done
        [ "$skip" -eq 1 ] && echo "  - Skipped (original): $basename" && continue

        cp "$file" "$SERVER_DATA_DIR/"
        echo "  - Deployed: $basename"
        ((copied++)) || true
    done

    if [ "$copied" -eq 0 ]; then
        echo "  (no plugins to deploy)"
    fi
fi

# --- Step 7: Deploy server scripts ---
echo ""
echo "[7/10] Deploying server scripts..."

# Clean sync: remove all existing custom scripts first
rm -f "$CUSTOM_SCRIPTS_DIR"/*.lua

script_copied=0
if [ -d "$TMP_DIR/scripts" ]; then
    for file in "$TMP_DIR/scripts"/*.lua "$TMP_DIR/scripts"/*.LUA; do
        [ -f "$file" ] || continue
        cp "$file" "$CUSTOM_SCRIPTS_DIR/"
        echo "  - Deployed: $(basename "$file")"
        ((script_copied++)) || true
    done
fi

if [ "$script_copied" -eq 0 ]; then
    echo "  (no server scripts to deploy)"
fi

# --- Step 8: Generate customScripts.lua ---
echo ""
echo "[8/10] Generating customScripts.lua..."

CUSTOM_SCRIPTS_LUA="$SERVER_SCRIPTS_DIR_TARGET/customScripts.lua"

echo "-- This file is auto-generated by import_mods.sh" > "$CUSTOM_SCRIPTS_LUA"
echo "-- Do not edit manually — changes will be overwritten" >> "$CUSTOM_SCRIPTS_LUA"

for file in "$CUSTOM_SCRIPTS_DIR"/*.lua; do
    [ -f "$file" ] || continue
    basename="$(basename "$file" .lua)"
    echo "require(\"custom.$basename\")" >> "$CUSTOM_SCRIPTS_LUA"
done

echo "  Generated: $(basename "$CUSTOM_SCRIPTS_LUA") ($(ls -1 "$CUSTOM_SCRIPTS_DIR"/*.lua 2>/dev/null | wc -l) scripts)"

# --- Step 9: Generate requiredDataFiles.json for TES3MP ---
echo ""
echo "[9/10] Generating server/data/requiredDataFiles.json..."

REQ_JSON_TARGET="$SERVER_DATA_DIR/requiredDataFiles.json"

# Copy the validated requiredDataFiles.json from the archive
cp "$REQ_JSON" "$REQ_JSON_TARGET"

echo "  Generated: $REQ_JSON_TARGET"
json_count=$(grep -cP '^\s*\{' "$REQ_JSON_TARGET" 2>/dev/null || echo 0)
echo "  Records: $json_count"

# --- Step 10: Recreate mods.tar.gz for HTTP distribution and restart ---
echo ""
echo "[10/10] Creating mods.tar.gz for distribution and restarting..."

# Remove old mods.tar.gz
rm -f "$DATA_DIR/mods.tar.gz"

# Create fresh mods.tar.gz using package.sh
package_mods_and_scripts "$DATA_DIR/mods.tar.gz"

# Restart Docker
echo ""
if command -v docker &>/dev/null && [ -f "$BASE_DIR/docker-compose.yml" ]; then
    cd "$BASE_DIR"
    docker compose restart
    ok "Docker containers restarted"
else
    warn "Docker compose not found — restart manually: docker compose restart"
fi

# Clean up import directory
rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
echo "=== Done! ==="