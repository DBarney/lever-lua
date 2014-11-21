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

return Resource