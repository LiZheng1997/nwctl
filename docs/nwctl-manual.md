# nwctl 使用手册

**Nuway Autoware Container Manager** — 多用户 Autoware Docker 测试与开发工具包

---

## 命令速查表

### 用户管理

| 命令 | 说明 |
|------|------|
| `nwctl register <name> --src <path>` | 注册新用户，绑定源码目录 |
| `nwctl update <name> --src <path>` | 更新用户源码路径 |
| `nwctl unregister <name>` | 注销用户（保留 workspace） |
| `nwctl unregister <name> --keep-workspace` | 注销用户（明确保留 workspace） |
| `nwctl list` | 列出所有已注册用户及其 DOMAIN_ID |

### 运行模式

| 命令 | 说明 |
|------|------|
| `nwctl <name> planning-sim` | 启动规划仿真（使用镜像预编译版本） |
| `nwctl <name> rosbag-replay` | 启动 rosbag 回放（使用镜像预编译版本） |
| `nwctl <name> shell` | 进入开发 shell（挂载用户源码） |
| `nwctl <name> stop` | 停止该用户所有运行中的容器 |
| `nwctl <name> clean` | 清理该用户的 build 缓存 |

### 状态与运维

| 命令 | 说明 |
|------|------|
| `nwctl status` | 显示所有正在运行的 aw-* 容器 |
| `nwctl disk` | 显示每个用户的磁盘占用（workspace） |
| `nwctl cleanup` | 清理孤立容器、临时文件、过期锁文件 |
| `nwctl cleanup --dry-run` | 预览 cleanup 会清理什么（不实际执行） |
| `nwctl check-env [mode]` | 检查运行环境（Docker/GPU/镜像/Display/数据/资源） |
| `nwctl version` | 显示版本号 |
| `nwctl -h` | 显示帮助 |

---

## 三种运行模式详解

### 1. planning-sim — 规划仿真

```bash
nwctl <name> planning-sim
```

- 使用镜像内 `/opt/autoware`（预编译），**无需本地编译**
- 自动打开 rviz2 窗口，通过 X11 转发显示

**操作步骤：**

1. 等待 rviz2 窗口出现（约 30 秒）
2. 点击工具栏 **2D Pose Estimate**，在地图上点击拖拽设置初始位姿
3. 点击 **2D Goal Pose** 设置目标点
4. 在 **AutowareStatePanel** 面板中点击按钮启动自动驾驶

---

### 2. rosbag-replay — 数据包回放

```bash
nwctl <name> rosbag-replay
```

- 使用镜像内预编译版本
- 启动后另开终端执行回放：

```bash
docker exec -it aw-<name>-rosbag-replay bash
source /opt/autoware/setup.bash
export ROS_DOMAIN_ID=<your_id>   # 从启动输出中查看分配的 ID
ros2 bag play /rosbag_data -r 0.2 -s sqlite3
```

- 在 rviz Views 面板中将 **Target Frame** 设为 `base_link` 以跟随车辆

---

### 3. shell — 开发模式

```bash
nwctl <name> shell
```

- 将用户源码目录挂载到容器 `/workspace/src`
- 容器内叠加 `/opt/autoware`（预编译）作为底层依赖

**容器内常用操作：**

```bash
# 增量编译单个包（最常用）
colcon build --packages-select <pkg> --symlink-install

# 编译包及其所有依赖
colcon build --packages-up-to <pkg> --symlink-install

# 全量编译（首次，耗时较长）
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

# 重新 source 后启动仿真测试
source /workspace/install/setup.bash
ros2 launch autoware_launch planning_simulator.launch.xml \
    map_path:=/autoware_map/sample-map-rosbag \
    vehicle_model:=sample_vehicle \
    sensor_model:=sample_sensor_kit
```

---

## 架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Host Machine (Jetson Orin)                     │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      nwctl CLI Tool                          │  │
│  │  install.sh  →  /usr/local/bin/nwctl  (symlink)              │  │
│  │                                                              │  │
│  │  env.sh          ← 全局配置（路径、镜像名、车辆型号）          │  │
│  │  users.conf      ← 注册表：name:domain_id:src_path           │  │
│  │  check-env.sh    ← 启动前环境自检                            │  │
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

## 容器模式对比

| 模式 | 源码来源 | setup.bash 路径 | 适用场景 |
|------|---------|----------------|---------|
| `planning-sim` | 镜像预编译 | `/opt/autoware/setup.bash` | 测试、演示、验证 |
| `rosbag-replay` | 镜像预编译 | `/opt/autoware/setup.bash` | 数据回放分析 |
| `shell` | 用户挂载源码 | `/workspace/install/setup.bash` | 开发、调试、修改算法 |

---

## 隔离机制

| 资源 | 隔离方式 | 说明 |
|------|---------|------|
| ROS 话题 | `ROS_DOMAIN_ID` | 每用户自动分配，从 10 开始，跳过保留 ID（5） |
| 源代码 | 独立 git clone | 每人管理自己的仓库和分支 |
| 编译产物 | 独立目录 | `nwctl/workspaces/<user>/build`, `install` |
| 容器命名 | `aw-<user>-<mode>` | 避免冲突，便于管理 |
| 注册表写入 | `flock`（10s 超时） | `users.conf.lock` 防止并发写冲突 |
| GPU | 共享 | NVIDIA runtime 支持多容器同时使用 |

---

## 典型工作流程

### 管理员（一次性）

```bash
# 拉取 Docker 镜像
docker pull ghcr.io/autowarefoundation/autoware:universe-devel-cuda

# 安装 nwctl
cd ~/autoware/nwctl
sudo ./install.sh
```

### 团队成员（每人）

```bash
# 1. 克隆自己的代码
cd ~
git clone https://github.com/autowarefoundation/autoware.git myname_aw
cd myname_aw
vcs import src < repositories/autoware.repos

# 2. 注册
nwctl register myname --src ~/myname_aw/src

# 3. 环境自检
nwctl check-env

# 4. 按需使用
nwctl myname planning-sim     # 测试
nwctl myname rosbag-replay    # 回放
nwctl myname shell            # 开发
```

---

## CI/CD 流程

```
提交到 dev/main 分支
        │
        ▼
  ci.yaml (自动触发)
  ├── shellcheck 静态检查
  └── 基础验证（可执行、symlink、版本、help、install/uninstall）

推送 tag v*
        │
        ▼
  release.yaml (自动触发)
  ├── 复用 ci.yaml
  ├── 验证 tag 与脚本内 NWCTL_VERSION 一致
  ├── 打包 nwctl-X.Y.Z.tar.gz
  ├── 自动生成 changelog
  └── 发布 GitHub Release（personal + org 两个仓库）
```

**远端仓库：**

| 别名 | 地址 | 用途 |
|------|------|------|
| `origin` | `git@github.com:LiZheng1997/nwctl.git` | 个人仓库 |
| `org` | `git@github.com:uwa-rev/nwctl.git` | 组织仓库 |

---

## FAQ

**Q: rviz2 黑屏或崩溃**
```bash
xhost +local:docker
echo $DISPLAY   # 应为 :0 或 :1
```

**Q: GPU 错误 "could not select device driver"**
```bash
docker run --rm --runtime=nvidia nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
# 失败则重装 nvidia-container-toolkit 并重启 Docker
```

**Q: 多用户 ROS 话题互相干扰**

每个用户自动分配唯一 `ROS_DOMAIN_ID`，设计上完全隔离，无需手动处理。

**Q: colcon build 找不到依赖**
```bash
source /opt/autoware/setup.bash   # 先 source 预编译版本
colcon build --packages-select <pkg> --symlink-install
```

**Q: 点云地图权限错误**
```bash
sudo chmod 644 ~/autoware_map/sample-map-rosbag/pointcloud_map.pcd
# 或使用 check-env 自动检测
nwctl check-env
```

**Q: 编译产物在容器重启后是否保留？**

保留。编译产物在宿主机的 `nwctl/workspaces/<user>/` 目录中，容器重启不影响。

---

*nwctl v0.1.2 — Nuway Autoware Team*
