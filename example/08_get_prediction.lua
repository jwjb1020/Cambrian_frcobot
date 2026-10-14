-- ====================================================================
-- 08. 기본 예측 → 픽
-- p1(촬영 자세) → 예측 → pre-approach → approach → grasp → 그립 → exit → p2(놓기)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

-- ====================== 사용자 설정 ======================
local CAM_IP     = "192.168.58.100"
local CAM_PORT   = 4000
local MODEL_NAME = "my_model"

local GRASP_OFFSET = {0, 0, 0, 0, 0, 0}   -- 예측 포즈 기준 그립 오프셋 (mm, deg)
local APP_DIST     = 50     -- mm
local PREAPP_DIST  = 100    -- mm
local EXIT_DIST    = 80     -- mm
local SPEED_TRAVEL = 30
local SPEED_GRASP  = 10
local GRIP_DO      = 0

local function grip()    SetDO(GRIP_DO, 1, 0, 1) WaitMs(300) end
local function release() SetDO(GRIP_DO, 0, 0, 1) WaitMs(300) end

-- ====================== 초기화 ======================
cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

-- ====================== 메인 루프 ======================
while true do
    PTP(p1, SPEED_TRAVEL, -1, 0)   -- 촬영 자세

    -- 그립 타입 우선순위 없음, 제외 없음, 정렬 0(신뢰도)
    if cam_get_prediction(MODEL_NAME, nil, nil, 0) then
        PrintMsg(string.format("pred %.1f %.1f %.1f type=%d conf=%.2f",
            cam_grasp_pose[1], cam_grasp_pose[2], cam_grasp_pose[3], cam_grasp_type, cam_confidence))

        local grasp, app, preapp, exit_p =
            cam_approach(cam_grasp_pose, GRASP_OFFSET, APP_DIST, PREAPP_DIST, EXIT_DIST)

        move_j(preapp, SPEED_TRAVEL)
        move_l(app, nil, SPEED_TRAVEL)
        move_l(grasp, nil, SPEED_GRASP)
        grip()
        move_l(exit_p, nil, SPEED_TRAVEL)

        cam_report_pick_result(1)

        PTP(p2, SPEED_TRAVEL, -1, 0)   -- 놓기 위치
        release()
    else
        if cam_too_close() == 1 then PrintMsg("부품이 카메라에 너무 가까움") end
        if cam_too_far() == 1 then PrintMsg("부품이 카메라에서 너무 멂") end
        popup("부품을 찾지 못했습니다. 부품을 채운 후 계속을 누르세요.", "cambrian")
    end
end
