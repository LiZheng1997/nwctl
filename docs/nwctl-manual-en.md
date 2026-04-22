# nwctl User Manual

**Nuway Autoware Container Manager** — Multi-user Autoware Docker testing and development toolkit

---

## Quick Command Reference

### User Management

| Command | Description |
|---------|-------------|
| `nwctl register <name> --src <path>` | Register a new user with source directory |
| `nwctl update <name> --src <path>` | Update user's source path |
| `nwctl unregister <name>` | Remove user from registry (keeps workspace) |
| `nwctl unregister <name> --keep-workspace` | Remove user (explicitly keep workspace) |
| `nwctl list` | List all registered users and their DOMAIN_IDs |

### Run Modes

| Command | Description |
|---------|-------------|
| `nwctl <name> planning-sim` | Launch planning simulation (uses prebuilt image) |
| `nwctl <name> rosbag-replay` | Launch rosbag replay (uses prebuilt image) |
| `nwctl <name> shell` | Enter development shell (mounts user source) |
| `nwctl <name> stop` | Stop all running containers for a user |
| `nwctl <name> clean` | Clean user's build cache |

### Status & Maintenance

| Command | Description |
|---------|-------------|
| `nwctl status` | Show all running aw-* containers |
| `nwctl disk` | Show disk usage per user (workspace) |
| `nwctl cleanup` | Remove orphan containers, temp files, stale locks |
| `nwctl cleanup --dry-run` | Preview what cleanup would remove (no changes) |
| `nwctl check-env [mode]` | Pre-flight check (Docker/GPU/image/display/data/resources) |
| `nwctl version` | Show version number |
| `nwctl -h` | Show help |

---

## Run Modes — Details

### 1. planning-sim — Planning Simulation

```bash
nwctl <name> planning-sim
```

- Uses `/opt/autoware` inside the image (prebuilt) — **no local compilation required**
- Opens an rviz2 window via X11 forwarding automatically

**Steps:**

1. Wait for the rviz2 window to appear (~30 seconds)
2. Click **2D Pose Estimate** in the toolbar, then click and drag on the map to set the initial pose
3. Click **2D Goal Pose** to set the destination
4. Click the buttons in the **AutowareStatePanel** to start autonomous driving

---

### 2. rosbag-replay — Bag File Replay

```bash
nwctl <name> rosbag-replay
```

- Uses the prebuilt version inside the image
- After startup, open another terminal to play the bag:

```bash
docker exec -it aw-<name>-rosbag-replay bash
source /opt/autoware/setup.bash
export ROS_DOMAIN_ID=<your_id>   # Check the startup output for your assigned ID
ros2 bag play /rosbag_data -r 0.2 -s sqlite3
```

- In the rviz **Views** panel, set **Target Frame** to `base_link` to follow the vehicle

---

### 3. shell — Development Mode

```bash
nwctl <name> shell
```

- Mounts the user's source directory to `/workspace/src` inside the container
- Overlays `/opt/autoware` (prebuilt) as the base dependency layer

**Common operations inside the container:**

```bash
# Incremental build — single package (most common)
colcon build --packages-select <pkg> --symlink-install

# Build a package with all its dependencies
colcon build --packages-up-to <pkg> --symlink-install

# Full build (first time only — takes a while)
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

# Re-source and test with planning simulation
source /workspace/install/setup.bash
ros2 launch autoware_launch planning_simulator.launch.xml \
    map_path:=/autoware_map/sample-map-rosbag \
    vehicle_model:=sample_vehicle \
    sensor_model:=sample_sensor_kit
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Host Machine (Jetson Orin)                     │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      nwctl CLI Tool                          │  │
│  │  install.sh  →  /usr/local/bin/nwctl  (symlink)              │  │
│  │                                                              │  │
│  │  env.sh          ← global config (paths, image, models)      │  │
│  │  users.conf      ← registry: name:domain_id:src_path         │  │
│  │  check-env.sh    ← pre-flight environment checker            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│          ┌───────────────────┼───────────────────┐                  │
│          ▼                   ▼                   ▼                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐           │
│  │  zhangsan    │   │  lisi        │   │  wangwu      │  ...       │
│  │  DOMAIN=10   │   │  DOMAIN=11   │   │  DOMAIN=12   │           │
│  │              │   │              │   │              │           │
│  │ workspaces/  │   │ workspaces/  │   │ workspaces/  │           │
│  │ zhangsan/    │   │ lisi/        │   │ wangwu/      │           │
│  │  build/      │   │  build/      │   │  build/      │           │
│  │  install/    │   │  install/    │   │  install/    │           │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘           │
│         │                  │                  │                    │
│  ┌──────▼──────────────────▼──────────────────▼──────────────┐    │
│  │                  Docker Runtime (NVIDIA)                    │    │
│  │                                                             │    │
│  │  aw-zhangsan-shell          aw-lisi-planning-sim            │    │
│  │  ┌─────────────────┐       ┌─────────────────┐             │    │
│  │  │/workspace→src   │       │ /opt/autoware   │             │    │
│  │  │ROS_DOMAIN_ID=10 │       │ ROS_DOMAIN_ID=11│             │    │
│  │  │GPU runtime      │       │ GPU runtime     │             │    │
│  │  └─────────────────┘       └─────────────────┘             │    │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Shared Read-Only Data                      │  │
│  │  ~/autoware_map/    →  /autoware_map/   (maps: .pcd, .osm)   │  │
│  │  ~/autoware_data/   →  /autoware_data/  (ML models)          │  │
│  │  ~/autoware_rosbag/ →  /rosbag_data/    (bag files)          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Container Mode Comparison

| Mode | Source | setup.bash | Use Case |
|------|--------|------------|----------|
| `planning-sim` | Prebuilt in image | `/opt/autoware/setup.bash` | Testing, demo, validation |
| `rosbag-replay` | Prebuilt in image | `/opt/autoware/setup.bash` | Data replay and analysis |
| `shell` | User-mounted source | `/workspace/install/setup.bash` | Development, debugging, algorithm changes |

---

## Isolation Mechanisms

| Resource | Method | Details |
|----------|--------|---------|
| ROS topics | `ROS_DOMAIN_ID` | Auto-assigned per user, starting at 10, skipping reserved IDs (5) |
| Source code | Separate git clones | Each user manages their own repository and branches |
| Build artifacts | Separate directories | `nwctl/workspaces/<user>/build`, `install` |
| Container names | `aw-<user>-<mode>` | Prevents conflicts, easy to identify |
| Registry writes | `flock` (10s timeout) | `users.conf.lock` prevents concurrent write conflicts |
| GPU | Shared | NVIDIA runtime supports multiple containers simultaneously |

---

## Typical Workflow

### Admin (one-time setup)

```bash
# Pull the Docker image
docker pull ghcr.io/autowarefoundation/autoware:universe-devel-cuda

# Install nwctl
cd ~/autoware/nwctl
sudo ./install.sh
```

### Each Team Member

```bash
# 1. Clone your own copy of the code
cd ~
git clone https://github.com/autowarefoundation/autoware.git myname_aw
cd myname_aw
vcs import src < repositories/autoware.repos

# 2. Register
nwctl register myname --src ~/myname_aw/src

# 3. Pre-flight check
nwctl check-env

# 4. Use as needed
nwctl myname planning-sim     # testing
nwctl myname rosbag-replay    # replay
nwctl myname shell            # development
```

---

## CI/CD Pipeline

```
Push to dev/main branch
        │
        ▼
  ci.yaml (triggered automatically)
  ├── shellcheck static analysis
  └── basic validation (executable, symlink, version, help, install/uninstall)

Push tag v*
        │
        ▼
  release.yaml (triggered automatically)
  ├── reuse ci.yaml
  ├── verify tag matches NWCTL_VERSION in script
  ├── create nwctl-X.Y.Z.tar.gz
  ├── auto-generate changelog
  └── publish GitHub Release (personal + org repos)
```

**Remote Repositories:**

| Alias | URL | Purpose |
|-------|-----|---------|
| `origin` | `git@github.com:LiZheng1997/nwctl.git` | Personal repo |
| `org` | `git@github.com:uwa-rev/nwctl.git` | Organization repo |

---

## FAQ

**Q: rviz2 shows a black screen or crashes**
```bash
xhost +local:docker
echo $DISPLAY   # Should be :0 or :1
```

**Q: GPU error "could not select device driver"**
```bash
docker run --rm --runtime=nvidia nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
# If this fails, reinstall nvidia-container-toolkit and restart Docker
```

**Q: Multiple users' ROS topics interfere with each other**

Each user is automatically assigned a unique `ROS_DOMAIN_ID`. Isolation is by design — no manual action needed.

**Q: colcon build can't find dependencies**
```bash
source /opt/autoware/setup.bash   # source prebuilt layer first
colcon build --packages-select <pkg> --symlink-install
```

**Q: Permission error on pointcloud map**
```bash
sudo chmod 644 ~/autoware_map/sample-map-rosbag/pointcloud_map.pcd
# Or run the automated check:
nwctl check-env
```

**Q: Are build artifacts preserved after container exit?**

Yes. Build artifacts live in `nwctl/workspaces/<user>/` on the host and persist across container restarts.

**Q: How do I switch branches for testing?**

Manage your code on the host:
```bash
cd ~/myname_aw/src/universe/autoware_universe
git checkout feature/new-branch
# Then enter the dev shell and rebuild
nwctl myname shell
```

---

*nwctl v0.1.2 — Nuway Autoware Team*
