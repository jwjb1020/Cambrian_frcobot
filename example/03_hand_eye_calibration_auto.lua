-- ====================================================================
-- 03. Hand-eye 캘리브레이션 (자동)                 ★ 실기 검증 2단계
-- 서버가 캘리브레이션 자세를 하나씩 알려주면 로봇이 이동한다.
--   step 0: 대기 / 1: 이동 / 2: 완료 / 3: 도달 가능 여부 회신
-- 준비:
--   · 캘리브레이션 보드를 작업대에 고정
--   · p1 = 카메라가 보드를 정면에서 내려다보는 시작 자세 (교시점)
--   · Cambrian UI에서 rig/카메라 설정 완료
-- 주의: 캘리브레이션 자세는 현재 툴(TCP) 기준으로 이동한다.
--       처음에는 속도를 낮게 두고 비상정지 버튼을 잡고 실행할 것
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

-- ====================== 사용자 설정 ======================
local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000

local MOUNT    = "FLANGE"              -- "FLANGE" = 로봇 장착 카메라, "BASE" = 고정 카메라
-- flange 기준 rig(카메라) 대략 위치 (mm, deg). FLANGE 마운트에서만 사용
local RIG_POSE = {0, -50, 50, 0, 0, 180}
local FOCAL_LENGTH      = 8       -- mm (표준 rig 8)
local STEREO_SEPARATION = 0.08    -- m  (표준 0.08, 소형 0.06)
local CAMERA_TILT       = 5       -- deg (표준 5, 소형 8)
local SPEED             = 20      -- %

CAM_PRINT_REPLY = true

-- ====================== 실행 ======================
cam_init(CAM_IP, CAM_PORT)
cam_startup()

if not cam_check_cameras() then
    popup("카메라가 연결되지 않았습니다.", "cambrian")
end

PTP(p1, SPEED, -1, 0)   -- 시작 자세 (교시점 이름을 직접 써야 함)

cam_set_calibration_mount(MOUNT)
PrintMsg("mount = " .. cam_get_calibration_mount())

local ok = cam_auto_calibration(RIG_POSE, FOCAL_LENGTH, STEREO_SEPARATION, CAMERA_TILT, SPEED)

PTP(p1, SPEED, -1, 0)

if ok then
    local rig = cam_get_rig_pose()
    popup("캘리브레이션 완료\nrig pose = " .. rig[1] .. ", " .. rig[2] .. ", " .. rig[3] ..
          ", " .. rig[4] .. ", " .. rig[5] .. ", " .. rig[6], "cambrian")
else
    popup("캘리브레이션 실패: " .. cam_msg, "cambrian")
end
