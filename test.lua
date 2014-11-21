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
timer = require('timer')

local lever = Lever:new(8080,"127.0.0.1")

local Echo = Lever.Stream.Transform:extend()
function Echo:initialize(options)
    self.options = options
    local opt = {objectMode = true}
    Lever.Stream.Transform.initialize(self, opt)
end
function Echo:_transform(opts,encoding,cb)
    opts.data = {ping = "pong",global = self.options,env = opts.req.env}
    cb(nil, opts)
end

local Stats = Lever.Stream.Readable:extend()
function Stats:initialize(init)
    self.value = init or 0
    local opt = {objectMode = true}
    Lever.Stream.Readable.initialize(self, opt)
end
function Stats:_read(opts)
    timer.setTimeout(1000,function() 
        self:push(self.value)
        self.value = self.value + 1
    end)
end

local echo = Echo:new("default")
local stats = Stats:new(12)


-- not sure how useful this function really is, it could be good for a stream
-- of events that the user subscribes to
stats:pipe(lever.json()):pipe(lever:get('/stats'))

-- this seems to work better for what we need in this case
echo:pipe(lever.json()):pipe(lever.reply())

lever:all('/ping'):pipe(echo)
lever:all('/ping/?test'):pipe(echo)

process:on('error',p)