-- ====================================================================
-- 19. 로봇 기구학 캘리브레이션 (서버 IK 정확도 향상)
-- 현재 관절값 주변의 여러 관절 자세로 이동하며 샘플을 보낸다 (최소 10, 권장 20+).
-- 샘플 = 각 자세에서의 관절값 + flange 포즈 (요청마다 자동 전송됨)
-- 끝나면 START ROBOT CALIBRATION (최대 60초) → CHECK → 서버 FK와 로봇 FK 비교.
-- ※ 주변에 장애물이 없는 곳에서, 처음엔 RANGE를 작게 두고 실행할 것
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000
local SAMPLES  = 20
local RANGE    = {20, 15, 15, 30, 30, 45}   -- 각 관절 ±deg
local SPEED    = 20
local SERIAL   = nil                         -- 로봇 시리얼 (선택)

cam_init(CAM_IP, CAM_PORT)
cam_startup()

PTP(p1, SPEED, -1, 0)
local center = cam_get_joints()
math.randomseed(12345)

local sent = 0
for k = 1, SAMPLES do
    local j = {}
    for a = 1, 6 do
        j[a] = center[a] + (math.random() * 2 - 1) * RANGE[a]
    end
    if cam_test_clearance(j) then
        move_joints(j, SPEED)
        WaitMs(300)
        if cam_send_robot_calibration_data() then sent = sent + 1 end
        PrintMsg("sample " .. sent .. "/" .. SAMPLES)
    else
        PrintMsg("skip (collision): " .. j[1] .. ", " .. j[2] .. ", " .. j[3])
    end
end

move_joints(center, SPEED)

if sent < 10 then
    popup("샘플이 부족합니다: " .. sent, "cambrian")
else
    cam_start_robot_calibration(SERIAL)
    if cam_check_robot_calibration() then
        -- 검증: 현재(center) 자세에서 서버 FK(TCP)와 로봇 실제 TCP 비교
        local tcp = cam_get_tcp_pose()
        local sp  = cam_get_fk(cam_get_joints(), true)
        popup(string.format("로봇 캘리브레이션 완료 (%d 샘플)\nFK 차이: %.2f, %.2f, %.2f mm",
            sent, sp[1] - tcp[1], sp[2] - tcp[2], sp[3] - tcp[3]), "cambrian")
    else
        popup("로봇 캘리브레이션 실패: " .. cam_msg, "cambrian")
    end
end
