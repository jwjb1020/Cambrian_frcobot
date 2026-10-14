-- ====================================================================
-- 13. 서치 그리드 자동 초기화 + 그리드 캘리브레이션 + 층(layer) 관리
-- 1) 월드 박스("bin")와 모델 시야로 셀 크기를 자동 계산
-- 2) 그리드 캘리브레이션: 서버가 알려주는 자세로 이동하며 높이 학습 (0 반환 시 완료)
-- 3) 간지(separator sheet)가 있는 적층 박스: 층 수 지정, 층이 끝나면 간지 제거 후 NEXT LAYER
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

local CAM_IP     = "192.168.58.100"
local CAM_PORT   = 4000
local MODEL_NAME = "my_model"
local GRID_NAME  = "grid_auto"
local LAYERS     = 3
local SPEED_TRAVEL, SPEED_GRASP = 30, 10

cam_init(CAM_IP, CAM_PORT)
cam_startup()
cam_load_model_and_wait(MODEL_NAME)

-- 빈 박스 정의 (예제 11 참고)
cam_set_box("bin", {-400, 100, -100, 0, 0, 0}, 400, 300, 200, 10)

-- 1) 자동 초기화: 회전 0, 시야 80% 사용, 셀 겹침 10%
local xc, yc = cam_search_grid_auto_init(GRID_NAME, "bin", MODEL_NAME, 0, 0.8, 0.1)
PrintMsg("grid " .. xc .. " x " .. yc)

-- 모드 1, 층 필터 두께 15 mm (m 단위)
cam_search_grid_set_mode(GRID_NAME, 1, 0.015)

-- 2) 그리드 캘리브레이션 (thorough = 1)
while cam_search_grid_calibrate(GRID_NAME, 1, MODEL_NAME) do
    move_j(cam_searchgrid_pose, SPEED_TRAVEL)
end

-- 3) 층 수 지정 (hold = 1: 층 경계에서 멈춤)
cam_search_grid_set_layer_count(GRID_NAME, LAYERS, 1)

while true do
    local st = cam_search_grid_get_layer_state(GRID_NAME)
    if st ~= nil then
        PrintMsg("layer " .. st.layer_index .. "/" .. st.expected_layers .. " cells left " .. st.cells_remaining)
        if st.grid_finished then
            popup("모든 층 완료. 박스를 교체하세요.", "cambrian")
            cam_search_grid_reset(GRID_NAME)
        elseif st.boundary_held then
            popup("층 완료. 간지를 제거한 뒤 계속을 누르세요.", "cambrian")
            cam_search_grid_next_layer(GRID_NAME)
        end
    end

    local pose, i, j = cam_search_grid_get_next(GRID_NAME)
    if pose ~= nil then
        move_j(pose, SPEED_TRAVEL)
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
            cam_search_grid_report(GRID_NAME, i, j, 0)
        end
    end
end
