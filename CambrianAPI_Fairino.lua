-- ====================================== --
-- Cambrian Vision API
-- (FAIRINO Edition)
-- Version  5.0.0
-- Release  2026/10/14
-- Based on FairinoForCambrian v0.4.2 and the Cambrian Doosan API v2.0
-- Modified for Fairino Robot by Jo Won Jun, Cambrian Robotics Korea
-- Targets Cambrian VISION API manual v2.5.5
-- ====================================== --
--
-- Quick start:
--   package.path = package.path .. ";/root/web/file/user/?.lua"
--   require("CambrianAPI_Fairino")
--   cam_init("192.168.58.100", 4000)     -- connect once
--   cam_startup()                         -- API version, ping, session, prediction space
--   cam_request("PING")                           -- raw command: '#', '*', robot state and '<<' added automatically
--   if cam_get_prediction("my_model") then move_l(cam_grasp_pose, nil, 20) end
--
-- What's new in v5.0.0 (vs FairinoForCambrian v0.4.2):
--   • cam_request(command, ...) — one-line raw command. No socket argument, no manual '#'.
--     Arguments are joined with '*'; a 6-value table becomes "[x,y,z,rx,ry,rz]".
--   • Persistent socket with automatic reconnect (CAM_PERSISTENT = false restores
--     the v0.4.2 connect-per-command behaviour)
--   • Reply codes handled centrally: 1=ERROR (print/log/popup), 2=WARNING, 3=PRINT
--   • All functions renamed cambrian_* → cam_* (same names as the Doosan API v2.0)
--   • New: API version handshake, pick sequence, path planning, server IK/FK,
--     waypoints, placement/drop poses, calibration verification, robot kinematic
--     calibration, advanced config, search grid modes/layers, multi-rig, HDR
--   • Auto calibration: waits on step 0, IK check with GetInverseKinHasSolution
--   • cam_test_pose() now follows the API: returns true when the pose is collision free
--   • LOAD MODEL now reads the server reply (the server replies OK)
--
-- Fairino rules: do not use pcall (save error on the controller), do not call
-- PTP() with a variable point name.
-- ====================================== --

-- ********* Global Parameters *********
cam_ip   = "127.0.0.1"
cam_port = 4000

-- This API's own version, sent with REPORT API VERSION
cam_api_version_number = {5, 0, 0}
-- Cambrian UI version reported by GET VERSION (filled by cam_get_version / cam_check_compatibility)
cam_ui_version_number  = {0, 0, 0}
-- Minimum Cambrian UI version required (major, minor)
cam_required_major = 1
cam_atleast_minor  = 6

-- Socket behaviour
CAM_SOCKET        = "socket_0"
CAM_PERSISTENT    = true   -- true: keep one connection open; false: connect/disconnect per command
CAM_READ_RETRIES  = 20     -- max extra reads when a reply arrives split across TCP segments
CAM_STOP_ON_ERROR = false  -- true: error() stops the script on an ERROR (code 1) reply
CAM_POPUP_ON_ERROR = true  -- true: show popup() on an ERROR (code 1) reply
CAM_PRINT_REPLY   = false  -- true: print every request/reply (debugging)

-- Prediction space. Cambrian default is FLANGE: the pose is relative to the flange
-- at capture time and is converted to base coordinates here. BASE: used as is.
cam_prediction_space = "FLANGE"

-- Box sizes are given in mm and multiplied by this before sending (server expects m).
-- Set to 1 if your Cambrian version expects mm.
CAM_BOX_SIZE_SCALE = 0.001

-- TCP offset override (only needed when camera position differs from TCP).
-- Default: automatically read from GetTCPOffset(). Override with cam_set_tool_offset().
_fr_tool_offset        = {0,0,0,0,0,0}
_fr_tool_offset_manual = false

-- File log path (uses io.open instead of print)
CAMBRIAN_LOG_PATH   = "/usr/local/etc/web/file/user/cambrian_log.txt"
CAMBRIAN_LOG_ENABLE = false

-- External GUI popup server settings (IP/port of PC running gui_popup_server.py)
POPUP_SERVER_IP   = "192.168.58.1"
POPUP_SERVER_PORT = 9999
POPUP_ENABLE      = true

-- ********* Last reply (DO NOT EDIT) *********
cam_msg      = ""   -- text message of the last reply
cam_code     = -1   -- return code of the last reply (0 OK, 1 ERROR, 2 WARNING, 3 PRINT, -1 no reply)
cam_data_str = ""   -- raw DATA field of the last reply
cam_data     = {}   -- DATA field split by ',' (strings)
cam_last_flange_pose = {0,0,0,0,0,0}  -- flange pose sent with the last request

-- ********* Result globals *********
cam_got_prediction = false
cam_grasp_pose     = {0,0,0,0,0,0}   -- base frame
cam_grasp_type     = -1              -- grasp type / grasp ID
cam_confidence     = -1
cam_prediction_flange_pose = {0,0,0,0,0,0}

cam_n_predictions   = 0
cam_poses_list      = {}
cam_types_list      = {}
cam_confidence_list = {}

cam_rig_pose    = {0,0,0,0,0,0}
cam_left_pose   = {0,0,0,0,0,0}
cam_search_pose = {0,0,0,0,0,0}
cam_avg_grasp_pose = {0,0,0,0,0,0}

cam_searchgrid_pose = {0,0,0,0,0,0}
cam_searchgrid_i = -1
cam_searchgrid_j = -1
cam_searchgrid_successive_bad_visits = 0
cam_searchgrid_total_bad_visits = 0
cam_searchgrid_x_cells = -1
cam_searchgrid_y_cells = -1

cam_ik_joints = {0,0,0,0,0,0}
cam_ik_pose   = {0,0,0,0,0,0}
cam_fk_pose   = {0,0,0,0,0,0}

-- Pick sequence result (joints in degrees, poses in base frame)
cam_hover_joints    = {0,0,0,0,0,0}
cam_hover_pose_seq  = {0,0,0,0,0,0}
cam_approach_joints = {0,0,0,0,0,0}
cam_approach_pose_seq = {0,0,0,0,0,0}
cam_grasp_joints    = {0,0,0,0,0,0}
cam_grasp_pose_seq  = {0,0,0,0,0,0}
cam_pick_sequence_grasp_id    = -1
cam_pick_sequence_grasp_score = 0

-- Path result: cam_path_joints[i] = {j1..j6}, cam_path_move_type[i] = 0 MoveJ / 1 MoveL,
-- cam_path_poses[i] = pose (only meaningful for MoveL entries)
cam_path_count     = 0
cam_path_joints    = {}
cam_path_move_type = {}
cam_path_poses     = {}
cam_path_grasp_id    = -1
cam_path_grasp_score = 0

cam_drop_pose       = {0,0,0,0,0,0}
cam_placement_pose  = {0,0,0,0,0,0}
cam_placement_index = -1
cam_waypoint_is_tcp = 0

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
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- Convert rotation matrix (3x3 flat array) to RPY angles (degrees)
-- Uses atan2+sy method: numerically stable, handles gimbal lock (pitch ±90°) correctly
function Rot2Rpy(Rot)
    local sy = sqrt(Rot[1]*Rot[1] + Rot[4]*Rot[4])
    local roll, pitch, yaw
    if sy >= 1e-9 then
        roll  = atan2(Rot[8], Rot[9])
        pitch = atan2(-Rot[7], sy)
        yaw   = atan2(Rot[4], Rot[1])
    else
        roll  = atan2(-Rot[6], Rot[5])
        pitch = atan2(-Rot[7], sy)
        yaw   = 0.0
    end
    return roll*R2D, pitch*R2D, yaw*R2D
end

-- Convert RPY angles (degrees) to rotation matrix (3x3 flat array), R = Rz(yaw)*Ry(pitch)*Rx(roll)
function Rpy2Rot(roll, pitch, yaw)
    local r = roll *D2R
    local b = pitch*D2R
    local a = yaw  *D2R
    local ca,sa = cos(a), sin(a)
    local cb,sb = cos(b), sin(b)
    local cr,sr = cos(r), sin(r)
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

-- Equivalent to UR's pose_trans(p_from, p_from_to): p_from_to is expressed in the p_from frame
-- Returns the resulting pose in the frame of p_from ({x,y,z,rx,ry,rz}, mm, deg)
function cam_pose_trans(coordinate_pose, relative_pose)
    local R0 = Rpy2Rot(coordinate_pose[4], coordinate_pose[5], coordinate_pose[6])
    local R1 = Rpy2Rot(relative_pose[4],   relative_pose[5],   relative_pose[6])
    local bP1 = MatVect(R0, {relative_pose[1], relative_pose[2], relative_pose[3]})
    local rx, ry, rz = Rot2Rpy(MatMult(R0, R1))
    return {coordinate_pose[1]+bP1[1], coordinate_pose[2]+bP1[2], coordinate_pose[3]+bP1[3], rx, ry, rz}
end

-- Inverse of a pose: T^-1 = [R^T, -R^T*p]
function cam_pose_inv(pose)
    local R = Rpy2Rot(pose[4], pose[5], pose[6])
    local Rt = {R[1],R[4],R[7], R[2],R[5],R[8], R[3],R[6],R[9]}
    local t = MatVect(Rt, {-pose[1], -pose[2], -pose[3]})
    local rx, ry, rz = Rot2Rpy(Rt)
    return {t[1], t[2], t[3], rx, ry, rz}
end

-- Offset a pose in its own (tool) frame. Example: cam_offset_pose(p, 0, 0, -50) = 50 mm back along tool Z
function cam_offset_pose(pose, x, y, z, rx, ry, rz)
    return cam_pose_trans(pose, {x or 0, y or 0, z or 0, rx or 0, ry or 0, rz or 0})
end

-- Backward compatible names (v0.4.2)
cambrian_pose_trans = cam_pose_trans
inv_pose_rpy_xyz    = cam_pose_inv

-- ======================================
-- Robot Motion Helpers
-- ======================================

-- (internal) Number or 0
local function _n(v)
    return type(v) == "number" and v or (tonumber(v) or 0)
end

-- Linear move (MoveL) to Cartesian TCP pose {x,y,z,rx,ry,rz} (mm, deg)
-- tool: tool number (nil = current), speed: % (default 30), blendR: mm (nil/-1 = stop at point)
function move_l(dPos, tool, speed, blendR)
    local x,y,z,rx,ry,rz = dPos[1],dPos[2],dPos[3],dPos[4],dPos[5],dPos[6]
    local j1,j2,j3,j4,j5,j6 = GetInverseKin(0, x, y, z, rx, ry, rz, -1)
    local t   = tool  or GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    local br  = blendR or -1
    MoveL(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100,br,0,0,0,0, -1,0,0,0,0,0,0,0)
end

-- Joint move (MoveJ) to Cartesian TCP pose {x,y,z,rx,ry,rz} (mm, deg)
-- speed: % (default 30), blendT: ms (nil/-1 = stop at point), tool: tool number (nil = current)
function move_j(dPos, speed, blendT, tool)
    local x,y,z,rx,ry,rz = dPos[1],dPos[2],dPos[3],dPos[4],dPos[5],dPos[6]
    local j1,j2,j3,j4,j5,j6 = GetInverseKin(0, x,y,z,rx,ry,rz, -1)
    local t   = tool or GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    local bt  = blendT or -1
    MoveJ(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100, 0,0,0,0, bt,0, 0,0,0,0,0,0)
end

-- Joint move (MoveJ) to joint target {j1..j6} (deg). blendT: ms (nil/-1 = stop)
function move_joints(joints, speed, blendT)
    local j1,j2,j3,j4,j5,j6 = joints[1],joints[2],joints[3],joints[4],joints[5],joints[6]
    local x,y,z,rx,ry,rz = GetForwardKin(j1,j2,j3,j4,j5,j6)
    local t   = GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    local bt  = blendT or -1
    MoveJ(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100, 0,0,0,0, bt,0, 0,0,0,0,0,0)
end

-- Linear move (MoveL) to the pose of joint target {j1..j6} (deg); keeps the server's IK configuration
function move_l_joints(joints, speed, blendR)
    local j1,j2,j3,j4,j5,j6 = joints[1],joints[2],joints[3],joints[4],joints[5],joints[6]
    local x,y,z,rx,ry,rz = GetForwardKin(j1,j2,j3,j4,j5,j6)
    local t   = GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    local br  = blendR or -1
    MoveL(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100,br,0,0,0,0, -1,0,0,0,0,0,0,0)
end

-- Current TCP pose {x,y,z,rx,ry,rz}
function cam_get_tcp_pose()
    local x,y,z,rx,ry,rz = GetActualTCPPose()
    return {_n(x),_n(y),_n(z),_n(rx),_n(ry),_n(rz)}
end

-- Current joints {j1..j6} (deg)
function cam_get_joints()
    local j1,j2,j3,j4,j5,j6 = GetActualJointPosDegree()
    return {_n(j1),_n(j2),_n(j3),_n(j4),_n(j5),_n(j6)}
end

-- (internal) true when GetInverseKinHasSolution says the TCP pose is reachable
local function _cam_has_ik(pose, ref_joints)
    local r = GetInverseKinHasSolution(0, pose, ref_joints or cam_get_joints())
    return r == true or r == 1 or r == "True" or r == "true"
end

-- Is the TCP pose reachable by the robot (local IK check, no server call)
function cam_is_pose_reachable(pose)
    return _cam_has_ik(pose, nil)
end

-- ======================================
-- Logging / Popup
-- ======================================

-- Write message to log file (only when CAMBRIAN_LOG_ENABLE = true)
function cambrian_log(msg)
    if not CAMBRIAN_LOG_ENABLE then return end
    local f = io.open(CAMBRIAN_LOG_PATH, "a")
    if f then f:write(msg .. "\n") f:close() end
end

-- (internal) Convert any value to a human-readable string
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
-- Returns true = continue. If the user presses STOP, the script is stopped with error().
-- When POPUP_ENABLE = false, prints to the WebApp print window (PrintMsg) and returns true
function popup(body, title)
    title = title or "Robot Alert"
    local body_str = _val_str(body)
    if not POPUP_ENABLE then
        PrintMsg("[POPUP] " .. title .. ": " .. body_str)
        return true
    end
    local sock = "socket_1"
    SocketClose(sock)
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
        PrintMsg("[POPUP server connection failed] " .. title .. ": " .. body_str)
        return true
    end
end

-- ======================================
-- Robot State
-- ======================================

-- Manually set the tool offset sent to Cambrian (disables auto-read from GetTCPOffset)
-- Pass nil to go back to auto-read
function cam_set_tool_offset(tool_offset)
    if tool_offset == nil then
        _fr_tool_offset_manual = false
    else
        _fr_tool_offset        = tool_offset
        _fr_tool_offset_manual = true
    end
end

-- Read current robot state: flange pose, joint angles (deg), tool offset
-- Called automatically on each request
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

    return flange_pose, joints, tool_offset
end

-- ======================================
-- Core: Serialization / Parsing
-- ======================================

-- (internal) "[a,b,c,...]"
local function _bracket(t)
    local s = "["
    for i = 1, #t do
        if i > 1 then s = s .. "," end
        s = s .. tostring(t[i])
    end
    return s .. "]"
end

-- Plain comma list (no brackets), for grasp type lists etc. Example: cam_list({1,3}) -> "1,3"
-- Values of -1 are skipped (v0.4.2 convention: -1 = none)
function cam_list(t)
    if type(t) ~= "table" then
        if t == nil then return "" end
        return tostring(t)
    end
    local s = ""
    local first = true
    for i = 1, #t do
        if t[i] ~= -1 then
            if not first then s = s .. "," end
            s = s .. tostring(t[i])
            first = false
        end
    end
    return s
end

-- (internal) Convert one argument of cam_request() to its wire string
--   nil -> ""        boolean -> "1"/"0"
--   6-value table -> "[x,y,z,rx,ry,rz]" (pose or joints)
--   other table   -> "a,b,c"
local function _arg_str(v)
    local tv = type(v)
    if v == nil then return "" end
    if tv == "boolean" then return v and "1" or "0" end
    if tv == "table" then
        if #v == 6 then return _bracket(v) end
        return cam_list(v)
    end
    return tostring(v)
end

-- (internal) Split reply by << >> delimiters
function cambrian_divid_reply_msg(cambrian_reply_msg)
    local parts = {}
    local pos = 1
    while true do
        local b = string.find(cambrian_reply_msg, "<<", pos, true)
        if b == nil then break end
        local e = string.find(cambrian_reply_msg, ">>", b + 2, true)
        if e == nil then break end
        parts[#parts + 1] = string.sub(cambrian_reply_msg, b + 2, e - 1)
        pos = e + 2
    end
    return parts
end

-- (internal) Split DATA field by commas
function cambrian_divid_reply_data(cambrian_reply_data)
    local out = {}
    if cambrian_reply_data == nil or cambrian_reply_data == "" then return out end
    local pos = 1
    while true do
        local c = string.find(cambrian_reply_data, ",", pos, true)
        if c == nil then
            out[#out + 1] = string.sub(cambrian_reply_data, pos)
            break
        end
        out[#out + 1] = string.sub(cambrian_reply_data, pos, c - 1)
        pos = c + 1
    end
    return out
end

-- (internal) Count non-overlapping occurrences of a plain substring
local function _count(s, sub)
    local n, pos = 0, 1
    while true do
        local f = string.find(s, sub, pos, true)
        if f == nil then return n end
        n = n + 1
        pos = f + #sub
    end
end

-- i-th DATA value of the last reply as a number (1-based). Returns default (or 0) if missing
function cam_num(i, default)
    local v = tonumber(cam_data[i])
    if v == nil then return default or 0 end
    return v
end

-- DATA values i .. i+5 of the last reply as a 6-value table
function cam_pose_at(i)
    return {cam_num(i), cam_num(i+1), cam_num(i+2), cam_num(i+3), cam_num(i+4), cam_num(i+5)}
end

-- ======================================
-- Core: Connection
-- ======================================

cam_connected = false

-- (internal) Open the socket
local function _cam_open()
    SocketClose(CAM_SOCKET)
    local r = SocketOpen(cam_ip, cam_port, CAM_SOCKET)
    cam_connected = (type(r) == "number" and r > 0)
    if not cam_connected then
        PrintMsg("CAMBRIAN: socket open failed " .. tostring(cam_ip) .. ":" .. tostring(cam_port))
        cambrian_log("ERROR: socket open failed " .. tostring(cam_ip) .. ":" .. tostring(cam_port))
    end
    return cam_connected
end

-- (internal) Close the socket
local function _cam_close()
    SocketClose(CAM_SOCKET)
    cam_connected = false
end

-- (internal) Send request, read until a full <<msg>><<code>><<data>> reply arrived
local function _cam_send_recv(req)
    if not cam_connected then
        if not _cam_open() then return nil end
    end
    SocketSendString(req, CAM_SOCKET, 0)
    local buf = ""
    local tries = 0
    while tries <= CAM_READ_RETRIES do
        local r = SocketReadString(CAM_SOCKET, 0)
        local chunk = nil
        if type(r) == "table" then chunk = r.buf
        elseif type(r) == "string" then chunk = r end
        if chunk == nil or chunk == "" then break end
        buf = buf .. chunk
        if _count(buf, ">>") >= 3 then break end
        tries = tries + 1
    end
    return buf
end

-- Set Cambrian server IP and port (does not connect)
function cam_set_ip(ip, port)
    cam_ip   = ip
    cam_port = port or cam_port
end

-- Connect to the Cambrian PC. Call once at the start of the program.
-- Returns true when the socket is open (always true when CAM_PERSISTENT = false)
function cam_init(ip, port)
    if ip ~= nil then cam_ip = ip end
    if port ~= nil then cam_port = port end
    if not CAM_PERSISTENT then return true end
    return _cam_open()
end

-- Close the connection
function cam_close()
    _cam_close()
end

-- Send one Cambrian command.
--   cam_request("PING")
--   cam_request("GET PREDICTION", "my_model", "1,3", "", 0)
--   cam_request("TEST POSE", {x,y,z,rx,ry,rz})
-- '#' separators, current flange pose / joints / tool offset and the '<<' terminator
-- are added automatically. Arguments are joined with '*'.
-- Returns: code (0 OK, 1 ERROR, 2 WARNING, 3 PRINT, -1 no reply), msg, data (array of strings)
-- The same values are stored in cam_code, cam_msg, cam_data (and cam_data_str).
function cam_request(command, ...)
    local n = select("#", ...)
    local args = {...}
    local data = ""
    for i = 1, n do
        if i > 1 then data = data .. "*" end
        data = data .. _arg_str(args[i])
    end
    return cam_raw(command, data)
end

-- Send one command with a pre-built DATA string (no '*' joining). Same returns as cam_request()
function cam_raw(command, data)
    local fp, j, to = get_current_robot_info()
    cam_last_flange_pose = fp
    local req = command .. "#" .. (data or "") .. "#" .. _bracket(fp) .. "#" .. _bracket(j)
             .. "#" .. _bracket(to) .. "#<<"

    local buf = _cam_send_recv(req)
    if (buf == nil or buf == "") and CAM_PERSISTENT then
        -- connection dropped: reconnect once and resend
        _cam_close()
        buf = _cam_send_recv(req)
    end
    if not CAM_PERSISTENT then _cam_close() end

    cam_code, cam_msg, cam_data_str, cam_data = -1, "", "", {}
    if buf == nil or buf == "" then
        cam_msg = "no reply"
    else
        local parts = cambrian_divid_reply_msg(buf)
        cam_msg      = parts[1] or ""
        cam_code     = tonumber(parts[2]) or -1
        cam_data_str = parts[3] or ""
        cam_data     = cambrian_divid_reply_data(cam_data_str)
    end

    if CAM_PRINT_REPLY then
        PrintMsg("CAM> " .. command .. "#" .. (data or "") .. "  <" .. tostring(cam_code) .. "> " .. cam_msg .. " | " .. cam_data_str)
    end

    if cam_code == 0 then
        -- OK
    elseif cam_code == 2 or cam_code == 3 then
        PrintMsg("CAMBRIAN [" .. command .. "] " .. cam_msg)
        cambrian_log("[" .. command .. "] code=" .. cam_code .. " " .. cam_msg)
    else
        local m = "CAMBRIAN ERROR [" .. command .. "] " .. cam_msg
        PrintMsg(m)
        cambrian_log(m)
        if CAM_POPUP_ON_ERROR then popup(cam_msg, "Cambrian ERROR: " .. command) end
        if CAM_STOP_ON_ERROR then error(m) end
    end
    return cam_code, cam_msg, cam_data
end

-- (internal) true when the last reply was not an error
local function _ok()
    return cam_code == 0 or cam_code == 2 or cam_code == 3
end

-- (internal) First DATA value == 1
local function _flag1()
    return _ok() and cam_num(1, 0) == 1
end

-- (internal) mm -> m for distances the API expects in metres
local function _m(mm)
    if mm == nil then return nil end
    return mm / 1000.0
end

-- (internal) Convert a predicted pose to base coordinates
local function _to_base(rel, flange)
    if cam_prediction_space == "FLANGE" then
        return cam_pose_trans(flange, rel)
    end
    return rel
end

-- ======================================
-- System
-- ======================================

-- Ping. Returns true when the server replied OK
function cam_ping()
    cam_request("PING")
    return _flag1()
end

-- Get Cambrian UI version. Returns major, minor, patch (-1 on failure)
function cam_get_version()
    cam_request("GET VERSION")
    if _ok() and #cam_data >= 3 then
        cam_ui_version_number = {cam_num(1), cam_num(2), cam_num(3)}
        return cam_num(1), cam_num(2), cam_num(3)
    end
    return -1, -1, -1
end

-- Report this API version to the UI. Returns false if the UI rejects it (incompatible)
function cam_report_api_version()
    cam_request("REPORT API VERSION", cam_list(cam_api_version_number))
    return cam_code ~= 1 and cam_code ~= -1
end

-- Check UI version >= required and report API version. Returns true when compatible
function cam_check_compatibility()
    local ma, mi = cam_get_version()
    if ma < 0 then PrintMsg("CAMBRIAN: error checking compatibility") return false end
    if ma < cam_required_major or (ma == cam_required_major and mi < cam_atleast_minor) then
        PrintMsg("CAMBRIAN: incompatible Cambrian UI version " .. ma .. "." .. mi)
        return false
    end
    return cam_report_api_version()
end

-- Start a new session (new log, reloads camera rig; unsaved camera settings are reverted)
function cam_start_session()
    cam_request("START SESSION")
    return _ok()
end

-- Standard startup: REPORT API VERSION -> PING -> START SESSION -> SET PREDICTION SPACE
-- space: "FLANGE" (default) or "BASE". Returns true when everything succeeded
function cam_startup(space)
    if not cam_report_api_version() then return false end
    if not cam_ping() then return false end
    cam_start_session()
    cam_set_prediction_space(space or cam_prediction_space)
    return _ok()
end

-- List all API commands supported by the server (printed, not parsed)
function cam_list_api_commands()
    cam_request("LIST API COMMANDS")
    PrintMsg(cam_msg)
end

function cam_log_text(text) cam_request("LOG TEXT", text) end

-- Save a support log on the Cambrian PC. tag/minutes optional. Returns output folder message
function cam_save_log(tag, minutes)
    cam_request("SAVE LOG", tag, minutes)
    return cam_msg
end

function cam_clear_memory() cam_request("CLEAR MEMORY") end

-- Report pick result. result: 1 success / 0 failure. prediction_id required after cam_get_all_predictions
function cam_report_pick_result(result, prediction_id)
    if prediction_id ~= nil then
        cam_request("REPORT PICK RESULT", prediction_id, result)
    else
        cam_request("REPORT PICK RESULT", result)
    end
end

-- ======================================
-- Model
-- ======================================

function cam_load_model(model_name)            cam_request("LOAD MODEL", model_name) return _ok() end
function cam_load_model_from_path(path)        cam_request("LOAD MODEL FROM PATH", path) return _ok() end
function cam_unload_model(model_name)          cam_request("UNLOAD MODEL", model_name) end
function cam_unload_all_models()               cam_request("UNLOAD ALL MODELS") end
-- Returns true when the model is loaded
function cam_check_model_ready(model_name)     cam_request("CHECK MODEL READY", model_name) return _flag1() end
-- Blocks until the model is launched. Returns true on success
function cam_wait_for_model_launch(model_name) cam_request("WAIT FOR MODEL LAUNCH", model_name) return _flag1() end
-- Load and wait in one call
function cam_load_model_and_wait(model_name)
    cam_load_model(model_name)
    return cam_wait_for_model_launch(model_name)
end
function cam_set_model_confidence(model_name, confidence)  cam_request("SET MODEL CONFIDENCE", model_name, confidence) end
function cam_set_model_recenter_crop(model_name, value)    cam_request("SET MODEL RECENTER CROP", model_name, value) end
function cam_set_edge_trim(model_name, trim)               cam_request("SET EDGE TRIM", model_name, trim) end

-- ======================================
-- Prediction
-- ======================================

-- space: "FLANGE" or "BASE"
function cam_set_prediction_space(space)
    cam_request("SET PREDICTION SPACE", space)
    if _ok() then cam_prediction_space = space end
end

-- (internal) Parse "valid,x,y,z,rx,ry,rz,type,score" into the prediction globals
local function _parse_prediction(flange)
    cam_got_prediction = _ok() and cam_num(1, 0) == 1
    if cam_got_prediction then
        cam_prediction_flange_pose = flange
        cam_grasp_pose = _to_base(cam_pose_at(2), flange)
        cam_grasp_type = cam_num(8, -1)
        cam_confidence = cam_num(9, -1)
    end
    return cam_got_prediction
end

-- Get the best prediction.
-- model_name: model, type_prio: grasp types in priority order ("1,3" or {1,3}),
-- type_ignore: grasp types to discard, sorting: sorting method (0 confidence, 1 depth asc, ...)
-- test_collision: false -> GET PREDICTION NO TEST
-- Returns true when found. Results: cam_grasp_pose (base frame), cam_grasp_type, cam_confidence
function cam_get_prediction(model_name, type_prio, type_ignore, sorting, test_collision)
    local cmd = (test_collision == false) and "GET PREDICTION NO TEST" or "GET PREDICTION"
    cam_request(cmd, model_name, cam_list(type_prio), cam_list(type_ignore), sorting)
    return _parse_prediction(cam_last_flange_pose)
end

function cam_get_prediction_notest(model_name, type_prio, type_ignore, sorting)
    return cam_get_prediction(model_name, type_prio, type_ignore, sorting, false)
end

-- Next prediction from the last capture (no new image). Same result globals
function cam_get_next_prediction()
    cam_request("GET NEXT PREDICTION")
    return _parse_prediction(cam_prediction_flange_pose)
end

-- Get all predictions (max 10). Returns count (0 when none).
-- Results: cam_poses_list[i], cam_types_list[i], cam_confidence_list[i]; prediction ID = i-1
function cam_get_all_predictions(model_name, type_prio, type_ignore, sorting, test_collision)
    local cmd = (test_collision == false) and "GET ALL PREDICTIONS NO TEST" or "GET ALL PREDICTIONS"
    cam_request(cmd, model_name, cam_list(type_prio), cam_list(type_ignore), sorting)
    local flange = cam_last_flange_pose
    cam_poses_list, cam_types_list, cam_confidence_list = {}, {}, {}
    cam_n_predictions = 0
    cam_got_prediction = false
    if not _ok() then return 0 end
    local count = cam_num(1, 0)
    for i = 1, count do
        local b = 1 + 8*(i-1)
        cam_poses_list[i]      = _to_base(cam_pose_at(b+1), flange)
        cam_types_list[i]      = cam_num(b+7, -1)
        cam_confidence_list[i] = cam_num(b+8, -1)
    end
    cam_n_predictions = count
    if count > 0 then
        cam_got_prediction = true
        cam_prediction_flange_pose = flange
        cam_grasp_pose = cam_poses_list[1]
        cam_grasp_type = cam_types_list[1]
        cam_confidence = cam_confidence_list[1]
    end
    return count
end

-- Raw model output of the last prediction: u, v, z, a, b, g
function cam_get_prediction_data()
    cam_request("GET PREDICTION DATA")
    return cam_pose_at(1)
end

-- 1 when parts are too close / too far from the camera
function cam_too_close() cam_request("TOO CLOSE") return cam_num(1, -1) end
function cam_too_far()   cam_request("TOO FAR")   return cam_num(1, -1) end
function cam_get_grasp_count() cam_request("GET GRASP COUNT") return cam_num(1, -1) end
function cam_get_part_count()  cam_request("GET PART COUNT")  return cam_num(1, -1) end

-- Start averaging predictions. threshold_mm default 10, space "BASE" (default) or "FLANGE"
function cam_start_prediction_average(threshold_mm, space)
    cam_request("START PREDICTION AVERAGE", threshold_mm, space)
end

-- Returns true and cam_avg_grasp_pose when the average is valid
function cam_end_prediction_average()
    cam_request("END PREDICTION AVERAGE")
    if _flag1() then
        cam_avg_grasp_pose = cam_pose_at(2)
        return true
    end
    return false
end

-- Search pose helpers. Return true and cam_search_pose when valid
function cam_get_search_z()
    cam_request("GET SEARCH Z")
    if _flag1() then cam_search_pose = cam_pose_at(2) return true end
    return false
end

function cam_smart_search_random()
    cam_request("SMART SEARCH RANDOM")
    if _flag1() then cam_search_pose = cam_pose_at(2) return true end
    return false
end

-- Block a volume around center (pose) for N predictions. radius_mm: sphere radius in mm (sent as metres)
function cam_block_volume(center, radius_mm, iterations)
    cam_request("BLOCK VOLUME", center, _m(radius_mm), iterations)
end
function cam_clear_block_volumes() cam_request("CLEAR BLOCK VOLUMES") end

-- ======================================
-- Camera
-- ======================================

-- Returns true when all cameras are connected
function cam_check_cameras()   cam_request("CHECK CAMERAS") return _flag1() end
function cam_wait_cameras()    cam_request("WAIT CAMERAS") end
-- Restart cameras and wait until they are ready
function cam_restart_cameras() cam_request("RESTART CAMERAS") cam_request("WAIT CAMERAS") end
function cam_cameras_auto()    cam_request("CAMERAS AUTO") end
function cam_cameras_manual()  cam_request("CAMERAS MANUAL") end
function cam_cameras_hdr()     cam_request("CAMERAS HDR") end
function cam_cameras_exposure(exposure) cam_request("CAMERAS EXPOSURE", exposure) end
function cam_cameras_gain(gain)         cam_request("CAMERAS GAIN", gain) end
-- target 5..250, tolerance, iterations, max_exposure
function cam_cameras_auto_params(target, tolerance, iterations, max_exposure)
    cam_request("CAMERAS AUTO PARAMS", target, tolerance, iterations, max_exposure)
end
function cam_cameras_hdr_params(bracket_stops, frames, auto_bracket, exposures_ms)
    cam_request("CAMERAS HDR PARAMS", bracket_stops, frames, auto_bracket, exposures_ms)
end
-- led, laser (0/1/2), focus_mm, focus_override
function cam_cameras_sensopart(led, laser, focus_mm, focus_override)
    cam_request("CAMERAS SENSOPART", led, laser, focus_mm, focus_override)
end
function cam_get_camera_auto()     cam_request("GET CAMERA AUTO") return cam_num(1, -1) end
function cam_get_camera_exposure() cam_request("GET CAMERA EXPOSURE") return cam_num(1, -1) end
function cam_get_camera_gain()     cam_request("GET CAMERA GAIN") return cam_num(1, -1) end
-- Returns "Auto", "Manual" or "HDR"
function cam_get_camera_mode()     cam_request("GET CAMERA MODE") return cam_data_str end
function cam_get_camera_auto_params()
    cam_request("GET CAMERA AUTO PARAMS")
    return cam_num(1, -1), cam_num(2, -1), cam_num(3, -1), cam_num(4, -1)
end
function cam_get_camera_hdr_params() cam_request("GET CAMERA HDR PARAMS") return cam_data end
function cam_get_camera_sensopart()  cam_request("GET CAMERA SENSOPART") return cam_data end

-- Rig pose. space: nil (default for the mount), 0 = flange, 1 = base. Returns pose (also cam_rig_pose)
function cam_get_rig_pose(space)
    cam_request("GET RIG POSE", space)
    if _ok() then cam_rig_pose = cam_pose_at(1) end
    return cam_rig_pose
end

-- Left camera pose relative to the flange
function cam_get_left_pose()
    cam_request("GET LEFT POSE")
    if _ok() then cam_left_pose = cam_pose_at(1) end
    return cam_left_pose
end

function cam_enable_liveview()  cam_request("ENABLE LIVEVIEW") end
function cam_disable_liveview() cam_request("DISABLE LIVEVIEW") end

-- Multi rig
function cam_load_rig_params(path)  cam_request("LOAD RIG PARAMS", path) end
function cam_set_total_rigs(n)      cam_request("SET TOTAL RIGS", n) end
function cam_get_total_rigs()       cam_request("GET TOTAL RIGS") return cam_num(1, -1) end
function cam_set_active_rig(index)  cam_request("SET ACTIVE RIG", index) end   -- 0-based
function cam_get_active_rig()       cam_request("GET ACTIVE RIG") return cam_num(1, -1) end

-- ======================================
-- Hand-eye Calibration
-- ======================================

-- mount: "FLANGE" (camera on robot) or "BASE" (fixed camera)
function cam_set_calibration_mount(mount) cam_request("SET CALIBRATION MOUNT", mount) end
function cam_get_calibration_mount()      cam_request("GET CALIBRATION MOUNT") return cam_data_str end

-- Rig parameters. rig_pose: approximate rig pose relative to flange {x,y,z,rx,ry,rz} (mm, deg)
-- focal_length mm (8), stereo_separation m (0.08), camera_tilt deg (5). Small rig: 8, 0.06, 8
-- Omitted values keep their current setting
function cam_set_calibration_rig_pose(rig_pose, focal_length, stereo_separation, camera_tilt)
    cam_request("SET CALIBRATION RIG POSE", rig_pose, focal_length, stereo_separation, camera_tilt)
end

-- Start a calibration (automatic: then call cam_next_calibration_step in a loop,
-- or use cam_auto_calibration). Defaults: {0,0,0,0,0,0}, 8, 0.08, 5
function cam_start_calibration(rig_pose, focal_length, stereo_separation, camera_tilt)
    cam_request("START CALIBRATION", rig_pose or {0,0,0,0,0,0}, focal_length or 8,
        stereo_separation or 0.08, camera_tilt or 5)
    return _ok()
end

-- Clear previous calibration data and start a new (manual) calibration
function cam_new_calibration() cam_request("NEW CALIBRATION") return _ok() end

-- One calibration step. reply: "1" reachable / "2" not reachable (answer to step 3), or nil
-- Returns step, pose. step: 0 wait, 1 move to pose, 2 finished, 3 test reachability of pose, other = aborted
function cam_next_calibration_step(reply)
    cam_request("NEXT CALIBRATION STEP", reply)
    if not _ok() or #cam_data < 1 or cam_data[1] == "" then return -1, nil end
    return cam_num(1, -1), cam_pose_at(2)
end

function cam_capture_calibration_image() cam_request("CAPTURE CALIBRATION IMAGE") return _ok() end
function cam_run_manual_calibration()    cam_request("RUN MANUAL CALIBRATION") return _ok() end

-- Automatic hand-eye calibration loop.
-- rig_pose: approximate rig pose relative to flange (mm, deg); focal_length, stereo_separation, camera_tilt
-- speed: MoveJ speed % (default 20)
-- The calibration poses are TCP poses of the current tool (same as the UR/Doosan APIs).
-- Returns true when the calibration finished
function cam_auto_calibration(rig_pose, focal_length, stereo_separation, camera_tilt, speed)
    if not cam_start_calibration(rig_pose, focal_length, stereo_separation, camera_tilt) then
        return false
    end
    local first_joints = cam_get_joints()
    local reply = nil
    local moves = 0
    while true do
        local step, pose = cam_next_calibration_step(reply)
        reply = nil
        if step == 0 then
            WaitMs(1000)
        elseif step == 1 then
            if not _cam_has_ik(pose, first_joints) then
                PrintMsg("CAMBRIAN CALIBRATION: no IK solution for " .. _val_str(pose))
                popup("Calibration pose not reachable: " .. _val_str(pose), "Cambrian")
                move_joints(first_joints, speed or 20)
                return false
            end
            -- IK referenced to the start joints keeps the same arm configuration for every pose
            local j1,j2,j3,j4,j5,j6 = GetInverseKinRef(0, pose, first_joints)
            moves = moves + 1
            PrintMsg("CAMBRIAN CALIBRATION: pose " .. moves .. " " .. _val_str(pose))
            move_joints({j1,j2,j3,j4,j5,j6}, speed or 20)
        elseif step == 2 then
            PrintMsg("CAMBRIAN CALIBRATION: finished (" .. moves .. " poses)")
            return true
        elseif step == 3 then
            reply = _cam_has_ik(pose, first_joints) and "1" or "2"
        else
            PrintMsg("CAMBRIAN CALIBRATION: aborted (step=" .. tostring(step) .. ") " .. cam_msg)
            popup("Camera calibration aborted. Check the Cambrian Vision UI. " .. cam_msg, "Cambrian")
            return false
        end
    end
end

-- Locate the calibration board. rig_space: true = result in rig frame
-- Returns foundL, poseL, foundR, poseR
function cam_locate_calibration_board(rig_space)
    cam_request("LOCATE CALIBRATION BOARD", rig_space and "RIG" or nil)
    return cam_num(1, 0) == 1, cam_pose_at(2), cam_num(8, 0) == 1, cam_pose_at(9)
end

-- Calibration board override (when it differs from the rig settings)
function cam_set_calibration_board_charuco(cols, rows, square_mm, marker_mm, dict_id, legacy)
    if legacy == false then
        cam_request("SET CALIBRATION BOARD", "charuco", cols, rows, square_mm, marker_mm, dict_id, "NOLEGACY")
    else
        cam_request("SET CALIBRATION BOARD", "charuco", cols, rows, square_mm, marker_mm, dict_id)
    end
    return _flag1()
end
function cam_set_calibration_board_chess(cols, rows, square_mm)
    cam_request("SET CALIBRATION BOARD", "chess", cols, rows, square_mm)
    return _flag1()
end
function cam_set_calibration_board_marker(dict_id, marker_id, len_mm)
    cam_request("SET CALIBRATION BOARD", "marker", dict_id, marker_id, len_mm)
    return _flag1()
end
function cam_clear_calibration_board() cam_request("SET CALIBRATION BOARD") end

-- Save the current board observation as a verification reference.
-- flange: true when the board is mounted on the flange. Returns saved, index
function cam_save_calibration_verification(name, flange)
    cam_request("SAVE CALIBRATION VERIFICATION", name or "default", flange and "FLANGE" or nil)
    return _flag1(), cam_num(2, -1)
end

-- Verify the calibration against the nearest saved observation.
-- trans_tol mm (2), rot_tol deg (1). Returns result table or nil when it could not run:
-- {pass, found_L, left_dT, left_dR, found_R, right_dT, right_dR, stereo_dT, stereo_dR,
--  flange_dT, flange_dR, calib_changed}
function cam_verify_calibration(name, trans_tol, rot_tol)
    if trans_tol ~= nil and rot_tol ~= nil then
        cam_request("VERIFY CALIBRATION", name or "default", trans_tol, rot_tol)
    else
        cam_request("VERIFY CALIBRATION", name or "default")
    end
    if cam_code == 1 or #cam_data < 12 then return nil end
    return {
        pass      = cam_num(1) == 1,
        found_L   = cam_num(2) == 1, left_dT   = cam_num(3),  left_dR   = cam_num(4),
        found_R   = cam_num(5) == 1, right_dT  = cam_num(6),  right_dR  = cam_num(7),
        stereo_dT = cam_num(8),      stereo_dR = cam_num(9),
        flange_dT = cam_num(10),     flange_dR = cam_num(11),
        calib_changed = cam_num(12) == 1,
    }
end

-- Saved verification pose. Returns found, count, pose
function cam_get_calibration_verification_pose(name, index)
    cam_request("GET CALIBRATION VERIFICATION POSE", name or "default", index or 0)
    if _flag1() and #cam_data >= 8 then return true, cam_num(2), cam_pose_at(3) end
    return false, cam_num(2, 0), nil
end

function cam_delete_calibration_verification(name) cam_request("DELETE CALIBRATION VERIFICATION", name or "default") return _flag1() end
-- JSON report string
function cam_get_verification_report(name) cam_request("GET VERIFICATION REPORT", name or "default") return cam_data_str end
function cam_set_calibration_fix_intrinsics(on) cam_request("SET CALIBRATION FIX INTRINSICS", on and 1 or 0) end
function cam_get_calibration_fix_intrinsics() cam_request("GET CALIBRATION FIX INTRINSICS") return cam_num(1, -1) end

-- ======================================
-- Robot Kinematic Calibration
-- ======================================

-- Send one sample. Without joints the current robot state is used (sent with every request).
-- With joints: GetForwardKin flange pose is sent (TCP pose when tool_is_tcp = true)
function cam_send_robot_calibration_data(joints, tool_is_tcp)
    if joints == nil then
        cam_request("SEND ROBOT CALIBRATION DATA")
    else
        local x,y,z,rx,ry,rz = GetForwardKin(joints[1],joints[2],joints[3],joints[4],joints[5],joints[6])
        if tool_is_tcp then
            cam_request("SEND ROBOT CALIBRATION DATA", joints, {x,y,z,rx,ry,rz}, 1)
        else
            cam_request("SEND ROBOT CALIBRATION DATA", joints, {x,y,z,rx,ry,rz})
        end
    end
    return _ok()
end
-- Start the solver (up to 60 s). serial: optional robot serial number
function cam_start_robot_calibration(serial) cam_request("START ROBOT CALIBRATION", serial) return _ok() end
function cam_check_robot_calibration()       cam_request("CHECK ROBOT CALIBRATION") return _flag1() end
function cam_reset_robot_calibration()       cam_request("RESET ROBOT CALIBRATION") end

-- ======================================
-- Collision / Workspace
-- ======================================

-- (internal) "sx,sy,sz" after CAM_BOX_SIZE_SCALE
local function _size3(x, y, z)
    local s = CAM_BOX_SIZE_SCALE
    return tostring(x*s) .. "," .. tostring(y*s) .. "," .. tostring(z*s)
end

-- Box in world. pose: box center {x,y,z,rx,ry,rz}; sizes mm; thickness mm (0 = solid, >0 = open bin)
function cam_set_box(name, pose, x_size, y_size, z_size, thickness)
    cam_request("SET BOX", name, pose, _size3(x_size, y_size, z_size), (thickness or 0) * CAM_BOX_SIZE_SCALE)
end
-- Box on the flange (gripper collision geometry). pose relative to flange
function cam_set_gripper_box(name, pose, x_size, y_size, z_size)
    cam_request("SET GRIPPER BOX", name, pose, _size3(x_size, y_size, z_size))
end
-- Box from 3 corner points (clockwise seen from above), depth and wall thickness mm
function cam_3_point_box(name, p1, p2, p3, depth, thickness)
    cam_request("3 POINT BOX", name, p1, p2, p3, depth * CAM_BOX_SIZE_SCALE, (thickness or 0) * CAM_BOX_SIZE_SCALE)
end
-- Box from 4 points, wall thickness mm
function cam_4_point_box(name, p1, p2, p3, p4, thickness)
    cam_request("4 POINT BOX", name, p1, p2, p3, p4, (thickness or 0) * CAM_BOX_SIZE_SCALE)
end
function cam_clear_collision_elements() cam_request("CLEAR COLLISION ELEMENTS") end

-- Test a TCP pose against the rig/boxes. Returns true when collision free (API: 1 = clear)
function cam_test_pose(pose)
    cam_request("TEST POSE", pose)
    return _flag1()
end
-- Test joints with the robot body. Returns the raw server flag (check the meaning on your version)
function cam_test_pose_withbody(joints) cam_request("TEST POSE WITHBODY", joints) return cam_num(1, -1) end
-- Returns true when the robot body model is loaded
function cam_check_body() cam_request("CHECK BODY") return _flag1() end
-- Returns true when there is no collision and no clearance violation
function cam_test_clearance(joints)
    cam_request("TEST CLEARANCE", joints)
    return _ok() and cam_num(1, 1) == 0 and cam_num(2, 1) == 0
end

-- CAD components
function cam_spawn_component_world(cad_name, name, pose)  cam_request("SPAWN COMPONENT WORLD", cad_name, name, pose) end
function cam_spawn_component_flange(cad_name, name, pose) cam_request("SPAWN COMPONENT FLANGE", cad_name, name, pose) end
function cam_set_component_world_pose(name, pose)  cam_request("SET COMPONENT WORLD POSE", name, pose) end
function cam_set_component_flange_pose(name, pose) cam_request("SET COMPONENT FLANGE POSE", name, pose) end
function cam_destroy_component_world(name)  cam_request("DESTROY COMPONENT WORLD", name) end
function cam_destroy_component_flange(name) cam_request("DESTROY COMPONENT FLANGE", name) end
function cam_enable_component_world(name)   cam_request("ENABLE COMPONENT WORLD", name) end
function cam_disable_component_world(name)  cam_request("DISABLE COMPONENT WORLD", name) end
function cam_enable_component_flange(name)  cam_request("ENABLE COMPONENT FLANGE", name) end
function cam_disable_component_flange(name) cam_request("DISABLE COMPONENT FLANGE", name) end

-- Robot base pose in the world (movable robot)
function cam_set_robot_pose(pose) cam_request("SET ROBOT POSE", pose) end
function cam_get_robot_pose() cam_request("GET ROBOT POSE") return cam_pose_at(1) end

-- ======================================
-- Search Grid
-- ======================================

-- Create a grid. pose: top-left search pose; sizes in mm
function cam_search_grid_init(grid_name, pose, x_cells, y_cells, max_z, cell_x, cell_y, z_step)
    cam_request("SEARCH GRID INIT", grid_name, pose, x_cells, y_cells, max_z, cell_x, cell_y, z_step)
    return _ok()
end

-- Auto init from a world box and the model FOV. Returns x_cells, y_cells
function cam_search_grid_auto_init(grid_name, box_name, model_name, rotation, fov_scale, overlap_x, overlap_y)
    local ov = nil
    if overlap_x ~= nil then ov = tostring(overlap_x) .. "," .. tostring(overlap_y or overlap_x) end
    cam_request("SEARCH GRID AUTO INIT", grid_name, box_name, model_name, rotation, fov_scale, ov)
    cam_searchgrid_x_cells, cam_searchgrid_y_cells = cam_num(1, -1), cam_num(2, -1)
    return cam_searchgrid_x_cells, cam_searchgrid_y_cells
end

function cam_search_grid_auto_init_fixed(grid_name, box_name, model_name, x_cells, y_cells, rotation)
    cam_request("SEARCH GRID AUTO INIT FIXED", grid_name, box_name, model_name, x_cells, y_cells, rotation)
    return _ok()
end

-- Next search pose. Returns pose, i, j (pose nil on error). Also cam_searchgrid_pose/_i/_j
function cam_search_grid_get_next(grid_name)
    cam_request("SEARCH GRID GET NEXT", grid_name)
    if not _ok() or #cam_data < 8 then return nil, -1, -1 end
    cam_searchgrid_pose = cam_pose_at(1)
    cam_searchgrid_i, cam_searchgrid_j = cam_num(7), cam_num(8)
    return cam_searchgrid_pose, cam_searchgrid_i, cam_searchgrid_j
end

function cam_search_grid_get_cell(grid_name, i, j)
    cam_request("SEARCH GRID GET CELL", grid_name, i, j)
    if not _ok() or #cam_data < 6 then return nil end
    return cam_pose_at(1)
end

function cam_search_grid_update(grid_name) cam_request("SEARCH GRID UPDATE", grid_name) end

-- Report the result for cell i, j (1 success / 0 fail). Returns successive_bad, total_bad
function cam_search_grid_report(grid_name, i, j, result)
    cam_request("SEARCH GRID REPORT", grid_name, i, j, result)
    cam_searchgrid_successive_bad_visits = cam_num(1, 0)
    cam_searchgrid_total_bad_visits      = cam_num(2, 0)
    return cam_searchgrid_successive_bad_visits, cam_searchgrid_total_bad_visits
end

function cam_search_grid_block(grid_name, i, j, iterations) cam_request("SEARCH GRID BLOCK", grid_name, i, j, iterations) end
function cam_search_grid_unblock(grid_name, i, j)  cam_request("SEARCH GRID UNBLOCK", grid_name, i, j) end
function cam_search_grid_ignore(grid_name, i, j)   cam_request("SEARCH GRID IGNORE", grid_name, i, j) end
function cam_search_grid_unignore(grid_name, i, j) cam_request("SEARCH GRID UNIGNORE", grid_name, i, j) end
function cam_search_grid_reset_cell(grid_name, i, j, level) cam_request("SEARCH GRID RESET CELL", grid_name, i, j, level) end
function cam_search_grid_reset(grid_name)       cam_request("SEARCH GRID RESET", grid_name) end
function cam_search_grid_destroy(grid_name)     cam_request("SEARCH GRID DESTROY", grid_name) end
function cam_search_grid_destroy_all()          cam_request("SEARCH GRID DESTROY ALL") end
-- Returns true when every cell is finished
function cam_search_grid_finished(grid_name)    cam_request("SEARCH GRID FINISHED", grid_name) return _flag1() end
function cam_search_grid_check_init(grid_name)  cam_request("SEARCH GRID CHECK INIT", grid_name) return _flag1() end
function cam_search_grid_level(grid_name)       cam_request("SEARCH GRID LEVEL", grid_name) return cam_num(1, -1) end
function cam_search_grid_set_level(grid_name, level) cam_request("SEARCH GRID SET LEVEL", grid_name, level) end
function cam_search_grid_set_cell_level(grid_name, i, j, level) cam_request("SEARCH GRID SET CELL LEVEL", grid_name, i, j, level) end
function cam_search_grid_get_cell_level(grid_name, i, j) cam_request("SEARCH GRID GET CELL LEVEL", grid_name, i, j) return cam_num(1, -1) end
-- weights: {cell_height, center_distance, last_distance, nr_predictions, iterations, randomness}
function cam_search_grid_set_weights(grid_name, w) cam_request("SEARCH GRID SET WEIGHTS", grid_name, cam_list(w)) end
function cam_search_grid_get_weights(grid_name)    cam_request("SEARCH GRID GET WEIGHTS", grid_name) return cam_data end
function cam_search_grid_dimensions(grid_name)
    cam_request("SEARCH GRID DIMENSIONS", grid_name)
    cam_searchgrid_x_cells, cam_searchgrid_y_cells = cam_num(1, -1), cam_num(2, -1)
    return cam_searchgrid_x_cells, cam_searchgrid_y_cells
end

-- Traversal mode 0..16. layer_offset in m (optional)
function cam_search_grid_set_mode(grid_name, mode, layer_offset) cam_request("SEARCH GRID SET MODE", grid_name, mode, layer_offset) end
function cam_search_grid_get_mode(grid_name) cam_request("SEARCH GRID GET MODE", grid_name) return cam_num(1, -1) end

-- Grid calibration step. mode 0 quick / 1 thorough. Returns true + cam_searchgrid_pose/_i/_j
-- while there is a pose to visit, false when done
function cam_search_grid_calibrate(grid_name, mode, model_name)
    cam_request("SEARCH GRID CALIBRATE", grid_name, mode, model_name)
    if not _flag1() then return false end
    cam_searchgrid_pose = cam_pose_at(2)
    cam_searchgrid_i, cam_searchgrid_j = cam_num(8), cam_num(9)
    return true
end
function cam_search_grid_calibrate_from(grid_name, mode, start_level, model_name)
    cam_request("SEARCH GRID CALIBRATE FROM", grid_name, mode, start_level, model_name)
    if not _flag1() then return false end
    cam_searchgrid_pose = cam_pose_at(2)
    cam_searchgrid_i, cam_searchgrid_j = cam_num(8), cam_num(9)
    return true
end

-- Layer state table
function cam_search_grid_get_layer_state(grid_name)
    cam_request("SEARCH GRID GET LAYER STATE", grid_name)
    if not _ok() or #cam_data < 9 then return nil end
    return {
        layer_index     = cam_num(1), current_layer_z = cam_num(2),
        cells_remaining = cam_num(3), parts_at_layer  = cam_num(4),
        filter_active   = cam_num(5) == 1, failed_cells = cam_num(6),
        grid_finished   = cam_num(7) == 1, boundary_held = cam_num(8) == 1,
        expected_layers = cam_num(9),
    }
end
function cam_search_grid_set_layer_offset(grid_name, offset_m) cam_request("SEARCH GRID SET LAYER OFFSET", grid_name, offset_m) return cam_num(1, -1) end
function cam_search_grid_set_layer_count(grid_name, count, hold) cam_request("SEARCH GRID SET LAYER COUNT", grid_name, count, hold) end
function cam_search_grid_next_layer(grid_name) cam_request("SEARCH GRID NEXT LAYER", grid_name) end

-- ======================================
-- IK / FK (server side)
-- ======================================

-- Server IK. Returns true + cam_ik_joints, cam_ik_pose
function cam_get_ik(target, test_collisions, seed_joints)
    if seed_joints ~= nil then
        cam_request("GET IK", target, test_collisions and 1 or 0, nil, seed_joints)
    elseif test_collisions then
        cam_request("GET IK", target, 1)
    else
        cam_request("GET IK", target)
    end
    if not _flag1() then return false end
    cam_ik_joints = cam_pose_at(2)
    cam_ik_pose   = cam_pose_at(8)
    return true
end

-- Server FK. apply_tcp: true = TCP pose, false = flange pose
function cam_get_fk(joints, apply_tcp)
    cam_request("GET FK", joints, apply_tcp and 1 or 0)
    cam_fk_pose = cam_pose_at(1)
    return cam_fk_pose
end

-- Configuration index (0-15) of joints (current joints when nil)
function cam_get_joints_configuration(joints)
    cam_request("GET JOINTS CONFIGURATION", joints)
    return cam_num(1, -1)
end

-- Allowed IK configurations, e.g. "2,3" or {2,3}. nil/"" = allow all. Returns the effective list
function cam_set_robot_configurations(configs)
    cam_request("SET ROBOT CONFIGURATIONS", cam_list(configs))
    return cam_data
end

-- ======================================
-- Pick Sequence
-- ======================================

-- (internal) "success,hoverJ6,hoverP6,apprJ6,apprP6,graspJ6,graspP6[,id,score]"
local function _unpack_pick_sequence(with_meta)
    if not _flag1() or #cam_data < 37 then return false end
    cam_hover_joints      = cam_pose_at(2)
    cam_hover_pose_seq    = cam_pose_at(8)
    cam_approach_joints   = cam_pose_at(14)
    cam_approach_pose_seq = cam_pose_at(20)
    cam_grasp_joints      = cam_pose_at(26)
    cam_grasp_pose_seq    = cam_pose_at(32)
    if with_meta then
        cam_pick_sequence_grasp_id    = cam_num(38, -1)
        cam_pick_sequence_grasp_score = cam_num(39, 0)
    end
    return true
end

-- AI prediction + IK + collision check in one call.
-- approach_mm / hover_mm: distances in mm (sent in m). hover_orientation: 0 grasp orientation, 1 vertical
-- Returns true + cam_hover/approach/grasp_joints and _pose_seq globals
function cam_get_pick_sequence(model_name, approach_mm, hover_mm, hover_orientation, type_prio, type_ignore, sorting)
    cam_request("GET PICK SEQUENCE", model_name, cam_list(type_prio), cam_list(type_ignore), sorting,
        _m(approach_mm), _m(hover_mm), hover_orientation or 0, "")
    return _unpack_pick_sequence(true)
end

-- Next valid sequence from the last GET PICK SEQUENCE (e.g. after a failed pick)
function cam_get_next_pick_sequence()
    cam_request("GET NEXT PICK SEQUENCE")
    return _unpack_pick_sequence(true)
end

-- Plan a sequence for a known grasp pose
function cam_get_pick_sequence_from_pose(grasp_pose, approach_mm, hover_mm, hover_orientation)
    cam_request("GET PICK SEQUENCE FROM POSE", grasp_pose, _m(approach_mm), _m(hover_mm), hover_orientation or 0, "")
    return _unpack_pick_sequence(false)
end

-- trans_thr_mm, rot_thr_deg, joint_thr_deg, spaces "joint"/"cartesian", skip_same_part 0/1
function cam_set_pick_sequence_settings(trans_thr_mm, rot_thr_deg, joint_thr_deg, cur_to_hover, hover_to_appr, appr_to_grasp, skip_same_part)
    cam_request("SET PICK SEQUENCE SETTINGS", _m(trans_thr_mm), rot_thr_deg, joint_thr_deg,
        cur_to_hover, hover_to_appr, appr_to_grasp, skip_same_part)
end

-- Execute the last pick sequence: MoveJ hover -> MoveJ approach -> MoveL grasp
function cam_execute_pick_sequence(speed_travel, speed_grasp)
    move_joints(cam_hover_joints, speed_travel or 30)
    move_joints(cam_approach_joints, speed_travel or 30)
    move_l_joints(cam_grasp_joints, speed_grasp or 10)
end

-- ======================================
-- Approach / Exit Poses
-- ======================================

-- Local helper (no server call): grasp, approach, pre-approach, exit poses from a pose
-- grasp_offset {x,y,z,rx,ry,rz} in tool frame; distances in mm along tool -Z
function cam_approach(pose, grasp_offset, app_dist, preapp_dist, exit_dist)
    local grasp  = cam_pose_trans(pose, grasp_offset or {0,0,0,0,0,0})
    local app    = cam_pose_trans(grasp, {0,0,-(app_dist or 0),0,0,0})
    local preapp = cam_pose_trans(app,   {0,0,-(preapp_dist or 0),0,0,0})
    local exit_p = cam_pose_trans(grasp, {0,0,-(exit_dist or 0),0,0,0})
    return grasp, app, preapp, exit_p
end

-- Server side helpers (use the gripper model of the Cambrian UI). Distances in mm
function cam_get_approach_pose(grasp_pose, approach_mm)
    cam_request("GET APPROACH POSE", grasp_pose, _m(approach_mm))
    return cam_pose_at(1)
end
function cam_get_hover_pose(approach_pose, hover_mm, hover_orientation)
    cam_request("GET HOVER POSE", approach_pose, _m(hover_mm), hover_orientation)
    return cam_pose_at(1)
end
-- Returns approach_pose, hover_pose
function cam_configure_approach(grasp_pose, approach_mm, hover_mm, hover_orientation)
    cam_request("CONFIGURE APPROACH", grasp_pose, _m(approach_mm), _m(hover_mm), hover_orientation)
    return cam_pose_at(1), cam_pose_at(7)
end
-- Exit pose out of a component (bin). overshoot in mm
function cam_get_exit_pose(tool_pose, component_name, overshoot_mm, center_factor)
    cam_request("GET EXIT POSE", tool_pose, component_name, _m(overshoot_mm), center_factor)
    return cam_pose_at(1)
end

-- ======================================
-- Path Planning (joints in degrees)
-- ======================================

-- (internal) Reset path cache
local function _reset_path()
    cam_path_count, cam_path_joints, cam_path_move_type, cam_path_poses = 0, {}, {}, {}
end

-- (internal) Read count MoveJ waypoints starting at DATA index idx
local function _read_movej(idx, count)
    for k = 1, count do
        local n = #cam_path_joints + 1
        cam_path_joints[n]    = cam_pose_at(idx + (k-1)*6)
        cam_path_move_type[n] = 0
        cam_path_poses[n]     = {0,0,0,0,0,0}
    end
    cam_path_count = #cam_path_joints
end

-- (internal) Parse a GET PICK PATH style reply
local function _parse_pick_path()
    if not _flag1() then return false end
    local count = cam_num(2, 0)
    if count <= 0 then return false end
    _read_movej(3, count - 1)
    local idx = 3 + (count - 1)*6
    local n = #cam_path_joints + 1
    cam_path_joints[n]    = cam_pose_at(idx)
    cam_path_move_type[n] = 1
    cam_path_poses[n]     = cam_pose_at(idx + 6)
    cam_path_grasp_id     = cam_num(idx + 12, -1)
    cam_path_grasp_score  = cam_num(idx + 13, 0)
    cam_path_count = n
    return true
end

-- Collision free pick path (RRT) in one call. Last waypoint is the MoveL grasp. approach in mm
function cam_get_pick_path(model_name, approach_mm, type_prio, type_ignore, sorting, timeout)
    _reset_path()
    cam_request("GET PICK PATH", model_name, cam_list(type_prio), cam_list(type_ignore), sorting,
        _m(approach_mm), nil, nil, nil, timeout)
    return _parse_pick_path()
end

-- Same as cam_get_pick_path but planned from start_joints
function cam_get_pick_path_from_pose(start_joints, model_name, approach_mm, type_prio, type_ignore, sorting, timeout)
    _reset_path()
    cam_request("GET PICK PATH FROM POSE", start_joints, model_name, cam_list(type_prio), cam_list(type_ignore),
        sorting, _m(approach_mm), nil, nil, nil, timeout)
    return _parse_pick_path()
end

-- RRT path between two joint configurations
function cam_get_planned_path(start_joints, target_joints, timeout)
    _reset_path()
    cam_request("GET PLANNED PATH", start_joints, target_joints, timeout)
    if not _flag1() then return false end
    local count = cam_num(2, 0)
    -- waypoints are the last count*6 values
    _read_movej(#cam_data - count*6 + 1, count)
    return cam_path_count > 0
end

-- Path from current (or start) joints to target joints
function cam_get_path_to_joints(target_joints, start_joints)
    _reset_path()
    cam_request("GET PATH TO JOINTS", target_joints, start_joints)
    if not _flag1() then return false end
    _read_movej(3, cam_num(2, 0))
    return cam_path_count > 0
end

-- Path from current (or start) joints to a TCP pose
function cam_get_path_to_pose(target_pose, start_joints)
    _reset_path()
    cam_request("GET PATH TO POSE", target_pose, start_joints)
    if not _flag1() then return false end
    _read_movej(3, cam_num(2, 0))
    return cam_path_count > 0
end

-- Exit path after a split pick path
function cam_get_exit_path()
    _reset_path()
    cam_request("GET EXIT PATH")
    if not _flag1() then return false end
    _read_movej(3, cam_num(2, 0))
    return cam_path_count > 0
end

-- Next pick path (after a failed pick)
function cam_get_next_pick_path()
    _reset_path()
    cam_request("GET NEXT PICK PATH")
    return _parse_pick_path()
end

-- Stream one waypoint from the server cursor (small buffer robots).
-- Returns nil when done, else {move_type=0, joints=...} or {move_type=1, pose=..., joints=seed}
function cam_stream_next_waypoint()
    cam_request("GET NEXT WAYPOINT")
    if not _flag1() then return nil end
    if cam_num(2) == 0 then return {move_type = 0, joints = cam_pose_at(3)} end
    return {move_type = 1, pose = cam_pose_at(3), joints = cam_pose_at(9)}
end

-- Execute the cached path: MoveJ entries with blendT (ms) between points, MoveL for the grasp
function cam_execute_path(speed_j, speed_l, blendT)
    for i = 1, cam_path_count do
        local last = (i == cam_path_count)
        if cam_path_move_type[i] == 1 then
            move_l_joints(cam_path_joints[i], speed_l or 10)
        else
            move_joints(cam_path_joints[i], speed_j or 30, last and -1 or (blendT or -1))
        end
    end
end

function cam_save_path(name, key)       cam_request("SAVE PATH", name, key) end
function cam_get_saved_path(name, key)
    _reset_path()
    cam_request("GET SAVED PATH", name, key)
    if not _flag1() then return false end
    _read_movej(3, cam_num(2, 0))
    return cam_path_count > 0
end
function cam_delete_saved_path(name)    cam_request("DELETE SAVED PATH", name) end

-- ======================================
-- Waypoints
-- ======================================

-- is_tcp: 1 = pose is a TCP pose
function cam_set_waypoint(name, pose, is_tcp) cam_request("SET WAYPOINT", name, pose, is_tcp) end
function cam_remove_waypoint(name)            cam_request("REMOVE WAYPOINT", name) end
-- Returns pose or nil
function cam_get_waypoint_pose(name)
    cam_request("GET WAYPOINT", name, 0)
    if not _flag1() then return nil end
    cam_waypoint_is_tcp = cam_num(2)
    return cam_pose_at(3)
end
-- Returns joints or nil
function cam_get_waypoint_joints(name)
    cam_request("GET WAYPOINT", name, 1)
    if not _flag1() then return nil end
    cam_waypoint_is_tcp = cam_num(2)
    return cam_pose_at(3)
end

-- ======================================
-- Grasped Part / Placement (call BEFORE cam_report_pick_result)
-- ======================================

function cam_set_part_grasped(grasp_pose, prediction_id) cam_request("SET PART GRASPED", grasp_pose, prediction_id) end
function cam_remove_grasped_part() cam_request("REMOVE GRASPED PART") end

-- Drop pose for the grasped part at target_pose. Returns pose or nil (also cam_drop_pose)
function cam_get_grasped_part_drop_pose(target_pose, gripper_type)
    cam_request("GET GRASPED PART DROP POSE", target_pose, gripper_type)
    if not _ok() or #cam_data < 6 then return nil end
    cam_drop_pose = cam_pose_at(1)
    return cam_drop_pose
end

function cam_get_drop_pose(grasp_pose, drop_gripper_type, target_pose, prediction_id)
    if prediction_id ~= nil then
        cam_request("GET DROP POSE", grasp_pose, prediction_id, drop_gripper_type, target_pose)
    else
        cam_request("GET DROP POSE", grasp_pose, drop_gripper_type, target_pose)
    end
    if not _ok() or #cam_data < 6 then return nil end
    cam_drop_pose = cam_pose_at(1)
    return cam_drop_pose
end

-- Part placement authored in the UI. placement_name "" = auto; prediction_id -1 = last
-- Returns pose or nil (also cam_placement_pose, cam_placement_index)
function cam_get_placement_pose(grasp_pose, placement_name, prediction_id)
    cam_placement_index = -1
    cam_request("GET PLACEMENT POSE", grasp_pose, prediction_id or -1, placement_name or "")
    if cam_code == 1 or #cam_data < 8 or cam_num(1) ~= 1 then return nil end
    cam_placement_index = cam_num(2)
    cam_placement_pose  = cam_pose_at(3)
    if cam_code == 2 then return nil end  -- not reachable
    return cam_placement_pose
end

-- ======================================
-- Math / Advanced Config (server side)
-- ======================================

function cam_get_inverse_transform(pose) cam_request("GET INVERSE TRANSFORM", pose) return cam_pose_at(1) end
function cam_get_pose_transform(a, b)    cam_request("GET POSE TRANSFORM", a, b) return cam_pose_at(1) end

-- Note: SET ADVANCED CONFIG uses ',' between key and value
function cam_set_advanced_config(key, value) cam_raw("SET ADVANCED CONFIG", tostring(key) .. "," .. tostring(value)) end
function cam_get_advanced_config(key)        cam_request("GET ADVANCED CONFIG", key) return cam_data_str end
function cam_save_advanced_config()          cam_request("SAVE ADVANCED CONFIG") end
function cam_reload_advanced_config()        cam_request("RELOAD ADVANCED CONFIG") end

-- ======================================
-- HMI helper
-- ======================================

-- Write current TCP pose into globals x..rz and register them for the HMI
function ShowPos()
    x, y, z, rx, ry, rz = GetActualTCPPose()
    RegisterVar("number", "x")
    RegisterVar("number", "y")
    RegisterVar("number", "z")
    RegisterVar("number", "rx")
    RegisterVar("number", "ry")
    RegisterVar("number", "rz")
end
