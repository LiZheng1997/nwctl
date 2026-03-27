#!/usr/bin/env bash
# ============================================================
# Standalone Rosbag Replay Launcher
# Replay real vehicle ROS2 bag data with pointcloud and lanelet2 maps
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Default parameters
PLAY_RATE="1.0"
AUTO_PLAY=false
ROSBAG_FILE=""
MAP_PATH="${SHARED_MAP_PATH}"
ROSBAG_PATH="${SHARED_ROSBAG_PATH}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-aw}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rate) PLAY_RATE="$2"; shift 2 ;;
        --auto) AUTO_PLAY=true; shift ;;
        --map-path) MAP_PATH="$2"; shift 2 ;;
        --rosbag-path) ROSBAG_PATH="$2"; shift 2 ;;
        --bag) ROSBAG_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: rosbag-replay.sh [OPTIONS]"
            echo "  --rate <float>       Playback rate (default: 1.0)"
            echo "  --auto               Auto-play mode (start bag automatically)"
            echo "  --map-path <path>    Specify map path"
            echo "  --rosbag-path <path> Specify rosbag directory path"
            echo "  --bag <filename>     Specify bag subdirectory name (optional)"
            echo "  -h, --help           Show help"
            echo ""
            echo "Examples:"
            echo "  ./rosbag-replay.sh                              # Manual mode"
            echo "  ./rosbag-replay.sh --auto --rate 0.5            # Auto-play at 0.5x"
            echo "  ./rosbag-replay.sh --auto --bag my_recording    # Auto-play specific bag"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Environment check
bash "${SCRIPT_DIR}/check-env.sh" rosbag-replay

# X11 permissions
xhost +local:docker 2>/dev/null || true

echo ""
echo -e "\033[0;32m================================================"
echo " Autoware Rosbag Replay"
echo -e "================================================\033[0m"
echo " Image:         ${AUTOWARE_IMAGE}"
echo " Map:           ${MAP_PATH}"
echo " Rosbag:        ${ROSBAG_PATH}"
echo " Playback rate: ${PLAY_RATE}x"
echo " Mode:          $([ "${AUTO_PLAY}" = true ] && echo 'auto-play' || echo 'manual')"
echo ""

if [ "${AUTO_PLAY}" = "false" ]; then
    echo " Manual mode steps:"
    echo "   1. After container starts, Autoware will load (~30 seconds)"
    echo "   2. Open a new terminal and enter the container:"
    echo "      docker exec -it ${CONTAINER_PREFIX:-aw}-rosbag-replay bash"
    echo "   3. Play rosbag inside the container:"
    echo "      source /opt/autoware/setup.bash"
    echo "      ros2 bag play /rosbag_data/<bag_name> --clock -r ${PLAY_RATE}"
    echo ""
fi
echo "================================================"
echo ""

# Build launch command
if [ "${AUTO_PLAY}" = "true" ]; then
    # Determine rosbag path
    if [ -n "${ROSBAG_FILE}" ]; then
        BAG_TARGET="/rosbag_data/${ROSBAG_FILE}"
    else
        BAG_TARGET="/rosbag_data"
    fi

    LAUNCH_CMD="bash -c '\
        source /opt/autoware/setup.bash && \
        ros2 launch autoware_launch logging_simulator.launch.xml \
            map_path:=/autoware_map \
            vehicle_model:=${VEHICLE_MODEL} \
            sensor_model:=${SENSOR_MODEL} & \
        echo \"Waiting for Autoware to start (30s)...\" && \
        sleep 30 && \
        echo \"Starting rosbag playback...\" && \
        ros2 bag play ${BAG_TARGET} --clock -r ${PLAY_RATE} && \
        wait'"
else
    LAUNCH_CMD="bash -c '\
        source /opt/autoware/setup.bash && \
        ros2 launch autoware_launch logging_simulator.launch.xml \
            map_path:=/autoware_map \
            vehicle_model:=${VEHICLE_MODEL} \
            sensor_model:=${SENSOR_MODEL}'"
fi

docker run -it --rm \
    --name "${CONTAINER_PREFIX:-aw}-rosbag-replay" \
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
    -v "${MAP_PATH}":/autoware_map:ro \
    -v "${ROSBAG_PATH}":/rosbag_data:ro \
    "${AUTOWARE_IMAGE}" \
    bash -c "${LAUNCH_CMD}"
