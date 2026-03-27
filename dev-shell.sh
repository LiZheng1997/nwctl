#!/usr/bin/env bash
# ============================================================
# Standalone Development Shell
# Mount source code into container for editing, building, and debugging
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Defaults
WORKSPACE_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAP_PATH="${SHARED_MAP_PATH}"
ROSBAG_PATH="${SHARED_ROSBAG_PATH}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-aw}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace) WORKSPACE_PATH="$2"; shift 2 ;;
        --map-path) MAP_PATH="$2"; shift 2 ;;
        --rosbag-path) ROSBAG_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: dev-shell.sh [OPTIONS]"
            echo "  --workspace <path>   Specify workspace path (default: autoware repo root)"
            echo "  --map-path <path>    Specify map path"
            echo "  --rosbag-path <path> Specify rosbag path"
            echo "  -h, --help           Show help"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Environment check
bash "${SCRIPT_DIR}/check-env.sh" dev

# X11 permissions
xhost +local:docker 2>/dev/null || true

echo ""
echo -e "\033[0;32m================================================"
echo " Autoware Development Shell"
echo "================================================\033[0m"
echo " Image:     ${AUTOWARE_IMAGE}"
echo " Source:    ${WORKSPACE_PATH}/src -> /workspace/src"
echo ""
echo " Inside container:"
echo "   # 1. Prebuilt packages are in /autoware/install/, source them first"
echo "   source /opt/autoware/setup.bash"
echo ""
echo "   # 2. Build only the package you modified (incremental, fast)"
echo "   cd /workspace"
echo "   colcon build --packages-select <your_package> --symlink-install"
echo "   source install/setup.bash"
echo ""
echo "   # 3. Run tests"
echo "   colcon test --packages-select <your_package>"
echo "   colcon test-result --verbose"
echo ""
echo "   # 4. Launch planning simulation to verify"
echo "   ros2 launch autoware_launch planning_simulator.launch.xml \\"
echo "       map_path:=/autoware_map \\"
echo "       vehicle_model:=${VEHICLE_MODEL} \\"
echo "       sensor_model:=${SENSOR_MODEL}"
echo "================================================"
echo ""

# Optional mounts
MAP_MOUNT=""
if [ -d "${MAP_PATH}" ]; then
    MAP_MOUNT="-v ${MAP_PATH}:/autoware_map:ro"
fi

ROSBAG_MOUNT=""
if [ -d "${ROSBAG_PATH}" ]; then
    ROSBAG_MOUNT="-v ${ROSBAG_PATH}:/rosbag_data:ro"
fi

docker run -it --rm \
    --name "${CONTAINER_PREFIX:-aw}-dev" \
    --net=host \
    --ipc=host \
    --runtime=nvidia \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e DISPLAY="${DISPLAY}" \
    -e XAUTHORITY="${XAUTHORITY:-}" \
    -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID}" \
    -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
    -e LOCAL_UID="$(id -u)" \
    -e LOCAL_GID="$(id -g)" \
    -e LOCAL_USER="$(id -un)" \
    -e LOCAL_GROUP="$(id -gn)" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "${WORKSPACE_PATH}/src":/workspace/src:rw \
    ${MAP_MOUNT} \
    ${ROSBAG_MOUNT} \
    "${AUTOWARE_IMAGE}" \
    /bin/bash
