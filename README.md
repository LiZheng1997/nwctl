# nwctl - Nuway Autoware Container Manager

Multi-user development and testing toolkit for Autoware. Multiple team members can work on the same host machine with fully isolated environments.

## Architecture

```
Host Machine
├── ~/zhangsan_aw/           User A's git clone (independent)
│   ├── src/                        User A's source code & branches
│   ├── build/                      User A's build artifacts
│   └── install/                    User A's install
├── ~/lisi_aw/              User B's git clone (independent)
│   ├── src/
│   ├── build/
│   └── install/
├── ~/autoware_map/          Shared map data (read-only)
├── ~/autoware_data/         Shared model data (read-only)
└── nwctl/
    └── nwctl                        CLI tool (install to PATH via install.sh)

Inside Docker Container
├── /workspace/                     Mounted from user's git clone (shell mode)
│   ├── src/                        User's source code
│   ├── build/                      User's build output
│   └── install/                    User's install (overlays prebuilt)
├── /opt/autoware/                  Prebuilt Autoware (shared, from image)
├── /autoware_map/                  Mounted map data (read-only)
├── /autoware_data/                 Mounted model data (read-only)
└── /rosbag_data/                   Mounted rosbag data (read-only)
```

### Isolation

| Resource | Method | Details |
|----------|--------|---------|
| ROS topics | ROS_DOMAIN_ID | Auto-assigned per user, fully isolated |
| Source code | Separate git clones | Each user manages their own repo & branches |
| Build artifacts | Separate directories | In each user's own workspace |
| Containers | Named per user | `aw-zhangsan-shell`, `aw-lisi-rosbag-replay` |
| Map / Data | Shared read-only | Saves disk space |
| GPU | Shared | NVIDIA runtime supports multi-container |

### Two Operating Modes

| Mode | Source Mount | Setup | Use Case |
|------|-------------|-------|----------|
| **planning-sim / rosbag-replay** | None | `/opt/autoware/setup.bash` (prebuilt) | Testing, demo, validation |
| **shell** | User's workspace | `/workspace/install/setup.bash` (user-built) | Development, debugging |

## Requirements

| Item | Requirement |
|------|-------------|
| OS | Ubuntu 22.04 (x86_64 or arm64) |
| GPU | NVIDIA (driver >= 525) |
| Docker | >= 24.0 |
| nvidia-container-toolkit | Installed |
| RAM | >= 16GB (64GB recommended for multi-user) |

## Quick Start

### 1. Pull Docker Image (admin, one-time)

```bash
docker pull ghcr.io/autowarefoundation/autoware:universe-devel-cuda
```

### 2. Clone Your Own Code

Each team member clones their own copy:

```bash
cd ~
git clone https://github.com/autowarefoundation/autoware.git myname_autoware
cd myname_autoware
vcs import src < repositories/autoware.repos

# Switch to your feature branch if needed
cd src/universe/autoware_universe
git checkout feature/my-algorithm
```

### 3. Register

```bash
cd ~/autoware/nwctl
nwctl register myname --src ~/myname_autoware/src
```

### 4. Use

```bash
# Planning simulation (uses prebuilt image, no compilation needed)
nwctl myname planning-sim

# Rosbag replay (uses prebuilt image)
nwctl myname rosbag-replay

# Development shell (mounts your source code)
nwctl myname shell
```

## Modes

### Planning Simulation

```bash
nwctl <username> planning-sim
```

1. Wait for rviz2 window to appear (~30 seconds)
2. Click **2D Pose Estimate** in toolbar, click and drag on map to set initial pose
3. Click **2D Goal Pose** to set destination
4. Click buttons in **AutowareStatePanel** to start autonomous driving

### Rosbag Replay

```bash
nwctl <username> rosbag-replay
```

1. Wait for Autoware to start, confirm pointcloud map is visible in rviz
2. Click **2D Pose Estimate** to set initial vehicle pose
3. Open another terminal and play the bag:

```bash
docker exec -it aw-<username>-rosbag-replay bash
source /opt/autoware/setup.bash
export ROS_DOMAIN_ID=<your_id>    # Check the startup output for your ID
ros2 bag play /rosbag_data -r 0.2 -s sqlite3
```

4. In rviz Views panel, set **Target Frame** to `base_link` to follow the vehicle

### Development Shell

```bash
nwctl <username> shell
```

Inside the container:

```bash
# Your workspace is already sourced

# Build only the package you modified (incremental, fast)
cd /workspace
colcon build --packages-select <package_name> --symlink-install

# Source updated workspace
source /workspace/install/setup.bash

# Test your changes - e.g. launch planning simulation
ros2 launch autoware_launch planning_simulator.launch.xml \
    map_path:=/autoware_map/sample-map-rosbag \
    vehicle_model:=sample_vehicle \
    sensor_model:=sample_sensor_kit
```

**Build a single package for testing:**
```bash
colcon build --packages-select autoware_node --symlink-install
```

**Build a package with its dependencies:**
```bash
colcon build --packages-up-to autoware_ndt_scan_matcher --symlink-install
```

**Full build (first time only, takes a while):**
```bash
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

## Management Commands

```bash
nwctl list                     # List all registered users
nwctl status                   # Show running containers
nwctl disk                     # Show disk usage per user
nwctl <username> stop          # Stop user's containers
nwctl <username> clean         # Clean user's build cache
nwctl update <username> --src <path>  # Update source path
```

## FAQ

### Q: rviz2 shows black screen or crashes
```bash
xhost +local:docker
echo $DISPLAY    # Should be :0 or :1
```

### Q: GPU error "could not select device driver"
```bash
docker run --rm --runtime=nvidia nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```
If this fails, reinstall nvidia-container-toolkit and restart Docker.

### Q: Multiple users' ROS topics interfere with each other
Each user is auto-assigned a unique `ROS_DOMAIN_ID`. No interference by design.

### Q: colcon build can't find dependencies
```bash
# Source the prebuilt workspace first
source /opt/autoware/setup.bash
# Then build
colcon build --packages-select <pkg> --symlink-install
```

### Q: Pointcloud map doesn't load
Check file permissions:
```bash
ls -la ~/autoware_map/sample-map-rosbag/pointcloud_map.pcd
# If permission is -rw-------, fix with:
sudo chmod 644 ~/autoware_map/sample-map-rosbag/pointcloud_map.pcd
```

### Q: Rosbag play shows no data
Make sure `ROS_DOMAIN_ID` matches. Check the startup output for your assigned ID:
```bash
export ROS_DOMAIN_ID=<your_id>
ros2 bag play /rosbag_data -r 0.2 -s sqlite3
```

### Q: Are build artifacts preserved after container exit?
Yes. Build artifacts are in your workspace directory on the host. They persist across container restarts.

### Q: How to switch branches for testing?
Manage your code on the host machine:
```bash
cd ~/myname_autoware/src/universe/autoware_universe
git checkout feature/new-branch
# Then enter dev shell and rebuild
nwctl myname shell
```

## Command Reference

| Command | Description |
|---------|-------------|
| `nwctl register <name> --src <path>` | Register new user |
| `nwctl update <name> --src <path>` | Update source path |
| `nwctl <name> planning-sim` | Planning simulation |
| `nwctl <name> rosbag-replay` | Rosbag replay |
| `nwctl <name> shell` | Development shell |
| `nwctl <name> stop` | Stop containers |
| `nwctl <name> clean` | Clean build cache |
| `nwctl list` | List all users |
| `nwctl status` | Show running containers |
| `nwctl disk` | Show disk usage |
| `nwctl -h` | Show help |
