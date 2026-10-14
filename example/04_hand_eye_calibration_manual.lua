-- ====================================================================
-- 04. Hand-eye 캘리브레이션 (수동)
-- 교시점 p1~p20을 차례로 돌며 보드 이미지를 캡처한 뒤 계산한다.
-- Cambrian 본사 권장: 16장 이상 (이 예제는 20장)
-- 로봇 자세는 매 요청마다 자동으로 전송되므로 따로 보낼 필요가 없다.
-- 교시점 팁: 보드가 화면 가장자리/모서리에도 오도록, 기울기(±15~30°)와 높이를 다양하게
-- ※ Fairino는 PTP(변수)가 불가하므로 교시점을 하나씩 직접 쓴다.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000
local MOUNT    = "FLANGE"   -- "FLANGE" 또는 "BASE"
local SPEED    = 20
local SETTLE   = 500        -- ms, 이동 후 진동 안정화 대기

cam_init(CAM_IP, CAM_PORT)
cam_startup()

cam_set_calibration_mount(MOUNT)
cam_new_calibration()

local captured = 0
local function capture()
    WaitMs(SETTLE)
    if cam_capture_calibration_image() then
        captured = captured + 1
        PrintMsg("captured " .. captured .. ": " .. cam_msg)
    else
        PrintMsg("capture failed: " .. cam_msg)
    end
end

PTP(p1, SPEED, -1, 0)  capture()
PTP(p2, SPEED, -1, 0)  capture()
PTP(p3, SPEED, -1, 0)  capture()
PTP(p4, SPEED, -1, 0)  capture()
PTP(p5, SPEED, -1, 0)  capture()
PTP(p6, SPEED, -1, 0)  capture()
PTP(p7, SPEED, -1, 0)  capture()
PTP(p8, SPEED, -1, 0)  capture()
PTP(p9, SPEED, -1, 0)  capture()
PTP(p10, SPEED, -1, 0) capture()
PTP(p11, SPEED, -1, 0) capture()
PTP(p12, SPEED, -1, 0) capture()
PTP(p13, SPEED, -1, 0) capture()
PTP(p14, SPEED, -1, 0) capture()
PTP(p15, SPEED, -1, 0) capture()
PTP(p16, SPEED, -1, 0) capture()
PTP(p17, SPEED, -1, 0) capture()
PTP(p18, SPEED, -1, 0) capture()
PTP(p19, SPEED, -1, 0) capture()
PTP(p20, SPEED, -1, 0) capture()

PTP(p1, SPEED, -1, 0)

-- 캡처 실패로 권장 장수(16장)보다 적으면 알림. Continue를 누르면 그대로 계산한다.
if captured < 16 then
    popup("캡처 " .. captured .. "장: 권장 16장보다 적습니다.\n교시점을 확인하세요.", "cambrian")
end

if cam_run_manual_calibration() then
    popup("수동 캘리브레이션 완료 (" .. captured .. "장)\n" .. cam_msg, "cambrian")
else
    popup("수동 캘리브레이션 실패: " .. cam_msg, "cambrian")
end
