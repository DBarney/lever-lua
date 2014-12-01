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
local core = require('core')
local Stream = require('stream')
local Json = require('./lib/json')
local Resource = require('./lib/resource')
local Reply = require('./lib/reply')
local Body = require('./lib/body')


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

function Lever:get(path,cb)
    return self:facade(path,'GET',cb)
end

function Lever:post(path,cb)
    return self:facade(path,'POST',cb)
end

function Lever:put(path,cb)
    return self:facade(path,'PUT',cb)
end

function Lever:head(path,cb)
    return self:facade(path,'HEAD',cb)
end

function Lever:delete(path,cb)
    return self:facade(path,'DELETE',cb)
end

function Lever:all(path,cb)
    return self:facade(path,'?__method',cb)
end

function Lever:facade(path,method,cb)
    local chunks = build_lookup(path,method)

    local resource = self:lookup(chunks,true)
    if not resource then
        if not (cb == nil) then

            resource = {handle = function(_,...) cb(...) end}
        else
            resource = Resource:new(self)
        end
        resource.path = path
        -- store off the resource somewhere
        self:_insert(chunks,resource)
    end
    return resource
end


function Lever:json() return Json:new() end
function Lever:reply() return Reply:new() end
function Lever:body() return Body:new() end

Lever.Stream = Stream
return Lever