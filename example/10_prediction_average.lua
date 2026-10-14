-- ====================================================================
-- 10. 예측 평균 (정밀 픽)
-- 같은 부품을 여러 자세에서 예측해 평균 포즈를 구한다 (최대 20개).
-- threshold(mm) 안에 들어오는 예측만 평균에 포함된다.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP     = "192.168.58.100"
local CAM_PORT   = 4000
local MODEL_NAME = "my_model"
local THRESHOLD  = 5        -- mm
local SPEED      = 30

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

cam_start_prediction_average(THRESHOLD, "BASE")

PTP(p1, SPEED, -1, 0) cam_get_prediction(MODEL_NAME)
PTP(p2, SPEED, -1, 0) cam_get_prediction(MODEL_NAME)
PTP(p3, SPEED, -1, 0) cam_get_prediction(MODEL_NAME)

if cam_end_prediction_average() then
    local p = cam_avg_grasp_pose
    PrintMsg(string.format("평균 포즈: %.2f %.2f %.2f %.2f %.2f %.2f", p[1], p[2], p[3], p[4], p[5], p[6]))
    local app = cam_offset_pose(p, 0, 0, -50)
    move_j(app, SPEED)
    move_l(p, nil, 10)
    move_l(app, nil, SPEED)
else
    popup("평균을 구할 수 없습니다 (유효 예측 없음).", "cambrian")
end
