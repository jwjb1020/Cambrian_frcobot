fzero = 1e-6
r2d   = 180.0/3.141592654 
d2r   = 3.141592654/180.0  
function AxisA2Rot(nx,ny,nz, th)
	local c = math.cos(th*d2r)
	local s = math.sin(th*d2r)
	local t = 1-c
	local rot = {0,0,0, 0,0,0, 0,0,0}
	rot[1] = t*nx*nx + c
	rot[2] = t*nx*ny - s*nz
	rot[3] = t*nx*nz + s*ny
	rot[4] = t*ny*nx + s*nz
	rot[5] = t*ny*ny + c
	rot[6] = t*ny*nz - s*nx
	rot[7] = t*nz*nx - s*ny
	rot[8] = t*nz*ny + s*nx
	rot[9] = t*nz*nz + c
	return rot
end	
function Rot2AxisA(R)
	local nx = R[8]-R[6]
	local ny = R[3]-R[7]
	local nz = R[4]-R[2]
	local norm = math.sqrt(nx*nx + ny*ny + nz*nz)
	nx = nx/norm
	ny = ny/norm
	nz = nz/norm
	local cth = (R[1]+R[5]+R[9]-1.0)/2.0
	local sth = nx*(R[8]-R[6])/2 + ny*(R[3]-R[7])/2 + nz*(R[4]-R[2])/2  
	local th = math.atan2(sth,cth)
	return nx, ny, nz, th*r2d
end	
function Rot2Rpy(Rot)
    local nx,ox,ax = Rot[1], Rot[2], Rot[3]
    local ny,oy,ay = Rot[4], Rot[5], Rot[6]
    local nz,oz,az = Rot[7], Rot[8], Rot[9]
    local pitch = math.asin(-nz)
    local cb    = math.cos(pitch)
    local roll,yaw  = 0,0
    if math.abs(cb)<fzero then
        sb    = math.sin(pitch)
        roll  = 0
        yaw   = math.atan2(ox*sb, oy)
    else
        yaw  = math.atan2(ny/cb, nx/cb)
        roll = math.atan2(oz/cb, az/cb)
    end
    return roll*r2d, pitch*r2d, yaw*r2d
end
function  Rpy2Rot(roll, pitch, yaw)
    local r = roll *d2r
    local b = pitch*d2r
    local a = yaw  *d2r
    local ca,sa = math.cos(a), math.sin(a)
    local cb,sb = math.cos(b), math.sin(b)
    local cr,sr = math.cos(r), math.sin(r)
    local nx = ca*cb
    local ny = sa*cb
    local nz = -sb
    local ox = ca*sb*sr - sa*cr
    local oy = sa*sb*sr + ca*cr
    local oz = cb*sr
    local ax = ca*sb*cr + sa*sr
    local ay = sa*sb*cr - ca*sr
    local az = cb*cr
    return {nx, ox, ax, ny, oy, ay, nz, oz, az}
end

function MoveO(pt,speed)
    local speed = speed or 30
    local x0,y0,z0,rx0,ry0,rz0 = GetActualTCPPose()
    if type(rx0)~="number" then return end
    local R0 = Rpy2Rot(rx0,ry0,rz0)
    local pdest = GetRobotTeachingPoint(pt)
    local x1,y1,z1,rx1,ry1,rz1 = x0,y0,z0, pdest[4], pdest[5], pdest[6]
    if type(rx1)~="number" then return end
    local R1 = Rpy2Rot(rx1,ry1,rz1)
    local Ra = MatMult_1(R1,R0)
    local nx,ny,nz,th = Rot2AxisA(Ra)

    -- Trajectory plan (Trapezoidal speed profile)
    local w = speed * 1.8 -- deg/s
    local a = 360.0       -- deg/s/s
    local Ta   = w/a      -- acc. time              
    local th_a = w*Ta     -- distance at acc. and dec. region
    local th_b = th - th_a -- distance at contant speed region
    local Tb   = Ta+(th_b)/w  -- constant speed time 
    local Tc   = Tb + Ta     -- total time

    -- Adjust parameters for triangle speed profile trajectory
    if th_b<=0 then
        Ta = math.sqrt(th/a)
        w  = a*Ta
        th_a = w*Ta
        th_b = 0 
        Tb = Ta 
        Tc = 2*Ta
    end
    local dT = 0.01
    local num = math.ceil(Tc/dT)
    local tool = GetActualTCPNum()
    local user = GetActualWObjNum()
    local kth = 0
    local kw = 0
    ServoMoveStart()
    for i=1,num do
        t = i*dT    -- time
        if t<Ta then      -- acceleration region
            kw = kw + a*dT
        elseif t<Tb then  -- constant speed region
            kw = w
        else              -- deceleratioin region    
            kw = kw - a*dT
            if kw<0 then kw = 0 end 
        end 
        kth = kth + kw*dT
        local Rk = AxisA2Rot(nx,ny,nz,kth)
        local R2 = MatMult(Rk, R0) 
        local rx2,ry2,rz2 = Rot2Rpy(R2)
        local j1,j2,j3,j4,j5,j6=GetInverseKin(0,x0,y0,z0,rx2,ry2,rz2, -1)
        ServoJ(j1,j2,j3,j4,j5,j6,0,0,dT,0,0)
    end
    ServoMoveEnd()
end
function MatMult_1(R0,R1)
    local Ra = {0,0,0,0,0,0,0,0,0}
    for i=1,3 do
        local row = (i-1)*3
        Ra[row+1] = R0[row+1]*R1[1] + R0[row+2]*R1[2] + R0[row+3]*R1[3]
        Ra[row+2] = R0[row+1]*R1[4] + R0[row+2]*R1[5] + R0[row+3]*R1[6]
        Ra[row+3] = R0[row+1]*R1[7] + R0[row+2]*R1[8] + R0[row+3]*R1[9]
    end
    return Ra
end 
function MatMult(R0,R1)
    local Ra = {0,0,0,0,0,0,0,0,0}
    for i=1,3 do
        local row = (i-1)*3
        Ra[row+1] = R0[row+1]*R1[1] + R0[row+2]*R1[4] + R0[row+3]*R1[7]
        Ra[row+2] = R0[row+1]*R1[2] + R0[row+2]*R1[5] + R0[row+3]*R1[8]
        Ra[row+3] = R0[row+1]*R1[3] + R0[row+2]*R1[6] + R0[row+3]*R1[9]
    end
    return Ra
end 
function trunc(x,d)
    local y = math.floor(x*d + 5.0/d)
    return y/d 
end
function makeString(x1,x2,x3)
    local str = tostring(trunc(x1,10)) .. ",  "
                ..tostring(trunc(x2,10)) .. ",  "
                ..tostring(trunc(x3,10))
    return str 
end
function write_log(logmsg1, logmsg2)
  local logmsg2 = logmsg2 or ""
  local logmsg3 = logmsg1 .. logmsg2 .. "\r\n"
  logfile= io.open("/usr/local/etc/web/file/user/log.lua","a")
  logfile:write(logmsg3) 
  logfile:close()
end
PTP(ph1,30,-1,0)
MoveO("ph2",10)
MoveO("ph3",10)
MoveO("ph1",30)
Mode(1)
