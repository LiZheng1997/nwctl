#!/usr/bin/env bash
# ============================================================
# nwctl uninstaller - Removes the symlink from /usr/local/bin
# Usage: sudo bash uninstall.sh
# ============================================================
set -e

INSTALL_PATH="/usr/local/bin/nwctl"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo: sudo bash $0"
    exit 1
fi

if [ -L "${INSTALL_PATH}" ] || [ -f "${INSTALL_PATH}" ]; then
    rm -f "${INSTALL_PATH}"
    echo "nwctl uninstalled from ${INSTALL_PATH}"
else
    echo "nwctl is not installed at ${INSTALL_PATH}"
fi
