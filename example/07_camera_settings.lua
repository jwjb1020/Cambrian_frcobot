-- ====================================================================
-- 07. 카메라 노출 설정
-- 자동 노출 파라미터 → 수동 노출/게인 → HDR → 다시 자동
-- ※ START SESSION은 저장하지 않은 카메라 설정을 되돌리므로 설정은 세션 시작 뒤에 한다.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000

cam_init(CAM_IP, CAM_PORT)
cam_startup()

if not cam_check_cameras() then
    PrintMsg("카메라 재시작")
    cam_restart_cameras()
end

-- 1) 자동 노출: 목표 밝기 120, 허용 오차 10, 반복 5, 최대 노출 30000 us
cam_cameras_auto()
cam_cameras_auto_params(120, 10, 5, 30000)
local t, tol, it, mx = cam_get_camera_auto_params()
PrintMsg("auto params: " .. t .. ", " .. tol .. ", " .. it .. ", " .. mx)

-- 2) 수동 노출
cam_cameras_manual()
cam_cameras_exposure(15000)
cam_cameras_gain(2)
PrintMsg("mode=" .. cam_get_camera_mode() .. " exposure=" .. cam_get_camera_exposure() ..
      " gain=" .. cam_get_camera_gain())

-- 3) HDR (반사가 심한 부품)
-- cam_cameras_hdr()
-- cam_cameras_hdr_params(2, 3, 1, "")

-- 4) 다시 자동
cam_cameras_auto()
PrintMsg("mode=" .. cam_get_camera_mode())

-- 라이브 뷰 (예측 요청이 오면 자동으로 꺼짐)
cam_enable_liveview()
