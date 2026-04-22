#!/usr/bin/env bash
# ============================================================
# Environment Check - Validate all dependencies before running Autoware
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}[OK]${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; echo -e "       ${YELLOW}Fix: $2${NC}"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

MODE="${1:-all}"

echo ""
echo "=========================================="
echo " Autoware Environment Check"
echo "=========================================="
echo ""

# 1. Docker
echo "[1/6] Docker"
if command -v docker &>/dev/null; then
    pass "Docker installed: $(docker --version | head -1)"
else
    fail "Docker not installed" "See https://docs.docker.com/engine/install/ubuntu/"
fi

if docker info &>/dev/null; then
    pass "Docker daemon is running"
else
    fail "Docker cannot run (permission denied or service not started)" "sudo usermod -aG docker \$USER && re-login"
fi

# 2. NVIDIA GPU
echo "[2/6] NVIDIA GPU"
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    pass "NVIDIA GPU: ${GPU_NAME}"
else
    fail "nvidia-smi not available" "Install NVIDIA driver >= 525"
fi

if dpkg -l 2>/dev/null | grep -q nvidia-container-toolkit; then
    pass "nvidia-container-toolkit installed"
elif rpm -qa 2>/dev/null | grep -q nvidia-container-toolkit; then
    pass "nvidia-container-toolkit installed"
else
    fail "nvidia-container-toolkit not installed" "See https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
fi

# 3. Docker image
echo "[3/6] Docker Image"
if docker image inspect "${AUTOWARE_IMAGE}" &>/dev/null; then
    SIZE=$(docker image inspect "${AUTOWARE_IMAGE}" --format='{{.Size}}' 2>/dev/null)
    SIZE_GB=$(echo "scale=1; ${SIZE}/1024/1024/1024" | bc 2>/dev/null || echo "?")
    pass "Image exists: ${AUTOWARE_IMAGE} (${SIZE_GB}GB)"
else
    fail "Image not found: ${AUTOWARE_IMAGE}" "docker pull ${AUTOWARE_IMAGE}"
fi

# 4. Display
echo "[4/6] Display"
if [ -n "${DISPLAY:-}" ]; then
    pass "DISPLAY=${DISPLAY}"
else
    fail "DISPLAY not set" "export DISPLAY=:0 (or :1)"
fi

if [ -d "/tmp/.X11-unix" ] && [ "$(ls -A /tmp/.X11-unix 2>/dev/null)" ]; then
    pass "X11 socket exists"
else
    fail "X11 socket not found" "Ensure a graphical desktop is running"
fi

# Check if ALL files matching a pattern are readable by current user
# Usage: check_readable <base_dir> <file_pattern> <label>
check_readable() {
    local base="$1" pattern="$2" label="$3"
    local unreadable
    unreadable=$(find "${base}" -name "${pattern}" \! -readable 2>/dev/null | head -3)
    if [ -n "${unreadable}" ]; then
        local count
        count=$(find "${base}" -name "${pattern}" \! -readable 2>/dev/null | wc -l)
        fail "${label}: ${count} unreadable file(s)" "sudo chmod a+r \"${base}\"/*${pattern#\*}"
        echo "       Unreadable samples:"
        echo "${unreadable}" | awk '{print "         "$0}'
        return 1
    fi
    return 0
}

# 5. Data paths
echo "[5/6] Data Paths"
if [ -d "${SHARED_MAP_PATH}" ]; then
    if find "${SHARED_MAP_PATH}" -name '*.pcd' -print -quit 2>/dev/null | grep -q .; then
        if check_readable "${SHARED_MAP_PATH}" '*.pcd' "Pointcloud map permission"; then
            pass "Pointcloud map: ${SHARED_MAP_PATH}"
        fi
    else
        warn "Map directory exists but no .pcd files found: ${SHARED_MAP_PATH}"
    fi
    if find "${SHARED_MAP_PATH}" -name '*.osm' -print -quit 2>/dev/null | grep -q .; then
        if check_readable "${SHARED_MAP_PATH}" '*.osm' "Lanelet2 map permission"; then
            pass "Lanelet2 map: ${SHARED_MAP_PATH}"
        fi
    else
        warn "Map directory exists but no .osm files found: ${SHARED_MAP_PATH}"
    fi
else
    if [ "${MODE}" = "planning-sim" ] || [ "${MODE}" = "rosbag-replay" ] || [ "${MODE}" = "all" ]; then
        fail "Map path does not exist: ${SHARED_MAP_PATH}" "Edit SHARED_MAP_PATH in env.sh"
    fi
fi

if [ "${MODE}" = "rosbag-replay" ] || [ "${MODE}" = "all" ]; then
    if [ -d "${SHARED_ROSBAG_PATH}" ]; then
        BAG_COUNT=$(find "${SHARED_ROSBAG_PATH}" \( -name "*.db3" -o -name "*.mcap" \) 2>/dev/null | wc -l)
        if [ "${BAG_COUNT}" -gt 0 ]; then
            if check_readable "${SHARED_ROSBAG_PATH}" '*.db3' "Rosbag permission" && \
               check_readable "${SHARED_ROSBAG_PATH}" '*.mcap' "Rosbag permission"; then
                pass "Rosbag data: ${SHARED_ROSBAG_PATH} (${BAG_COUNT} files)"
            fi
        else
            warn "Rosbag directory exists but no .db3/.mcap files found: ${SHARED_ROSBAG_PATH}"
        fi
    else
        fail "Rosbag path does not exist: ${SHARED_ROSBAG_PATH}" "Edit SHARED_ROSBAG_PATH in env.sh"
    fi
fi

# 6. System resources
echo "[6/6] System Resources"
AVAIL_GB=$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -d ' G')
if [ "${AVAIL_GB:-0}" -ge 20 ]; then
    pass "Disk available: ${AVAIL_GB}GB"
else
    warn "Less than 20GB disk available (current: ${AVAIL_GB}GB), may affect compilation"
fi

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "${MEM_GB:-0}" -ge 16 ]; then
    pass "Memory: ${MEM_GB}GB"
else
    warn "Less than 16GB memory (current: ${MEM_GB}GB), compilation may OOM"
fi

# Summary
echo ""
echo "=========================================="
echo -e " Result: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}  ${YELLOW}${WARN} warnings${NC}"
echo "=========================================="

if [ "${FAIL}" -gt 0 ]; then
    echo -e " ${RED}Please fix the failed items before running Autoware${NC}"
    exit 1
fi
echo ""
