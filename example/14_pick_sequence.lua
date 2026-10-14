-- ====================================================================
-- 14. Pick Sequence (AI + IK + 충돌 검사를 서버에서 한 번에)
-- 서버가 hover / approach / grasp 관절값을 계산해 준다.
--   MoveJ hover → MoveJ approach → MoveL grasp → 그립
-- 픽이 실패하면 GET NEXT PICK SEQUENCE로 다음 후보.
-- 사전 조건: 로봇 기구학 캘리브레이션(예제 19) 권장, 그리퍼/빈 충돌 요소 설정(예제 11)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP       = "192.168.58.100"
local CAM_PORT     = 4000
local MODEL_NAME   = "my_model"
local APPROACH_MM  = 100     -- grasp → approach 거리
local HOVER_MM     = 50      -- approach → hover 거리
local HOVER_ORIENT = 0       -- 0: 그립 방향 유지, 1: 수직
local SPEED_TRAVEL, SPEED_GRASP = 30, 10
local GRIP_DI_OK   = nil     -- 그립 확인 센서 DI 번호가 있으면 설정

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

-- 허용 IK 자세 (빈칸 = 전부). 예: "2,3"
cam_set_robot_configurations("")
-- 이동 허용 오차: 위치 10 mm, 회전 5 deg, 관절 10 deg / 구간 공간 joint, cartesian, cartesian
cam_set_pick_sequence_settings(10, 5, 10, "joint", "cartesian", "cartesian")

local function pick_ok()
    if GRIP_DI_OK == nil then return true end
    return GetDI(GRIP_DI_OK, 0) == 1
end

while true do
    PTP(p1, SPEED_TRAVEL, -1, 0)

    local found = cam_get_pick_sequence(MODEL_NAME, APPROACH_MM, HOVER_MM, HOVER_ORIENT)
    local tries = 0
    while found and tries < 3 do
        tries = tries + 1
        PrintMsg("pick sequence: grasp id " .. cam_pick_sequence_grasp_id ..
              " score " .. cam_pick_sequence_grasp_score)

        cam_execute_pick_sequence(SPEED_TRAVEL, SPEED_GRASP)
        SetDO(0, 1, 0, 1) WaitMs(300)
        move_l_joints(cam_approach_joints, SPEED_TRAVEL)   -- 같은 경로로 빠져나옴

        if pick_ok() then
            cam_report_pick_result(1)
            PTP(p2, SPEED_TRAVEL, -1, 0)
            SetDO(0, 0, 0, 1) WaitMs(300)
            break
        else
            SetDO(0, 0, 0, 1)
            cam_report_pick_result(0)
            found = cam_get_next_pick_sequence()
        end
    end

    if not found then
        popup("유효한 pick sequence 없음: " .. cam_msg, "cambrian")
    end
end
