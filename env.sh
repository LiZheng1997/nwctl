#!/usr/bin/env bash
# ============================================================
# Shared Configuration
#
# Paths default to $HOME-based locations. Override by setting
# environment variables before running nwctl, or edit this file.
# ============================================================

# Docker image
AUTOWARE_IMAGE="${AUTOWARE_IMAGE:-ghcr.io/autowarefoundation/autoware:universe-devel-cuda}"

# Shared data paths (read-only)
SHARED_MAP_PATH="${SHARED_MAP_PATH:-${HOME}/autoware_map}"
SHARED_DATA_PATH="${SHARED_DATA_PATH:-${HOME}/autoware_data}"
SHARED_ROSBAG_PATH="${SHARED_ROSBAG_PATH:-${HOME}/autoware_map/sample-rosbag}"
SHARED_SRC_PATH="${SHARED_SRC_PATH:-${HOME}/autoware/src}"

# User workspaces root (each user gets a subdirectory)
USER_WORKSPACES_ROOT="${USER_WORKSPACES_ROOT:-${SCRIPT_DIR}/workspaces}"

# User registry file
USER_REGISTRY="${SCRIPT_DIR}/users.conf"

# Default vehicle and sensor model
VEHICLE_MODEL="${VEHICLE_MODEL:-sample_vehicle}"
SENSOR_MODEL="${SENSOR_MODEL:-sample_sensor_kit}"

# Default map name
DEFAULT_MAP_NAME="${DEFAULT_MAP_NAME:-sample-map-rosbag}"
