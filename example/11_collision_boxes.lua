-- ====================================================================
-- 11. 충돌 요소 설정
-- 작업 공간 박스(빈), 3점/4점 박스, 그리퍼 박스, 블록 볼륨, CAD 컴포넌트
-- 크기는 mm로 입력 (라이브러리가 CAM_BOX_SIZE_SCALE(0.001)을 곱해 m로 전송)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP   = "192.168.58.100"
local CAM_PORT = 4000

cam_init(CAM_IP, CAM_PORT)
cam_startup()

cam_clear_collision_elements()

-- 1) 중심 포즈 + 크기로 빈 만들기: 400 x 300 x 200 mm, 벽 두께 10 mm (0 = 꽉 찬 박스)
cam_set_box("bin", {-400, 100, -100, 0, 0, 0}, 400, 300, 200, 10)

-- 2) 3점 박스: 위에서 볼 때 시계 방향으로 세 모서리 교시 → 깊이 200, 벽 10
--    ShowPos() 또는 cam_get_tcp_pose()로 읽은 값을 넣는다
local c1 = {-600,  -50, -100, 180, 0, 0}
local c2 = {-600,  250, -100, 180, 0, 0}
local c3 = {-200,  250, -100, 180, 0, 0}
cam_3_point_box("bin_3p", c1, c2, c3, 200, 10)

-- 3) 4점 박스
local c4 = {-200, -50, -100, 180, 0, 0}
cam_4_point_box("table_4p", c1, c2, c3, c4, 10)

-- 4) 그리퍼 박스 (flange 기준): 60 x 60 x 150 mm, flange에서 75 mm 아래 중심
cam_set_gripper_box("gripper", {0, 0, 75, 0, 0, 0}, 60, 60, 150)

-- 5) 블록 볼륨: 실패한 위치 주변 20 mm를 다음 3번의 예측에서 제외
cam_block_volume({-400, 100, -50, 0, 0, 0}, 20, 3)
-- cam_clear_block_volumes()

-- 6) CAD 컴포넌트 (Cambrian UI에 등록된 CAD 이름)
-- cam_spawn_component_world("fixture_cad", "fixture1", {-300, 0, -100, 0, 0, 0})
-- cam_disable_component_world("fixture1")

-- 7) 현재 자세 충돌 검사
PrintMsg("현재 TCP 충돌 없음: " .. tostring(cam_test_pose(cam_get_tcp_pose())))
PrintMsg("로봇 바디 모델: " .. tostring(cam_check_body()))
PrintMsg("관절 클리어런스 OK: " .. tostring(cam_test_clearance(cam_get_joints())))
