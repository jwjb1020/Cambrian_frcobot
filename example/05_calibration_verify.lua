-- ====================================================================
-- 05. 캘리브레이션 검증
-- MODE = "SAVE"   : 캘리브레이션 직후 기준 관측값을 저장 (p1~p3)
-- MODE = "VERIFY" : 나중에 같은 자세에서 다시 보고 오차를 확인
-- 판정 기준: 이동 2 mm, 회전 1 deg (TRANS_TOL / ROT_TOL)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP    = "192.168.58.100"
local CAM_PORT  = 4000
local MODE      = "VERIFY"     -- "SAVE" 또는 "VERIFY"
local NAME      = "default"    -- 검증 기록 이름
local TRANS_TOL = 2            -- mm
local ROT_TOL   = 1            -- deg
local SPEED     = 20

cam_init(CAM_IP, CAM_PORT)
cam_startup()

-- 보드가 보이는지 먼저 확인
local function check_board()
    WaitMs(500)
    local fl, pl, fr, pr = cam_locate_calibration_board(false)
    PrintMsg("board found L=" .. tostring(fl) .. " R=" .. tostring(fr) ..
          "  L=" .. pl[1] .. "," .. pl[2] .. "," .. pl[3])
end

local results = ""
local function step()
    check_board()
    if MODE == "SAVE" then
        local saved, idx = cam_save_calibration_verification(NAME, false)
        PrintMsg("saved=" .. tostring(saved) .. " index=" .. idx)
    else
        local r = cam_verify_calibration(NAME, TRANS_TOL, ROT_TOL)
        if r == nil then
            results = results .. "실행 불가: " .. cam_msg .. "\n"
        else
            results = results .. (r.pass and "PASS" or "FAIL") ..
                string.format("  L %.2fmm/%.2fdeg  R %.2fmm/%.2fdeg  flange %.2fmm/%.2fdeg\n",
                    r.left_dT, r.left_dR, r.right_dT, r.right_dR, r.flange_dT, r.flange_dR)
        end
    end
end

PTP(p1, SPEED, -1, 0) step()
PTP(p2, SPEED, -1, 0) step()
PTP(p3, SPEED, -1, 0) step()

if MODE == "SAVE" then
    local found, count = cam_get_calibration_verification_pose(NAME, 0)
    popup("검증 기준 저장 완료: " .. tostring(count) .. "개", "cambrian")
else
    PrintMsg(cam_get_verification_report(NAME))
    popup(results, "캘리브레이션 검증")
end
