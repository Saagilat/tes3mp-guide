#!/bin/bash
#
# import_world.sh — Import world data (players + cells) from a world.tar.gz archive
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-world/world.tar.gz
#   2. Backs up current world via package.sh
#   3. Stops TES3MP container
#   4. Extracts world.tar.gz to container-data/server/data/
#   5. Starts TES3MP container
#   6. Cleans up import directory
#
# Usage:
#   Place world.tar.gz in /tes3mp-easy/import-world/
#   Run: bash import_world.sh
#
# Requirements: bash, tar, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BASE_DIR/container-data"

IMPORT_DIR="$BASE_DIR/import-world"
ARCHIVE="$IMPORT_DIR/world.tar.gz"

SERVER_DATA_DIR="$DATA_DIR/server/data"
PLAYER_DIR="$SERVER_DATA_DIR/player"
CELL_DIR="$SERVER_DATA_DIR/cell"

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

# --- Source the shared packaging library for package_world() ---
export PLAYER_DIR
export CELL_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Import World ==="
echo "Archive:       $ARCHIVE"
echo "Player dir:    $PLAYER_DIR"
echo "Cell dir:      $CELL_DIR"
echo ""

# --- Dependency check ---
for cmd in tar docker; do
    if ! command -v "$cmd" &>/dev/null; then
        err "'$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Step 1: Check archive ---
echo "[1/6] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place world.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Backup current world ---
echo ""
echo "[2/6] Backing up current world..."

TIMESTAMP=$(date +%F_%H-%M-%S)
mkdir -p "$BACKUPS_DIR"
package_world "$BACKUPS_DIR/world_${TIMESTAMP}.tar.gz"

ok "World backup saved to: $BACKUPS_DIR"

# --- Step 3: Stop TES3MP ---
echo ""
echo "[3/6] Stopping TES3MP container..."

cd "$BASE_DIR"
if command -v docker &>/dev/null && [ -f "$BASE_DIR/docker-compose.yml" ]; then
    docker compose stop tes3mp
    ok "TES3MP container stopped"
else
    warn "Docker compose not found — stop TES3MP manually"
fi

# --- Step 4: Extract world archive ---
echo ""
echo "[4/6] Extracting world data to $SERVER_DATA_DIR..."

mkdir -p "$PLAYER_DIR" "$CELL_DIR"
tar xzf "$ARCHIVE" -C "$SERVER_DATA_DIR"

ok "World data extracted"

# --- Step 5: Start TES3MP ---
echo ""
echo "[5/6] Starting TES3MP container..."

if command -v docker &>/dev/null && [ -f "$BASE_DIR/docker-compose.yml" ]; then
    cd "$BASE_DIR"
    docker compose start tes3mp
    ok "TES3MP container started"
else
    warn "Docker compose not found — start TES3MP manually"
fi

# --- Step 6: Clean up ---
echo ""
echo "[6/6] Cleaning up import directory..."

rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
echo "=== Done! ==="