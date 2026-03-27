#!/usr/bin/env bash
# ============================================================
# Manual Test Script - Mount locally compiled autoware workspace
# ============================================================
set -euo pipefail

AUTOWARE_IMAGE="ghcr.io/autowarefoundation/autoware:universe-devel-cuda"
WORKSPACE_PATH="/home/lz/autoware"
MAP_PATH="/home/lz/autoware_map"
DATA_PATH="/home/lz/autoware_data"
ROSBAG_PATH="/home/lz/autoware_map/sample-rosbag"
CONTAINER_NAME="aw-test-manual"

# Detect DISPLAY
if [ -z "${DISPLAY:-}" ]; then
    if [ -S "/tmp/.X11-unix/X1" ]; then
        export DISPLAY=:1
    elif [ -S "/tmp/.X11-unix/X0" ]; then
        export DISPLAY=:0
    else
        echo "Error: No DISPLAY detected"
        exit 1
    fi
fi

if [ -z "${XAUTHORITY:-}" ]; then
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
        export XAUTHORITY
    fi
fi

xhost +local:docker 2>/dev/null || true

# If container is already running, attach to it
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container is already running, attaching..."
    exec docker exec -it "${CONTAINER_NAME}" bash
fi

echo ""
echo "================================================"
echo " Autoware Manual Test"
echo "================================================"
echo " Image:     ${AUTOWARE_IMAGE}"
echo " Workspace: ${WORKSPACE_PATH} -> /workspace"
echo " Map:       ${MAP_PATH} -> /autoware_map"
echo " Rosbag:    ${ROSBAG_PATH} -> /rosbag_data"
echo " DISPLAY:   ${DISPLAY}"
echo ""
echo " Inside container:"
echo "   # Launch logging simulator"
echo "   source /workspace/install/setup.bash"
echo "   ros2 launch autoware_launch logging_simulator.launch.xml \\"
echo "       map_path:=/autoware_map/sample-map-rosbag \\"
echo "       vehicle_model:=sample_vehicle \\"
echo "       sensor_model:=sample_sensor_kit"
echo ""
echo "   # In another terminal, play rosbag"
echo "   docker exec -it ${CONTAINER_NAME} bash"
echo "   source /workspace/install/setup.bash"
echo "   ros2 bag play /rosbag_data -r 0.2 -s sqlite3"
echo "================================================"
echo ""

exec docker run -it --rm \
    --name "${CONTAINER_NAME}" \
    --net=host \
    --ipc=host \
    --runtime=nvidia \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e DISPLAY="${DISPLAY}" \
    -e XAUTHORITY="${XAUTHORITY:-}" \
    -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
    -e LOCAL_UID="$(id -u)" \
    -e LOCAL_GID="$(id -g)" \
    -e LOCAL_USER="$(id -un)" \
    -e LOCAL_GROUP="$(id -gn)" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "${WORKSPACE_PATH}":/workspace \
    -v "${MAP_PATH}":/autoware_map:ro \
    -v "${DATA_PATH}":/autoware_data:ro \
    -v "${ROSBAG_PATH}":/rosbag_data:ro \
    "${AUTOWARE_IMAGE}" \
    bash
