-- ====================================================================
-- 20. 화장품 Pick & Place (블렌딩 없음, 모든 점에서 정지)  ※ legacy_v4_2/pickandplace_noblend.lua 의 v5 이식판
-- Cambrian VISION (Search Grid) + Fairino 로봇 + 공압 그리퍼(IO Output 0)
-- ====================================================================
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

-- ====================== 사용자 설정 (현장 환경에 맞게 수정) ======================
local CAM_IP     = "192.168.58.100"      -- Cambrian VISION PC IP
local CAM_PORT   = 4000
local MODEL_NAME = "cosmetic_wd400_fp"   -- Cambrian VISION에 등록된 모델 이름
local GRID_NAME  = "cosmetic_grid"       -- search grid 이름

-- p1(home) / p2(place): Fairino 교시 화면에서 저장한 점 이름.
-- PTP(점이름, ...)의 점 이름 자리는 변수가 아니라 리터럴로 직접 써야 함.

-- search grid 원점(좌상단) 촬영 자세 (mm, deg): ShowPos() 또는 cam_get_tcp_pose()로 읽은 값
local POSE_SEARCH_ORIGIN = {-295.124,131.456,127.254,-178.521,-1.344,-86.476}

-- 공압 그리퍼/흡착 (IO Output 0번)
local GRIP_DO        = 0
local GRIP_ON_DELAY  = 300   -- ms
local GRIP_OFF_DELAY = 300   -- ms

-- 이동 속도 (%)
local SPEED_SEARCH   = 30
local SPEED_APPROACH = 40
local SPEED_GRASP    = 10
local SPEED_PLACE    = 30

-- 접근 오프셋 (mm): cam_approach(pose, grasp_offset, app, preapp, exit)
local GRASP_OFFSET = {0,0,10,0,0,0}
local APP_DIST     = 50
local PREAPP_DIST  = 100
local EXIT_DIST    = 80

-- 블렌딩 없음: -1 = 각 점에서 완전 정지 (21번 예제가 블렌딩 버전)
local OACC_SCALE = 100   -- SetOaccScale(%)
local BLEND_R    = -1
local BLEND_T    = -1

-- grasp_type == 3 (쓰러뜨려야 하는 자세): 공압 없이 옆으로 밀어서 자세를 바꿈
local TOPPLE_OFFSET    = {0,0,10,0,0,0}
local TOPPLE_PUSH_DIST = -30    -- mm, 접촉점 로컬 X축 기준

-- Search grid (mm). MAX_Z/Z_STEP: 못 찾을 때마다 Z_STEP씩 내려가고 MAX_Z에서 셀 완료
local GRID_X_CELLS = 2
local GRID_Y_CELLS = 2
local GRID_MAX_Z   = 40
local GRID_CELL_X  = 150
local GRID_CELL_Y  = 150
local GRID_Z_STEP  = 5
local GRID_BLOCK_ITERATIONS = 3   -- 못 찾은 셀을 N번 후보에서 제외

-- 서버가 예측 시 그리드를 자동 갱신(autoUpdateSearchGridOnPrediction)하면 false 유지.
-- 자동 갱신을 끈 경우에만 true (중복 호출 시 "redundant SEARCH GRID UPDATE" 경고)
local GRID_MANUAL_UPDATE = false

-- ====================== 그리퍼 ======================
local function gripper_grip()    SetDO(GRIP_DO, 1, 0, 1) WaitMs(GRIP_ON_DELAY)  end
local function gripper_release() SetDO(GRIP_DO, 0, 0, 1) WaitMs(GRIP_OFF_DELAY) end

-- ====================== 초기화 ======================
SetOaccScale(OACC_SCALE)

cam_init(CAM_IP, CAM_PORT)
cam_startup("FLANGE")

if not cam_check_cameras() then
    popup("카메라가 연결되지 않았습니다. 확인 후 계속하세요.", "cambrian")
end

cam_load_model_and_wait(MODEL_NAME)

-- 같은 이름이 있으면 자동 리셋됨
cam_search_grid_init(GRID_NAME, POSE_SEARCH_ORIGIN,
    GRID_X_CELLS, GRID_Y_CELLS, GRID_MAX_Z, GRID_CELL_X, GRID_CELL_Y, GRID_Z_STEP)

PTP(p1, SPEED_SEARCH, BLEND_T, 0)   -- home

-- ====================== 메인 루프 ======================
while true do
    if cam_search_grid_finished(GRID_NAME) then
        popup("화장품 박스가 비었습니다. 채운 후 계속을 누르세요.", "cambrian")
        cam_search_grid_reset(GRID_NAME)
    end

    local search_pose, cell_x, cell_y = cam_search_grid_get_next(GRID_NAME)

    if search_pose ~= nil then
        move_j(search_pose, SPEED_SEARCH, BLEND_T)

        local found = cam_get_prediction(MODEL_NAME)
        if GRID_MANUAL_UPDATE then cam_search_grid_update(GRID_NAME) end

        if found then
            if cam_grasp_type == 3 then
                -- 쓰러뜨리기: 접촉 지점에서 옆으로 밀고 빠져나옴 (픽 아님 → report 없이 같은 셀 재스캔)
                local push_p, push_app, push_preapp =
                    cam_approach(cam_grasp_pose, TOPPLE_OFFSET, APP_DIST, PREAPP_DIST, EXIT_DIST)
                local push_end  = cam_offset_pose(push_p, TOPPLE_PUSH_DIST, 0, 0)
                local push_exit = cam_offset_pose(push_end, 0, 0, -20)
                move_j(push_preapp, SPEED_APPROACH, BLEND_T)
                move_l(push_app,    nil, SPEED_APPROACH, BLEND_R)
                move_l(push_p,      nil, SPEED_GRASP)
                move_l(push_end,    nil, SPEED_GRASP)
                move_l(push_exit,   nil, SPEED_APPROACH, BLEND_R)
            else
                local grasp_p, app_p, preapp_p, exit_p =
                    cam_approach(cam_grasp_pose, GRASP_OFFSET, APP_DIST, PREAPP_DIST, EXIT_DIST)

                move_j(preapp_p, SPEED_APPROACH, BLEND_T)       -- pre-approach
                move_l(app_p,    nil, SPEED_APPROACH, BLEND_R)  -- approach
                move_l(grasp_p,  nil, SPEED_GRASP)              -- grasp (정지)

                gripper_grip()

                move_l(exit_p, nil, SPEED_APPROACH, BLEND_R)    -- retreat

                cam_search_grid_report(GRID_NAME, cell_x, cell_y, 1)
                cam_report_pick_result(1)

                PTP(p2, SPEED_PLACE, -1, 0)                     -- place (정지)
                gripper_release()

                PTP(p1, SPEED_SEARCH, BLEND_T, 0)               -- home
            end
        else
            -- 못 찾은 셀은 N번 동안 제외 → 다음 GET NEXT는 다른 셀
            cam_search_grid_block(GRID_NAME, cell_x, cell_y, GRID_BLOCK_ITERATIONS)
        end
    else
        popup("Search grid 응답 오류 - 연결을 확인하세요. " .. cam_msg, "cambrian")
    end
end
