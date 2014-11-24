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
fs = require('fs')

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

local Static = Lever.Stream.Transform:extend()
function Static:initialize(folder)
    self.folder = folder
    local opt = {objectMode = true}
    Lever.Stream.Transform.initialize(self, opt)
end
function Static:_transform(opts,encoding,cb)
    local file = self.folder .. '/' .. opts.req.env.name
    -- yeah not safe at all.
    fs.stat(file,function(err,_)
        if not err then
            opts.stream = fs.createReadStream(file)
            cb(nil,opts)
        else
            opts.code = 404
            cb(nil,opts)
        end
    end)
end





-- old express.js style api
lever:all('/test',function(req,res)
    res:finish('response')
end)

-- stream of events that clients can subscribe to, no history
Stats:new(12)
    :pipe(lever.json())
    :pipe(lever:get('/stats'))


-- echo endpoint that responds with data stored in the url.
local echo = Echo:new("default")
    :pipe(lever.json())
    :pipe(lever.reply())

lever:all('/ping')
    :pipe(echo)
lever:all('/ping/?test')
    :pipe(echo)


-- static file streamer, no cache, always reads from disk.
lever:get('/file/?name')
    :pipe(Static:new(process.env.PWD))
    :pipe(lever.reply())

process:on('error',p)