# Fairino + Cambrian VISION API v5

Fairino 협동로봇 Lua 스크립트에서 Cambrian VISION PC를 호출하는 라이브러리입니다.
대상 매뉴얼은 CambrianAPI v2.5.5이며(v2.5.8 문서로 재확인), 함수 이름은 Doosan API v2.0과 같은 `cam_*` 체계입니다.

- 라이브러리: [CambrianAPI_Fairino.lua](CambrianAPI_Fairino.lua)
- 예제: [example/](example/) (22개)
- Cambrian API 문서(v2.5.8): `documents/Cambrian_VISION_API_v2_5_8.md`, 한국어 요약 `documents/Cambrian_VISION_API_v2_5_8_ko.html` (로컬 전용, git 제외)
- 이전 버전: `FairinoForCambrian_v4_2.lua`, [documents/README_v4_2.md](documents/README_v4_2.md), [example/legacy_v4_2/](example/legacy_v4_2/)

## 1. 시스템 구성

```
┌──────────────────┐   TCP 4000    ┌────────────────────┐
│  Fairino 로봇     │──────────────►│  Cambrian VISION PC │
│  (Lua 스크립트)   │◄──────────────│  (AI 서버)          │
└──────────────────┘               └────────────────────┘
         │ TCP 9999 (선택: popup)
         ▼
┌──────────────────┐
│ 호스트 PC         │
│ gui_popup_server  │
└──────────────────┘
```

로봇이 TCP 클라이언트이고 Cambrian PC가 서버입니다. 예제의 기본 IP는 `192.168.58.100:4000`입니다.

## 2. 빠른 시작

1. `CambrianAPI_Fairino.lua`를 로봇 웹 UI에서 `/root/web/file/user/`에 업로드합니다.
2. (선택) 호스트 PC에서 `python gui_popup_server.py`를 실행합니다. 자세한 설정은 아래 [팝업 서버 설정](#팝업-서버-설정-선택)을 보세요. popup이 필요 없으면 스크립트에서 `POPUP_ENABLE = false`로 두면 됩니다.
3. 로봇 스크립트를 작성합니다.

```lua
package.path = package.path .. ";/root/web/file/user/?.lua"
require("CambrianAPI_Fairino")

cam_init("192.168.58.100", 4000)   -- 한 번만 연결
cam_startup()                       -- API 버전 보고 → PING → START SESSION → SET PREDICTION SPACE
cam_load_model_and_wait("my_model")

if cam_get_prediction("my_model") then
    local grasp, app, preapp, exit_p = cam_approach(cam_grasp_pose, {0,0,0,0,0,0}, 50, 100, 80)
    move_j(preapp, 30)
    move_l(app, nil, 30)
    move_l(grasp, nil, 10)
    -- 그리퍼 ON
    move_l(exit_p, nil, 30)
    cam_report_pick_result(1)
end
```

> 라이브러리를 수정해 다시 업로드한 뒤에는 `require` 캐시 때문에 컨트롤러 재시작이 필요할 수 있습니다.

### 팝업 서버 설정 (선택)

Fairino 컨트롤러에는 사용자 메시지 창을 띄우는 Lua 명령이 없습니다. 그래서 `popup()`은 호스트 PC에서 실행한 `gui_popup_server.py`에 TCP로 메시지를 보내 창을 띄우고, 작업자가 버튼을 누를 때까지 기다립니다.

**1) 호스트 PC 준비**
- Python 3와 tkinter가 필요합니다. Windows용 python.org 설치본에는 tkinter가 포함되어 있고, Ubuntu는 `sudo apt install python3-tk`로 설치합니다.
- 호스트 PC가 로봇과 같은 네트워크(예: `192.168.58.x`)에 있어야 합니다.
- Windows 방화벽에서 TCP `9999` 인바운드를 허용합니다. 관리자 PowerShell에서:
  ```powershell
  New-NetFirewallRule -DisplayName "Fairino popup 9999" -Direction Inbound -Protocol TCP -LocalPort 9999 -Action Allow
  ```

**2) 서버 실행**
```bash
python gui_popup_server.py
# [Popup server] Listening on 0.0.0.0:9999...
```
- 포트를 바꾸려면 `gui_popup_server.py`의 `PORT`와 로봇 스크립트의 `POPUP_SERVER_PORT`를 같이 바꿉니다.
- 창이 뜨는 동안 터미널을 닫으면 안 됩니다.

**3) 로봇 스크립트 설정** (`require` 다음에 덮어씁니다)

| 변수 | 기본값 | 설명 |
|---|---|---|
| `POPUP_SERVER_IP` | `"192.168.58.1"` | 서버를 실행한 호스트 PC의 IP |
| `POPUP_SERVER_PORT` | `9999` | 서버 포트 |
| `POPUP_ENABLE` | `true` | `false`면 창 없이 WebApp print 창에 `[POPUP] 제목: 내용`만 남기고 바로 진행 |
| `CAM_POPUP_ON_ERROR` | `true` | Cambrian 서버가 ERROR를 돌려주면 자동으로 popup 표시 |

**4) 동작 방식**
- `popup(내용, 제목)`: 내용에는 문자열, 숫자, 테이블을 넣을 수 있습니다. 테이블은 `{a, b, c}` 형태로 표시됩니다.
- **Continue**를 누르거나 창을 닫으면 스크립트가 계속 진행합니다.
- **Stop**을 누르면 `error()`로 스크립트가 즉시 종료됩니다.
- 서버에 연결하지 못하면 print 창에 `[POPUP server connection failed]`를 남기고 기다리지 않고 진행합니다.
- 모든 popup은 호스트 PC의 `log messages/YYYY-MM-DD.txt`에 시간, 버튼, 내용과 함께 기록됩니다.
- 통신 형식: 로봇 → 서버 `POPUP|제목|내용\n`, 서버 → 로봇 `CONTINUE\n` 또는 `STOP\n`
- 제목이나 내용에 `|` 문자를 넣으면 형식이 깨집니다. 줄바꿈(`\n`)은 써도 됩니다.
- popup은 `socket_1`을 쓰고 Cambrian 통신은 `socket_0`을 써서 서로 겹치지 않습니다.

**5) 연결 테스트**
1. 호스트 PC에서 서버를 켭니다.
2. 같은 PC의 다른 터미널에서 아래를 실행해 창이 뜨는지 봅니다.
   ```bash
   python -c "import socket;s=socket.create_connection(('127.0.0.1',9999));s.sendall(b'POPUP|test|hello\n');print(s.recv(64))"
   ```
3. 로봇에서 `example/22_popup.lua`를 실행합니다.

창이 안 뜨면 순서대로 확인하세요.
- `POPUP_SERVER_IP`가 호스트 PC의 실제 IP인지
- 방화벽에서 9999 포트를 허용했는지
- 로봇과 호스트 PC가 서로 ping 되는지

## 3. 명령 보내기: `cam_request()`

v4_2에서는 다음과 같이 보냈습니다.

```lua
local sock, ok = cambrian_connect(ip, port)
cambrian_request(sock, "GET PREDICTION#" .. model .. "*1,3**0")
cambrian_disconnect(sock)
```

v5에서는 이렇게 보냅니다.

```lua
cam_request("GET PREDICTION", model, "1,3", nil, 0)
```

| 입력 | 전송 |
|---|---|
| 인자 여러 개 | `*`로 연결 |
| `nil` | 빈 칸 (`a**b`) |
| 6개짜리 테이블 (포즈/관절) | `[x,y,z,rx,ry,rz]` |
| `cam_list({1,3})` | `1,3` |
| `true` / `false` | `1` / `0` |

- `#` 구분자, 현재 flange 포즈·관절·툴 오프셋, `<<` 종료자는 자동으로 붙습니다.
  - 예: `GET PREDICTION#m*1,3**0#[flange]#[joints]#[tool]#<<`
- 반환값은 `code, msg, data`입니다.
  - code: 0 OK / 1 ERROR / 2 WARNING / 3 PRINT / -1 응답 없음
  - data: 콤마로 나눈 문자열 배열
- 같은 값이 전역 `cam_code`, `cam_msg`, `cam_data`, `cam_data_str`에도 저장됩니다.
- 응답 읽기 헬퍼:
  - `cam_num(i)`: i번째 값을 숫자로 반환
  - `cam_pose_at(i)`: i~i+5번째 값을 포즈로 반환
- `cam_raw(cmd, "data")`는 DATA 문자열을 그대로 보냅니다. `SET ADVANCED CONFIG`처럼 `,` 구분자를 쓰는 명령에 사용합니다.

### 설정 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `CAM_PERSISTENT` | `true` | 연결을 유지합니다. 끊기면 자동으로 재연결해 한 번 재전송합니다. `false`면 명령마다 연결하고 해제합니다(v4_2 방식). |
| `CAM_POPUP_ON_ERROR` | `true` | ERROR 응답이면 popup을 띄웁니다. |
| `CAM_STOP_ON_ERROR` | `false` | ERROR 응답이면 `error()`로 스크립트를 정지합니다. |
| `CAM_PRINT_REPLY` | `false` | 모든 요청과 응답을 출력합니다. |
| `CAM_BOX_SIZE_SCALE` | `0.001` | 박스 크기 mm에 곱하는 값입니다(서버가 m를 기대한다고 가정). |
| `cam_prediction_space` | `"FLANGE"` | FLANGE면 예측 포즈를 요청 시점의 flange와 합성해 base 좌표로 바꿉니다. |
| `CAMBRIAN_LOG_ENABLE` | `false` | 로봇 파일 로그를 켭니다(`cambrian_log.txt`). |

## 4. 함수 레퍼런스

단위는 포즈 mm/deg, 관절 deg입니다. 반환된 포즈는 모두 base 좌표입니다. 거리 인자(approach, hover 등)는 mm로 받아 라이브러리가 m로 바꿔 보냅니다.

| 분류 | 함수 |
|---|---|
| 연결/시스템 | `cam_init(ip,port)`, `cam_close()`, `cam_startup(space)`, `cam_ping()`, `cam_get_version()`, `cam_report_api_version()`, `cam_check_compatibility()`, `cam_start_session()`, `cam_list_api_commands()`, `cam_log_text(t)`, `cam_save_log(tag,min)`, `cam_clear_memory()`, `cam_report_pick_result(result[,id])` |
| 모델 | `cam_load_model`, `cam_load_model_from_path`, `cam_load_model_and_wait`, `cam_wait_for_model_launch`, `cam_check_model_ready`, `cam_unload_model`, `cam_unload_all_models`, `cam_set_model_confidence`, `cam_set_model_recenter_crop`, `cam_set_edge_trim` |
| 예측 | `cam_get_prediction(model,prio,ignore,sort[,test])`, `cam_get_prediction_notest`, `cam_get_next_prediction`, `cam_get_all_predictions` (반환: 개수, 결과 `cam_poses_list`/`cam_types_list`/`cam_confidence_list`), `cam_get_prediction_data`, `cam_set_prediction_space`, `cam_start/end_prediction_average`, `cam_too_close/far`, `cam_get_grasp_count`, `cam_get_part_count`, `cam_get_search_z`, `cam_smart_search_random`, `cam_block_volume`, `cam_clear_block_volumes` |
| 카메라 | `cam_check_cameras`, `cam_wait_cameras`, `cam_restart_cameras`, `cam_cameras_auto/manual/hdr`, `cam_cameras_exposure/gain`, `cam_cameras_auto_params`, `cam_cameras_hdr_params`, `cam_cameras_sensopart`, `cam_get_camera_*`, `cam_get_rig_pose([space])`, `cam_get_left_pose`, `cam_enable/disable_liveview`, `cam_load_rig_params`, `cam_set/get_total_rigs`, `cam_set/get_active_rig` |
| Hand-eye 캘리브레이션 | `cam_set/get_calibration_mount`, `cam_start_calibration`, `cam_new_calibration`, `cam_next_calibration_step`, `cam_auto_calibration(rig,fl,sep,tilt,speed)`, `cam_capture_calibration_image`, `cam_run_manual_calibration`, `cam_set_calibration_rig_pose`, `cam_locate_calibration_board`, `cam_set_calibration_board_charuco/chess/marker`, `cam_clear_calibration_board` |
| 캘리브레이션 검증 | `cam_save_calibration_verification`, `cam_verify_calibration` (결과 테이블 반환), `cam_get_calibration_verification_pose`, `cam_delete_calibration_verification`, `cam_get_verification_report`, `cam_set/get_calibration_fix_intrinsics` |
| 로봇 기구학 캘리브레이션 | `cam_send_robot_calibration_data([joints])`, `cam_start_robot_calibration`, `cam_check_robot_calibration`, `cam_reset_robot_calibration` |
| 충돌/작업공간 | `cam_set_box`, `cam_3_point_box`, `cam_4_point_box`, `cam_set_gripper_box`, `cam_clear_collision_elements`, `cam_test_pose` (true = 충돌 없음), `cam_test_pose_withbody`, `cam_check_body`, `cam_test_clearance`, `cam_spawn/destroy/enable/disable_component_world/flange`, `cam_set_component_world/flange_pose`, `cam_set/get_robot_pose` |
| 서치 그리드 | `cam_search_grid_init`, `_auto_init`, `_auto_init_fixed`, `_get_next` (반환: pose, i, j), `_get_cell`, `_update`, `_report`, `_block/_unblock`, `_ignore/_unignore`, `_reset_cell`, `_reset`, `_destroy(_all)`, `_finished`, `_check_init`, `_level`, `_set_level`, `_set/get_cell_level`, `_set/get_weights`, `_dimensions`, `_set/get_mode`, `_calibrate`, `_calibrate_from`, `_get_layer_state`, `_set_layer_offset`, `_set_layer_count`, `_next_layer` |
| IK/FK | `cam_get_ik(pose,test,seed)`, `cam_get_fk(joints,tcp)`, `cam_get_joints_configuration`, `cam_set_robot_configurations` |
| Pick sequence | `cam_get_pick_sequence(model,approach_mm,hover_mm,orient,...)`, `cam_get_next_pick_sequence`, `cam_get_pick_sequence_from_pose`, `cam_set_pick_sequence_settings`, `cam_execute_pick_sequence` |
| 접근 포즈 | `cam_approach` (로컬 계산), `cam_offset_pose`, `cam_get_approach_pose`, `cam_get_hover_pose`, `cam_configure_approach`, `cam_get_exit_pose` |
| 경로 계획 | `cam_get_pick_path`, `cam_get_pick_path_from_pose`, `cam_get_next_pick_path`, `cam_get_planned_path`, `cam_get_path_to_joints`, `cam_get_path_to_pose`, `cam_get_exit_path`, `cam_stream_next_waypoint`, `cam_execute_path(speed_j,speed_l,blendT)`, `cam_save_path`, `cam_get_saved_path`, `cam_delete_saved_path` |
| Waypoint | `cam_set_waypoint`, `cam_get_waypoint_pose`, `cam_get_waypoint_joints`, `cam_remove_waypoint` |
| 배치/드롭 | `cam_get_placement_pose`, `cam_set_part_grasped`, `cam_get_grasped_part_drop_pose`, `cam_get_drop_pose`, `cam_remove_grasped_part` (모두 `cam_report_pick_result` 전에 호출) |
| 수학/설정 | `cam_pose_trans`, `cam_pose_inv`, `cam_get_inverse_transform`, `cam_get_pose_transform`, `cam_set/get/save/reload_advanced_config` |
| 모션/상태 | `move_l(pose,tool,speed,blendR)`, `move_j(pose,speed,blendT,tool)`, `move_joints(j,speed,blendT)`, `move_l_joints(j,speed,blendR)`, `cam_get_tcp_pose`, `cam_get_joints`, `cam_is_pose_reachable`, `cam_set_tool_offset`, `popup`, `ShowPos` |

## 5. 예제

| 파일 | 내용 |
|---|---|
| `01_ping.lua` | 연결, startup, 연속 PING (**실기 1단계**) |
| `02_raw_command.lua` | `cam_request()` 직접 호출, 응답 파싱 |
| `03_hand_eye_calibration_auto.lua` | 자동 hand-eye 캘리브레이션 (**실기 2단계**) |
| `04_hand_eye_calibration_manual.lua` | 교시점 20개 수동 캘리브레이션 (본사 권장 16개 이상) |
| `05_calibration_verify.lua` | 검증 기준 저장(SAVE) / 오차 확인(VERIFY) |
| `06_get_rig_pose.lua` | rig / 왼쪽 카메라 포즈 |
| `07_camera_settings.lua` | 자동/수동 노출, 게인, HDR |
| `08_get_prediction.lua` | 기본 예측 → 픽 → 놓기 |
| `09_get_all_predictions.lua` | 전체 후보 중 도달 가능하고 충돌 없는 것 선택 |
| `10_prediction_average.lua` | 여러 자세 예측 평균 |
| `11_collision_boxes.lua` | 박스, 3/4점 박스, 그리퍼 박스, 블록 볼륨 |
| `12_search_grid.lua` | 서치 그리드 기본 |
| `13_search_grid_auto_layers.lua` | 자동 초기화, 그리드 캘리브레이션, 층 관리 |
| `14_pick_sequence.lua` | 서버 IK 기반 hover/approach/grasp |
| `15_pick_path.lua` | RRT pick path + 홈 복귀 경로 |
| `16_waypoints.lua` | 이름 있는 위치 저장/복귀 |
| `17_placement_drop.lua` | Part Placement / 드롭 포즈 |
| `18_multi_model.lua` | 모델 두 개 번갈아 사용 |
| `19_robot_calibration_ik.lua` | 로봇 기구학 캘리브레이션 |
| `20_pickandplace_noblend.lua` / `21_pickandplace_blend.lua` | 기존 화장품 pick & place 예제를 v5로 이식 |
| `22_popup.lua` | popup 알림, 값 표시, 이동 전 작업자 확인, ERROR 자동 popup, `POPUP_ENABLE` 끄기 |

예제의 `p1`, `p2` 등은 Fairino 교시점 이름입니다. 현장에서 저장한 이름으로 바꿔 쓰세요.

## 6. 실기 검증 순서

1. **01_ping**: `CAM_PRINT_REPLY = true` 상태로 실행합니다.
   - startup이 `true`이고 PING 5회가 모두 `true`이면 영구 연결이 정상입니다.
   - 두 번째 명령부터 실패하면 `CAM_PERSISTENT = false`로 바꿔 다시 확인합니다.
2. **02_raw_command**: 인자 직렬화와 응답 파싱을 확인합니다.
3. **03_hand_eye_calibration_auto**: 처음에는 `SPEED`를 낮게 두고 실행합니다.
   - 확인할 것: step 1(이동), 3(도달 가능 회신), 2(완료)가 순서대로 진행되는지
   - 이어서 `06_get_rig_pose`로 결과를 확인합니다.
4. **05_calibration_verify**: SAVE를 실행한 뒤 VERIFY를 실행해 오차를 확인합니다.
5. 이후 08 → 12 → 14 → 15 순으로 진행합니다.

문제가 생기면 컨트롤러 출력과 `log messages/` popup 로그를 함께 확인하세요.

## 7. v4_2 → v5 대응표

| v4_2 | v5 |
|---|---|
| `set_connection_info(ip, port)` | `cam_init(ip, port)` |
| `cambrian_request(sock, "CMD#data")` | `cam_request("CMD", arg1, arg2, ...)` |
| `cambrian_ping()` → `code, msg` | `cam_ping()` → `true/false` |
| `cambrian_get_prediction(m,{},{},0)` → `got, {coordinate=p}, type` | `cam_get_prediction(m,nil,nil,0)` → `true/false`, 결과는 `cam_grasp_pose`, `cam_grasp_type`, `cam_confidence` |
| `cambrian_get_all_predictions(...)` → `n, poses, types` | `cam_get_all_predictions(...)` → `n`, 결과는 `cam_poses_list`, `cam_types_list` |
| `cambrian_next_prediction()` | `cam_get_next_prediction()` |
| `cambrian_approach(pred, off, a, pa, e)` → `{coordinate=}` ×4 | `cam_approach(pose, off, a, pa, e)` → 포즈 테이블 ×4 |
| `cambrian_pose_trans`, `inv_pose_rpy_xyz` | `cam_pose_trans`, `cam_pose_inv` (옛 이름도 사용 가능) |
| `cambrian_search_grid_get_next(g)` → `{coordinate=p}, i, j` | `cam_search_grid_get_next(g)` → `p, i, j` |
| `cambrian_search_grid_finished(g) == 1` | `cam_search_grid_finished(g)` (true/false) |
| `cambrian_check_cameras() ~= 1` | `not cam_check_cameras()` |
| `cambrian_test_pose(p)` (0 = 안전, 반전됨) | `cam_test_pose(p)` (true = 안전) |
| `cambrian_run_auto_calibration(rig, fl, sep, tilt, move_fn)` | `cam_auto_calibration(rig, fl, sep, tilt, speed)` (이동은 내부 처리) |
| `cambrian_set_state(nil, nil, tool)` | `cam_set_tool_offset(tool)` |
| `cambrian_load_model` (응답 안 읽음) | `cam_load_model` (응답 읽음) |

## 8. Fairino Lua 제약

| 제약 | 내용 |
|---|---|
| `pcall` 금지 | 저장 시 `pcall is not allowed in lua file` 오류가 납니다. 라이브러리도 `pcall`을 쓰지 않습니다. |
| `PTP(변수)` 금지 | 교시점 이름은 리터럴로 써야 합니다. 좌표로 이동하려면 `move_j`/`move_l`을 씁니다. |
| 저장 시 실행 | 저장/검사 단계에서 스크립트가 실행되어 API가 nil을 반환할 수 있습니다. 라이브러리는 nil이면 0으로 처리합니다. |
| `require` 캐시 | 라이브러리를 갱신한 뒤 컨트롤러 재시작이 필요할 수 있습니다. |
| popup API 없음 | `popup()`은 외부 `gui_popup_server.py`와 TCP로 통신합니다. |

## 9. 실기에서 확인이 필요한 항목

라이브러리와 예제는 Fairino 함수와 Cambrian 서버를 흉내 낸 mock 환경(Lua 5.1/5.3/5.4/5.5)에서 검증했습니다. 송신 문자열, 응답 파싱, 예제 실행 흐름은 확인됐습니다. 아래 항목은 실제 로봇에서 확인해야 합니다.

- **영구 연결:** `SocketReadString`으로 같은 소켓에서 연속 수신이 되는지(01_ping). 안 되면 `CAM_PERSISTENT = false`로 씁니다.
- **응답 분할:** 긴 응답(pick path 등)이 여러 번에 나뉘어 와도 이어 붙는지. 라이브러리는 `>>`가 3개 모일 때까지 최대 `CAM_READ_RETRIES`번 다시 읽습니다.
- **`GetInverseKinHasSolution` 반환 형식:** boolean / 숫자 / 문자열을 모두 처리하지만 실기 값 확인이 필요합니다.
- **자동 캘리브레이션 포즈 기준:** UR/Doosan과 같이 현재 툴(TCP) 기준으로 이동합니다. flange 기준으로 와야 한다면 툴 0으로 바꿔 실행하세요.
- **박스 크기 단위:** `CAM_BOX_SIZE_SCALE`(기본 m 변환)을 확인해야 합니다. Doosan v2.0은 변환하지 않고 보냅니다.
- **`TEST POSE WITHBODY` 플래그 의미:** 매뉴얼 안에서도 서로 다르게 적혀 있어 원시 값을 반환합니다.
- **경로/IK 관절값:** deg 기준(매뉴얼상 Fairino는 deg)인지 확인이 필요합니다.
