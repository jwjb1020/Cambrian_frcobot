-- ====================================================================
-- 12. 서치 그리드 + 예측
-- 박스를 X x Y 셀로 나누고 서버가 정해주는 다음 셀로 이동해 예측한다.
-- 못 찾은 셀은 BLOCK으로 N회 제외, 모든 셀이 끝나면 작업자 확인 후 RESET.
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP     = "192.168.58.100"
local CAM_PORT   = 4000
local MODEL_NAME = "my_model"
local GRID_NAME  = "grid1"

-- 그리드 원점(좌상단) 촬영 자세 (mm, deg) - ShowPos()로 읽은 값
local GRID_ORIGIN = {-295.124, 131.456, 127.254, -178.521, -1.344, -86.476}
local X_CELLS, Y_CELLS = 2, 2
local MAX_Z   = 40      -- mm, 탐색 허용 깊이
local CELL_X  = 150     -- mm
local CELL_Y  = 150     -- mm
local Z_STEP  = 5       -- mm, 1회 미검출 시 하강량
local BLOCK_N = 3
local SPEED_TRAVEL, SPEED_GRASP = 30, 10

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

cam_search_grid_init(GRID_NAME, GRID_ORIGIN, X_CELLS, Y_CELLS, MAX_Z, CELL_X, CELL_Y, Z_STEP)

while true do
    if cam_search_grid_finished(GRID_NAME) then
        popup("박스가 비었습니다. 채운 후 계속을 누르세요.", "cambrian")
        cam_search_grid_reset(GRID_NAME)
    end

    local pose, i, j = cam_search_grid_get_next(GRID_NAME)
    if pose == nil then
        popup("서치 그리드 응답 오류: " .. cam_msg, "cambrian")
    else
        move_j(pose, SPEED_TRAVEL)
        -- 서버가 예측 시 그리드를 자동 갱신하므로 SEARCH GRID UPDATE는 호출하지 않는다
        if cam_get_prediction(MODEL_NAME) then
            local grasp, app = cam_approach(cam_grasp_pose, nil, 50, 0, 50)
            move_j(app, SPEED_TRAVEL)
            move_l(grasp, nil, SPEED_GRASP)
            SetDO(0, 1, 0, 1) WaitMs(300)
            move_l(app, nil, SPEED_TRAVEL)

            cam_search_grid_report(GRID_NAME, i, j, 1)
            cam_report_pick_result(1)

            PTP(p2, SPEED_TRAVEL, -1, 0)
            SetDO(0, 0, 0, 1) WaitMs(300)
        else
            cam_search_grid_block(GRID_NAME, i, j, BLOCK_N)
        end
    end
end
