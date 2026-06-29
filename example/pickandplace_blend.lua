-- ====================================================================
-- 화장품 Pick & Place
-- Cambrian VISION (Search Grid) + Fairino 로봇 + 공압 그리퍼(IO Output 0)
-- ====================================================================
-- package.path = package.path .. ";/usr/local/etc/controller/lua/?.lua"
package.path = package.path .. ";/root/web/file/user/?.lua"
require("FairinoForCambrian_v4_2")
set_connection_info("192.168.58.100", 4000)   -- Cambrian VISION PC IP:Port

-- ====================== 사용자 설정 (현장 환경에 맞게 수정) ======================
local MODEL_NAME = "cosmetic_wd400_fp"   -- Cambrian VISION에 등록된 모델 이름
local GRID_NAME  = "cosmetic_grid"     -- search grid 이름

-- p_home / p_place : Fairino 교시(teaching) 화면에서 미리 저장해 둔 점 이름.
-- PTP(point_name, ovl, blendT, offset_flag)로 이름 그대로 이동하므로 좌표를 옮겨 적을 필요 없음.
-- 주의: point_name 자리는 변수가 아니라 저장된 이름을 코드에 직접(리터럴로) 써야 함
-- (Fairino가 저장 시점에 교시점 이름을 정적으로 해석하기 때문). 아래 PTP(p_home,...) /
-- PTP(p_place,...) 호출부의 p_home / p_place를 실제 저장한 이름으로 바꿔서 사용하세요.

-- POSE_SEARCH_ORIGIN은 search grid 초기화에 실제 좌표값이 필요하므로(이름 참조 불가),
-- 로봇을 직접 jog하여 ShowPos() 또는 GetActualTCPPose()로 읽은 값을
-- {x, y, z, rx, ry, rz} (mm, deg) 형식으로 입력하세요.
local POSE_SEARCH_ORIGIN = {-295.124,131.456,127.254,-178.521,-1.344,-86.476}   -- search grid 원점(좌상단), 박스를 내려보는 자세

-- 공압 그리퍼/흡착 (IO Output 0번)
local GRIP_DO        = 0
local GRIP_ON_DELAY  = 300   -- ms, 파지(흡착) 후 안정화 대기
local GRIP_OFF_DELAY = 300   -- ms, 릴리즈 후 대기

-- 이동 속도 (%)
local SPEED_SEARCH   = 30   -- search grid 위치로 이동
local SPEED_APPROACH = 40   -- pre-approach / approach
local SPEED_GRASP    = 10   -- 그립 포인트 진입
local SPEED_PLACE    = 30   -- place 위치로 이동

-- 접근 오프셋 (mm)
-- cambrian_approach(pred_pose, grasp_offset, app_dist, preapp_dist, exit_dist)
local GRASP_OFFSET = {0,0,10,0,0,0}  -- 그립 포인트 기준 오프셋
local APP_DIST      = 50    -- approach distance
local PREAPP_DIST    = 100   -- pre-approach distance
local EXIT_DIST       = 80    -- retreat distance

-- 모션 블렌딩 / 가속 파라미터 (이동 구간 고속화, 접촉 지점은 영향 없음)
local OACC_SCALE = 90    -- SetOaccScale(%) - 전역 가속도 스케일 (0-100)
local BLEND_R    = 20    -- mm, MoveL 기반 travel move의 smooth corner radius (0-1000)
                         -- APP_DIST=50 / PREAPP_DIST=100 / EXIT_DIST=80보다 충분히 작게 설정
local BLEND_T    = 100   -- ms, MoveJ/PTP 기반 travel move의 smooth blend time (0-500)

-- grasp_type == 3 (쓰러뜨려야 하는 부적합 자세): 공압 없이 옆으로 밀어서 자세를 바꿈
local TOPPLE_OFFSET    = {0,0,10,0,0,0}  -- 예측 중심 기준 접촉 지점 오프셋 (mm/deg)
local TOPPLE_PUSH_DIST = -30               -- 접촉 지점에서 밀어내는 거리 (mm, 접촉점 로컬 X축 기준)

-- Search grid 파라미터 (mm) — 실제 박스/트레이 크기에 맞게 수정
local GRID_X_CELLS = 2
local GRID_Y_CELLS = 2
-- 서버는 한 셀에서 물체를 못 찾을 때마다 깊이를 Z_STEP만큼 전진시키고,
-- 깊이가 MAX_Z에 도달하면 그 셀은 "완료(최소 높이)"로 처리됨.
-- 단일 층이라 깊이 자체는 의미 없고 "한 번 못 찾으면 그 셀 완료" 정도만 필요하므로
-- MAX_Z == Z_STEP (1회 미검출 = 해당 셀 완료)로 설정.
-- (0은 서버가 "invalid values"로 거부하므로 반드시 양수)
local GRID_MAX_Z    = 40    -- POSE_SEARCH_ORIGIN 기준 탐색 허용 깊이
local GRID_CELL_X   = 150   -- 셀 가로 크기
local GRID_CELL_Y   = 150   -- 셀 세로 크기
local GRID_Z_STEP    = 5   -- 1회 미검출 시 전진량 (MAX_Z와 동일 = 1회 미검출로 셀 완료)

-- 한 셀에서 물체를 못 찾으면 SEARCH GRID BLOCK으로 그 셀을 N번 동안 후보에서 제외시켜
-- GET NEXT가 무조건 다른 셀을 반환하게 함 (Mode 0의 가중치 스코어링에 의존하지 않는
-- 확정적인 방법 - FANUC 공식 예제(Example 06)와 동일 패턴)
local GRID_BLOCK_ITERATIONS = 3

-- ====================== 로컬 블렌드 이동 헬퍼 (travel move 전용, 본 파일 한정) ======================
-- move_l/move_j(공유 라이브러리)는 blendR/blendT를 -1(완전 정지)로 고정하므로 건드리지 않고,
-- 이 파일 안에서만 쓰는 "부드러운 전환" 버전을 별도로 둔다.
-- 그립/접촉/배치 등 정밀 정지가 필요한 지점은 기존 move_l/move_j/PTP를 그대로 사용한다.

-- MoveL 기반 직선 travel move (smooth blend, BLEND_R 적용)
function move_l_blend(dPos, tool, speed, blendR)
    local x,y,z,rx,ry,rz = dPos[1],dPos[2],dPos[3],dPos[4],dPos[5],dPos[6]
    local j1,j2,j3,j4,j5,j6 = GetInverseKin(0, x, y, z, rx, ry, rz, -1)
    local t   = tool  or GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    local br  = blendR or BLEND_R
    MoveL(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100,br,0,0,0,0, -1,0,0,0,0,0,0,0)
end

-- MoveJ 기반 관절공간 travel move (smooth blend, BLEND_T 적용)
function move_j_blend(dPos, speed, blendT)
    local x,y,z,rx,ry,rz = dPos[1],dPos[2],dPos[3],dPos[4],dPos[5],dPos[6]
    local j1,j2,j3,j4,j5,j6 = GetInverseKin(0, x,y,z,rx,ry,rz, -1)
    local t   = GetActualTCPNum()
    local usr = GetActualWObjNum()
    local spd = speed or 30
    local bt  = blendT or BLEND_T
    MoveJ(j1,j2,j3,j4,j5,j6, x,y,z,rx,ry,rz,
          t,usr,spd,180,100, 0,0,0,0, bt,0, 0,0,0,0,0,0)
end

-- ====================== 공압 그리퍼 제어 ======================
-- SetDO(id, status, smooth, thread): id=IO 번호, status=0/1, smooth=0(즉시)/1(서서히), thread=0/1
function gripper_grip()
    SetDO(GRIP_DO, 1, 0, 1)
    WaitMs(GRIP_ON_DELAY)
end

function gripper_release()
    SetDO(GRIP_DO, 0, 0, 1)
    WaitMs(GRIP_OFF_DELAY)
end

-- ====================== 초기화 ======================
SetOaccScale(OACC_SCALE)   -- 전역 가속도 스케일 적용 (이동 구간 고속화)

if cambrian_check_cameras() ~= 1 then
    popup("카메라가 연결되지 않았습니다. 확인 후 계속하세요.", "cambrian")
end

cambrian_load_model(MODEL_NAME)
cambrian_wait_for_model_launch(MODEL_NAME)

-- search grid 원점(POSE_SEARCH_ORIGIN)을 기준으로 그리드 생성 (동일 이름이 있으면 자동 리셋됨)
cambrian_search_grid_init(GRID_NAME, POSE_SEARCH_ORIGIN,
    GRID_X_CELLS, GRID_Y_CELLS, GRID_MAX_Z,
    GRID_CELL_X, GRID_CELL_Y, GRID_Z_STEP)

PTP(p1, SPEED_SEARCH, BLEND_T, 0)   -- p_home: 저장된 교시점 이름으로 교체

-- ====================== 메인 루프 ======================
while true do

    -- 그리드를 모두 탐색했으면(=박스가 비었을 확률 높음) 작업자 확인 후 리셋
    if cambrian_search_grid_finished(GRID_NAME) == 1 then
        popup("화장품 박스가 비었습니다. 채운 후 계속을 누르세요.", "cambrian")
        cambrian_search_grid_reset(GRID_NAME)
    end

    -- 다음 탐색 셀 위치로 이동 (절대좌표, robot base 기준)
    local search_pose, cell_x, cell_y = cambrian_search_grid_get_next(GRID_NAME)

    if search_pose ~= nil then
        move_j_blend(search_pose.coordinate, SPEED_SEARCH, BLEND_T)

        -- 비전 예측 요청
        -- 주의: Cambrian VISION 서버가 GET NEXT 이후 예측 시 그리드를 자동으로 갱신함
        -- (autoUpdateSearchGridOnPrediction). 여기서 cambrian_search_grid_update를 추가로
        -- 호출하면 한 사이클에 깊이가 2배로 전진하는 "redundant SEARCH GRID UPDATE" 경고가
        -- 발생하므로 호출하지 않음.
        local result, pred_pose, grasp_type = cambrian_get_prediction(MODEL_NAME, {}, {}, 0)
        cambrian_search_grid_update(GRID_NAME)

        if result > 0 then
            if grasp_type == 3 then
                -- 쓰러진/부적합 자세: 공압 없이 접촉 지점에서 옆으로 밀어서 자세를 바꿈
                local push_p, push_app_p, push_preapp_p, push_exit_p =
                    cambrian_approach(pred_pose, TOPPLE_OFFSET, APP_DIST, PREAPP_DIST, EXIT_DIST)
                local push_end_p = cambrian_pose_trans(push_p.coordinate, {TOPPLE_PUSH_DIST,0,0,0,0,0})
                local push_exit_p = cambrian_pose_trans(push_end_p, {0,0,-20,0,0,0})
                move_j_blend(push_preapp_p.coordinate, SPEED_APPROACH, BLEND_T)      -- pre-approach
                move_l_blend(push_app_p.coordinate,    nil, SPEED_APPROACH, BLEND_R) -- approach
                move_l(push_p.coordinate,        nil, SPEED_GRASP)    -- 접촉 지점
                move_l(push_end_p,               nil, SPEED_GRASP)    -- 밀어서 쓰러뜨림
                move_l_blend(push_exit_p,   nil, SPEED_APPROACH, BLEND_R) -- retreat
                -- 픽이 아니므로 report/place 없이 같은 셀을 다시 스캔 (block도 하지 않음)
            else
                -- 접근/파지/탈출 포즈 계산
                local grasp_p, app_p, preapp_p, exit_p =
                    cambrian_approach(pred_pose, GRASP_OFFSET, APP_DIST, PREAPP_DIST, EXIT_DIST)

                move_j_blend(preapp_p.coordinate, SPEED_APPROACH, BLEND_T)       -- pre-approach
                move_l_blend(app_p.coordinate,    nil, SPEED_APPROACH, BLEND_R)  -- approach
                move_l(grasp_p.coordinate,  nil, SPEED_GRASP)     -- grasp point

                gripper_grip()                                    -- 공압 ON: 화장품 파지/흡착

                move_l_blend(exit_p.coordinate, nil, SPEED_APPROACH, BLEND_R)    -- retreat

                cambrian_search_grid_report(GRID_NAME, cell_x, cell_y, 1)
                cambrian_report_pick_result(1)

                -- place 위치로 이동 후 릴리즈
                PTP(p2, SPEED_PLACE, -1, 0)   -- p_place: 저장된 교시점 이름으로 교체
                gripper_release()                                 -- 공압 OFF: 릴리즈

                PTP(p1, SPEED_SEARCH, BLEND_T, 0)   -- p_home: 저장된 교시점 이름으로 교체
            end
        else
            -- 이 셀에서 못 찾았으면 N번 동안 후보에서 제외 → 다음 GET NEXT는 다른 셀을 반환
            cambrian_search_grid_block(GRID_NAME, cell_x, cell_y, GRID_BLOCK_ITERATIONS)
        end
    else
        popup("Search grid 응답 오류 - 연결을 확인하세요.", "cambrian")
    end
end


