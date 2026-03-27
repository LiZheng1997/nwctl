#!/usr/bin/env bash
# ============================================================
# nwctl installer - Creates a symlink in /usr/local/bin
# Usage: sudo bash install.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NWCTL_BIN="${SCRIPT_DIR}/nwctl"
INSTALL_PATH="/usr/local/bin/nwctl"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo: sudo bash $0"
    exit 1
fi

if [ ! -f "${NWCTL_BIN}" ]; then
    echo "Error: nwctl not found at ${NWCTL_BIN}"
    exit 1
fi

# Check if already installed and pointing to the same target
if [ -L "${INSTALL_PATH}" ]; then
    CURRENT_TARGET="$(readlink -f "${INSTALL_PATH}")"
    if [ "${CURRENT_TARGET}" = "$(readlink -f "${NWCTL_BIN}")" ]; then
        echo "nwctl is already installed at ${INSTALL_PATH}"
        echo "  -> ${CURRENT_TARGET}"
        echo "No action needed."
        exit 0
    fi
    echo "Updating existing symlink..."
    rm -f "${INSTALL_PATH}"
elif [ -f "${INSTALL_PATH}" ]; then
    echo "Warning: ${INSTALL_PATH} exists as a regular file, replacing..."
    rm -f "${INSTALL_PATH}"
fi

chmod +x "${NWCTL_BIN}"
ln -s "${NWCTL_BIN}" "${INSTALL_PATH}"

echo "nwctl installed successfully!"
echo ""
echo "  Symlink: ${INSTALL_PATH} -> ${NWCTL_BIN}"
echo ""
echo "  You can now use 'nwctl' from anywhere:"
echo "    nwctl --help"
echo "    nwctl register <username> --src <path>"
echo "    nwctl <username> planning-sim"
echo ""
