-- ====================================== --
-- Cambrian Vision API
-- (FAIRINO Edition)
-- Version  0.4.2
-- Release  2026/05/22
-- Based on v0.1.2 by Digital Media Professionals Inc.
-- Modified for Fairino Robot by Jo Won Jun, Cambrian Robotics Korea
-- ====================================== --
--
-- What's new in v0.4.2:
--   • Added inv_pose_rpy_xyz(pose) — computes the inverse homogeneous transform
--     of a pose given as {x,y,z,roll,pitch,yaw} (degrees); uses atan2+sy-based RPY
--   • Added local helpers: rpydeg_to_rotmat_xyz, mat3_transpose, mat3_vec_mul,
--     rotmat_to_rpydeg_xyz (all local, supporting inv_pose_rpy_xyz and Rot2Rpy)
--   • Translated all Korean comments to English
--
-- What's new in v0.4.1:
--   • Replaced Rot2Rpy algorithm: asin-based → atan2+sy-based
--     Fixes a bug in v0.4.0 where pitch ±90° (gimbal lock) produced an incorrect
--     output pose with no error or warning
--   • Replaced hardcoded pi constant (3.141592654) with math.pi (Lua built-in)
--
-- What's new in v0.4.0:
--   • Calibration commands: cambrian_start_calibration, cambrian_next_calibration_step,
--     cambrian_capture_calibration_image, cambrian_set_calibration_rig_pose,
--     cambrian_set_calibration_mount, cambrian_run_manual_calibration
--   • cambrian_run_auto_calibration() — high-level automatic calibration loop helper
--   • Fixed set_tcp(): type guard condition was inverted (type ~= vs ==)
--   • _n() safe-number helper is now module-level (was nested in get_current_robot_info)
--   • cambrian_ping() now returns (code, msg) for connection status checking
-- ====================================== --

-- ********* Global Parameters *********
cambrian_convert_user_num = 2
cambrian_ipname = "127.0.0.1"
cambrian_port = 4000
pred_flange_pose = {0,0,0,0,0,0}

-- TCP offset override (only needed when camera position differs from TCP).
-- Default: automatically read from GetTCPOffset().
-- Set manually via cambrian_set_state(nil, nil, {x,y,z,rx,ry,rz}) to override auto-read.
_fr_tool_offset        = {0,0,0,0,0,0}
_fr_tool_offset_manual = false  -- set to true when overridden via cambrian_set_state

-- File log path (uses io.open instead of print)
CAMBRIAN_LOG_PATH = "/usr/local/etc/web/file/user/cambrian_log.txt"
CAMBRIAN_LOG_ENABLE = false  -- set to true to enable file logging

-- External GUI popup server settings (IP/port of PC running gui_popup_server.py)
POPUP_SERVER_IP   = "192.168.58.1"  -- host PC IP (Docker bridge gateway)
POPUP_SERVER_PORT = 9999
POPUP_ENABLE      = true  -- set to true to enable popups (requires gui_popup_server.py running)

-- ======================================
-- Math Utilities
-- ======================================
FZERO = 1e-6
R2D   = 180.0/math.pi
D2R   = math.pi/180.0
local math = math
local sin  = math.sin
local cos  = math.cos
local sqrt = math.sqrt

------------------------------------------------
-- 1. RPY(deg, XYZ order) → 3×3 rotation matrix
--    R = Rz(yaw) * Ry(pitch) * Rx(roll)
------------------------------------------------
local function rpydeg_to_rotmat_xyz(roll_deg, pitch_deg, yaw_deg)
    local roll  = roll_deg  * D2R
    local pitch = pitch_deg * D2R
    local yaw   = yaw_deg   * D2R

    local cr = cos(roll)
    local sr = sin(roll)
    local cp = cos(pitch)
    local sp = sin(pitch)
    local cy = cos(yaw)
    local sy = sin(yaw)

    local R = {
        { cy*cp,              cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr },
        { sy*cp,              sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr },
        { -sp,                cp*sr,             cp*cr            }
    }

    return R
end

------------------------------------------------
-- 2. 3×3 rotation matrix transpose (= inverse, since rotation matrices are orthonormal)
------------------------------------------------
local function mat3_transpose(R)
    return {
        {R[1][1], R[2][1], R[3][1]},
        {R[1][2], R[2][2], R[3][2]},
        {R[1][3], R[2][3], R[3][3]}
    }
end

------------------------------------------------
-- 3. 3×3 matrix × 3×1 vector
------------------------------------------------
local function mat3_vec_mul(R, v)
    return {
        R[1][1]*v[1] + R[1][2]*v[2] + R[1][3]*v[3],
        R[2][1]*v[1] + R[2][2]*v[2] + R[2][3]*v[3],
        R[3][1]*v[1] + R[3][2]*v[2] + R[3][3]*v[3]
    }
end

------------------------------------------------
-- 4. Rotation matrix → RPY(deg, XYZ order)
--    R = Rz(yaw) * Ry(pitch) * Rx(roll)
--    Uses atan2+sy method: numerically stable, handles gimbal lock (pitch ±90°) correctly
------------------------------------------------
local function rotmat_to_rpydeg_xyz(R)
    local sy = sqrt(R[1][1]*R[1][1] + R[2][1]*R[2][1])
    local singular = sy < 1e-9

    local roll, pitch, yaw

    if not singular then
        roll  = math.atan2(R[3][2], R[3][3])   -- x-axis
        pitch = math.atan2(-R[3][1], sy)        -- y-axis
        yaw   = math.atan2(R[2][1], R[1][1])   -- z-axis
    else
        roll  = math.atan2(-R[2][3], R[2][2])
        pitch = math.atan2(-R[3][1], sy)
        yaw   = 0.0
    end

    return roll * R2D, pitch * R2D, yaw * R2D
end

------------------------------------------------
-- 5. pose = {x, y, z, roll_deg, pitch_deg, yaw_deg}
--    → inverse pose = {x', y', z', roll', pitch', yaw'}
--    T     = [ R  p ]     T_inv = [ R^T  -R^T*p ]
--            [ 0  1 ]             [  0      1   ]
------------------------------------------------
function inv_pose_rpy_xyz(pose)
    local x   = pose[1]
    local y   = pose[2]
    local z   = pose[3]
    local r_d = pose[4]
    local p_d = pose[5]
    local y_d = pose[6]

    local R  = rpydeg_to_rotmat_xyz(r_d, p_d, y_d)   -- original rotation matrix
    local Rt = mat3_transpose(R)                       -- inverse rotation = transpose

    local tinv = mat3_vec_mul(Rt, {-x, -y, -z})       -- inverse translation = -R^T * p
    local xi, yi, zi = tinv[1], tinv[2], tinv[3]

    local ri, pi, yi_d = rotmat_to_rpydeg_xyz(Rt)     -- extract RPY(deg) from inverse rotation matrix

    return {xi, yi, zi, ri, pi, yi_d}
end

-- Convert rotation matrix (3x3 flat array) to RPY angles (degrees)
-- Uses atan2+sy method: numerically stable, handles gimbal lock (pitch ±90°) correctly
function Rot2Rpy(Rot)
    local R = {
        {Rot[1], Rot[2], Rot[3]},
        {Rot[4], Rot[5], Rot[6]},
        {Rot[7], Rot[8], Rot[9]}
    }

    local sy = math.sqrt(R[1][1]*R[1][1] + R[2][1]*R[2][1])
    local singular = sy < 1e-9

    local roll, pitch, yaw

    if not singular then
        roll  = math.atan2(R[3][2], R[3][3])
        pitch = math.atan2(-R[3][1], sy)
        yaw   = math.atan2(R[2][1], R[1][1])
    else
        roll  = math.atan2(-R[2][3], R[2][2])
        pitch = math.atan2(-R[3][1], sy)
        yaw   = 0.0
    end

    return roll*R2D, pitch*R2D, yaw*R2D
end

-- Convert RPY angles (degrees) to rotation matrix (3x3 flat array)
function Rpy2Rot(roll, pitch, yaw)
    local r = roll *D2R
    local b = pitch*D2R
    local a = yaw  *D2R
    local ca,sa = math.cos(a), math.sin(a)
    local cb,sb = math.cos(b), math.sin(b)
    local cr,sr = math.cos(r), math.sin(r)
    return {
        ca*cb,        ca*sb*sr - sa*cr,  ca*sb*cr + sa*sr,
        sa*cb,        sa*sb*sr + ca*cr,  sa*sb*cr - ca*sr,
        -sb,          cb*sr,             cb*cr
    }
end

-- 3x3 rotation matrix multiplication (R0 × R1)
function MatMult(R0, R1)
    local Ra = {0,0,0,0,0,0,0,0,0}
    for i = 1, 3 do
        local row = (i-1)*3
        Ra[row+1] = R0[row+1]*R1[1] + R0[row+2]*R1[4] + R0[row+3]*R1[7]
        Ra[row+2] = R0[row+1]*R1[2] + R0[row+2]*R1[5] + R0[row+3]*R1[8]
        Ra[row+3] = R0[row+1]*R1[3] + R0[row+2]*R1[6] + R0[row+3]*R1[9]
    end
    return Ra
end

-- 3x3 rotation matrix × 3D vector
function MatVect(R0, V1)
    local Va = {0,0,0}
    for i = 1, 3 do
        local row = (i-1)*3
        Va[i] = R0[row+1]*V1[1] + R0[row+2]*V1[2] + R0[row+3]*V1[3]
    end
    return Va
end

-- Equivalent to UR's pose_trans(p_from, p_from_to): transforms p_from_to (relative to p_from frame) into world coordinates
-- coordinate_pose: reference frame pose (UR's p_from), relative_pose: relative pose (UR's p_from_to)
function cambrian_pose_trans(coordinate_pose, relative_pose)
    local P0 = {coordinate_pose[1], coordinate_pose[2], coordinate_pose[3]}
    local P1 = {relative_pose[1],   relative_pose[2],   relative_pose[3]}
    local R0 = Rpy2Rot(coordinate_pose[4], coordinate_pose[5], coordinate_pose[6])
    local R1 = Rpy2Rot(relative_pose[4],   relative_pose[5],   relative_pose[6])
    local bP1 = MatVect(R0, P1)
    local Pa  = {P0[1]+bP1[1], P0[2]+bP1[2], P0[3]+bP1[3]}
    local Ra  = MatMult(R0, R1)
    local rx, ry, rz = Rot2Rpy(Ra)
    return {Pa[1], Pa[2], Pa[3], rx, ry, rz}
end

-- ======================================
-- TCP Low-Level Communication
-- ======================================

-- Send string to an open socket
function TCPWrite(sock_name, send_str)
    SocketSendString(send_str, sock_name, 0)
    return 0
end

-- Receive string from an open socket
function TCPRead(sock_name)
    local rdata = SocketReadString(sock_name, 0)
    return 0, rdata
end

-- ======================================
-- Robot Motion Helpers
-- ======================================

-- Linear move (MoveL) to Cartesian position {x,y,z,rx,ry,rz}
-- dPos: {x,y,z,rx,ry,rz} (mm, degrees), tool: tool number (nil = current), speed: speed % (default 30)
function move_l(dPos, tool, speed)
    local x,y,z,rx,ry,rz = dPos[1],dPos[2],dPos[3],dPos[4],dPos[5],dPos[6]
    local j1,j2,j3,j4,j5,j6 = GetInverseKin(0, x, y, z, rx, ry, rz, -1)
    local t   = tool  or GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    MoveL(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100,-1,0,0,0,0, -1,0,0,0,0,0,0,0)
end

-- Joint move (MoveJ) to a Cartesian pose
-- dPos: {x,y,z,rx,ry,rz}, speed: speed % (default 30)
function move_j(dPos, speed)
    local x,y,z,rx,ry,rz = dPos[1],dPos[2],dPos[3],dPos[4],dPos[5],dPos[6]
    local j1,j2,j3,j4,j5,j6 = GetInverseKin(0, x,y,z,rx,ry,rz, -1)
    local t   = GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    MoveJ(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100, 0,0,0,0,-1,0, 0,0,0,0,0,0)
end

-- Set TCP coordinate frame of the active tool slot to a new offset (equivalent to UR's set_tcp)
-- pose: {x,y,z,rx,ry,rz} (mm, degrees) — verify with GetTCPOffset() after calling
-- Note: SetToolCoord parameter order should be validated on the actual robot
function set_tcp(pose)
    local slot = GetActualTCPNum()
    if type(slot) == "number" then
        SetToolCoord(slot, pose[1],pose[2],pose[3],pose[4],pose[5],pose[6], 0, 0, slot, 0)
    end
end

-- ======================================
-- Connection Configuration
-- ======================================

-- Set Cambrian server IP and port
function set_connection_info(ipname, port)
    cambrian_ipname = ipname
    cambrian_port   = port
    return ipname, port
end

-- Get current Cambrian server IP and port
function get_connection_info()
    return cambrian_ipname, cambrian_port
end

-- Set user coordinate frame number used for coordinate transforms
function set_convert_user_flame(flame_num)
    cambrian_convert_user_num = flame_num
end

-- Get current user coordinate frame number
function get_convert_user_flame()
    return cambrian_convert_user_num
end

-- ======================================
-- Core: Connect / Request / Disconnect
-- ======================================

-- Open TCP socket connection to Cambrian server. Returns: (socket_name, success)
function cambrian_connect(ipname, port)
    local socket_name = "socket_0"
    local tcp = SocketOpen(ipname, port, socket_name)
    local ok  = false
    if type(tcp) == "number" then
        if tcp > 0 then
            ok = true
        else
            print("ERROR: cambrian socket open failed")
        end
    end
    return socket_name, ok
end

-- Close socket connection
function cambrian_disconnect(socket)
    SocketClose(socket)
end

-- Write message to log file (only when CAMBRIAN_LOG_ENABLE = true)
function cambrian_log(msg)
    if not CAMBRIAN_LOG_ENABLE then return end
    local f = io.open(CAMBRIAN_LOG_PATH, "a")
    if f then f:write(msg .. "\n") f:close() end
end

-- (internal) Convert any value to a human-readable string
-- Tables are serialized as {v1, v2, ...} or {k=v, ...}
local function _val_str(v)
    if type(v) ~= "table" then return tostring(v) end
    local s = "{"
    local first = true
    if #v > 0 then
        for i = 1, #v do
            if not first then s = s .. ", " end
            s = s .. tostring(v[i])
            first = false
        end
    else
        for k, val in pairs(v) do
            if not first then s = s .. ", " end
            s = s .. tostring(k) .. "=" .. tostring(val)
            first = false
        end
    end
    return s .. "}"
end

-- Send popup request to external PC running gui_popup_server.py
-- title: popup title (default "Robot Alert"), body: any value including tables
-- Returns: true = continue, false = stop
-- When POPUP_ENABLE = false, prints to console and always returns true
function popup(body, title)
    title = title or "Robot Alert"
    local body_str = _val_str(body)
    if not POPUP_ENABLE then
        print("[POPUP] " .. title .. ": " .. body_str)
        return true
    end
    local sock = "socket_1"
    SocketClose(sock)  -- prevent connection leak from previous call
    local ok = SocketOpen(POPUP_SERVER_IP, POPUP_SERVER_PORT, sock)
    if type(ok) == "number" and ok > 0 then
        SocketSendString("POPUP|" .. title .. "|" .. body_str .. "\n", sock, 0)
        local resp = SocketReadString(sock, 0)  -- block until user clicks
        SocketClose(sock)
        local buf = ""
        if type(resp) == "table" then buf = resp.buf or ""
        elseif type(resp) == "string" then buf = resp end
        if string.find(buf, "STOP") then
            error("[STOP] " .. title)
        end
        return true
    else
        print("[POPUP server connection failed] " .. title .. ": " .. body_str)
        return true
    end
end

-- Manually set TCP offset (only needed when camera position differs from TCP)
-- Default is auto-read from GetTCPOffset(). Setting here disables auto-read.
-- Usage: cambrian_set_state(nil, nil, {x,y,z,rx,ry,rz})
function cambrian_set_state(flange_pose, joint_angles, tool_offset)
    if tool_offset ~= nil then
        _fr_tool_offset        = tool_offset
        _fr_tool_offset_manual = true
    end
end

-- (internal) Safe number conversion: returns v if it is a number, else tonumber(v) or 0
-- Needed because GetTCPOffset() can return function values on some Fairino firmware builds;
-- Lua's 'v or 0' does not catch truthy non-numbers (functions are truthy).
local function _n(v)
    return type(v) == "number" and v or (tonumber(v) or 0)
end

-- Read current robot state: flange pose, joint angles, TCP offset
-- Called automatically on each Cambrian request (no need to call directly)
function get_current_robot_info()
    local fx, fy, fz, frx, fry, frz = GetActualToolFlangePose()
    local flange_pose
    if type(fx) == "number" then
        flange_pose = {fx, fy, fz, frx, fry, frz}
    else
        cambrian_log("WARN: GetActualToolFlangePose failed")
        flange_pose = {0,0,0,0,0,0}
    end

    local j1, j2, j3, j4, j5, j6 = GetActualJointPosDegree()
    local joints
    if type(j1) == "number" then
        joints = {j1, j2, j3, j4, j5, j6}
    else
        cambrian_log("WARN: GetActualJointPosDegree failed")
        joints = {0,0,0,0,0,0}
    end

    local _t = {GetTCPOffset()}
    local tcp_off = {_n(_t[1]), _n(_t[2]), _n(_t[3]), _n(_t[4]), _n(_t[5]), _n(_t[6])}

    local tool_offset = _fr_tool_offset_manual and _fr_tool_offset or tcp_off

    return flange_pose, {joint = joints}, tool_offset
end

-- (internal) Split Cambrian reply string by << >> delimiters
function cambrian_divid_reply_msg(cambrian_reply_msg)
    local div_rep_table = {}
    local i = 1
    local begin_num, end_num = 0, 0
    repeat
        begin_num = string.find(cambrian_reply_msg, "<<", begin_num+1)
        end_num   = string.find(cambrian_reply_msg, ">>", end_num+1)
        if begin_num ~= nil and end_num ~= nil then
            div_rep_table[i] = string.sub(cambrian_reply_msg, begin_num+2, end_num-1)
            begin_num = begin_num + 2
            end_num   = end_num   + 2
            i = i + 1
        end
    until begin_num == nil or end_num == nil
    return div_rep_table
end

-- (internal) Split Cambrian data field by commas and return as array
function cambrian_divid_reply_data(cambrian_reply_data)
    local div_data_table = {}
    local i = 1
    local begin_num, end_num = 0, 0
    repeat
        begin_num = end_num + 1
        end_num   = string.find(cambrian_reply_data, ",", begin_num)
        if end_num ~= nil then
            div_data_table[i] = string.sub(cambrian_reply_data, begin_num, end_num-1)
        else
            div_data_table[i] = string.sub(cambrian_reply_data, begin_num, string.len(cambrian_reply_data))
        end
        i = i + 1
    until end_num == nil
    return div_data_table
end

-- (internal) Send command over open socket and receive response. Returns: (code, msg, data, flange_pose)
function cambrian_request(socket, cambrian_command_str)
    local flange_pose, joints, tool_offset = get_current_robot_info()
    local j = joints.joint

    local robot_data = "#[" .. flange_pose[1] .. "," .. flange_pose[2] .. "," .. flange_pose[3] .. ","
                             .. flange_pose[4] .. "," .. flange_pose[5] .. "," .. flange_pose[6] .. "]"
    robot_data = robot_data .. "#[" .. j[1] .. "," .. j[2] .. "," .. j[3] .. ","
                                    .. j[4] .. "," .. j[5] .. "," .. j[6] .. "]"
    robot_data = robot_data .. "#[" .. tool_offset[1] .. "," .. tool_offset[2] .. "," .. tool_offset[3] .. ","
                                    .. tool_offset[4] .. "," .. tool_offset[5] .. "," .. tool_offset[6] .. "]#<<"

    local request_str = cambrian_command_str .. robot_data
    local err = TCPWrite(socket, request_str)

    local reply_code = -1
    local reply_msg  = ""
    local reply_dat  = nil

    if err == 0 then
        local reply_err, reply_str = TCPRead(socket)
        if reply_err == 0 then
            local buf = nil
            if type(reply_str) == "table" then
                buf = reply_str.buf
            elseif type(reply_str) == "string" then
                buf = reply_str
            end
            if buf == nil or buf == "" then
                reply_code = 0
                reply_msg  = "sent"
            else
                local parts = cambrian_divid_reply_msg(buf)
                reply_msg  = parts[1]
                reply_code = tonumber(parts[2])
                reply_dat  = parts[3]
            end
        end
    end

    return reply_code, reply_msg, reply_dat, flange_pose
end

-- (internal) Connect → send command → receive response → disconnect
local function _cmd(req_str)
    local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
    if not ok then return -1, "connection failed", nil, nil end
    local code, msg, dat, fp = cambrian_request(sock, req_str)
    cambrian_disconnect(sock)
    if code ~= 0 and code ~= nil then
        print("CAMBRIAN: [" .. tostring(msg) .. "] cmd=" .. req_str:sub(1, 40))
    end
    return code, msg, dat, fp
end

-- (internal) Fire-and-forget command with no response (e.g. LOAD MODEL)
local function _noread_cmd(req_str)
    local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
    if not ok then return end
    local fp, joints, to = get_current_robot_info()
    local j = joints.joint
    local rd = "#[" .. fp[1] .. "," .. fp[2] .. "," .. fp[3] .. ","
                    .. fp[4] .. "," .. fp[5] .. "," .. fp[6] .. "]"
            .. "#[" .. j[1] .. "," .. j[2] .. "," .. j[3] .. ","
                    .. j[4] .. "," .. j[5] .. "," .. j[6] .. "]"
            .. "#[" .. to[1] .. "," .. to[2] .. "," .. to[3] .. ","
                    .. to[4] .. "," .. to[5] .. "," .. to[6] .. "]#<<"
    TCPWrite(sock, req_str .. rd)
    cambrian_disconnect(sock)
end

-- (internal) Convert pose table {x,y,z,rx,ry,rz} to "[x,y,z,rx,ry,rz]" string
local function _pose_str(p)
    return "[" .. p[1] .. "," .. p[2] .. "," .. p[3] .. ","
               .. p[4] .. "," .. p[5] .. "," .. p[6] .. "]"
end

-- (internal) Convert priority/ignore number array to comma-separated string (-1 means all, omitted)
local function _arr_str(arr)
    if type(arr) ~= "table" then return "" end
    local s = ""
    local first = true
    for _, v in ipairs(arr) do
        if v ~= -1 then
            if not first then s = s .. "," end
            s = s .. tostring(v)
            first = false
        end
    end
    return s
end

-- ======================================
-- Approach Helpers
-- ======================================

-- Calculate 4 approach-related poses from a grasp pose
-- pred_pose   : return value of cambrian_get_prediction (table with coordinate field)
-- grasp_offset: {x,y,z,rx,ry,rz} offset from prediction center to grasp point (mm, degrees)
-- app_offset  : approach distance (mm, along Z- axis of grasp frame)
-- preapp_offset: pre-approach distance from approach point (mm)
-- exit_offset : retreat distance from grasp point (mm)
-- Returns: grasp_pose, approach_pose, pre_approach_pose, exit_pose
function cambrian_approach(pred_pose, grasp_offset, app_offset, preapp_offset, exit_offset)
    local pred_matrix    = pred_pose.coordinate
    local grasp_matrix   = cambrian_pose_trans(pred_matrix,   grasp_offset)
    local app_matrix     = cambrian_pose_trans(grasp_matrix,  {0,0,-app_offset,    0,0,0})
    local preapp_matrix  = cambrian_pose_trans(app_matrix,    {0,0,-preapp_offset, 0,0,0})
    local exit_matrix    = cambrian_pose_trans(grasp_matrix,  {0,0,-exit_offset,   0,0,0})
    return {coordinate=grasp_matrix},
           {coordinate=app_matrix},
           {coordinate=preapp_matrix},
           {coordinate=exit_matrix}
end

-- ======================================
-- Prediction Request Functions
-- ======================================

-- Request the single highest-priority grasp prediction
-- Returns: got_prediction (1=success, -1=failure), pred_pose ({coordinate={x,y,z,rx,ry,rz}}), grasp_type
-- priority_num_array: list of preferred grasp types (empty = {}), ignore_num_array: list of ignored types
-- sort_code: sort criterion (0 = default)
function cambrian_get_prediction(model_name, priority_num_array, ignore_num_array, sort_code)
    local got_prediction = -1
    local pred_pose
    local grasp_type = -1

    local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
    if not ok then return got_prediction, pred_pose, grasp_type end

    local req = "GET PREDICTION#" .. model_name .. "*"
              .. _arr_str(priority_num_array) .. "*"
              .. _arr_str(ignore_num_array)   .. "*"
              .. tostring(sort_code)

    local code, msg, dat, fp = cambrian_request(sock, req)
    cambrian_disconnect(sock)

    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        got_prediction = tonumber(d[1])
        pred_flange_pose = fp
        local world = cambrian_pose_trans(
            fp,
            {tonumber(d[2]),tonumber(d[3]),tonumber(d[4]),tonumber(d[5]),tonumber(d[6]),tonumber(d[7])})
        pred_pose  = {coordinate = world}
        grasp_type = tonumber(d[8])
    else
        print("ERROR: get prediction -> " .. tostring(msg))
    end

    return got_prediction, pred_pose, grasp_type
end

-- Request a single prediction without reachability test
-- Return format is identical to cambrian_get_prediction
function cambrian_get_prediction_notest(model_name, priority_num_array, ignore_num_array, sort_code)
    local got_prediction = -1
    local pred_pose
    local grasp_type = -1

    local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
    if not ok then return got_prediction, pred_pose, grasp_type end

    local req = "GET PREDICTION NO TEST#" .. model_name .. "*"
              .. _arr_str(priority_num_array) .. "*"
              .. _arr_str(ignore_num_array)   .. "*"
              .. tostring(sort_code)

    local code, msg, dat, fp = cambrian_request(sock, req)
    cambrian_disconnect(sock)

    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        got_prediction = tonumber(d[1])
        pred_flange_pose = fp
        local world = cambrian_pose_trans(
            fp,
            {tonumber(d[2]),tonumber(d[3]),tonumber(d[4]),tonumber(d[5]),tonumber(d[6]),tonumber(d[7])})
        pred_pose  = {coordinate = world}
        grasp_type = tonumber(d[8])
    else
        print("ERROR: get prediction no test -> " .. tostring(msg))
    end

    return got_prediction, pred_pose, grasp_type
end

-- Request list of all detected grasp predictions
-- Returns: got_prediction (total count), pred_pose_array (pose array), pred_type_array (type array)
function cambrian_get_all_predictions(model_name, priority_num_array, ignore_num_array, sort_code)
    local got_prediction = -1
    local pred_pose_array = {}
    local pred_type_array = {}

    local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
    if not ok then return got_prediction, pred_pose_array, pred_type_array end

    local req = "GET ALL PREDICTIONS#" .. model_name .. "*"
              .. _arr_str(priority_num_array) .. "*"
              .. _arr_str(ignore_num_array)   .. "*"
              .. tostring(sort_code)

    local code, msg, dat, fp = cambrian_request(sock, req)
    cambrian_disconnect(sock)

    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        got_prediction = tonumber(d[1])
        pred_flange_pose = fp
        for i = 1, got_prediction do
            local base = 1 + 8*(i-1)
            local world = cambrian_pose_trans(
                fp,
                {tonumber(d[base+1]),tonumber(d[base+2]),tonumber(d[base+3]),
                 tonumber(d[base+4]),tonumber(d[base+5]),tonumber(d[base+6])})
            pred_pose_array[i] = {coordinate = world}
            pred_type_array[i] = tonumber(d[base+7])
        end
    else
        print("ERROR: get all predictions -> " .. tostring(msg))
    end

    return got_prediction, pred_pose_array, pred_type_array
end

-- Request all predictions without reachability test
-- Return format is identical to cambrian_get_all_predictions
function cambrian_get_all_predictions_notest(model_name, priority_num_array, ignore_num_array, sort_code)
    local got_prediction = -1
    local pred_pose_array = {}
    local pred_type_array = {}

    local sock, ok = cambrian_connect(cambrian_ipname, cambrian_port)
    if not ok then return got_prediction, pred_pose_array, pred_type_array end

    local req = "GET ALL PREDICTIONS NO TEST#" .. model_name .. "*"
              .. _arr_str(priority_num_array) .. "*"
              .. _arr_str(ignore_num_array)   .. "*"
              .. tostring(sort_code)

    local code, msg, dat, fp = cambrian_request(sock, req)
    cambrian_disconnect(sock)

    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        got_prediction = tonumber(d[1])
        pred_flange_pose = fp
        for i = 1, got_prediction do
            local base = 1 + 8*(i-1)
            local world = cambrian_pose_trans(
                fp,
                {tonumber(d[base+1]),tonumber(d[base+2]),tonumber(d[base+3]),
                 tonumber(d[base+4]),tonumber(d[base+5]),tonumber(d[base+6])})
            pred_pose_array[i] = {coordinate = world}
            pred_type_array[i] = tonumber(d[base+7])
        end
    else
        print("ERROR: get all predictions no test -> " .. tostring(msg))
    end

    return got_prediction, pred_pose_array, pred_type_array
end

-- Return next prediction from stored list (use after cambrian_get_all_predictions)
-- Returns: got_prediction, pred_pose, grasp_type
function cambrian_next_prediction()
    local got_prediction = -1
    local pred_pose
    local grasp_type = -1

    local code, msg, dat, fp = _cmd("GET NEXT PREDICTION#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        got_prediction = tonumber(d[1])
        local world = cambrian_pose_trans(
            pred_flange_pose,
            {tonumber(d[2]),tonumber(d[3]),tonumber(d[4]),tonumber(d[5]),tonumber(d[6]),tonumber(d[7])})
        pred_pose  = {coordinate = world}
        grasp_type = tonumber(d[8])
    end
    return got_prediction, pred_pose, grasp_type
end

-- Get rig (fixture) pose. Returns: {coordinate={x,y,z,rx,ry,rz}} or nil
function cambrian_get_rig_pose()
    local code, msg, dat = _cmd("GET RIG POSE#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local m = {tonumber(d[1]),tonumber(d[2]),tonumber(d[3]),
                   tonumber(d[4]),tonumber(d[5]),tonumber(d[6])}
        return {coordinate = m}
    end
    return nil
end

-- Get remaining part pose. Returns: {coordinate={x,y,z,rx,ry,rz}} or nil
function cambrian_get_left_pose()
    local code, msg, dat = _cmd("GET LEFT POSE#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local m = {tonumber(d[1]),tonumber(d[2]),tonumber(d[3]),
                   tonumber(d[4]),tonumber(d[5]),tonumber(d[6])}
        return {coordinate = m}
    end
    return nil
end

-- Get search Z-axis pose. Returns: (valid (1=valid), {coordinate=...}) or (valid, nil)
function cambrian_get_search_z()
    local code, msg, dat = _cmd("GET SEARCH Z#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local valid = tonumber(d[1])
        if valid == 1 then
            local m = {tonumber(d[2]),tonumber(d[3]),tonumber(d[4]),
                       tonumber(d[5]),tonumber(d[6]),tonumber(d[7])}
            return valid, {coordinate = m}
        end
        return valid, nil
    end
    return -1, nil
end

-- ======================================
-- Model Management
-- ======================================

-- Load model (async — no server response; use cambrian_wait_for_model_launch to wait for completion)
function cambrian_load_model(model_name)
    _noread_cmd("LOAD MODEL#" .. model_name)
end

-- Load model from full path (async)
function cambrian_load_model_from_path(full_path)
    _noread_cmd("LOAD MODEL FROM PATH#" .. full_path)
end

-- Unload specific model
function cambrian_unload_model(model_name)
    _cmd("UNLOAD MODEL#" .. model_name)
end

-- Unload all loaded models
function cambrian_unload_all_models()
    _cmd("UNLOAD ALL MODELS#")
end

-- Check if model is ready. Returns: 1=ready, 0=loading, -1=error
function cambrian_check_model_ready(model_name)
    local code, msg, dat = _cmd("CHECK MODEL READY#" .. model_name)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Block until model loading completes (use immediately after cambrian_load_model)
function cambrian_wait_for_model_launch(model_name)
    _cmd("WAIT FOR MODEL LAUNCH#" .. model_name)
end

-- Set prediction confidence threshold for a model (0.0–1.0)
function cambrian_set_model_confidence(model_name, confidence)
    _cmd("SET MODEL CONFIDENCE#" .. model_name .. "*" .. tostring(confidence))
end

-- Enable/disable model recenter crop
function cambrian_set_model_recenter_crop(model_name, recenter_crop)
    _cmd("SET MODEL RECENTER CROP#" .. model_name .. "*" .. tostring(recenter_crop))
end

-- Set edge trim region to exclude from images (0.0–0.4; 0.1 = trim 10% from each side)
function cambrian_set_edge_trim(model_name, edge_trim)
    _cmd("SET EDGE TRIM#" .. model_name .. "*" .. tostring(edge_trim))
end

-- ======================================
-- Prediction Info Queries
-- ======================================

-- Get cumulative grasp count
function cambrian_get_grasp_count()
    local code, msg, dat = _cmd("GET GRASP COUNT#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Get current detected part count (Full Pose models only)
function cambrian_get_part_count()
    local code, msg, dat = _cmd("GET PART COUNT#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Check if parts are too close to the camera (1 = too close)
function cambrian_get_too_close()
    local code, msg, dat = _cmd("TOO CLOSE#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Check if parts are too far from the camera (1 = too far)
function cambrian_get_too_far()
    local code, msg, dat = _cmd("TOO FAR#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- ======================================
-- Prediction Averaging
-- ======================================

-- Start collecting prediction average
-- threshold: max distance (mm) for a prediction to be included
-- space: "BASE" (world-stationary parts) or "FLANGE" (flange-stationary parts), optional
function cambrian_start_prediction_average(threshold, space)
    local req = "START PREDICTION AVERAGE#" .. tostring(threshold or 10)
    if space ~= nil then
        req = req .. "*" .. space
    end
    _cmd(req)
end

-- Stop collecting and return averaged pose. Returns: (valid (1=valid), {coordinate=...})
function cambrian_end_prediction_average()
    local code, msg, dat = _cmd("END PREDICTION AVERAGE#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local valid = tonumber(d[1])
        if valid == 1 then
            local m = {tonumber(d[2]),tonumber(d[3]),tonumber(d[4]),
                       tonumber(d[5]),tonumber(d[6]),tonumber(d[7])}
            return valid, {coordinate = m}
        end
        return valid, nil
    end
    return -1, nil
end

-- ======================================
-- System Commands
-- ======================================

-- Check server connection (ping). Returns: (code, msg) — code=0 means OK
function cambrian_ping()
    local code, msg = _cmd("PING#")
    return code, msg
end

-- Get Cambrian server version. Returns: (major, minor, patch)
function cambrian_get_version()
    local code, msg, dat = _cmd("GET VERSION#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1]), tonumber(d[2]), tonumber(d[3])
    end
    return -1, -1, -1
end

-- Start new session (reset statistics and training data)
function cambrian_start_session()
    _cmd("START SESSION#")
end

-- Clear server internal memory (reset smart search state)
function cambrian_clear_memory()
    _cmd("CLEAR MEMORY#")
end

-- Set prediction coordinate space. space: "BASE" (world) or "FLANGE" (flange-relative)
function cambrian_set_prediction_space(space)
    _cmd("SET PREDICTION SPACE#" .. space)
end

-- Write text to server log file (for debugging)
function cambrian_log_text(text)
    _cmd("LOG TEXT#" .. text)
end

-- Report pick result. pick_result: 1=success, 0=failure. prediction_id is optional (nil allowed)
function cambrian_report_pick_result(pick_result, prediction_id)
    local req = "REPORT PICK RESULT#"
    if prediction_id ~= nil then
        req = req .. tostring(prediction_id) .. "*"
    end
    req = req .. tostring(pick_result)
    _cmd(req)
end

-- Smart random search: return next search pose using random algorithm
-- Returns: (valid (1=valid), {coordinate=...})
function cambrian_smart_search_random()
    local code, msg, dat = _cmd("SMART SEARCH RANDOM#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local valid = tonumber(d[1])
        if valid == 1 then
            local m = {tonumber(d[2]),tonumber(d[3]),tonumber(d[4]),
                       tonumber(d[5]),tonumber(d[6]),tonumber(d[7])}
            return valid, {coordinate = m}
        end
        return valid, nil
    end
    return -1, nil
end

-- ======================================
-- Calibration Commands
-- ======================================

-- Set rig parameters before starting calibration.
-- rig_pose: {x,y,z,rx,ry,rz} — approximate camera rig pose relative to robot flange (mm, degrees)
-- focal_length: focal length in mm (standard rig = 8)
-- stereo_separation: stereo separation in meters (optional; standard = 0.08)
-- camera_tilt: camera tilt in degrees (optional; standard = 5)
function cambrian_set_calibration_rig_pose(rig_pose, focal_length, stereo_separation, camera_tilt)
    rig_pose          = rig_pose         or {0,0,0,0,0,0}
    focal_length      = focal_length     or 8
    stereo_separation = stereo_separation or 0.08
    camera_tilt       = camera_tilt      or 5
    local req = "SET CALIBRATION RIG POSE#" .. _pose_str(rig_pose) .. "*" .. tostring(focal_length)
              .. "*" .. tostring(stereo_separation) .. "*" .. tostring(camera_tilt)
    _cmd(req)
end

-- Initiate a new calibration (both automatic and manual).
-- For automatic calibration: rig_pose should be a rough approximation of rig pose relative to flange.
-- For manual calibration: rig_pose can be {0,0,0,0,0,0}.
-- Defaults (standard rig): rig_pose={0,0,0,0,0,0}, focal_length=8, stereo_separation=0.08, camera_tilt=5
-- Small rig:                focal_length=8, stereo_separation=0.06, camera_tilt=8
function cambrian_start_calibration(rig_pose, focal_length, stereo_separation, camera_tilt)
    rig_pose          = rig_pose         or {0,0,0,0,0,0}
    focal_length      = focal_length     or 8
    stereo_separation = stereo_separation or 0.08
    camera_tilt       = camera_tilt      or 5
    local req = "START CALIBRATION#" .. _pose_str(rig_pose) .. "*" .. tostring(focal_length)
              .. "*" .. tostring(stereo_separation) .. "*" .. tostring(camera_tilt)
    _cmd(req)
end

-- Query the next calibration step. Only valid after cambrian_start_calibration().
-- reply_data: optional string to pass back when previous step was 3:
--             "1" = pose is reachable, "2" = pose is not reachable
-- Returns: (step, x, y, z, a, b, g)
--   step=1 → move robot to {x,y,z,a,b,g}, then call again
--   step=2 → calibration finished
--   step=3 → test reachability of {x,y,z,a,b,g}, pass result in next call via reply_data
--   step=-1 → error
function cambrian_next_calibration_step(reply_data)
    local req = "NEXT CALIBRATION STEP#"
    if reply_data ~= nil and reply_data ~= "" then
        req = req .. reply_data
    end
    local code, msg, dat = _cmd(req)
    if code == 0 and dat ~= nil then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1]),
               tonumber(d[2]), tonumber(d[3]), tonumber(d[4]),
               tonumber(d[5]), tonumber(d[6]), tonumber(d[7])
    end
    return -1, 0, 0, 0, 0, 0, 0
end

-- Capture one image for manual calibration.
-- Must be called after cambrian_start_calibration(). Requires at least 8 captures
-- from different positions before calling cambrian_run_manual_calibration().
function cambrian_capture_calibration_image()
    _cmd("CAPTURE CALIBRATION IMAGE#")
end

-- Set calibration mount mode.
-- space: "BASE" = fixed-mounted camera, "FLANGE" = robot-mounted camera
function cambrian_set_calibration_mount(space)
    _cmd("SET CALIBRATION MOUNT#" .. space)
end

-- Begin manual calibration procedure.
-- Requires at least 8 images captured via cambrian_capture_calibration_image() first.
function cambrian_run_manual_calibration()
    _cmd("RUN MANUAL CALIBRATION#")
end

-- High-level automatic calibration loop.
-- Handles the full NEXT CALIBRATION STEP loop including reachability testing.
--
-- Parameters:
--   rig_pose: {x,y,z,rx,ry,rz} — approximate rig pose relative to flange (mm, degrees)
--   focal_length: mm (standard rig: 8)
--   stereo_separation: meters (standard: 0.08), nil to omit
--   camera_tilt: degrees (standard: 5), nil to omit
--   move_fn: function(x, y, z, a, b, g) — called to move robot to each calibration pose.
--            Must block until the motion is complete (e.g. use Go() or MoveJ inside).
--            Pass nil to skip motion (for testing only).
--
-- Returns: true = calibration finished successfully, false = error
--
-- Example:
--   local rig = {0, 0, 200, 0, 0, 0}
--   cambrian_run_auto_calibration(rig, 8, 0.08, 5, function(x,y,z,a,b,g)
--       Go({x,y,z,a,b,g}, nil, 20)
--   end)
function cambrian_run_auto_calibration(rig_pose, focal_length, stereo_separation, camera_tilt, move_fn)
    cambrian_start_calibration(rig_pose, focal_length, stereo_separation, camera_tilt)
    local reply_data = ""
    while true do
        local step, x, y, z, a, b, g = cambrian_next_calibration_step(reply_data)
        reply_data = ""
        if step == 1 then
            if move_fn then move_fn(x, y, z, a, b, g) end
        elseif step == 2 then
            return true
        elseif step == 3 then
            local j1 = GetInverseKin(0, x, y, z, a, b, g, -1)
            reply_data = (type(j1) == "number") and "1" or "2"
        else
            print("CAMBRIAN CALIBRATION: unexpected step=" .. tostring(step))
            return false
        end
    end
end

-- ======================================
-- Camera Commands
-- ======================================

-- Set cameras to auto exposure mode
function cambrian_cameras_auto()
    _cmd("CAMERAS AUTO#")
end

-- Set cameras to manual exposure mode
function cambrian_cameras_manual()
    _cmd("CAMERAS MANUAL#")
end

-- Set auto exposure parameters
-- target: target brightness (5–255), tolerance: allowed deviation (1–250)
-- max_iterations: max algorithm iterations (1–10), max_exposure: max exposure value
function cambrian_cameras_auto_params(target, tolerance, max_iterations, max_exposure)
    _cmd("CAMERAS AUTO PARAMS#" .. tostring(target) .. "*"
         .. tostring(tolerance) .. "*"
         .. tostring(max_iterations) .. "*"
         .. tostring(max_exposure))
end

-- Set camera exposure directly (manual mode only)
function cambrian_cameras_exposure(exposure)
    _cmd("CAMERAS EXPOSURE#" .. tostring(exposure))
end

-- Set camera gain (higher = brighter but more noise; send 999 for maximum)
function cambrian_cameras_gain(gain)
    _cmd("CAMERAS GAIN#" .. tostring(gain))
end

-- Check camera connection status. Returns: 1=OK, 0=no cameras, -1=error
function cambrian_check_cameras()
    local code, msg, dat = _cmd("CHECK CAMERAS#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Restart the camera server and reconnect
function cambrian_restart_cameras()
    _cmd("RESTART CAMERAS#")
end

-- Block until camera connection is established (errors on timeout)
function cambrian_wait_cameras()
    _cmd("WAIT CAMERAS#")
end

-- Get current camera exposure mode. Returns: 1=auto, 0=manual
function cambrian_get_camera_auto()
    local code, msg, dat = _cmd("GET CAMERA AUTO#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Get current auto exposure parameters. Returns: (target, tolerance, max_iterations, max_exposure)
function cambrian_get_camera_auto_params()
    local code, msg, dat = _cmd("GET CAMERA AUTO PARAMS#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1]), tonumber(d[2]), tonumber(d[3]), tonumber(d[4])
    end
    return -1, -1, -1, -1
end

-- Get current camera exposure value
function cambrian_get_camera_exposure()
    local code, msg, dat = _cmd("GET CAMERA EXPOSURE#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Get current camera gain value
function cambrian_get_camera_gain()
    local code, msg, dat = _cmd("GET CAMERA GAIN#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- ======================================
-- Collision / Box Commands
-- ======================================

-- Clear all registered collision elements (environment + flange boxes)
function cambrian_clear_collision_elements()
    _cmd("CLEAR COLLISION ELEMENTS#")
end

-- Clear all registered block volumes
function cambrian_clear_block_volumes()
    _cmd("CLEAR BLOCK VOLUMES#")
end

-- Set a spherical block volume around a pose (in Robot Base space)
-- pose: {x,y,z,rx,ry,rz}, radius: radius (meters), iterations: prediction cycles to maintain
function cambrian_block_volume(pose, radius, iterations)
    local req = "BLOCK VOLUME#" .. _pose_str(pose) .. "*"
              .. tostring(radius) .. "*" .. tostring(iterations)
    _cmd(req)
end

-- Set gripper collision box (flange-attached). Dimensions in mm — converted to meters internally.
-- box_name: box name, center_matrix: {x,y,z,rx,ry,rz} relative to flange, x/y/z_size: mm
function cambrian_set_gripper_box(box_name, center_matrix, x_size, y_size, z_size)
    local req = "SET GRIPPER BOX#" .. box_name
              .. "*" .. _pose_str(center_matrix)
              .. "*" .. tostring(x_size/1000) .. "," .. tostring(y_size/1000) .. "," .. tostring(z_size/1000)
    _cmd(req)
end

-- Set workspace environment box. Dimensions in mm — converted to meters internally.
-- wall_thick=0: solid box (center of cuboid); wall_thick>0: concave box (center of floor)
function cambrian_set_box(box_name, center_matrix, x_size, y_size, z_size, wall_thick)
    local req = "SET BOX#" .. box_name
              .. "*" .. _pose_str(center_matrix)
              .. "*" .. tostring(x_size/1000) .. "," .. tostring(y_size/1000) .. "," .. tostring(z_size/1000)
              .. "*" .. tostring(wall_thick/1000)
    _cmd(req)
end

-- Define box from 3 corner points (p1,p2,p3 must be clockwise from above). Dimensions in mm.
function cambrian_3_point_box(box_name, p1, p2, p3, depth, wall_thick)
    local req = "3 POINT BOX#" .. box_name
              .. "*" .. _pose_str(p1)
              .. "*" .. _pose_str(p2)
              .. "*" .. _pose_str(p3)
              .. "*" .. tostring(depth/1000)
              .. "*" .. tostring(wall_thick/1000)
    _cmd(req)
end

-- Define box from 4 corner points (p4 on box floor). Dimensions in mm.
function cambrian_4_point_box(box_name, p1, p2, p3, p4, wall_thick)
    local req = "4 POINT BOX#" .. box_name
              .. "*" .. _pose_str(p1)
              .. "*" .. _pose_str(p2)
              .. "*" .. _pose_str(p3)
              .. "*" .. _pose_str(p4)
              .. "*" .. tostring(wall_thick/1000)
    _cmd(req)
end

-- Test rig collision boxes against environment boxes for a given pose. Returns: 0=safe, 1=collision
function cambrian_test_pose(test_pose)
    local code, msg, dat = _cmd("TEST POSE#" .. _pose_str(test_pose))
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local raw = tonumber(d[1])
        return raw == 1 and 0 or 1  -- API returns 1=safe; we return 0=safe
    end
    return -1
end

-- Test collision including robot body using joint angles. Returns: 1=collision, 0=safe
-- joints: {j1,j2,j3,j4,j5,j6} in degrees
function cambrian_test_pose_withbody(joints)
    local req = "TEST POSE WITHBODY#"
              .. tostring(joints[1]) .. "," .. tostring(joints[2]) .. ","
              .. tostring(joints[3]) .. "," .. tostring(joints[4]) .. ","
              .. tostring(joints[5]) .. "," .. tostring(joints[6])
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Check robot body collision status. Returns: 1=valid body for collision detection, 0=not valid
function cambrian_check_body()
    local code, msg, dat = _cmd("CHECK BODY#")
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- ======================================
-- Workspace Component Commands
-- ======================================

-- Spawn CAD component in world coordinate frame
function cambrian_spawn_component_world(cad_name, name, pose)
    _cmd("SPAWN COMPONENT WORLD#" .. cad_name .. "*" .. name .. "*" .. _pose_str(pose))
end

-- Spawn CAD component in flange coordinate frame
function cambrian_spawn_component_flange(cad_name, name, pose)
    _cmd("SPAWN COMPONENT FLANGE#" .. cad_name .. "*" .. name .. "*" .. _pose_str(pose))
end

-- Update component pose in world coordinate frame
function cambrian_set_component_world_pose(box_name, pose)
    _cmd("SET COMPONENT WORLD POSE#" .. box_name .. "*" .. _pose_str(pose))
end

-- Update component pose in flange coordinate frame
function cambrian_set_component_flange_pose(box_name, pose)
    _cmd("SET COMPONENT FLANGE POSE#" .. box_name .. "*" .. _pose_str(pose))
end

-- Destroy world-frame component
function cambrian_destroy_component_world(box_name)
    _cmd("DESTROY COMPONENT WORLD#" .. box_name)
end

-- Destroy flange-frame component
function cambrian_destroy_component_flange(box_name)
    _cmd("DESTROY COMPONENT FLANGE#" .. box_name)
end

-- ======================================
-- Search Grid Commands
-- ======================================

-- Destroy all search grids
function cambrian_search_grid_destroy_all()
    _cmd("SEARCH GRID DESTROY ALL#")
end

-- Destroy a specific search grid
function cambrian_search_grid_destroy(grid_name)
    _cmd("SEARCH GRID DESTROY#" .. grid_name)
end

-- Check if search grid is initialized. Returns: 1=initialized, 0=not found
function cambrian_search_grid_check_init(grid_name)
    local code, msg, dat = _cmd("SEARCH GRID CHECK INIT#" .. grid_name)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Check if search grid is complete. Returns: 1=all cells at max depth, 0=incomplete
-- grid_name is optional (nil for single-grid setups)
function cambrian_search_grid_finished(grid_name)
    local req = "SEARCH GRID FINISHED#"
    if grid_name ~= nil then req = req .. grid_name end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Get next search cell pose. Returns: (pose, cell_x, cell_y)
-- grid_name is optional
function cambrian_search_grid_get_next(grid_name)
    local req = "SEARCH GRID GET NEXT#"
    if grid_name ~= nil then req = req .. grid_name end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local m = {tonumber(d[1]),tonumber(d[2]),tonumber(d[3]),
                   tonumber(d[4]),tonumber(d[5]),tonumber(d[6])}
        return {coordinate=m}, tonumber(d[7]), tonumber(d[8])
    end
    return nil, -1, -1
end

-- Get pose for a specific cell. Returns: (pose, cell_x, cell_y)
-- Usage: cambrian_search_grid_get_cell(cell_x, cell_y) or
--        cambrian_search_grid_get_cell(grid_name, cell_x, cell_y)
function cambrian_search_grid_get_cell(...)
    local arg1, arg2, arg3 = ...
    local req = "SEARCH GRID GET CELL#"
    if arg3 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2) .. "*" .. tostring(arg3)
    else
        req = req .. tostring(arg1) .. "*" .. tostring(arg2)
    end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        local m = {tonumber(d[1]),tonumber(d[2]),tonumber(d[3]),
                   tonumber(d[4]),tonumber(d[5]),tonumber(d[6])}
        return {coordinate=m}, tonumber(d[7]), tonumber(d[8])
    end
    return nil, -1, -1
end

-- Update search grid state (mark current cell as visited — call after every GET PREDICTION)
-- grid_name is optional
function cambrian_search_grid_update(grid_name)
    local req = "SEARCH GRID UPDATE#"
    if grid_name ~= nil then req = req .. grid_name end
    _cmd(req)
end

-- Reset search grid (restart from beginning)
-- grid_name is optional
function cambrian_search_grid_reset(grid_name)
    local req = "SEARCH GRID RESET#"
    if grid_name ~= nil then req = req .. grid_name end
    _cmd(req)
end

-- Add a specific cell to the ignore list (ignored cells are never visited)
-- Usage: cambrian_search_grid_ignore(cell_x, cell_y) or
--        cambrian_search_grid_ignore(grid_name, cell_x, cell_y)
function cambrian_search_grid_ignore(...)
    local arg1, arg2, arg3 = ...
    local req = "SEARCH GRID IGNORE#"
    if arg3 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2) .. "*" .. tostring(arg3)
    else
        req = req .. tostring(arg1) .. "*" .. tostring(arg2)
    end
    _cmd(req)
end

-- Block a specific cell for a given number of prediction cycles
-- Usage: cambrian_search_grid_block(cell_x, cell_y, iterations) or
--        cambrian_search_grid_block(grid_name, cell_x, cell_y, iterations)
function cambrian_search_grid_block(...)
    local arg1, arg2, arg3, arg4 = ...
    local req = "SEARCH GRID BLOCK#"
    if arg4 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2) .. "*" .. tostring(arg3) .. "*" .. tostring(arg4)
    else
        req = req .. tostring(arg1) .. "*" .. tostring(arg2) .. "*" .. tostring(arg3)
    end
    _cmd(req)
end

-- Report cell pick result. Returns: (successive_bad_visits, total_bad_visits)
-- Usage: cambrian_search_grid_report(cell_x, cell_y, result) or
--        cambrian_search_grid_report(grid_name, cell_x, cell_y, result)
function cambrian_search_grid_report(...)
    local arg1, arg2, arg3, arg4 = ...
    local req = "SEARCH GRID REPORT#"
    if arg4 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2) .. "*" .. tostring(arg3) .. "*" .. tostring(arg4)
    else
        req = req .. tostring(arg1) .. "*" .. tostring(arg2) .. "*" .. tostring(arg3)
    end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1]), tonumber(d[2])
    end
    return -1, -1
end

-- Initialize search grid (dimensions in mm)
-- Usage (no name): cambrian_search_grid_init(grid_pose, x_cells, y_cells, max_z, cell_x, cell_y, z_step)
-- Usage (with name): cambrian_search_grid_init(grid_name, grid_pose, x_cells, y_cells, max_z, cell_x, cell_y, z_step)
function cambrian_search_grid_init(...)
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 = ...
    local req = "SEARCH GRID INIT#"
    if arg8 ~= nil then
        req = req .. arg1 .. "*" .. _pose_str(arg2)
              .. "*" .. tostring(arg3) .. "*" .. tostring(arg4) .. "*" .. tostring(arg5)
              .. "*" .. tostring(arg6) .. "*" .. tostring(arg7) .. "*" .. tostring(arg8)
    else
        req = req .. _pose_str(arg1)
              .. "*" .. tostring(arg2) .. "*" .. tostring(arg3) .. "*" .. tostring(arg4)
              .. "*" .. tostring(arg5) .. "*" .. tostring(arg6) .. "*" .. tostring(arg7)
    end
    _cmd(req)
end

-- Auto-initialize search grid from box and model info. Returns: (num_x_cells, num_y_cells)
-- rotate_grid: 0–3 (optional), fov_scaling_factor: FOV scale (optional), fov_overlap_ratios: {x,y} (optional)
function cambrian_search_grid_auto_init(grid_name, box_name, model_name, rotate_grid, fov_scaling_factor, fov_overlap_ratios)
    local req = "SEARCH GRID AUTO INIT#" .. grid_name .. "*" .. box_name .. "*" .. model_name
    if rotate_grid ~= nil then
        req = req .. "*" .. tostring(rotate_grid)
        if fov_scaling_factor ~= nil then
            req = req .. "*" .. tostring(fov_scaling_factor)
            if fov_overlap_ratios ~= nil then
                req = req .. "*" .. fov_overlap_ratios[1] .. "," .. fov_overlap_ratios[2]
            end
        end
    end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1]), tonumber(d[2])
    end
    return -1, -1
end

-- Get grid fill level (1.0=initial/full, 0.0=fully explored)
-- grid_name is optional
function cambrian_search_grid_level(grid_name)
    local req = "SEARCH GRID LEVEL#"
    if grid_name ~= nil then req = req .. grid_name end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Get grid cell count. Returns: (num_x_cells, num_y_cells)
-- grid_name is optional
function cambrian_search_grid_dimensions(grid_name)
    local req = "SEARCH GRID DIMENSIONS#"
    if grid_name ~= nil then req = req .. grid_name end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1]), tonumber(d[2])
    end
    return -1, -1
end

-- Get fill level of a specific cell. Returns: float (0=empty, 1=initial)
-- Usage: cambrian_search_grid_get_cell_level(cell_x, cell_y) or
--        cambrian_search_grid_get_cell_level(grid_name, cell_x, cell_y)
function cambrian_search_grid_get_cell_level(...)
    local arg1, arg2, arg3 = ...
    local req = "SEARCH GRID GET CELL LEVEL#"
    if arg3 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2) .. "*" .. tostring(arg3)
    else
        req = req .. tostring(arg1) .. "*" .. tostring(arg2)
    end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return tonumber(d[1])
    end
    return -1
end

-- Set fill level of a specific cell (1=reset to initial; range: 0 to infinity)
-- Usage: cambrian_search_grid_set_cell_level(cell_x, cell_y, level) or
--        cambrian_search_grid_set_cell_level(grid_name, cell_x, cell_y, level)
function cambrian_search_grid_set_cell_level(...)
    local arg1, arg2, arg3, arg4 = ...
    local req = "SEARCH GRID SET CELL LEVEL#"
    if arg4 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2) .. "*" .. tostring(arg3) .. "*" .. tostring(arg4)
    else
        req = req .. tostring(arg1) .. "*" .. tostring(arg2) .. "*" .. tostring(arg3)
    end
    _cmd(req)
end

-- Set fill level for all cells at once (1=reset all to initial; range: 0 to infinity)
-- Usage: cambrian_search_grid_set_level(level) or
--        cambrian_search_grid_set_level(grid_name, level)
function cambrian_search_grid_set_level(...)
    local arg1, arg2 = ...
    local req = "SEARCH GRID SET LEVEL#"
    if arg2 ~= nil then
        req = req .. arg1 .. "*" .. tostring(arg2)
    else
        req = req .. tostring(arg1)
    end
    _cmd(req)
end

-- Set search grid cell scoring weights
-- weights: {cell_height, center_dist, prev_visit_dist, pred_count, time_since_visit, randomness} — 6 floats
-- Usage: cambrian_search_grid_set_weights(weights) or
--        cambrian_search_grid_set_weights(grid_name, weights)
function cambrian_search_grid_set_weights(...)
    local arg1, arg2 = ...
    local req = "SEARCH GRID SET WEIGHTS#"
    local w
    if arg2 ~= nil then
        req = req .. arg1 .. "*"
        w = arg2
    else
        w = arg1
    end
    req = req .. w[1] .. "," .. w[2] .. "," .. w[3] .. ","
              .. w[4] .. "," .. w[5] .. "," .. w[6]
    _cmd(req)
end

-- Get current search grid weights. Returns: {w1,w2,w3,w4,w5,w6} or nil
-- grid_name is optional
function cambrian_search_grid_get_weights(grid_name)
    local req = "SEARCH GRID GET WEIGHTS#"
    if grid_name ~= nil then req = req .. grid_name end
    local code, msg, dat = _cmd(req)
    if code == 0 then
        local d = cambrian_divid_reply_data(dat)
        return {tonumber(d[1]),tonumber(d[2]),tonumber(d[3]),
                tonumber(d[4]),tonumber(d[5]),tonumber(d[6])}
    end
    return nil
end

-- ======================================
-- HMI / Debug Utilities
-- ======================================

-- Store current TCP pose in global variables (for HMI monitoring)
function ShowPos()
    x,y,z,rx,ry,rz = GetActualTCPPose()
    RegisterVar("number","x")
    RegisterVar("number","y")
    RegisterVar("number","z")
    RegisterVar("number","rx")
    RegisterVar("number","ry")
    RegisterVar("number","rz")
end
