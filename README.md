#Lever

Lever is a simple express.js like http server that allow quick routing of paths to functions that act as handlers.

##Example Usage

```

local lever = require('lever')


-- log every request that goes through lever
function logger(req,res,pass)
	p("new request ",req.url)
	pass()
end

lever:add_middleware(logger)

-- all means map to any method
lever.all('/ping',function(req,res)
	res:writeHead(200,{})
	res:finish("{\"ping\":\"pong\"}")
end)

-- only handle GET requests
lever.get('/status',function(req,res)
	res:writeHead(200,{})
	res:finish("{\"status\":\"alive\"}")
end)

-- lever also supports matching from the url
-- and acessing those matches later
lever.get('/echo/?match', function(req,res)
	res:writeHead(200, {})
	res:finish(req.env.match)
end)

lever.listen(8080)

```