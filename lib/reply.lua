-- -*- mode: lua tab-width: 2 indent-tabs-mode: 1 st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
---------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2014, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   21 Nov 2014 by Daniel Barney <daniel@pagodabox.com>
---------------------------------------------------------------------

local Stream = require('stream')

local Streamed = Stream.Writable:extend()

function Streamed:initialize(res)
    self.res = res
    local opt = 
        {objectMode = true}
    Stream.Writable.initialize(self, opt)
end

function Streamed:_write(data,encoding,cb)
    self.res:write(data)
    cb()
end

local Reply = Stream.Writable:extend()

function Reply:initialize()
    local opt = {objectMode = true}
    Stream.Writable.initialize(self, opt)
end

function Reply:_write(data,encoding,cb)
    if data.res then
        if data.stream then
            data.res:writeHead(data.code or 200,data.headers or {})
            local res = Streamed:new(data.res)
            data.stream:pipe(res)
            data.stream:once('end',function()
                data.res:finish()
            end)
            data.stream:once('error',function()
                data.res:finish()
            end)
        else
            
            if not data.headers then
                data.headers = {}
            end
            data.headers["Content-Length"] = #data.data

            data.res:writeHead(data.code or 200,data.headers)
            data.res:finish(data.data)
        end
        cb()
    else
        cb(core.Error:new('stream doesn\'t have the response' ))
    end
end

return Reply