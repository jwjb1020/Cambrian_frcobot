-- ====================================================================
-- 09. 전체 예측 + 충돌/도달 검사 후 선택
-- GET ALL PREDICTIONS(최대 10개) 중 로봇이 도달 가능하고 충돌이 없는 첫 후보를 픽.
-- 여러 후보를 받은 뒤에는 REPORT PICK RESULT에 prediction ID(0부터)를 함께 보낸다.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP     = "192.168.58.100"
local CAM_PORT   = 4000
local MODEL_NAME = "my_model"
local APP_DIST   = 50
local SPEED_TRAVEL, SPEED_GRASP = 30, 10

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

-- 그리퍼 충돌 형상 (flange 기준, mm)
cam_set_gripper_box("gripper", {0, 0, 75, 0, 0, 0}, 60, 60, 150)

while true do
    PTP(p1, SPEED_TRAVEL, -1, 0)

    local n = cam_get_all_predictions(MODEL_NAME, nil, nil, 0)
    PrintMsg(n .. "개 후보")

    local picked = false
    for i = 1, n do
        local pose = cam_poses_list[i]
        local app  = cam_offset_pose(pose, 0, 0, -APP_DIST)
        if cam_is_pose_reachable(pose) and cam_is_pose_reachable(app) and cam_test_pose(pose) then
            PrintMsg("후보 " .. (i-1) .. " 선택 (type=" .. cam_types_list[i] .. ", conf=" .. cam_confidence_list[i] .. ")")
            move_j(app, SPEED_TRAVEL)
            move_l(pose, nil, SPEED_GRASP)
            SetDO(0, 1, 0, 1) WaitMs(300)
            move_l(app, nil, SPEED_TRAVEL)
            cam_report_pick_result(1, i - 1)    -- prediction ID = i-1
            PTP(p2, SPEED_TRAVEL, -1, 0)
            SetDO(0, 0, 0, 1) WaitMs(300)
            picked = true
            break
        else
            PrintMsg("후보 " .. (i-1) .. " 건너뜀 (도달 불가 또는 충돌)")
        end
    end

    if not picked then
        popup("집을 수 있는 후보가 없습니다.", "cambrian")
    end
end
