#Lever

```
 /\
 \ \  "Give me a place to stand and with a lever I will move the whole world."
  \ \           - Archimedes
   \ \
    \ \
     \ \
      \ \
       \ \
        \/
```


Lever gives developers a very good place to stand. It is built on [luvit](https://luvit.io), which means that it is very fast and uses very little memory, and it has a simple api to use.

Lever should be considered a work in progress, as the api has and will go through considerable changes as luvit evolves and matures, and as new ideas are incorporated into the project.


Right now there are four types of systems available to the developer.
- standard req,res callbacks
- stream based req,res functions
- stream based handoff functions
- stream based event systems

##Standard req,res callbacks

This is a simple api that just calls a callback with the request and the response as the first and second paramter. This is good for simple actions that really don't need anything else.

###Example

```lua
local lever = require('lever')

lever:get('/identify/?name',function(req,res)
	res.finish("hello, " .. req.env.name)
end)

```

##Stream based req,res functions

This is the Standard version wrapped up in a streams api.

###Example

```lua
local lever = require('lever')


-- kind of messy right now, but working to clean it up
local Echo = Lever.Stream.Transform:extend()

function Echo:initialize(data)
    self.data = data
    local opt = {objectMode = true}
    Lever.Stream.Transform.initialize(self, opt)
end

function Echo:_transform(opts,encoding,cb)
    opts.data = self.data
    
    -- optional
    self.code = 200
    self.headers = {}

    cb(nil, opts)
end


local send = lever.json():pipe(lever.reply())
local echo = Echo:new("some data to send")
local echo2 = Echo:new("some other data to send")

lever:get('/ask')
	:pipe(echo)
	:pipe(send)

lever:get('/ask2')
	:pipe(echo2)
	:pipe(send) -- you can reuse streams!

```

##Stream based handoff functions

Sometimes, you need more then just a single response. With this version you pass a stream back to lever, and lever hooks the stream onto the response.

###Example

```lua
local lever = require('lever')


-- kind of messy right now, but working to clean it up
local Static = Lever.Stream.Transform:extend()

function Static:initialize(folder)
    self.folder = folder
    local opt = {objectMode = true}
    Lever.Stream.Transform.initialize(self, opt)
end

function Static:_transform(opts,encoding,cb)
    local file = self.folder .. '/' .. opts.req.env.name
    -- yeah this is not safe, I should change this.
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


lever:get('/file/?name')
    :pipe(Static:new(process.env.PWD)) -- serve files from the current directory
    :pipe(lever.reply())
```

##Stream based event systems

Piping to a lever endpoint creates a subscription type system. This is makes it really easy to generate pub sub style systems where events are not stored and are instantly send to eveyone interested.

###Example

```lua
local lever = require('lever')


-- kind of messy right now, but working to clean it up
local Publish = Lever.Stream.Readable:extend()

function Publish:initialize(init)
    self.value = init or 0
    local opt = {objectMode = true}
    Lever.Stream.Readable.initialize(self, opt)
end

function Publish:_read(opts)
	-- don't need anything here, all data comes from some where else
end


local publish = Publish:new(12)
lever:post('pub/?msg',function(req,res)
	publish:push(req.env.msg)
	res.finish()
end)

publish
    :pipe(lever.json())
    :pipe(lever:get('/sub'))
```