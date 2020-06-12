local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local computil = world:interface "ant.render|entity"
local gizmo_sys = ecs.system "gizmo_system"
local assetmgr  = import_package "ant.asset"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local cylinder_cone_ratio = 8
local cylinder_rawradius = 0.25

local cube
local switch = true
local function onChangeColor(obj)
	if switch then
		obj.material.properties.u_color = world.component "vector" {1, 0, 0, 1}
		switch = false
	else
		obj.material.properties.u_color = world.component "vector" {1, 1, 1, 1}
		switch = true
	end
	
end

function gizmo_sys:init()
	-- local cubeid = world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 		"ant.general|name",
	-- 		"ant.objcontroller|select",
	-- 	},
	-- 	data = {
	-- 		scene_entity = true,
	-- 		can_render = true,
	-- 		can_select = true,
	-- 		transform = world.component "transform" {
	-- 			srt= world.component "srt" {
	-- 				s={100},
	-- 				t={0, 2, 0, 0}
	-- 			}
	-- 		},
	-- 		material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
	-- 		mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
	-- 		name = "test_cube",
	-- 	}
	-- }
	-- cube = world[cubeid]
	-- cube.material.properties.u_color = world.component "vector" {1, 1, 1, 1}

	-- local rooteid = world:create_entity {
	-- 	policy = {
	-- 		"ant.scene|transform_policy",
	-- 		"ant.general|name",
	-- 	},
	-- 	data = {
	-- 		transform = world.component "transform" {
	-- 			srt = world.component "srt" {
	-- 				t = {0, 0, 3, 1}
	-- 			}
	-- 		},
	-- 		name = "mesh_root",
	-- 		scene_entity = true,
	-- 	}
	-- }
	-- -- world:instance("/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab", {import={root=rooteid}})

    -- -- computil.create_plane_entity(
	-- -- 	{t = {0, 0, 0, 1}, s = {50, 1, 50, 0}},
	-- -- 	"/pkg/ant.resources/materials/mesh_shadow.material",
	-- -- 	{0.8, 0.8, 0.8, 1},
	-- -- 	"test shadow plane"
	-- -- )
end

local function create_arrow_widget(axis_root, axis_str)
	--[[
		cylinde & cone
		1. center in (0, 0, 0, 1)
		2. size is 2
		3. pointer to (0, 1, 0)

		we need to:
		1. rotate arrow, make it rotate to (0, 0, 1)
		2. scale cylinder as it match cylinder_cone_ratio
		3. scale cylinder radius
	]]
	local cone_rawlen<const> = 2
	local cone_raw_halflen = cone_rawlen * 0.5
	local cylinder_rawlen = cone_rawlen
	local cylinder_len = cone_rawlen * cylinder_cone_ratio
	local cylinder_halflen = cylinder_len * 0.5
	local cylinder_scaleY = cylinder_len / cylinder_rawlen

	local cylinder_radius = cylinder_rawradius or 0.65

	local cone_raw_centerpos = mc.ZERO_PT
	--local cone_centerpos = math3d.add(math3d.add({0, cylinder_halflen, 0, 1}, cone_raw_centerpos), {0, cone_raw_halflen, 0, 1})
	local cone_centerpos = math3d.add(math3d.add({0, cylinder_len, 0, 1}, cone_raw_centerpos), {0, cone_raw_halflen, 0, 1})
	--local cylinder_bottom_pos = math3d.vector(0, -cylinder_halflen, 0, 1)
	local cylinder_bottom_pos = math3d.vector(0, 0, 0, 1)
	local cone_top_pos = math3d.add(cone_centerpos, {0, cone_raw_halflen, 0, 1})

	--local arrow_center = math3d.mul(0.5, math3d.add(cylinder_bottom_pos, cone_top_pos))
	local arrow_center = math3d.add(cylinder_bottom_pos, cone_top_pos)
	local cylinder_raw_centerpos = mc.ZERO_PT
	local cylinder_offset = math3d.sub(cylinder_raw_centerpos, arrow_center)

	local cone_offset = math3d.sub(cone_centerpos, arrow_center)

	local cylindere_t
	local local_rotator
	if axis_str == "x" then
		local_rotator = math3d.ref(math3d.quaternion{0, 0, math.rad(-90)})
		cylinder_t = math3d.ref(math3d.vector(cylinder_halflen, 0, 0))
	elseif axis_str == "y" then
		local_rotator = math3d.ref(math3d.quaternion{0, 0, 0})
		cylinder_t = math3d.ref(math3d.vector(0, cylinder_halflen, 0))
	elseif axis_str == "z" then
		local_rotator = math3d.ref(math3d.quaternion{math.rad(90), 0, 0})
		cylinder_t = math3d.ref(math3d.vector(0, 0, cylinder_halflen))
	end
	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			can_render = true,
			transform = world.component "transform" {
				srt = world.component "srt" {
					s = math3d.ref(math3d.mul(100, math3d.vector(cylinder_radius, cylinder_scaleY, cylinder_radius))),
					r = local_rotator,
					t = cylinder_t,
				},
			},
			material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder",
		},
		action = {
            mount = axis_root,
		},
		writable = {
			material = true,
		}
	}

	local cylinder = world[cylindereid]
	cylinder.material.properties.u_color = world.component "vector" {1, 0, 0, 1}

	local cone_t
	if axis_str == "x" then
		cone_t = math3d.ref(math3d.add(math3d.vector(cylinder_len, 0, 0), math3d.vector(cone_raw_halflen, 0, 0)))
	elseif axis_str == "y" then
		cone_t = math3d.ref(math3d.add(math3d.vector(0, cylinder_len, 0), math3d.vector(0, cone_raw_halflen, 0)))
	elseif axis_str == "z" then
		cone_t = math3d.ref(math3d.add(math3d.vector(0, 0, cylinder_len), math3d.vector(0, 0, cone_raw_halflen)))
	end
	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			can_render = true,
			transform = world.component "transform" {srt=world.component "srt"{s = {100}, r = local_rotator, t = cone_t}},
			material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone"
		},
		action = {
            mount = axis_root,
		},
		writable = {
			material = true,
		}
	}

	local cone = world[coneeid]
	cone.material = assetmgr.patch(cylinder.material, {properties = {u_color = world.component "vector" {0, 1, 0, 1}}})
end

function gizmo_sys:post_init()
	local dl = world:singleton_entity "directional_light"
	local rotator = math3d.torotation(math3d.inverse(dl.direction))
	--directional_light_arrow_widget({s = {0.02,0.02,0.02,0}, r = rotator, t = dl.position}, 8, 0.45)
	local srt = {s = {0.02,0.02,0.02,0}, r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = world.component "transform" {srt= world.component "srt"(srt)},
			name = "directional light arrow",
		},
	}
	create_arrow_widget(axis_root, "x")
	-- create_arrow_widget(axis_root, "y")
	-- create_arrow_widget(axis_root, "z")
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

function gizmo_sys:data_changed()
	for _, key, press, state in keypress_mb:unpack() do
		if key == "SPACE" and press == 0 then
			world:pub{"record_camera_state"}
			onChangeColor(cube)
		end
	end
	for _,pick_id,pick_ids in pickup_mb:unpack() do
		print("pickup_mb", pick_id, pick_ids)
        local hub = world.args.hub
        local eid = pick_id
        if eid and world[eid] then
            -- if not world[eid].gizmo_object then
            --     hub.publish(WatcherEvent.RTE.SceneEntityPick,{eid})
            --     on_pick_entity(eid)
			-- end
			onChangeColor(world[eid])
        else
            -- hub.publish(WatcherEvent.RTE.SceneEntityPick,{})
            -- on_pick_entity(nil)
        end
    end
end