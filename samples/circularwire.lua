-- File to generate a discretized circular wire input file to simulate in Fast Henry

require("LuaMath")

require("debugUtil")

c = require("geom.circle")

-- Get the discretization of a wire of circular radius of 1mm and length of 1m
err = 100
seg = 3
while err > 3 do	-- get less than 3% error
	seg = seg + 1
	rects,err = c.discreteRect(1,seg)
end

-- Now create a FastHenry input file
gi = require("fasthenryUtils.genInput")
inp = gi.newInput("mm")

-- There are just 2 electrical nodes "start" and "end"
ST = "start"
EN = "end"

-- Add the segments
for i = 1,#rects do
	print("Add Segment: ",inp:addSegment{
		w = rects[i].l,
		h = rects[i].w,
		sn1 = {x = rects[i].x, y = 0, z = rects[i].y},	-- Making the x-y plane along the length of the wire so y=0 at START and y=length at END
		sn2 = {x = rects[i].x, y = 1000, z = rects[i].y},
		en1 = ST,
		en2 = EN,
		rho = 1.68e-8	-- Copper resistivity
	})
end

-- Add Ports
print("Add Port: ",inp:addPorts{
	{ST,EN}
})
-- Set Frequency
print("Set Frequency: ",inp:setFreq(10,100e6,0.5))

-- Write File
print("Write File: ",inp:writeFile("circularWire.txt",true))