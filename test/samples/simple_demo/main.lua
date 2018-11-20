--dofile "libs/init.lua"
package.path = "engine/libs/?.lua;engine/libs/?/?.lua;?.lua"

local rt = require "runtime"

function dprint(...)
	print(...)
	local nio = package.loaded.nativeio or io	
	nio.stdout:flush()
end

require "common/import"
require "common/log"

local native = require "window.native"
local window = require "window"

local width = 1024
local height = 768
local nwh = native.create(width,height,"Hello World")

local inputmgr = require "inputmgr"
local iq = inputmgr.queue {
	button = "_,_,_,_,_",
	motion = "_,_,_",
}

local callback = {}

function callback.error(err)
	print(err)
end

local status = {}
function callback.move(x,y)
	iq:push("motion", x, y, status)
end

function callback.touch(what, x, y)
	local function translate()
		local press = what % 2
		if what > 2 then
			status.RIGHT = press == 1
			status.LEFT = false
			return "RIGHT", press
		end
		status.RIGHT = false
		status.LEFT = press == 1
		return "LEFT", press
	end
	local btn, p = translate()
	iq:push("button", btn, p, x, y)
end

function callback.keypress(k, p)
	if not p then
		print(k)
	end
end

local su = require "scene.util"
local rhwi = require "render.hardware_interface"
rhwi.init(nwh, width, height)

local world = su.start_new_world(iq, width, height, {"simplescene"}, "?.lua")

function callback.update()
	rt.update()
	world.update()
end

function callback.exit()	
	dprint("exit")
end

window.register(callback)
native.mainloop()


