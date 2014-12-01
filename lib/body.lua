-- -*- mode: lua tab-width: 2 indent-tabs-mode: 1 st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
---------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2014, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   1 Dec 2014 by Daniel Barney <daniel@pagodabox.com>
---------------------------------------------------------------------

local Stream = require('stream')

local Body = Stream.Transform:extend()

function Body:initialize(max)
    self.max = max
    local opt = 
        {objectMode = true}
    Stream.Transform.initialize(self, opt)
end

function Body:_transform(data,encoding,cb)
    local chunks = {}
    local current = 0
    data.req:on('data',function(data)
        chunks[#chunks + 1] = data
        current = current + data:len()
        if current > self.max then
            chunks = nil
            -- this should send an error back to the client
            cb("error",nil)
        end
    end)

    data.opts.req:on('end',function()
        if chunks then
            data.data = table.concat(chunks,"")
            cb(nil,data)
        end
    end)
end


return Body