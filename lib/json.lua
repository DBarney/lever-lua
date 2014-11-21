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
local json = require('json')

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

return Json