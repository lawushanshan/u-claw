#!/bin/bash
# ============================================================
# U-Claw Portable — Setup Script
# Usage: bash setup.sh
# Downloads Node.js runtime + installs OpenClaw to app/
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
CORE_DIR="$APP_DIR/core"
RUNTIME_DIR="$APP_DIR/runtime"
MIRROR="https://registry.npmmirror.com"
NODE_MIRROR="https://npmmirror.com/mirrors/node"
NODE_VERSION="v22.22.1"
ALL_PLATFORMS=false
[ "$1" = "--all-platforms" ] && ALL_PLATFORMS=true

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🦞 U-Claw Portable Setup           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ---- Detect OS & Arch ----
OS=$(uname -s)
ARCH=$(uname -m)

if [ "$OS" = "Darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
        PLATFORM="darwin-arm64"
        NODE_DIR_NAME="node-mac-arm64"
    else
        PLATFORM="darwin-x64"
        NODE_DIR_NAME="node-mac-x64"
    fi
else
    echo -e "${RED}Please run this script on Mac. For Windows, use setup.bat${NC}"
    exit 1
fi

echo -e "  System: ${GREEN}$OS $ARCH${NC}"
echo ""

# ---- 1. Download Node.js (Current Platform) ----
NODE_TARGET="$RUNTIME_DIR/$NODE_DIR_NAME"

if [ -f "$NODE_TARGET/bin/node" ]; then
    echo -e "  ${GREEN}✓${NC} Node.js ($PLATFORM) already exists, skipping"
else
    echo -e "  ${CYAN}↓${NC} Downloading Node.js $NODE_VERSION ($PLATFORM)..."
    mkdir -p "$NODE_TARGET"

    NODE_URL="$NODE_MIRROR/$NODE_VERSION/node-$NODE_VERSION-$PLATFORM.tar.gz"
    echo "    $NODE_URL"

    curl -fSL "$NODE_URL" | tar xz -C "$NODE_TARGET" --strip-components=1

    if [ -f "$NODE_TARGET/bin/node" ]; then
        echo -e "  ${GREEN}✓${NC} Node.js ($PLATFORM) downloaded"
    else
        echo -e "  ${RED}✗ Node.js download failed${NC}"
        exit 1
    fi
fi

# ---- 1b. Download Node.js for Windows (only with --all-platforms) ----
if [ "$ALL_PLATFORMS" = "true" ]; then
    WIN_NODE_TARGET="$RUNTIME_DIR/node-win-x64"
    if [ -f "$WIN_NODE_TARGET/node.exe" ]; then
        echo -e "  ${GREEN}✓${NC} Node.js (win-x64) already exists, skipping"
    else
        echo -e "  ${CYAN}↓${NC} Downloading Node.js $NODE_VERSION (win-x64) - Windows support..."
        mkdir -p "$WIN_NODE_TARGET"

        WIN_NODE_URL="$NODE_MIRROR/$NODE_VERSION/node-$NODE_VERSION-win-x64.zip"
        echo "    $WIN_NODE_URL"

        TMP_ZIP="/tmp/node-win-x64-$$.zip"
        curl -fSL "$WIN_NODE_URL" -o "$TMP_ZIP"

        if command -v unzip >/dev/null 2>&1; then
            unzip -q "$TMP_ZIP" -d "/tmp/node-win-extract-$$"
            cp -r "/tmp/node-win-extract-$$"/node-$NODE_VERSION-win-x64/* "$WIN_NODE_TARGET/"
            rm -rf "/tmp/node-win-extract-$$"
        else
            echo -e "    ${RED}✗ unzip not found, skipping Windows runtime${NC}"  # unchanged
        fi
        rm -f "$TMP_ZIP"

        if [ -f "$WIN_NODE_TARGET/node.exe" ]; then
            echo -e "  ${GREEN}✓${NC} Node.js (win-x64) downloaded"
        else
            echo -e "  ${CYAN}⚠${NC}  Windows runtime download failed (does not affect current platform)"
        fi
    fi
fi

# ---- 2. Install OpenClaw ----
if [ -d "$CORE_DIR/node_modules/openclaw" ]; then
    echo -e "  ${GREEN}✓${NC} OpenClaw already installed, skipping"
else
    echo -e "  ${CYAN}↓${NC} Installing OpenClaw..."
    mkdir -p "$CORE_DIR"

    # Init package.json if not exists
    if [ ! -f "$CORE_DIR/package.json" ]; then
        cat > "$CORE_DIR/package.json" << 'PKGJSON'
{
  "name": "u-claw-core",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "openclaw": "latest"
  }
}
PKGJSON
    fi

    # Install with China mirror
    NODE_BIN="$NODE_TARGET/bin/node"
    NPM_BIN="$NODE_TARGET/bin/npm"
    "$NODE_BIN" "$NPM_BIN" install --prefix "$CORE_DIR" --registry="$MIRROR"

    echo -e "  ${GREEN}✓${NC} OpenClaw installed"
fi

# ---- 3. Install QQ Plugin ----
if [ -d "$CORE_DIR/node_modules/@sliverp/qqbot" ]; then
    echo -e "  ${GREEN}✓${NC} QQ plugin already installed, skipping"
else
    echo -e "  ${CYAN}↓${NC} Installing QQ plugin..."
    NODE_BIN="$NODE_TARGET/bin/node"
    NPM_BIN="$NODE_TARGET/bin/npm"
    "$NODE_BIN" "$NPM_BIN" install @sliverp/qqbot@latest --prefix "$CORE_DIR" --registry="$MIRROR" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} QQ plugin installed"
fi

# ---- 4. Install China-optimized skills ----
SKILLS_CN="$SCRIPT_DIR/skills-cn"
SKILLS_TARGET="$CORE_DIR/node_modules/openclaw/skills"

if [ -d "$SKILLS_CN" ] && [ -d "$SKILLS_TARGET" ]; then
    echo -e "  ${CYAN}↓${NC} Installing China-optimized skills (skills-cn)..."
    SKILL_COUNT=0
    for skill_dir in "$SKILLS_CN"/*/; do
        skill_name=$(basename "$skill_dir")
        if [ ! -d "$SKILLS_TARGET/$skill_name" ]; then
            cp -R "$skill_dir" "$SKILLS_TARGET/$skill_name"
            SKILL_COUNT=$((SKILL_COUNT + 1))
        fi
    done
    echo -e "  ${GREEN}✓${NC} China skills installed (+$SKILL_COUNT new)"
fi

# ---- Done ----
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Setup complete!${NC}"
echo ""
echo -e "  To start:"
echo -e "    Mac:     ${CYAN}bash Mac-Start.command${NC}"
echo -e "    Windows: Double-click ${CYAN}Windows-Start.bat${NC}"
echo ""
echo -e "  Directory structure:"
echo -e "    app/core/       ← OpenClaw + dependencies"
echo -e "    app/runtime/    ← Node.js $NODE_VERSION"
echo -e "    data/           ← Auto-generated on first run"
echo ""
echo -e "  ${CYAN}Tip: For cross-platform USB, use: bash setup.sh --all-platforms${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
