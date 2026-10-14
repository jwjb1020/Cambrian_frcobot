-- ====================================================================
-- 22. popup 사용법
-- 호스트 PC의 gui_popup_server.py로 메시지 창을 띄우고, 작업자의 Continue/Stop을 기다린다.
-- 먼저 호스트 PC에서 실행: python gui_popup_server.py  (README "팝업 서버 설정" 참고)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

-- ====================== 사용자 설정 ======================
POPUP_SERVER_IP   = "192.168.58.1"   -- gui_popup_server.py를 실행한 PC의 IP (로봇과 같은 네트워크)
POPUP_SERVER_PORT = 9999             -- gui_popup_server.py의 PORT와 같게
POPUP_ENABLE      = true             -- false: 창을 띄우지 않고 WebApp print 창에만 출력 (대기 없음)

local CAM_IP   = "192.168.58.100"    -- Cambrian VISION PC IP
local CAM_PORT = 4000
local SPEED    = 20

-- ====================== 실행 ======================

-- 1) 단순 알림. Continue를 누를 때까지 로봇 스크립트가 멈춰 있다.
--    Stop을 누르면 error()로 스크립트가 즉시 종료된다.
popup("popup 테스트를 시작합니다.", "22_popup")

-- 2) 숫자, 테이블도 그대로 넘길 수 있다 (테이블은 {a, b, c} 형태 문자열로 표시).
popup({GetActualTCPPose()},        "현재 TCP 포즈")
popup({GetActualJointPosDegree()}, "현재 관절 각도 (deg)")
popup(cam_get_tcp_pose(),          "cam_get_tcp_pose()")

-- 3) 위험한 동작 전 작업자 확인. Stop이면 여기서 끝나므로 아래 이동은 실행되지 않는다.
local home = cam_get_tcp_pose()
local up   = {home[1], home[2], home[3] + 50, home[4], home[5], home[6]}   -- 베이스 기준 Z +50 mm
popup("베이스 기준 Z +50 mm 위로 이동했다가 돌아옵니다.\n주변을 확인한 뒤 Continue를 누르세요.", "이동 확인")
move_l(up, nil, SPEED)
move_l(home, nil, SPEED)

-- 4) Cambrian 연결 실패 등 오류 안내
if not cam_init(CAM_IP, CAM_PORT) then
    popup("Cambrian PC 연결 실패: " .. CAM_IP .. ":" .. CAM_PORT, "cambrian")
else
    -- 5) CAM_POPUP_ON_ERROR = true(기본값)면 서버가 ERROR를 돌려줄 때 라이브러리가 자동으로 popup을 띄운다.
    --    일부러 없는 모델을 내려서 확인: 창 제목은 "Cambrian ERROR: UNLOAD MODEL"
    cam_request("UNLOAD MODEL", "model_that_does_not_exist")

    -- 자동 popup을 끄고 직접 처리하려면 false로 두고 cam_code / cam_msg를 확인한다.
    CAM_POPUP_ON_ERROR = false
    cam_request("UNLOAD MODEL", "model_that_does_not_exist")
    if cam_code == 1 then
        popup("직접 처리한 오류: " .. cam_msg, "cambrian")
    end
    CAM_POPUP_ON_ERROR = true

    cam_close()
end

-- 6) POPUP_ENABLE = false면 창 없이 WebApp print 창에 "[POPUP] 제목: 내용"으로만 남고 바로 진행한다.
POPUP_ENABLE = false
popup("이 메시지는 창 없이 print 창에만 출력됩니다.", "22_popup")
POPUP_ENABLE = true

popup("popup 테스트 완료", "22_popup")
