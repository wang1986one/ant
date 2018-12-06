--luacheck: globals import log
local require = import and import(...) or require
local log = log and log(...) or print

local bgfx = require "bgfx"

local path = require "filesystem.path"
local assetmgr = require "asset"

local vfs = require "vfs"

local localfile = require "filesystem.file"

local alluniforms = {}

local shader_mgr = {}
shader_mgr.__index = shader_mgr

local function gen_shader_filepath(shadername)	
	assert(path.ext(shadername)==nil)
	local shadername_withext = shadername .. ".sc"
	local filepath = assetmgr.find_valid_asset_path(shadername_withext)
	if filepath then
		return filepath 
	end

	--local enginepath, matchnum = shadername_withext:gsub("(engine/assets/shaders)(.+)", "%1/" .. shadertype .. "%2")
	-- local foundpos = shadername_withext:find("engine/assets/shaders/src")
	-- if foundpos then
	-- 	filepath = assetmgr.find_valid_asset_path(enginepath)
	-- 	if filepath then
	-- 		return filepath
	-- 	end
	-- end

	local shadersrc_filepath = path.join("shaders/src", shadername_withext)	
	return assetmgr.find_valid_asset_path(shadersrc_filepath)
end

local function load_shader(name)
	local filename = gen_shader_filepath(name)
	if filename == nil then
		error(string.format("not found shader file: %s", name))
	end

	if vfs.localvfs then
		local cvtutil = require "fileconvert.util"
		assert(cvtutil.need_build(filename))
	end
	local validfile = vfs.realpath(filename)
	local f = assert(localfile.open(assert(validfile), "rb"))
	local data = f:read "a"
	f:close()
	local h = bgfx.create_shader(data)
	bgfx.set_name(h, name)
	return h    
end

local function load_shader_uniforms(name)
    local h = load_shader(name)
    print("load uniform ",name )
    assert(h)
    local uniforms = bgfx.get_shader_uniforms(h)
    return h, uniforms
end

local function uniform_info(uniforms, handles)
    for _, h in ipairs(handles) do
        local name, type, num = bgfx.get_uniform_info(h)
        if uniforms[name] == nil then
            uniforms[name] = { handle = h, name = name, type = type, num = num }
        end
    end
end

local function programLoadEx(vs,fs, uniform)
    local vsid, u1 = load_shader_uniforms(vs)
    local fsid, u2
    if fs then
        fsid, u2 = load_shader_uniforms(fs)
    end
    uniform_info(uniform, u1)
    if u2 then
        uniform_info(uniform, u2)
    end
    return bgfx.create_program(vsid, fsid, true), uniform
end

function shader_mgr.programLoad(vs,fs, uniform)
    if uniform then
        local prog = programLoadEx(vs,fs, uniform)
        if prog then            
            for k, v in pairs(uniform) do
                local old_u = alluniforms[k]
                if old_u and old_u.type ~= v.type and old_u.num ~= v.num then
                    log(string.format([[previous has been defined uniform, 
                                    nameis : %s, type=%s, num=%d, replace as : type=%s, num=%d]],
                                    old_u.name, old_u.type, old_u.num, v.type, v.num))
                end

                alluniforms[k] = v
            end
        end
        return prog
    else
        local vsid = load_shader(vs)
        local fsid = fs and load_shader(fs)          
        return bgfx.create_program(vsid, fsid, true)
    end
end

function shader_mgr.computeLoad(cs)
    local csid = load_shader(cs)
    return bgfx.create_program(csid, true)
end

function shader_mgr.get_uniform(name)
    return alluniforms[name]
end

-- function shader_mgr.add_uniform(name, type, num)
-- 	local uh = alluniforms[name]
-- 	if uh == nil then
-- 		num = num or 1
-- 		uh = bgfx.create_uniform(name, type, num)
-- 		alluniforms[name] = { handle = uh, name = name, type = type, num = num }
-- 	end
-- 	return uh
-- end

return shader_mgr