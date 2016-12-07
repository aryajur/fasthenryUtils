-- Module to help generate the fast henry input file
-- The basic thing that the module helps with is separation of electrical nodes with spatial nodes. So now you specify each segment with 
--  spatial nodes and electrical nodes separately. The input file write takes care of writing .equiv statements to finally converge the 
--  spatial nodes and electrical nodes in the FastHenry input file

-- Currently planes are not supported

local modname = ...
local setmetatable = setmetatable
local getmetatable = getmetatable
local type = type
local table = table
local tostring = tostring
local io = io

local M = {}
package.loaded[modname] = M
if setfenv then
	setfenv(1,M)
else
	_ENV = M
end

local meta

-- Function to add a segment to the structure definition object
-- The structure object is the 1st argument
-- The parameter table is the 2nd argument. The table keys expected are:
--		* sn1 - 1st spatial node coordinate {x,y,z}
--		* sn2 - 2nd spatial node coordinate {x,y,z}
--		* en1 - 1st electrical node name
--		* en2 - 2nd electrical node name
--		* w - Width of segment
--		* h - Height of segment
--		* sigma or rho	- Conductivity or resistivity of the segment
--	Optional keys:
--		* wx,wy,wz
local function addSegment(inp,para)
	if type(para) ~= "table" then
		return nil,"Need the parameter table as the second argument to define the segment."
	end
	if not para.sn1 or not para.sn2 or not para.en1 or not para.en2 then
		return nil, "Need the sn1, sn2, en1 and en2 nodes betwen which the segment connects"
	end
	if not type(para.sn1) == "table" or not para.sn1.x or type(para.sn1.x) ~= "number" or not para.sn1.y or type(para.sn1.y) ~= "number" 
	  or not para.sn1.z or type(para.sn1.z) ~= "number" then
		return nil, "sn1 needs to be a table with x, y and z numbers"
	end
	if not type(para.sn2) == "table" or not para.sn2.x or type(para.sn2.x) ~= "number" or not para.sn2.y or type(para.sn2.y) ~= "number"
	  or not para.sn2.z or type(para.sn2.z) ~= "number" then
		return nil, "sn2 needs to be a table with x, y and z numbers"
	end
	if type(para.en1) ~= "string" or type(para.en2) ~= "string" then
		return nil,"en1 and en2 need to be electrical node names as strings."
	end
	if not para.w or not para.h then
		return nil, "Need the w and h parameters for the segment"
	end
	if not para.sigma and not para.rho then
		return nil,"Either sigma (conductivity) or rho (resistivity) of the segment must be given"
	end
	if para.sigma and type(para.sigma) ~= "number" then
		return nil,"sigma (conductivity) should be a number"
	end
	if para.rho and type(para.rho) ~= "number" then
		return nil,"rho (resistivity) should be a number"
	end
	-- Check if wx,wy,wz is given then all 3 should be there
	if (para.wx and (not para.wy or not para.wz)) or (para.wz and (not para.wy or not para.wx)) or (para.wy and (not para.wx or not para.wz)) then
		return nil,"wx,wy,wz should all be given if any one of them is specified."
	end
	if para.wx and (type(para.wx) ~= "number" or type(para.wy) ~= "number" or type(para.wz) ~= "number") then
		return nil,"wx,wy and wz should be numbers"
	end
	
	if type(inp) ~= "table" or inp.gm ~= meta then
		return nil,"The first argument should be a valid input object."
	end
	local function mergeNodes(nodes,node)
		for i = 1,#nodes do
			if nodes[i].x == node.x and nodes[i].y == node.y and nodes[i].z == node.z then
				return i
			end
		end
		nodes[#nodes + 1] = {x=node.x,y=node.y,z=node.z}
		return #nodes
	end
	local sn1 = mergeNodes(inp.snodes,para.sn1)
	local sn2 = mergeNodes(inp.snodes,para.sn2)
	inp.snodes[sn1].en = para.en1
	inp.snodes[sn2].en = para.en2
	para.sn1 = sn1
	para.sn2 = sn2
	inp.segments[#inp.segments + 1] = para
	return true
end

-- Function to define ports for the system
-- inp is the input file object
-- ports is a table containing a list of tables each containing 2 electrical node names which would act as a port
-- It will replace any previously defined ports
local function addPorts(inp,ports)
	if type(inp) ~= "table" or inp.gm ~= meta then
		return nil,"The first argument should be a valid input object."
	end
	local iports = {}
	for i = 1,#ports do
		if type(ports[i][1]) ~= "string" or type(ports[i][2]) ~= "string" then
			return nil,"Port should have two electrical node names"
		end
		iports[i] = {ports[i][1],ports[i][2]}
	end
	inp.ports = iports
	return true
end

-- Function to setup the frequency information for the input file object
-- inp is the input file object
-- fmin is the minimum frequency
-- fmax is the maximum frequency
-- ndec is the number of points per decade (it can be float)
-- It will replace any previously defined frequency information
local function setFreq(inp,fmin,fmax,ndec)
	if type(inp) ~= "table" or inp.gm ~= meta then
		return nil,"The first argument should be a valid input object."
	end
	if type(fmin) ~= "number" or type(fmax) ~= "number" or (type(ndec) ~= "number" and type(ndec) ~= "nil") then
		return nil,"Need fmin, fmax and ndec numbers."
	end
	inp.fmin = fmin
	inp.fmax = fmax
	inp.ndec = ndec
	return true
end

local function file_exists(file)
	local f,err = io.open(file,"r")
	if not f then
		return nil,err
	end
	f:close()
	return true
end 

-- inp is the input object
-- fileName is the path and name of the file which is created with the input object data
-- force is a boolean. If true then even if file exists it will overwrite.
local function writeFile(inp,fileName,force)
	if file_exists(fileName) and not force then
		return nil,"File already exists."
	end
	if type(inp) ~= "table" or inp.gm ~= meta then
		return nil,"The first argument should be a valid input object."
	end
	-- Write the units
	local fileStr = {"* Set the units\n.units ",inp.unit,"\n"}
	-- Write the nodes
	for i = 1,#inp.snodes do
		fileStr[#fileStr+1] = "N"..tostring(i).." x="..tostring(inp.snodes[i].x)..
		              " y="..tostring(inp.snodes[i].y).." z="..tostring(inp.snodes[i].z).."\n"
	end
	fileStr[#fileStr+1] = "\n"
	-- Now write the segments connecting the nodes
	for i = 1,#inp.segments do
		fileStr[#fileStr+1] = "E"..tostring(i).." N"..tostring(inp.segments[i].sn1)..
		              " N"..tostring(inp.segments[i].sn2).." w="..tostring(inp.segments[i].w).." h="..tostring(inp.segments[i].h)
		if inp.segments[i].sigma then
			fileStr[#fileStr+1] = " sigma="..tostring(inp.segments[i].sigma)
		else
			fileStr[#fileStr+1] = " rho="..tostring(inp.segments[i].rho)
		end
		if inp.segments[i].wx then
			fileStr[#fileStr+1] = " wx="..tostring(inp.segments[i].wx).." wy="..tostring(inp.segments[i].wy).." wz="..tostring(inp.segments[i].wz)
		end
		if inp.segments[i].nhinc then
			fileStr[#fileStr+1] = " nhinc="..tostring(inp.segments[i].nhinc)
		end
		if inp.segments[i].nwinc then
			fileStr[#fileStr+1] = " nwinc="..tostring(inp.segments[i].nwinc)
		end
		if inp.segments[i].rh then
			fileStr[#fileStr+1] = " rh="..tostring(inp.segments[i].rh)
		end
		if inp.segments[i].rw then
			fileStr[#fileStr+1] = " rw="..tostring(inp.segments[i].rw)
		end
		fileStr[#fileStr+1] = "\n"
	end
	fileStr[#fileStr+1] = "\n"
	-- Write all the equivalent statements
	local enodes = {}	-- Create a lookup based on electrical node names
	for i = 1,#inp.snodes do
		local found
		for j = 1,#enodes do
			if enodes[j].name == inp.snodes[i].en then
				enodes[j].nodes[#enodes[j].nodes + 1] = i
				found = true
				break
			end
		end
		if not found then
			enodes[#enodes+1] = {name = inp.snodes[i].en, nodes = {i}}
		end
	end
	for i = 1,#enodes do
		fileStr[#fileStr + 1] = ".Equiv "
		for j = 1,#enodes[i].nodes do
			fileStr[#fileStr + 1] = "N"..tostring(enodes[i].nodes[j]).." "
		end
		fileStr[#fileStr + 1] = "\n"
	end
	fileStr[#fileStr + 1] = "\n* Define the ports of the network\n"
	-- Create the ports
	if not inp.ports then
		return nil,"Define the ports first."
	end
	for i = 1,#inp.ports do
		local found1,found2
		for j = 1,#enodes do
			if inp.ports[i][1] == enodes[j].name then
				found1 = j
			end
			if inp.ports[i][2] == enodes[j].name then
				found2 = j
			end
			if found1 and found2 then
				break
			end
		end
		if not found1 or not found2 then
			return nil,"All port nodes not defined in the segment nodes."
		end
		fileStr[#fileStr + 1] = ".external N"..tostring(enodes[found1].nodes[1]).." N"..tostring(enodes[found2].nodes[1]).."\n"
	end
	-- Enter the frequency
	fileStr[#fileStr+1] = "\n.freq fmin="..tostring(inp.fmin).." fmax="..tostring(inp.fmax)..
	  " "..((inp.ndec and "ndec="..tostring(inp.ndec)) or "").."\n"
	-- Mark end of file
	fileStr[#fileStr + 1] = "* Mark end of file\n.end"
	-- Write the file to disk
	local f = io.open(fileName,"w+")
	f:write(table.concat(fileStr))
	f:close()
	return true
end

meta = {
	__metatable="Do not change",
	__index = function(t,k)
		if k == "addSegment" then
			return addSegment
		elseif k == "addPorts" then
			return addPorts
		elseif k == "writeFile" then
			return writeFile
		elseif k == "setFreq" then
			return setFreq
		elseif k =="gm" then
			return meta
		end		
	end,
}


-- Function to define a new input file instance
function newInput(unit)
	if type(unit) ~= "string" or (unit ~= "km" and unit ~= "m" and unit ~= "cm" and unit ~= "mm" and unit ~= "um" and unit ~= "in" and unit ~= "mils") then
		return nil,"Need a unit 'km','m','cm','mm','um','in','mils'"
	end
		
	local inp = {
			unit = unit,
			snodes = {},	-- spatial nodes
			segments = {}
		}
	return setmetatable(inp,meta)
end
