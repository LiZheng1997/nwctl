#!/usr/bin/env bash
# ============================================================
# Standalone Planning Simulation Launcher
# Learn Autoware basics without real sensor data
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Defaults
HEADLESS=false
MAP_PATH="${SHARED_MAP_PATH}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-aw}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --headless) HEADLESS=true; shift ;;
        --map-path) MAP_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: planning-sim.sh [OPTIONS]"
            echo "  --map-path <path>  Specify map path"
            echo "  --headless         Run without GUI"
            echo "  -h, --help         Show help"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Environment check
bash "${SCRIPT_DIR}/check-env.sh" planning-sim

# X11 permissions
if [ "${HEADLESS}" = "false" ]; then
    xhost +local:docker 2>/dev/null || true
fi

# Display config
echo ""
echo -e "\033[0;32m================================================"
echo " Autoware Planning Simulation"
echo "================================================\033[0m"
echo " Image:   ${AUTOWARE_IMAGE}"
echo " Map:     ${MAP_PATH}"
echo " Vehicle: ${VEHICLE_MODEL}"
echo " Sensor:  ${SENSOR_MODEL}"
echo ""
echo " Steps after launch:"
echo "   1. Wait for rviz2 window to appear"
echo "   2. Click '2D Pose Estimate' in toolbar to set initial pose"
echo "   3. Click '2D Goal Pose' to set destination"
echo "   4. Click buttons in AutowareStatePanel to start driving"
echo "================================================"
echo ""

# Build docker run display args
DISPLAY_ARGS=""
if [ "${HEADLESS}" = "false" ]; then
    DISPLAY_ARGS="-e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix"
fi

docker run -it --rm \
    --name "${CONTAINER_PREFIX:-aw}-planning-sim" \
    --net=host \
    --ipc=host \
    --runtime=nvidia \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e XAUTHORITY="${XAUTHORITY:-}" \
    -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID}" \
    -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
    -e LOCAL_UID="$(id -u)" \
    -e LOCAL_GID="$(id -g)" \
    -e LOCAL_USER="$(id -un)" \
    -e LOCAL_GROUP="$(id -gn)" \
    ${DISPLAY_ARGS} \
    -v "${MAP_PATH}":/autoware_map:ro \
    "${AUTOWARE_IMAGE}" \
    bash -c "source /opt/autoware/setup.bash && \
        ros2 launch autoware_launch planning_simulator.launch.xml \
            map_path:=/autoware_map \
            vehicle_model:=${VEHICLE_MODEL} \
            sensor_model:=${SENSOR_MODEL}"
