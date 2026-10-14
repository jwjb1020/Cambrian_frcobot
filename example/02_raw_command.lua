-- ====================================================================
-- 02. cam_request() 직접 호출
-- 래퍼 함수가 없는 명령도 cam_request("명령", 인자...) 한 줄로 보낼 수 있다.
--   · '#' 구분자, 현재 flange/관절/툴 오프셋, '<<' 종료자는 자동으로 붙음
--   · 인자는 '*'로 연결됨 (nil = 빈 칸)
--   · 6개짜리 테이블 → "[x,y,z,rx,ry,rz]",  cam_list({1,3}) → "1,3"
--   · 반환: code(0 OK,1 ERROR,2 WARNING,3 PRINT,-1 응답없음), msg, data(문자열 배열)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP     = "192.168.58.100"
local CAM_PORT   = 4000
local MODEL_NAME = "my_model"

CAM_PRINT_REPLY = true
cam_init(CAM_IP, CAM_PORT)

-- 1) 인자 없는 명령:  PING##[flange]#[joints]#[tool]#<<
local code, msg, data = cam_request("PING")
PrintMsg("PING code=" .. code .. " msg=" .. msg .. " data[1]=" .. tostring(data[1]))

-- 2) 숫자 응답 읽기: cam_num(i) = i번째 DATA 값을 숫자로
cam_request("GET VERSION")
PrintMsg("version = " .. cam_num(1) .. "." .. cam_num(2) .. "." .. cam_num(3))

-- 3) 여러 인자:  GET PREDICTION#my_model*1,3**0
cam_request("GET PREDICTION", MODEL_NAME, cam_list({1, 3}), nil, 0)
if cam_code == 0 and cam_num(1) == 1 then
    local rel = cam_pose_at(2)                               -- flange 기준 포즈 (DATA 2~7)
    local world = cam_pose_trans(cam_last_flange_pose, rel)  -- base 기준으로 변환
    PrintMsg("grasp(base) = " .. world[1] .. ", " .. world[2] .. ", " .. world[3])
    PrintMsg("type = " .. cam_num(8) .. "  score = " .. cam_num(9))
end

-- 4) 포즈 인자:  TEST POSE#[x,y,z,rx,ry,rz]
cam_request("TEST POSE", cam_get_tcp_pose())
PrintMsg("현재 자세 충돌 없음: " .. tostring(cam_num(1) == 1))

-- 5) DATA를 직접 만들어 보내기 (구분자가 '*'가 아닌 명령)
cam_raw("SET ADVANCED CONFIG", "rrtClearanceM,0.01")
cam_request("GET ADVANCED CONFIG", "rrtClearanceM")
PrintMsg("rrtClearanceM = " .. cam_data_str)

-- 6) 오류 응답 처리: code 1이면 자동으로 print/popup.
--    CAM_STOP_ON_ERROR = true 로 두면 오류 시 스크립트 정지
cam_request("UNLOAD MODEL", "model_that_does_not_exist")
PrintMsg("code=" .. cam_code .. " msg=" .. cam_msg)
