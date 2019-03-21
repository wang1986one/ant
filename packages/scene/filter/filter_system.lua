local ecs = ...
local world = ecs.world

local render = import_package "ant.render"
local cu = render.components
local ru = render.util

local ms = import_package "ant.math" .stack
local math3d = require "math3d"

local primitive_filter_sys = ecs.system "primitive_filter_system"
primitive_filter_sys.singleton "hierarchy_transform_result"
primitive_filter_sys.singleton "event"

local function update_transform(transform, hierarchy_cache)
	local peid = transform.parent
	local localmat = ms:srtmat(transform)
	if peid then
		local parentresult = hierarchy_cache[peid]
		local parentmat = parentresult.world
		if parentmat then
			local hie_result = parentresult.hierarchy
			local slotname = transform.slotname
			if hie_result and slotname then
				local hiemat = ms:matrix(hie_result[(slotname)])
				localmat = ms(parentmat, hiemat, localmat, "**P")
			else
				localmat = ms(parentmat, localmat, "*P")
			end
		end
	end

	local w = transform.world
	ms(w, localmat, "=")
	return w
end

--luacheck: ignore self
function primitive_filter_sys:update()	
	for _, prim_eid in world:each("primitive_filter") do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		filter._cache_idx = 1
		local viewtag = filter.view_tag
		local filtertag = filter.filter_tag
		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			local vt = ce[viewtag]
			if vt then
				ru.insert_primitive(eid, 
					assert(ce.mesh.assetinfo).handle,
					assert(ce.material.content),
					ce.transform.world,
					filter)
			end
		end	
	end
end

function primitive_filter_sys:post_init()	
	for eid in world:each_new("transform") do
		local e = world[eid]
		e.transform.world = math3d.ref "matrix"

		self.event:new(eid, "transform")
	end
end

function primitive_filter_sys:event_changed()
	local hierarchy_cache = self.hierarchy_transform_result
	for eid, events, init in self.event:each("transform") do
		local e = world[eid]
		local trans = e.transform

		if init then
			assert(not next(events))
			update_transform(e.transform, hierarchy_cache)
		else
			for k, v in pairs(events) do			
				if k == 's' or k == 'r' or k == 't' then
					ms(trans[k], v, "=")
					update_transform(e.transform, hierarchy_cache)
				elseif k == 'parent' then
					trans.parent = v
					update_transform(e.transform, hierarchy_cache)
				elseif k == 'base' then
					ms(trans.base, v, "=")
					update_transform(e.transform, hierarchy_cache)
				end
			end
		end
	end
end

-- all filter system need depend 
local final_filter_sys = ecs.system "final_filter_system"
final_filter_sys.depend "primitive_filter_system"