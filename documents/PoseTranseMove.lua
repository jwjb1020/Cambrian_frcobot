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

x1,y1,z1,rx1,ry1,rz1= 495, -130, 679, -90, 0,-90

-- (현재 설정된)작업좌표계 기준의 옵셋만큼 이동
MoveTo(x1,y1,z1,rx1,ry1,rz1,30, 1, 100,0,0, 0,0,30)
ShowPos()
Pause(0)
MoveTo(x1,y1,z1,rx1,ry1,rz1,30, 1, 0,100,0, 30,0,0)
ShowPos()
Pause(0)
MoveTo(x1,y1,z1,rx1,ry1,rz1,30, 1, 0,0,-100, 0,30,0)
ShowPos()

-- (현재 설정된)툴좌표계 기준의 옵셋 만큼 이동
MoveTo(x1,y1,z1,rx1,ry1,rz1,30, 2, 100,0,0, 0,0,30)
ShowPos()
Pause(0)
MoveTo(x1,y1,z1,rx1,ry1,rz1,30, 2, 0,100,0, 30,0,0)
ShowPos()
Pause(0)
MoveTo(x1,y1,z1,rx1,ry1,rz1,30, 2, 0,0,-100, 0,30,0)
ShowPos()