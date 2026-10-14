-- ====================================================================
-- 01. 연결 테스트 (PING)                         ★ 실기 검증 1단계
-- Cambrian PC에 연결 → API 버전 보고 → PING → 버전 확인 → 세션 시작
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

-- ====================== 사용자 설정 ======================
local CAM_IP   = "192.168.58.100"   -- Cambrian VISION PC IP
local CAM_PORT = 4000

CAM_PRINT_REPLY = true   -- 모든 요청/응답을 출력 (디버깅용)
-- 영구 연결이 동작하지 않으면 아래 주석을 풀고 다시 실행 (명령마다 연결/해제)
-- CAM_PERSISTENT = false

-- ====================== 실행 ======================
if not cam_init(CAM_IP, CAM_PORT) then
    popup("Cambrian PC 연결 실패: " .. CAM_IP .. ":" .. CAM_PORT, "cambrian")
else
    -- 1) API 버전 보고 + PING + START SESSION + SET PREDICTION SPACE
    local ok = cam_startup("FLANGE")
    PrintMsg("startup: " .. tostring(ok))

    -- 2) 개별 명령으로도 확인 (영구 연결에서 연속 전송 테스트)
    for i = 1, 5 do
        PrintMsg("ping " .. i .. ": " .. tostring(cam_ping()))
    end

    local major, minor, patch = cam_get_version()
    PrintMsg("Cambrian UI version: " .. major .. "." .. minor .. "." .. patch)
    PrintMsg("compatible: " .. tostring(cam_check_compatibility()))
    PrintMsg("cameras ok: " .. tostring(cam_check_cameras()))

    popup("PING 성공 / Cambrian " .. major .. "." .. minor .. "." .. patch, "cambrian")
    cam_close()
end
