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

local Stream = require('stream')
local http = require('http')
local json = require('json')
-- local querystring = require('querystring')
-- local table = require('table')
local core = require('core')

local Endpoint = Stream.Writable:extend()

function Endpoint:initialize()
    local opt = {objectMode = true}
    Stream.Writable.initialize(self, opt)
end

function Endpoint:_write(data,encoding,cb)
    if data.res then
        data.res:writeHead(data.code or 200,data.headers or {})
        data.res:finish(data.data)
        cb()
    else
        cb(core.Error:new('stream doesn\'t have the response' ))
    end
end

local Json = Stream.Transform:extend()

function Json:initialize()
    local opt = {objectMode = true}
    Stream.Transform.initialize(self, opt)
end

function Json:_transform(data,encoding,cb)
    -- this will cause issues eventually...
    local encoded = data
    if type(data) == "table" and data.data then
        data.data = json.stringify(data.data or data)
    else
        encoded = json.stringify(data)
    end
    cb(nil,encoded)
end


local Resource = Stream.Duplex:extend()

function Resource:initialize(lever)
    local opt = 
        {objectMode = true}
    self.lever = lever

    Stream.Duplex.initialize(self, opt)
    self.readable = true
    self.writable = true

    
    -- if this stream has pipe called on it, then it will be
    -- sending requests down the pipe to be handled
    local prev_pipe = self.pipe
    self.pipe = function(...)
        if self.readable then
            self.writable = false
            self.need_read = false
            self.queue = {}
            return prev_pipe(...)
                
        else
            error(core.Error:new('reading from a non readable stream'))
        end
    end

    self:on('pipe',function(from)
        if self.writable then
            self.readable = false
        else
            error(core.Error:new('writting to a non writable stream'))
        end
    end)
end

function Resource:_write(chunk, encoding, cb)
    self:emit('publish',chunk)
    cb()
end

local next_alive_req = function(queue)
    return table.remove(queue,1)
end
function Resource:_read(_n)
    local elem = next_alive_req(self.queue)

    if elem then
        self:push(elem)
    else
        self.need_read = true
    end
end

function Resource:handle(req,res)
    if self.writable then
        -- this is the resource for streaming data out from
        -- the system
        res:writeHead(200,{["Transfer-Encoding"] = "chunked"})
        res.chunkedEncoding = true
        self:on('publish',function(data)
            res:write(data)
        end)
    elseif self.readable then
        -- this is the start for requests made to the system
        local elem = {req = req,res = res}
        if self.need_read then
            self.need_read = false
            self:push(elem)
        else
            self.queue[#self.queue + 1] = elem
        end
    end
end

local Lever = core.Object:extend()

function Lever:initialize(ip,port)
    self.resources = {map = {}}
    self.server = http.createServer(function (req, res)
        -- lookup what stream to read from, then read from it
        local resource,env = self:lookup(req.url,req.method:upper())
        if resource then
            req.env = env
            resource:handle(req,res)
        else
            res:writeHead(404, {})
            res:finish("")
        end
    end)
    self.server:listen(ip,port)
end

local build_lookup = function(path,method)
    local chunks = {}

    for chunk in path:gmatch("[^/]*") do
        if chunk:len() > 0 then
            chunks[#chunks + 1] = chunk
        end
    end

    chunks[#chunks + 1] = method
    return chunks
end

function Lever:lookup(path,method)
    if type(path) == "string" then
        path = build_lookup(path,method)
    end
    return self:_lookup(path,false)
end

function Lever:_lookup(chunks,exact)
    local match = self.resources
    local glob = {}
    for _idx,key in pairs(chunks) do
        local new_match = match.map[key]
        if not new_match then
            new_match = match.map['?']
            if not new_match then
                match = nil
                break
            end
            glob[#glob + 1] = key
        end
        match = new_match
    end
    if match then
        local map = {}
        if match.glob[#match.glob] == '__method' then
            match.glob[#match.glob] = nil
        end
        for idx,key in pairs(match.glob) do
            map[key] = glob[idx]
        end
        return match.resource,map
    end
end

function Lever:_insert(chunks,resource)
    local match = self.resources
    local glob = {}
    for _idx,key in pairs(chunks) do
        if key:sub(1,1) == '?' then
            glob[#glob + 1] = key:sub(2,key:len())
            key = '?'
        end

        new_match = match.map[key]
        if not new_match then
            new_match = {map = {},glob = {}}
            match.map[key] = new_match
        end
        match = new_match
    end

    match.resource = resource
    match.glob = glob
end

function Lever:get(path)
    return self:facade(path,'GET')
end

function Lever:post(path)
    return self:facade(path,'POST')
end

function Lever:put(path)
    return self:facade(path,'PUT')
end

function Lever:head(path)
    return self:facade(path,'HEAD')
end

function Lever:delete(path)
    return self:facade(path,'DELETE')
end

function Lever:all(path)
    return self:facade(path,'?__method')
end

function Lever:facade(path,method)
    local chunks = build_lookup(path,method)

    local resource = self:lookup(chunks,true)
    if not resource then
        resource = Resource:new(self)
        -- store off the resource somewhere
        self:_insert(chunks,resource)
    end
    return resource
end

function Lever:json() return Json:new() end
function Lever:reply() return Endpoint:new() end

Lever.Stream = Stream
return Lever