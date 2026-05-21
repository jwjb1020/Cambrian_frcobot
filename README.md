# Fairino + Cambrian Vision — Integration API

Lua API library for integrating **Cambrian Vision AI** with **Fairino FR series robots**.  
The library communicates with the Cambrian server over TCP/IP and returns grasp predictions to the robot program.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Network Architecture](#2-network-architecture)
3. [Development Environment](#3-development-environment)
4. [Docker Simulator Setup](#4-docker-simulator-setup)
5. [File Structure](#5-file-structure)
6. [Quick Start](#6-quick-start)
7. [API Reference](#7-api-reference)
8. [GUI Popup Server](#8-gui-popup-server)
9. [Fairino Lua Constraints](#9-fairino-lua-constraints)
10. [Debugging](#10-debugging)
11. [Uploading Files to the Robot](#11-uploading-files-to-the-robot)
12. [Changelog](#12-changelog)

---

## 1. System Overview

```
┌─────────────────────┐     TCP/IP      ┌─────────────────────┐
│   Fairino Robot     │◄───────────────►│  Cambrian Vision PC │
│  (Lua script runs   │   192.168.58.x  │  (AI grasp server)  │
│   on controller)    │                 │  Port 4000          │
└─────────────────────┘                 └─────────────────────┘
          │
          │ TCP (popup)
          ▼
┌─────────────────────┐
│   Host / Dev PC     │
│  gui_popup_server   │
│  Port 9999          │
└─────────────────────┘
```

| Component | IP Address | Port |
|-----------|-----------|------|
| Fairino Robot (simulator) | `192.168.58.2` | — |
| Cambrian Vision PC | `192.168.58.200` | `4000` |
| Host PC (popup server) | `192.168.58.1` | `9999` |

---

## 2. Network Architecture

The development setup uses Docker to run the Fairino simulator alongside a physical Cambrian Vision PC connected over LAN.

```
Host PC (developer machine)
  ├── enp12s0          ← Physical LAN → Camera/Vision PC (192.168.58.200)
  └── br-xxxxxxx       ← Docker bridge (gateway: 192.168.58.1)
       └── fairino-container → Virtual robot (192.168.58.2)
```

### Routing Table After Setup

| Destination | Interface | Purpose |
|-------------|-----------|---------|
| `192.168.58.2/32` | `br-xxxxxxx` | Virtual robot (Docker) |
| `192.168.58.200/32` | `enp12s0` | Camera PC (physical LAN) |
| Inside container: `192.168.58.200` via `192.168.58.1` | — | Container → Camera PC |

By default Docker adds a catch-all `/24` route for the bridge subnet, which prevents packets to `192.168.58.200` from routing to the physical LAN interface. The setup script removes this catch-all and adds host-specific `/32` routes.

---

## 3. Development Environment

| Item | Details |
|------|---------|
| OS | Ubuntu (Linux) |
| Robot SDK | Fairino FR Series |
| Scripting Language | Lua 5.3 (embedded in Fairino controller) |
| Vision API | Cambrian Vision 2.4b18 |
| Popup Server | Python 3 + tkinter |
| Simulator | Fairino SimMachine (Docker) |

### Dependencies

**Python (popup server only):**
```bash
# No additional packages required — uses Python standard library only
python3 --version   # 3.6+ recommended
```

**Lua** runs embedded in the Fairino robot controller. No external installation needed.

---

## 4. Docker Simulator Setup

The Fairino SimMachine Docker image provides a virtual robot controller accessible via web browser, identical to the physical robot software.
- this site help to you https://fairino-doc-en.readthedocs.io/latest/VMMachine/controller_docker_machine.html
- And I attached the docker and sim files on `frcobot_en/start_sim/FAIRINO SimMachine Docker`

### 4.1 First-Time Setup

**Step 1 — Import the Docker image:**
```bash
# The image file is: FAIRINOSimMachine (provided by Fairino)
docker load -i FAIRINOSimMachine
```

**Step 2 — Create and start the container:**
```bash
docker run -d \
  --name fairino-container \
  --network bridge \
  -p 80:80 \
  <image-name>
```

> Refer to the official Fairino SimMachine user manual for the exact image name and full `docker run` parameters.

**Step 3 — Run the network setup script:**
```bash
sudo bash start_sim/fairino_network_setup.sh
```

This script:
- Starts Docker and the `fairino-container` if not running
- Removes the Docker bridge catch-all `/24` route
- Adds `/32` host routes for the virtual robot and camera PC
- Adds the camera PC route inside the container
- Runs ping tests to verify connectivity

**Step 4 — Access the robot web UI:**
```
URL:      http://192.168.58.2
Username: admin
Password: 123
```

### 4.2 Daily Startup

After rebooting the host PC, run the network setup script again (Docker routing resets on reboot):

```bash
sudo bash start_sim/fairino_network_setup.sh
```

### 4.3 Network Configuration Reference

The script variables can be adjusted if your network configuration differs:

```bash
# In start_sim/fairino_network_setup.sh
DOCKER_BRIDGE="br-1771327d712f"   # docker network ls to find your bridge name
VIRTUAL_ROBOT_IP="192.168.58.2"
CAMERA_PC_IP="192.168.58.200"
LAN_INTERFACE="enp12s0"           # ip link to find your interface name
CONTAINER_NAME="fairino-container"
GATEWAY_IP="192.168.58.1"
```

To find your Docker bridge name:
```bash
docker network ls
ip link show | grep br-
```

---

## 5. File Structure

```
frcobot_en/
├── README.md                        ← This file
├── FairinoForCambrian_v4_1.lua      ← Main library (current — upload to robot)
├── FairinoForCambrian_v4.lua        ← Previous version (kept for reference)
├── FairinoForCambrian_v3.lua        ← Older version (kept for reference)
├── gui_popup_server.py              ← Popup GUI server (run on host PC)
│
├── example/
│   └── cambrianAPItest.lua          ← Example robot script
│
├── start_sim/
│   └── fairino_network_setup.sh     ← Network routing setup script
│
├── log messages/                    ← Auto-created; popup logs stored here
│   └── YYYY-MM-DD.txt
│
└── documents/
    ├── Cambrian_VISION_API.md       ← Official Cambrian API documentation (v2.3, full reference)
    ├── FRLua_programming_script_user_manual.md  ← Fairino Lua manual
    ├── MoveO.lua                    ← Fairino engineer example (ServoMove)
    ├── PoseTranseCalc.lua           ← Fairino engineer example (kinematics)
    └── PoseTranseMove.lua           ← Fairino engineer example (MoveL)
```

---

## 6. Quick Start

### Step 1 — Start the popup server on the host PC
```bash
python3 gui_popup_server.py
# Output: [Popup server] Listening on 0.0.0.0:9999...
```

### Step 2 — Upload the library to the robot

Upload `FairinoForCambrian_v4_1.lua` to the robot controller via the web UI:
```
Path on robot: /usr/local/etc/controller/lua/FairinoForCambrian_v4_1.lua
```

### Step 3 — Write a robot script

```lua
-- Load the library
package.path = package.path .. ";/usr/local/etc/controller/lua/?.lua"
require("FairinoForCambrian_v4_1")

-- Configure connection
set_connection_info("192.168.58.200", 4000)  -- Cambrian Vision PC IP:port
POPUP_SERVER_IP = "192.168.58.1"             -- Host PC IP (Docker gateway)
POPUP_ENABLE    = true

-- Load model and wait for it to be ready
local model = "your_model_name"
cambrian_load_model(model)
cambrian_wait_for_model_launch(model)

-- Move to observation position
Move("p_home", 30)

-- Request grasp prediction
local result, pred_pose, grasp_type = cambrian_get_prediction(model, {}, {}, 0)

if result > 0 then
    -- Calculate approach poses
    local grasp_p, app_p, preapp_p, exit_p =
        cambrian_approach(pred_pose, {0,0,0,0,0,0}, 50, 100, 50)

    Go(preapp_p.coordinate, nil, 50)  -- move to pre-approach
    Go(app_p.coordinate,    nil, 20)  -- move to approach
    -- close gripper here
    Go(exit_p.coordinate,   nil, 20)  -- retreat
    -- open gripper here
end
```

---

## 7. API Reference

### 7.1 Connection

```lua
-- Set Cambrian server address
set_connection_info(ip_string, port_number)

-- Ping the server (returns code=0 on success)
local code, msg = cambrian_ping()

-- Get server version
local major, minor, patch = cambrian_get_version()
```

### 7.2 Sending Raw Commands (Without a Wrapper)

Not every Cambrian API command has a dedicated wrapper function. For commands not covered by the library, use `cambrian_request` directly.

> **Why can't I call `_cmd("PING#")` directly?**  
> `_cmd` is declared `local function` inside the library file. In Lua, `local` is file-scoped — `require()` does not expose local symbols to the caller. Calling `_cmd` from a user script always results in `attempt to call a nil value (global '_cmd')`.

**Pattern — open socket, send command, close socket:**

```lua
local sock, ok = cambrian_connect("192.168.58.200", 4000)
if ok then
    local code, msg, dat = cambrian_request(sock, "PING#")
    cambrian_disconnect(sock)
    popup({code, msg, dat}, "result")
end
```

> **Common mistake:** calling `cambrian_request(sock, ...)` without `cambrian_connect` first leaves `sock = nil`, causing:  
> `500 Error: bad argument #2 to 'SocketSendString' (string expected, got nil)`

**Using wrapper functions is shorter and handles the socket automatically:**

```lua
-- These two are exactly equivalent:

-- Option A: wrapper (recommended)
local code, msg = cambrian_ping()

-- Option B: manual
local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
local code, msg = cambrian_request(sock, "PING#")
cambrian_disconnect(sock)
```

Use Option B only when a wrapper doesn't exist for the command you need.

---

### 7.3 Model Management

```lua
-- Load model (async — returns immediately, no response from server)
cambrian_load_model("model_name")

-- Block until model is ready
cambrian_wait_for_model_launch("model_name")

-- Check if ready without blocking (1=ready, 0=loading, -1=error)
local status = cambrian_check_model_ready("model_name")

-- Unload
cambrian_unload_model("model_name")
cambrian_unload_all_models()
```

> **Important:** `cambrian_load_model` is a fire-and-forget command — the Cambrian server sends no response. Always follow it with `cambrian_wait_for_model_launch` before requesting predictions.

### 7.4 Grasp Prediction

```lua
-- Get the single best grasp prediction
-- priority_num_array: preferred grasp types, e.g. {1, 2} or {} for any
-- ignore_num_array:   grasp types to exclude, e.g. {3} or {}
-- sort_code:          0 = default sort
local result, pred_pose, grasp_type =
    cambrian_get_prediction("model_name", {}, {}, 0)

-- result > 0  → prediction found
-- result == 0 → no prediction (bin empty or no valid grasp)
-- result < 0  → error

-- Access the predicted pose:
local x  = pred_pose.coordinate[1]
local y  = pred_pose.coordinate[2]
local z  = pred_pose.coordinate[3]
local rx = pred_pose.coordinate[4]
local ry = pred_pose.coordinate[5]
local rz = pred_pose.coordinate[6]
```

```lua
-- Get all predictions at once
local count, poses, types =
    cambrian_get_all_predictions("model_name", {}, {}, 0)

-- Iterate through results
for i = 1, count do
    local pose = poses[i].coordinate
    local type = types[i]
end
```

### 7.5 Approach Pose Calculation

```lua
-- Calculate grasp, approach, pre-approach, and exit poses from a prediction
local grasp_p, app_p, preapp_p, exit_p =
    cambrian_approach(
        pred_pose,        -- from cambrian_get_prediction
        {0, 0, 0, 0, 0, 0},  -- grasp offset {x,y,z,rx,ry,rz} (mm, deg)
        50,               -- approach distance (mm, Z- axis)
        100,              -- pre-approach distance (mm)
        50                -- exit/retreat distance (mm)
    )

Go(preapp_p.coordinate, nil, 50)
Go(app_p.coordinate,    nil, 20)
Go(exit_p.coordinate,   nil, 20)
```

### 7.6 Motion

```lua
-- Linear move (MoveL) to Cartesian pose
-- pose: {x, y, z, rx, ry, rz} (mm, degrees)
-- tool: tool number (nil = use current active tool)
-- speed: speed % (default 30)
Go({x, y, z, rx, ry, rz}, tool, speed)

-- Joint move (MoveJ) to a named teaching point
-- pName: teaching point name as registered in robot software
Move("point_name", speed)
```

### 7.7 Coordinate Transform

```lua
-- Transform relative_pose (expressed in coordinate_pose frame) to world coordinates
-- Equivalent to UR's pose_trans(p_from, p_from_to)
local world_pose = cambrian_pose_trans(coordinate_pose, relative_pose)

-- Example: offset 50 mm in Z from flange pose
local target = cambrian_pose_trans(flange_pose, {0, 0, 50, 0, 0, 0})
```

### 7.8 Camera Commands

```lua
cambrian_check_cameras()        -- 1=OK, 0=error
cambrian_cameras_auto()         -- switch to auto exposure
cambrian_cameras_manual()       -- switch to manual exposure
cambrian_cameras_exposure(val)  -- set exposure (manual mode)
cambrian_cameras_gain(val)      -- set gain
cambrian_wait_cameras()         -- block until cameras ready
cambrian_restart_cameras()
```

### 7.9 TCP Offset

The library reads the active tool's TCP offset automatically via `GetTCPOffset()`. Manual override is available when the camera is mounted separately from the TCP:

```lua
-- Override TCP offset manually
cambrian_set_state(nil, nil, {x, y, z, rx, ry, rz})

-- Revert to automatic reading: set _fr_tool_offset_manual = false
```

### 7.10 Calibration

Calibration must be run once before the first prediction to establish the relationship between the camera rig and the robot flange.

**Automatic calibration (recommended):**

```lua
-- High-level helper — handles the full loop automatically
-- move_fn is called each time the robot needs to move to a calibration pose
local rig_pose = {0, 0, 200, 0, 0, 0}  -- rough camera position relative to flange (mm)
cambrian_run_auto_calibration(
    rig_pose,   -- approximate rig pose {x,y,z,rx,ry,rz} relative to flange
    8,          -- focal length mm (standard rig = 8)
    0.08,       -- stereo separation m (standard = 0.08; small rig = 0.06)
    5,          -- camera tilt degrees (standard = 5; small rig = 8)
    function(x, y, z, a, b, g)
        Go({x, y, z, a, b, g}, nil, 20)   -- move robot to calibration pose
    end
)
```

**Manual calibration (step by step):**

```lua
-- 1. Start calibration session
cambrian_start_calibration({0,0,0,0,0,0}, 8)

-- 2. Move robot to different positions overlooking the calibration board,
--    capturing one image at each position (minimum 8 images)
Move("calib_pose_1")
cambrian_capture_calibration_image()
Move("calib_pose_2")
cambrian_capture_calibration_image()
-- ... repeat for at least 8 poses

-- 3. Trigger the calibration calculation
cambrian_run_manual_calibration()
```

**Low-level step-by-step (auto calibration without the helper):**

```lua
cambrian_start_calibration(rig_pose, 8, 0.08, 5)
local reply = ""
while true do
    local step, x, y, z, a, b, g = cambrian_next_calibration_step(reply)
    reply = ""
    if step == 1 then
        Go({x, y, z, a, b, g}, nil, 20)   -- move to pose
    elseif step == 2 then
        break   -- done
    elseif step == 3 then
        -- test reachability and report back
        local j1 = GetInverseKin(0, x, y, z, a, b, g, -1)
        reply = (type(j1) == "number") and "1" or "2"
    end
end
```

| Function | Description |
|----------|-------------|
| `cambrian_run_auto_calibration(rig_pose, fl, ss, tilt, move_fn)` | Full auto-calibration loop |
| `cambrian_start_calibration(rig_pose, focal_length, sep, tilt)` | Start calibration session |
| `cambrian_next_calibration_step(reply_data)` | Get next step (1=move, 2=done, 3=test reach) |
| `cambrian_capture_calibration_image()` | Capture image for manual calibration |
| `cambrian_run_manual_calibration()` | Run manual calibration (after ≥8 images) |
| `cambrian_set_calibration_rig_pose(pose, fl, sep, tilt)` | Set rig params without starting |
| `cambrian_set_calibration_mount(space)` | `"BASE"` fixed / `"FLANGE"` robot-mounted |

### 7.11 Popup

```lua
-- Show a blocking popup on the host PC
-- [Continue] → program continues normally
-- [Stop]     → throws error(), terminating the script immediately
popup("Camera connection failed!", "Alert")

-- Any type can be passed directly — tables are auto-serialized to {v1, v2, ...}
popup({GetActualTCPPose()},          "TCP Pose")    -- e.g. {100.0, 200.0, 300.0, 0.0, 90.0, 0.0}
popup({GetActualJointPosDegree()},   "Joints")
popup({GetTCPOffset()},              "TCP Offset")

-- Loop until Stop is clicked (Stop throws error and exits)
while true do
    popup(cambrian_check_cameras(), "Camera Status")
end
```

**Global settings:**
```lua
POPUP_SERVER_IP   = "192.168.58.1"  -- host PC IP (Docker gateway)
POPUP_SERVER_PORT = 9999
POPUP_ENABLE      = true            -- false = print to console only (not visible without direct controller access)
```

---

## 8. GUI Popup Server

`gui_popup_server.py` runs on the host PC and displays tkinter popup dialogs triggered by the robot script.

### Running

```bash
python3 gui_popup_server.py
```

The server listens on port `9999` and logs all popup events to `log messages/YYYY-MM-DD.txt`.

### Protocol

```
Robot → Server:  "POPUP|Title|Body text\n"
Server → Robot:  "CONTINUE\n"  or  "STOP\n"
```

The server blocks until the user clicks a button before sending the response, which in turn blocks the robot script. This enables human-in-the-loop decision making at any point in the program.

### Log Format

```
[HH:MM:SS] [CONTINUE] Title: Body text
[HH:MM:SS] [STOP] Title: Body text
```

Logs are saved to `log messages/YYYY-MM-DD.txt` next to the script file.

---

## 9. Fairino Lua Constraints

These constraints are specific to the Fairino controller's embedded Lua environment and differ from standard Lua:

| Constraint | Details |
|------------|---------|
| `pcall` not allowed | Saving a script with `pcall` produces: `pcall is not allowed in lua file` |
| `PTP(variable)` not allowed | Fairino statically resolves teaching point names at save time; variable names cause errors |
| `print` not visible by default | Output goes to the web UI console. Use `io.open()` file logging for persistent output |
| Code runs on save | Fairino executes the script during the save/check step — runtime API calls may return nil |
| `require()` caching | Modules are cached in `package.loaded`. After modifying a library file, a controller restart may be required |
| No popup/HMI API | Neither the Fairino Lua API nor the Python SDK (626 functions) provides any popup or dialog function — `popup()` in this library communicates externally via TCP |

### Key Fairino Lua API Signatures

```lua
-- Current TCP pose (6 direct return values)
local x, y, z, rx, ry, rz = GetActualTCPPose()

-- Flange pose (unaffected by TCP offset)
local fx, fy, fz, frx, fry, frz = GetActualToolFlangePose()

-- Joint angles in degrees
local j1, j2, j3, j4, j5, j6 = GetActualJointPosDegree()

-- Active tool and workobject numbers
local tool = GetActualTCPNum()
local user = GetActualWObjNum()

-- TCP offset of active tool (x, y, z, rx, ry, rz)
local tx, ty, tz, trx, try, trz = GetTCPOffset()

-- Inverse kinematics
local j1, j2, j3, j4, j5, j6 = GetInverseKin(0, x, y, z, rx, ry, rz, -1)

-- Teaching point lookup (runtime string lookup — use instead of PTP(variable))
local pt = GetRobotTeachingPoint("point_name")
-- pt[1..6] = {x, y, z, rx, ry, rz}

-- MoveL (verified parameter order)
MoveL(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
      tool, user, vel, acc, ovl, blendR, blendMode,
      ex1, ex2, ex3, ex4, search, offset_flag,
      dx, dy, dz, drx, dry, drz)

-- MoveJ (29 parameters total)
MoveJ(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
      tool, user, vel, acc, ovl,
      ex1, ex2, ex3, ex4,
      blendT, offset_flag,
      ox, oy, oz, orx, ory, orz)
```

---

## 10. Debugging

| Method | Location | How to Enable |
|--------|----------|---------------|
| `print("message")` | Fairino web UI console | Always active |
| `cambrian_log(msg)` | Robot file: `cambrian_log.txt` | `CAMBRIAN_LOG_ENABLE = true` |
| `cambrian_log_text(text)` | Cambrian server log | Always active |
| `popup(body, title)` | Host PC tkinter popup + `log messages/` | Run `gui_popup_server.py` + `POPUP_ENABLE = true` |

### File Log Path on Robot

```
/usr/local/etc/web/file/user/cambrian_log.txt
```

Accessible via the robot web UI file browser.

### Popup Debug Pattern

```lua
-- Pass any value directly — tables are auto-serialized
popup({GetActualTCPPose()},        "TCP Pose")    -- {x, y, z, rx, ry, rz}
popup({GetTCPOffset()},            "TCP Offset")
popup({GetActualJointPosDegree()}, "Joints")
popup(GetActualTCPNum(),           "Tool Number")
```

---

## 11. Uploading Files to the Robot

1. Open the Fairino robot web UI in a browser: `http://192.168.58.2` (simulator) or the physical robot IP
2. Navigate to the Lua script file manager
3. Upload `FairinoForCambrian_v4_1.lua` to:
   ```
   /usr/local/etc/controller/lua/FairinoForCambrian_v4_1.lua
   ```
4. Load it in your robot script with:
   ```lua
   package.path = package.path .. ";/usr/local/etc/controller/lua/?.lua"
   require("FairinoForCambrian_v4_1")
   ```

> **Note:** After modifying and re-uploading the library, a robot controller restart may be needed to clear the `require()` module cache.

---

## 12. Changelog

### v0.4.1 (current — `FairinoForCambrian_v4_1.lua`)
- **Fixed `Rot2Rpy` gimbal lock bug**: the `asin`-based algorithm in v0.4.0 produced a physically incorrect output pose when pitch = ±90°, with no error or warning. Replaced with `atan2 + sy` algorithm that handles the singular case correctly.
- Replaced hardcoded `π = 3.141592654` with Lua built-in `math.pi` for full double precision.

### v0.4.0 (`FairinoForCambrian_v4.lua`)
- Added full **Calibration Commands** section:
  - `cambrian_start_calibration()` — initiate auto or manual calibration
  - `cambrian_next_calibration_step()` — query next step in auto-calibration loop (step 1=move, 2=done, 3=test reachability)
  - `cambrian_capture_calibration_image()` — capture image for manual calibration
  - `cambrian_run_manual_calibration()` — trigger manual calibration after ≥8 images
  - `cambrian_set_calibration_rig_pose()` — set rig parameters without starting calibration
  - `cambrian_set_calibration_mount()` — set BASE (fixed) or FLANGE (robot-mounted) mode
  - `cambrian_run_auto_calibration()` — high-level loop helper: handles full NEXT CALIBRATION STEP loop including reachability testing via `GetInverseKin`
- Fixed `set_tcp()`: type guard condition was inverted (`type ~= "number"` → `type == "number"`)
- `_n()` safe-number helper moved to module level (was nested closure inside `get_current_robot_info`)
- `cambrian_ping()` now returns `(code, msg)` so callers can detect connection failure

### v0.3.3 (`FairinoForCambrian_v3.lua`)
- Added `popup()` function — sends TCP message to external PC GUI server, shows tkinter dialog
- Added `POPUP_SERVER_IP / PORT / ENABLE` globals — defaults to `192.168.58.1:9999`
- [Stop] button calls `error()` to terminate the script immediately; no return value check needed
- Any type (number, string, table) can be passed to `popup()` — tables auto-serialized to `{v1, v2, ...}`

### v0.3.2
- Added `set_tcp()` function — `SetToolCoord` wrapper to change active tool TCP offset
- Added Korean → English comments throughout (this release restores English)
- Renamed `cambrian_cnv_relative2world_pose` → `cambrian_pose_trans` to match UR's `pose_trans` argument order (`coordinate_pose, relative_pose`)

### v0.3.1
- Fixed `Move()` function:
  - Changed from `pt[7..12]` (uncertain joint indices) to `pt[1..6]` (Cartesian) + `GetInverseKin()`
  - Removed argument from `GetActualTCPNum()` — no argument matches engineer examples
  - Fixed MoveJ exaxis/blendT order: `-1,0,0,0,0` → `0,0,0,0,-1`

### v0.3.0
- Rewrote `get_current_robot_info()`:
  - Uses `GetActualToolFlangePose()` directly for flange pose
  - Uses `GetActualJointPosDegree()` directly for joint angles
  - Reads TCP offset automatically via `GetTCPOffset()` with manual override option
- Changed `cambrian_load_model()` to use `_noread_cmd()` (fire-and-forget — Cambrian sends no response for LOAD MODEL)
- Added nil guard in `cambrian_request()` for empty server responses
- Added non-table input guard in `_arr_str()`

### v0.2.4 and earlier
- `pcall` usage → save error (removed)
- `PTP(variable)` usage → save error (replaced with `GetRobotTeachingPoint` + `MoveJ`)
- TCP offset hardcoded as `{0,0,0,0,0,0}` (replaced with `GetTCPOffset()` auto-read)

---
## 13. Note
- Docker image maybe working on only ubuntu, I already hit the problem on windows. 
- if you want to know variable please use the function ShowPos() 
- if you want more information for this develope, please connect to Jo Won Jun using slack
- The engineer said rua script were not perfectly, so please check the SDK.
---
## Known Issues / TODO

- [ ] **`set_tcp()` not yet validated on physical robot** — `SetToolCoord` parameter order needs live verification. Test: call `set_tcp({100,0,200,0,0,0})` then confirm `GetTCPOffset()` returns `x=100, z=200`. (type-guard bug fixed in v4)
- [ ] **Full pick cycle test** — end-to-end grasp cycle with gripper I/O not yet validated.
- [ ] **`cambrian_run_auto_calibration` not yet tested on physical robot** — loop logic and `GetInverseKin` reachability check needs live verification.
- [ ] There has no `popup` command so developing for debuging with another tcp server.

