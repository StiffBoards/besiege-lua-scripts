--standard lua functions for besiege lua mod by Stiff Boards

---*************************CONSTANTS*************************
const_g = 32.810001373291 --acceleration due to gravity
const_cannonPow2Vel=60 --convert cannon power to unit/s

---*************************LINE DRAWING FUNCTIONS*************************
--lines are a huge pain in the ass. Every single line needs a linerenderer in a global variable. If it's not a global variable and you make a new line renderer as a local variable, you can't delete them, and get an annoying trail effect.
--so I put all the line renderers in a global variable, set all of them so they aren't visible, then modify and make them visible for every line I draw on the screen
--to use we need the following global variables
drawBuffer={}-- put every single line here
lineNumber=0 --number of lines on the screen
--put all draw functions in on gui and at the start call clearLines
local function drawLine(pta,ptb,wda,wdb,color)
--pta: start point
--ptb: end point
--wda: start width
local tl=lineNumber+1
if(drawBuffer[tl] == nil) then
  drawBuffer[tl]=lines.new_line_renderer()
end
drawBuffer[tl].set_points(pta,ptb)
drawBuffer[tl].set_width(wda,wdb)
drawBuffer[tl].set_color(color)
lineNumber=tl
end

function clearLines()
lineNumber=0
local test=vector.new(0,0,0)
for i, thisLine in pairs(drawBuffer) do
 drawBuffer[i].set_points(test,test)
 thisLine.set_width(0,0)
end
end


function drawVectors(ref)
--this draws the goddamn fucking vectors on a block given by a ref
--blue will be right() x
--red will be up() y
--green will be forward() z
local size= 2
local width=0.1
drawLine(ref.position(),vector.add(vector.multiply(ref.up(),size),ref.position()),width,width,vector.new(1,0,0))
drawLine(ref.position(),vector.add(vector.multiply(ref.right(),size),ref.position()),width,width,vector.new(0,0,1))
drawLine(ref.position(),vector.add(vector.multiply(ref.forward(),size),ref.position()),width,width,vector.new(0,1,0))
end

function drawAxesAtPoint(point, color)

if (vector.magnitude(point)>0.001)then
local wd=0.1
local size=1

drawLine(point,vector.add(vector.new(0,size,0),point),wd,wd,color)
drawLine(point,vector.add(vector.new(0,-size,0),point),wd,wd,color)
drawLine(point,vector.add(vector.new(size,0,0),point),wd,wd,color)
drawLine(point,vector.add(vector.new(-size,0,0),point),wd,wd,color)
drawLine(point,vector.add(vector.new(0,0,size),point),wd,wd,color)
drawLine(point,vector.add(vector.new(0,0,-size),point),wd,wd,color)
end

end

---*************************MATH FUNCTIONS N' SHIT*************************

function signum(number)
--get the sign of a number
    return ((number > 0 and 1) or (number == 0 and 0) or -1)
end

--clamp a number so it's in range min,max
function clamp(input,min,max)
 if input<min then
  return min
 elseif input>max then
  return max
 else
  return input
 end
end



--wrap angle to range -pi, pi
function angleReset(w)
 return math.atan2(math.sin(w),math.cos(w))
end


--You know what would be nice? A function that gives you joint angle
--there isn't one, so I made my own
--set baseX and baseY to the local vectors(forward, up, right, etc) of a block and joint x to one of the local vectors on the joint
--gives you the angle jointX makes from the baseX vector 
function relAngleInFrame(baseX,baseY,jointX)
local lx=vector.dot(baseX,jointX)
local ly=vector.dot(baseY,jointX)
return math.atan2(ly,lx)
end

function matrixMul(m1,m2)
--matrix multiplication, requires that matrices have a .r and .c for specifying number of rows and columns
        --if(m1.c~=m2.r)then
        --        error(string.format("m1:%d , m2:%d",m1.c,m2.r),2)
        --end
        local mat = {}
        mat.r = m1.r
        mat.c = m2.c
       
        for i=1,m1.r do
                mat[i] = {}
                for j=1,m2.c do
                        mat[i][j] = 0
                        for k=1,m1.c do
                                mat[i][j] = mat[i][j] + m1[i][k]*m2[k][j]
                        end
                end
        end
        return mat
end

--if you're doing operations on position vectors rather than orientation vectors, you will need to add/subtract ref position
-- convert world coordinates to coordinates in the block(specified by ref) frame of reference
function world2Local(vec,ref)
-- get a vector in the frame of the ref
return vector.new(vector.dot(ref.right(),vec),
                  vector.dot(ref.up(),vec),
		  vector.dot(ref.forward(),vec))

end
--convert local coordinates of ref to world coordinates
function local2World(vec,ref)
local wvec=vector.add(vector.multiply(ref.right(),vec.x), vector.multiply(ref.up(),vec.y))
return vector.add(wvec,vector.multiply(ref.forward(),vec.z))
end

---*************************NIVE CONTROL FUNCTIONS*************************
--controlling knives is fucking annoying
--so nives have some pecularities. In order to make them work properly, for the first 10 timesteps in fixed update you need to set nive thrust to -1 and click the corresponding nive key
--I find it's best to have a single nive key for everything and turn hold to fire off. Setting all knive on hold to fire and pressing the button all the time might work?
--makeNiveAxisTable, initializeNiveAxisTable, and niveAxisThrust are all functions that make controlling a pair of sets of nives that face in opposite directions.
--this way, when you send a number to niveAxisThrust, you can get thrust in that axis, depending on whether it's positive, negative, or zero
 
--
--nive axis tables are of the form {{positive nive string refs},{negative nive string refs},clamp=maximum thrust on each nive}
--call makeNiveAxisTable in play
function makeNiveAxisTable(nvT)
--takes in a table listing knive refs, makes the table consist of two tables consisting of nive controls. The first one for nives that act on the positive axis, and the second one for nives that act on the negative axis

 local pos = nvT[1]
 local neg = nvT[2]
 local posCtrls={}
 for i, ref in ipairs(pos) do
 posCtrls[i]=machine.get_refs_control(ref)
 end
 local posCtrls={}
 for i, ref in ipairs(pos) do
 posCtrls[i]=machine.get_refs_control(ref)
 end
 nvT["posCtrls"]=posCtrls
 local negCtrls={}
 for i, ref in ipairs(neg) do
 negCtrls[i]=machine.get_refs_control(ref)
 end
 nvT["negCtrls"]=negCtrls
 --return posCtrls
end

function initializeNiveAxisTable(nvT)
local initVal=-1
 for i, ctrl in ipairs(nvT["posCtrls"]) do
  ctrl.set_slider('strength',initVal)
 end
 for i, ctrl in ipairs(nvT["negCtrls"]) do
  ctrl.set_slider('strength',initVal)
 end
end

function niveAxisThrust(nvT,thrust)
 local absThrust=math.abs(thrust)
 if absThrust>nvT["clamp"] then
 absThrust=nvT["clamp"]
 end
 
 for i, ctrl in ipairs(nvT["posCtrls"]) do
  ctrl.set_slider('strength',0)
 end
 for i, ctrl in ipairs(nvT["negCtrls"]) do
  ctrl.set_slider('strength',0)
 end

if (thrust>0) then
 for i, ctrl in ipairs(nvT["posCtrls"]) do
  ctrl.set_slider('strength',-absThrust)
 end
else 
 for i, ctrl in ipairs(nvT["negCtrls"]) do
  ctrl.set_slider('strength',-absThrust)
 end
 
end

end

function niveThrust2Power(thr)
local a=(thr+4)/14
return a
end

function niveThrust2PowerVec(thr)
return vector.new(niveThrust2Power(thr.x),niveThrust2Power(thr.y),niveThrust2Power(thr.z))
end



---*************************CRAP THAT HAS STATES*************************

--PID control, define a pid as a global variable= {{kp,ki,kd},{integrator min,integrator max}}, feed that into make pid
function makePID(pid)
pid["i"]=0
pid["v"]=0
pid["val"]=0

end
--then run PIDctrl, preferably every step
function PIDctrl(pid,v)
 pid["i"]=math.min(pid[2][2],math.max(pid[2][1],v*pid[1][2]+pid["i"]))
 pid["val"]=pid[1][1]*v+pid["i"]+(v-pid["v"])*pid[1][3]
 pid["v"]=v
 return pid["val"]
end

--works similar to makePID and PIDctrl
function makeLowPassFilter(name, RC, dt)
--name is string name of the variable
--RC time constant
--dt is 1/100, unless you're not calling it every frame
--_ENV[name]={}

name.alpha=dt/(RC+dt)
name.ylast=0
end

function lowPassFilter(name,x)
local y= name.ylast+name.alpha*(x-name.ylast)
name.ylast=y
return y
end


