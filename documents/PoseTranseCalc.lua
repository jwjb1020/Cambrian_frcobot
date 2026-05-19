function MoveTo(x,y,z,rx,ry,rz, speed, nOffset, dx,dy,dz,drx,dry,drz)
	local speed  = speed or 30
    local nOffset = nOffset or 0
	local dx = dx or 0 
	local dy = dy or 0 
	local dz = dz or 0 
	local drx = drx or 0 
	local dry = dry or 0 
	local drz = drz or 0 
	
	local j1,j2,j3,j4,j5,j6 = GetInverseKin(0,x,y,z,rx,ry,rz,-1)
	local tool = GetActualTCPNum()
	local user = GetActualWObjNum()

	MoveL(j1,j2,j3,j4,j5,j6,x,y,z,rx,ry,rz,
		  tool,user,speed,180,100,-1,0,0,0,0, 
		  -1,nOffset, dx,dy,dz,drx,dry,drz)
end
function ShowPos()
    x,y,z,rx,ry,rz = GetActualTCPPose()
    RegisterVar("number","x")
    RegisterVar("number","y")
    RegisterVar("number","z")
    RegisterVar("number","rx")
    RegisterVar("number","ry")
    RegisterVar("number","rz")
end

function ShowPos2()
    RegisterVar("number","x2")
    RegisterVar("number","y2")
    RegisterVar("number","z2")
    RegisterVar("number","rx2")
    RegisterVar("number","ry2")
    RegisterVar("number","rz2")
end

x1,y1,z1,rx1,ry1,rz1= 495, -130, 679, -90, 0,-90

-- 지정된 좌표로 이동한 후,
MoveTo(x1,y1,z1,rx1,ry1,rz1,30)
ShowPos()
Pause(0)

-- 작업좌표계 기준으로 x방향 100mm 이동한 위치 계산
j1,j2,j3,j4,j5,j6 = GetInverseKin(1,100,0,0, 0,0,0,-1)
x2,y2,z2,rx2,ry2,rz2 = GetForwardKin(j1,j2,j3,j4,j5,j6)
ShowPos2()
Pause(0)

-- 작업좌표계 기준으로 yaw방향 30도 이동한 위치 계산
j1,j2,j3,j4,j5,j6 = GetInverseKin(1,0,0,0, 0,0,30,-1)
x2,y2,z2,rx2,ry2,rz2 = GetForwardKin(j1,j2,j3,j4,j5,j6)
ShowPos2()
Pause(0)

-- 작업좌표계 기준으로 z방향 100mm, roll 30도 이동한 위치 계산
j1,j2,j3,j4,j5,j6 = GetInverseKin(1,0,0,100, 30,0,0,-1)
x2,y2,z2,rx2,ry2,rz2 = GetForwardKin(j1,j2,j3,j4,j5,j6)
ShowPos2()
Pause(0)

-- 툴좌표계 기준으로 x방향 100mm 이동한 위치 계산
j1,j2,j3,j4,j5,j6 = GetInverseKin(2,100,0,0, 30,0,0,-1)
x2,y2,z2,rx2,ry2,rz2 = GetForwardKin(j1,j2,j3,j4,j5,j6)
ShowPos2()
Pause(0)

-- 툴좌표계 기준으로 yaw방향 30도 이동한 위치 계산
j1,j2,j3,j4,j5,j6 = GetInverseKin(2,0,0,0, 0,0,30,-1)
x2,y2,z2,rx2,ry2,rz2 = GetForwardKin(j1,j2,j3,j4,j5,j6)
ShowPos2()
Pause(0)

-- 툴좌표계 기준으로 z방향 100mm, roll 30도 이동한 위치 계산
j1,j2,j3,j4,j5,j6 = GetInverseKin(2,0,0,100, 30,0,0,-1)
x2,y2,z2,rx2,ry2,rz2 = GetForwardKin(j1,j2,j3,j4,j5,j6)
ShowPos2()

