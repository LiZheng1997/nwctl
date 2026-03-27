#!/usr/bin/env bash
# ============================================================
# Shared Configuration - Maintained by admin
# ============================================================

# Docker image
AUTOWARE_IMAGE="ghcr.io/autowarefoundation/autoware:universe-devel-cuda"

# Shared data paths (read-only)
SHARED_MAP_PATH="/home/lz/autoware_map"
SHARED_DATA_PATH="/home/lz/autoware_data"
SHARED_ROSBAG_PATH="/home/lz/autoware_map/sample-rosbag"
SHARED_SRC_PATH="/home/lz/autoware/src"

# User workspaces root (each user gets a subdirectory)
USER_WORKSPACES_ROOT="/home/lz/autoware/workspaces"

# User registry file
USER_REGISTRY="${SCRIPT_DIR}/users.conf"

# Default vehicle and sensor model
VEHICLE_MODEL="${VEHICLE_MODEL:-sample_vehicle}"
SENSOR_MODEL="${SENSOR_MODEL:-sample_sensor_kit}"

# Default map name
DEFAULT_MAP_NAME="sample-map-rosbag"
