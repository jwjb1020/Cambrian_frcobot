package.path = package.path .. ";/root/web/file/user/?.lua"
require("FairinoForCambrian_v4_2")
set_connection_info("192.168.58.200", 4000)
local model1 = "NX4_WD700_D03_tilt_15_gp"
cambrian_load_model("NX4_WD700_D03_tilt_15_gp")
move_j(p2, 100)
result, pred_pose, grasp_type = cambrian_get_prediction(model1, {}, {}, 0)
if result > 0 then
  -- cambrian_approach(pred_pose, grasp_offset, app_dist, preapp_dist, exit_dist)
  -- grasp_offset : offset from gripper center to grasp point {x,y,z,rx,ry,rz} (mm/deg)
  -- app_dist     : approach distance (mm, along Z- axis)
  -- preapp_dist  : pre-approach distance (mm)
  -- exit_dist    : retreat distance (mm)
  local grasp_p, app_p, preapp_p, exit_p =
      cambrian_approach(pred_pose, {0,0,0,0,0,0}, 50, 100, 50)
  move_l(preapp_p.coordinate, nil, 50)   -- move to pre-approach
  move_l(app_p.coordinate,    nil, 20)   -- move to approach
  -- close gripper
  move_l(exit_p.coordinate,   nil, 20)   -- retreat
  -- open gripper
end
