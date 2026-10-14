-- ====================================================================
-- 06. Rig(카메라) 포즈 확인
-- 캘리브레이션 결과로 나온 카메라 위치를 확인한다.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000

cam_init(CAM_IP, CAM_PORT)
cam_startup()

local function s(p) return string.format("%.2f, %.2f, %.2f, %.2f, %.2f, %.2f", p[1], p[2], p[3], p[4], p[5], p[6]) end

local rig_default = cam_get_rig_pose()      -- 마운트 기본 기준
local rig_flange  = cam_get_rig_pose(0)     -- flange 기준
local rig_base    = cam_get_rig_pose(1)     -- base 기준
local left        = cam_get_left_pose()     -- 왼쪽 카메라 (flange 기준)

PrintMsg("mount       : " .. cam_get_calibration_mount())
PrintMsg("rig default : " .. s(rig_default))
PrintMsg("rig flange  : " .. s(rig_flange))
PrintMsg("rig base    : " .. s(rig_base))
PrintMsg("left camera : " .. s(left))

popup("rig(flange) = " .. s(rig_flange) .. "\nrig(base) = " .. s(rig_base), "cambrian")
