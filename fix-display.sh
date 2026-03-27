#!/usr/bin/env bash
# ============================================================
# Fix NoMachine display when no physical monitor is connected
# Requires sudo: sudo bash fix-display.sh
# ============================================================
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo: sudo bash $0"
    exit 1
fi

echo "[1/3] Backing up and writing xorg.conf ..."
cp /etc/X11/xorg.conf /etc/X11/xorg.conf.bak.$(date +%Y%m%d%H%M%S)

cat > /etc/X11/xorg.conf << 'XEOF'
# Disable extensions not useful on Tegra.
Section "Module"
    Disable     "dri"
    SubSection  "extmod"
        Option  "omit xfree86-dga"
    EndSubSection
EndSection

# ---- NVIDIA physical display ----
Section "Device"
    Identifier  "Tegra0"
    Driver      "nvidia"
    Option      "AllowEmptyInitialConfiguration" "true"
EndSection

Section "Screen"
    Identifier  "NVIDIAScreen"
    Device      "Tegra0"
    DefaultDepth 24
EndSection

# ---- Dummy virtual display (NoMachine fallback) ----
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
    VideoRam    256000
EndSection

Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   30-70
    VertRefresh  50-75
EndSection

Section "Screen"
    Identifier  "DummyScreen"
    Device      "DummyDevice"
    Monitor     "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Modes   "1920x1080" "1280x720"
    EndSubSection
EndSection

# Dummy first (always available), NVIDIA second (when monitor connected)
Section "ServerLayout"
    Identifier  "Default"
    Screen 0    "DummyScreen"
    Screen 1    "NVIDIAScreen" RightOf "DummyScreen"
    Option      "AllowEmptyInitialConfiguration" "true"
EndSection
XEOF
echo "  done."

echo "[2/3] Configuring gdm auto-login ..."
if ! grep -q "AutomaticLogin=lz" /etc/gdm3/custom.conf 2>/dev/null; then
    sed -i '/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=lz' /etc/gdm3/custom.conf
    echo "  done."
else
    echo "  Already configured, skipping."
fi

echo "[3/3] Restarting gdm3 ..."
systemctl restart gdm3
echo "  done."

echo ""
echo "All done. NoMachine should now be able to connect."
