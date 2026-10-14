-- ====================================================================
-- 15. Pick Path (충돌 없는 RRT 경로를 서버에서 한 번에)
-- GET PICK PATH: 현재 자세 → (MoveJ waypoint들) → MoveL grasp
-- 픽 후에는 GET PATH TO JOINTS로 홈 관절값까지 충돌 없는 경로를 받아 복귀.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP      = "192.168.58.100"
local CAM_PORT    = 4000
local MODEL_NAME  = "my_model"
local APPROACH_MM = 100
local TIMEOUT     = 3.0          -- s, RRT 계획 시간
local SPEED_J, SPEED_L = 40, 10
local BLEND_T     = 100          -- ms, waypoint 사이 블렌딩

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

PTP(p1, 30, -1, 0)
local HOME_J = cam_get_joints()   -- 홈 관절값 기록

while true do
    if cam_get_pick_path(MODEL_NAME, APPROACH_MM, nil, nil, 0, TIMEOUT) then
        PrintMsg("path: " .. cam_path_count .. " waypoints, grasp id " .. cam_path_grasp_id)
        cam_execute_path(SPEED_J, SPEED_L, BLEND_T)    -- 마지막은 MoveL grasp
        SetDO(0, 1, 0, 1) WaitMs(300)
        cam_report_pick_result(1)

        -- 빠져나오기: 분할 경로(split path)가 켜져 있으면 GET EXIT PATH, 아니면 홈까지 계획
        if cam_get_path_to_joints(HOME_J) then
            cam_execute_path(SPEED_J, SPEED_L, BLEND_T)
        else
            PTP(p1, 30, -1, 0)
        end

        PTP(p2, 30, -1, 0)
        SetDO(0, 0, 0, 1) WaitMs(300)
        PTP(p1, 30, -1, 0)
    else
        popup("pick path를 찾지 못했습니다: " .. cam_msg, "cambrian")
    end
end
