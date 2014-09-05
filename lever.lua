-- -*- mode: lua tab-width: 2 indent-tabs-mode: 1 st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
---------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2014, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   3 Sept 2014 by Daniel Barney <daniel@pagodabox.com>
---------------------------------------------------------------------

local http = require('http')
local querystring = require('querystring')

local Lever = {}
Lever.__index = Lever

function Lever.new ()
	local self = {
		cbs = {}}
    self = setmetatable(self, Lever)
    return self
end

function Lever:get(path,callback)
    self:add_route('/GET',path,callback)
end

function Lever:put(path,callback)
    self:add_route('/PUT',path,callback)
end

function Lever:post(path,callback)
    self:add_route('/POST',path,callback)
end

function Lever:delete(path,callback)
    self:add_route('/DELETE',path,callback)
end

function Lever:all(path,callback)
    self:add_route('?',path,callback)
end

function Lever:add_route(method,path,callback)
    local cbs = self.cbs
    local fields = {}
    local matches = {}
    path = path:lower()
    for c in path:gmatch("/[^/]*") do
    	-- print("test:",c,c:sub(2,2))
    	if c:sub(2,2) == "?" then
    		-- print("matching",path,c)
    		
    		matches[#matches + 1] = c:sub(3,c:len())

    		fields[#fields + 1] = "?"
    	else
    		-- print("inserting",path,c)
	    	fields[#fields + 1] = c 
	    end
    end

    local node = cbs
    local elem
    for index,elem in ipairs(fields) do
    	-- print("path",path,elem)
    	local tmp = node[elem]
    	if not tmp then
    		tmp = {}
    		node[elem] = tmp
    	end
    	node = tmp
    end
    if not node[method] then
    	node[method] = {}
    	node = node[method]
    end
    if method == '?' then
    	matches[#matches + 1] = "priv__method"
    end
    node.callback = callback
    node.matches = matches


end


-- private function
function find_route(lever,method,url)
	-- print("method",method)
	local fields = {}
	for c in url:gmatch("/[^/]*") do
  	fields[#fields + 1] = c
  end
  fields[#fields + 1] = "/" .. method

  local node = lever.cbs
  local elem
  local matches = {}

	for index,elem in ipairs(fields) do
		-- print("checking",elem)
    	local tmp = node[elem]
    	if (not tmp) and node["?"] then
    		matches[#matches + 1] = elem:sub(2,elem:len())
    		-- print("match?",elem,matches[#matches])
    		tmp = node["?"]
    	end
    	if not tmp then
			return nil
    	end
    	node = tmp
    end

    if #node.matches == #matches then
    	-- print("matched!",#matches)
    	local env = {}
    	for index in ipairs(matches) do
    		-- print ("adding",node.matches[index],index,matches[index])
    		env[node.matches[index]] = matches[index]
    	end
    	return node.callback, env
    else
    	-- print("didn't match...")
    	return nil
    end

end

function Lever:listen(port,ip)
	if not ip then
		ip = "127.0.0.1"
	end
	local lever = self
	self.server = http.createServer(function (req, res)
	  
	  res:on("error", function(err)
	    msg = tostring(err)
	    -- print("Error while sending a response: " .. msg)
	  end)

      local path,qs = req.url:match("([^?]+)(|?(.*))")
	  local callback, env = find_route(lever,req.method,path)
	  
	  if callback then
        if qs then
            req.qs = querystring.parse(qs:sub(2,qs:len()))
        else
            req.qs = {}
        end
	  	req.env = env
	    callback(req,res)
	  else
	    res:writeHead(404,{})
	    res:finish()
	  end

	end)
	print("Server listening at http://"..ip..":"..port.."/")
	self.server:listen(port,ip)
end

return Lever