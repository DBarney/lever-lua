#!/usr/local/bin/luvit
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

Lever = require('./lever')

local lever = Lever:new(8080,"127.0.0.1")

local Readable = Lever.Stream.Readable
local Publish = Readable:extend()

function Publish:initialize()
    local opt = {objectMode = true}
    Readable.initialize(self,opt)
end

function Publish:_read(opts)
    -- don't need anything here, all data comes from some where else
end


local publish = Publish:new(12)
lever:post('pub/?msg',function(req,res)
    publish:push(req.env.msg)
    res:writeHead(200,{})
    res:finish("")
end)

publish
    :pipe(lever.json())
    :pipe(lever:get('/sub'))


lever:all('ping',function(req,res)
	res:writeHead(200,{})
	res:finish("pong")
end)