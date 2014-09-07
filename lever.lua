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
local table = require('table')

local Lever = {}
Lever.__index = Lever

function Lever.new ()
    local self = 
        {cbs = {}
        ,middleware = {}}
    self = setmetatable(self, Lever)
    return self
end

function Lever:add_middleware(middleware)
    self.middleware[#self.middleware +1] = middleware
end

function Lever:get(path,...)
    self:add_route('/GET',path,...)
end

function Lever:put(path,...)
    self:add_route('/PUT',path,...)
end

function Lever:post(path,...)
    self:add_route('/POST',path,...)
end

function Lever:delete(path,...)
    self:add_route('/DELETE',path,...)
end

function Lever:all(path,...)
    self:add_route('?',path,...)
end

function Lever:add_route(method,path,...)
    local stack = {...}
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
    node.stack = stack
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
        return node.stack, env
    else
        -- print("didn't match...")
        return nil
    end

end

function handle_stack (stack,req,res)
  local step = stack[1]
  if step then
    table.remove(stack,1)
    step(req,res,function()
        handle_stack(stack,req,res)
    end)
  end
end

function concat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
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
      local route_stack, env = find_route(lever,req.method,path)
      
      local stack = concat({},self.middleware);
      
      if route_stack then
        if qs then
            req.qs = querystring.parse(qs:sub(2,qs:len()))
        else
            req.qs = {}
        end
            
        req.env = env
        req.user = {}

        stack = concat(stack,route_stack);
      else
        stack[#stack +1] = function(req,res,pass)
            res:writeHead(404,{})
            res:finish()
          end
      end
      
      handle_stack(stack,req,res)

    end)
    print("Server listening at http://"..ip..":"..port.."/")
    self.server:listen(port,ip)
end

return Lever