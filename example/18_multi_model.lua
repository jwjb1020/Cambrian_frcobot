-- ====================================================================
-- 18. 모델 두 개 번갈아 사용
-- 두 모델을 미리 로드해 두고 촬영 위치별로 다른 모델로 예측한다.
-- 모델별 신뢰도 임계값 / 가장자리 제외 설정 포함.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000
local MODEL_A  = "part_a_model"
local MODEL_B  = "part_b_model"
local SPEED_TRAVEL, SPEED_GRASP = 30, 10

cam_init(CAM_IP, CAM_PORT)
cam_startup()

cam_load_model(MODEL_A)
cam_load_model(MODEL_B)
cam_wait_for_model_launch(MODEL_A)
cam_wait_for_model_launch(MODEL_B)

cam_set_model_confidence(MODEL_A, 0.6)
cam_set_model_confidence(MODEL_B, 0.5)
cam_set_edge_trim(MODEL_B, 0.1)      -- 이미지 가장자리 10% 제외

local function pick(model)
    if not cam_get_prediction(model) then
        PrintMsg(model .. ": 부품 없음")
        return false
    end
    local grasp, app = cam_approach(cam_grasp_pose, nil, 50, 0, 50)
    move_j(app, SPEED_TRAVEL)
    move_l(grasp, nil, SPEED_GRASP)
    SetDO(0, 1, 0, 1) WaitMs(300)
    move_l(app, nil, SPEED_TRAVEL)
    cam_report_pick_result(1)
    return true
end

while true do
    PTP(p1, SPEED_TRAVEL, -1, 0)            -- A 박스 촬영 위치
    if pick(MODEL_A) then
        PTP(p3, SPEED_TRAVEL, -1, 0)        -- A 놓는 위치
        SetDO(0, 0, 0, 1) WaitMs(300)
    end

    PTP(p2, SPEED_TRAVEL, -1, 0)            -- B 박스 촬영 위치
    if pick(MODEL_B) then
        PTP(p4, SPEED_TRAVEL, -1, 0)        -- B 놓는 위치
        SetDO(0, 0, 0, 1) WaitMs(300)
    end
end
