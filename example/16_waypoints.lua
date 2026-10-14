-- ====================================================================
-- 16. Waypoint (서버에 이름 있는 위치 저장)
-- 현재 위치를 "home"으로 저장 → 다른 곳으로 이동 → 서버에 경로 계획을 받아 home으로 복귀
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000

cam_init(CAM_IP, CAM_PORT)
cam_startup()

-- 1) 현재 TCP 포즈를 "home"으로 저장 (is_tcp = 1)
PTP(p1, 30, -1, 0)
cam_set_waypoint("home", cam_get_tcp_pose(), 1)

-- 2) 저장된 값 읽기
local pose = cam_get_waypoint_pose("home")
local joints = cam_get_waypoint_joints("home")
if pose ~= nil then
    PrintMsg(string.format("home pose %.1f %.1f %.1f (tcp=%d)", pose[1], pose[2], pose[3], cam_waypoint_is_tcp))
end

-- 3) 다른 곳으로 이동 후 home으로 경로 계획 복귀
PTP(p2, 30, -1, 0)
if joints ~= nil then
    if cam_get_path_to_joints(joints) then
        cam_execute_path(30, 10, 100)
    else
        move_joints(joints, 30)
    end
end

-- 4) 삭제
-- cam_remove_waypoint("home")
