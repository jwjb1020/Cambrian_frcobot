-- ====================================================================
-- 17. Placement / Drop 포즈 (잡은 부품을 정해진 자세로 놓기)
-- A) GET PLACEMENT POSE : Cambrian UI(Workspace > Part Placement)에 만든 배치 위치 사용
-- B) GET GRASPED PART DROP POSE : 목표 포즈를 직접 주고 놓는 flange 포즈 계산
-- ※ 두 명령 모두 REPORT PICK RESULT 전에 호출해야 한다 (pick result가 예측을 소멸시킴)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP         = "192.168.58.100"
local CAM_PORT       = 4000
local MODEL_NAME     = "my_model"
local USE_PLACEMENT  = true          -- true: A 방식, false: B 방식
local PLACEMENT_NAME = ""            -- "" = 자동 (도달 가능한 첫 배치)
local DROP_TARGET    = {-300, -300, 50, 180, 0, 0}   -- B 방식 목표 부품 포즈 (mm, deg)
local GRIPPER_TYPE   = 0
local SPEED_TRAVEL, SPEED_GRASP = 30, 10

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

while true do
    PTP(p1, SPEED_TRAVEL, -1, 0)
    if cam_get_prediction(MODEL_NAME) then
        local grasp, app = cam_approach(cam_grasp_pose, nil, 50, 0, 50)
        move_j(app, SPEED_TRAVEL)
        move_l(grasp, nil, SPEED_GRASP)
        SetDO(0, 1, 0, 1) WaitMs(300)
        local picked_pose = cam_get_tcp_pose()
        move_l(app, nil, SPEED_TRAVEL)

        local place = nil
        if USE_PLACEMENT then
            place = cam_get_placement_pose(picked_pose, PLACEMENT_NAME, -1)
        else
            cam_set_part_grasped(picked_pose)
            place = cam_get_grasped_part_drop_pose(DROP_TARGET, GRIPPER_TYPE)
        end

        cam_report_pick_result(1)   -- 배치 포즈를 받은 뒤에 보고

        if place ~= nil then
            local above = cam_offset_pose(place, 0, 0, -50)
            move_j(above, SPEED_TRAVEL)
            move_l(place, nil, SPEED_GRASP)
            SetDO(0, 0, 0, 1) WaitMs(300)
            move_l(above, nil, SPEED_TRAVEL)
        else
            popup("배치 포즈를 받지 못했습니다: " .. cam_msg, "cambrian")
            PTP(p2, SPEED_TRAVEL, -1, 0)
            SetDO(0, 0, 0, 1) WaitMs(300)
        end
        if not USE_PLACEMENT then cam_remove_grasped_part() end
    else
        popup("부품 없음", "cambrian")
    end
end
