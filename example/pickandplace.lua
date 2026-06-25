-- package.path = package.path .. ";/usr/local/etc/controller/lua/?.lua"
package.path = package.path .. ";/root/web/file/user/?.lua"
require("FairinoForCambrian_v4_2")
set_connection_info("192.168.58.100", 4000)

while true do 
    PTP(handel,100,-1,0)
    
    -- 찍는 위치
    result, pred_pose, grasp_type = cambrian_get_prediction("handle_400", {}, {}, 0)
    if result > 0 then
      -- cambrian_approach(pred_pose, grasp_offset, app_dist, preapp_dist, exit_dist)
      -- grasp_offset : offset from gripper center to grasp point {x,y,z,rx,ry,rz} (mm/deg)
      -- app_dist     : approach distance (mm, along Z- axis)
      -- preapp_dist  : pre-approach distance (mm)
      -- exit_dist    : retreat distance (mm)
      local grasp_p, app_p, preapp_p, exit_p =
          cambrian_approach(pred_pose, {0,0,0,0,0,0}, 50, 100, 50)
      move_j(app_p.coordinate, nil, 10)   -- move to pre-approach
      move_l(grasp_p.coordinate,    nil, 10)   -- move to approach
      popup(grasp_p.coordinate,"cambrian")
      -- close gripper
      move_j(exit_p.coordinate,   nil, 10)   -- retreat
      -- open gripper
    end
    PTP(handel,50,-1,0)
    popup("change","cambrian")
end










