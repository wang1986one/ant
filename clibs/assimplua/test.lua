-- dofile "libs/init.lua"

-- local fu = require "filesystem.util"

-- local meshfile = "mem://test.mesh"
-- fu.write_to_file(meshfile, [[
-- 	mesh_path = "meshes/PVPScene/BH-Scene-campsite-Door"
-- ]])

-- local assetmgr = require "asset"
-- assetmgr.


local assimp = require "assimplua"

assimp.ConvertFBX("../../assets/build/meshes/PVPScene/BH-Scene-campsite-Door.FBX", "./BH-Scene-campsite-Door.antmesh", {
	layout = "p3|n|T|b|t20|c30",
	flags = {
		gen_normal = false,
		tangentspace = true,
	
		invert_normal = false,
		flip_uv = true,
		ib_32 = false,	-- if index num is lower than 65535
	},
	animation = {
		load_skeleton = true,
		ani_list = "all" -- or {"walk", "stand"}
	},
})

local function v3_unpack(v)
	local v1, v2, v3 = string.unpack("<fff", v)
	return {v1, v2, v3}
end

local function float_unpack(v)
	return string.unpack("<f", v)
end

local function uint_unpack(v)
	return string.unpack("<I4", v)
end

local function uint8_unpack(v)
	return string.unpack("<I1", v)
end

local function string_unpack(v)
	return v
end

local function matrix_unpack(v)	
	local t = table.pack(string.unpack("<ffffffffffffffff", v))
	assert(#t == 17 and t.n == 17)
	t[17], t.n = nil, nil
	return t
end


-- local function split(s)
-- 	return s:match("([^:]+):(.*)$")
-- end

local function read_antmesh(filename)	
	local function openfile(filename)
		local ff = io.open(filename, "rb")
		-- local content = ff:read("a")
		-- ff:close()
		-- local readit = 1
		-- local function read(sizeinbytes)
		-- 	local beg = readit
		-- 	readit = readit + sizeinbytes
		-- 	return content:sub(beg, readit - 1)
		-- end
		-- return function()
		-- 	local prefix = read(4)
		-- 	if prefix == nil or #prefix < 4 then
		-- 		return nil
		-- 	end

		-- 	local fullsize = string.unpack("<I4", prefix)
		-- 	if fullsize == 0 then
		-- 		return nil
		-- 	end
		-- 	local elemsize = string.unpack("<I4", read(4))			
		-- 	local elem = read(elemsize)
		-- 	local valuesize = fullsize - elemsize - 8
		-- 	local value = read(valuesize)
		-- 	return elem, value

		-- end
		return function ()
			local prefix = ff:read(4)	-- full content size and elem size
			if prefix == nil or #prefix < 4 then
				ff:close()
				return nil
			end

			local fullsize = uint_unpack(prefix)
			if fullsize == 0 then
				return nil 
			end

			assert(fullsize > 4)
			local elemsize = uint_unpack(ff:read(4))
			local elem = ff:read(elemsize)
			local valuesize = fullsize - elemsize - 8
			local value = ff:read(valuesize)			
			return elem, value
		end
	end
	
	local kvpairs = openfile(filename)

	local function struct_unpack(v, mapper)
		assert(v == nil or v == "")
		local t = {}		
		while true do
			local k, vv = kvpairs()
			if k == nil then
				break
			end
			assert(k)
			local unpacker = mapper[k]
			if unpacker == nil then
				error("not found unpacker, member is : " .. k)
			end			
			t[k] = mapper[k](vv)
		end
		return t
	end

	local function array_unpack(v, mapper)
		local r = {}
		while true do
			local t = struct_unpack(v, mapper)
			if t and next(t) then
				table.insert(r, t)
			else
				break
			end
		end
		return r
	end

	local function bounding_unpack(v)
		return struct_unpack(v, {
			aabb = function (v) 
				return struct_unpack(v, {
					min = v3_unpack,
					max = v3_unpack,
				})end,			
			sphere = function (v)
				return struct_unpack(v, {
					center = v3_unpack,
					radius = float_unpack,
				})
			end,
		})
	end

	-- actually, we can provide a common mapper for some common members, 
	-- like : bounding, transform, num_vertiecs, num_indices etc.	
	-- and when we need something special member mapper, we can provide from 
	-- mapper function. when a member not found in current level, it should 
	-- try to found in it's parent level, until it not found, and it will 
	-- raise an lua error(access to nil member).
	struct_unpack(nil, 
	{
		srcfile = string_unpack,
		bounding = bounding_unpack,

		materials = function (v)	
			return array_unpack(v, {
				name = string_unpack,
				textures = function (v) 
					return struct_unpack(v, {
						diffuse=string_unpack,
						ambient=string_unpack,
						specular=string_unpack,
						normals=string_unpack,
						shininess=string_unpack,
						lightmap=string_unpack,
					})
				end,
				colors = function (v)
					return struct_unpack(v, {
						diffuse=v3_unpack,
						specular=v3_unpack,
						ambient=v3_unpack,
					})
				end
			})
		end,

		groups = function(v)
			return array_unpack(v, {
				bounding	= bounding_unpack,
				vb_layout	= string_unpack,
				num_vertices= uint_unpack,
				vbraw		= string_unpack,

				ib_format	= uint8_unpack,
				num_indices	= uint_unpack,
				ibraw		= string_unpack,
				primitives = function (v)
					return array_unpack(v, {
						bounding= bounding_unpack,
						transform =matrix_unpack,
						name = string_unpack,
						material_idx = uint_unpack,

						start_vertex = uint_unpack,
						num_vertices = uint_unpack,

						start_index = uint_unpack,
						num_indices = uint_unpack,
					}) 
				end,
			})
		end,
	})
end

read_antmesh("./BH-Scene-campsite-Door.antmesh")