-- Deterministic headless workload. Writes results to <world>/bench_result.txt
local out = {}
local function rec(k, v) out[#out+1] = k .. "=" .. tostring(v); core.log("action", "[bench] " .. k .. "=" .. tostring(v)) end
local now = core.get_us_time
local ie = core.request_insecure_environment and core.request_insecure_environment()
local function rss(tag)
	local f = (ie and ie.io or io).open("/proc/self/status", "r")
	if not f then rec("rss_" .. tag .. "_kb", "NA") return end
	local s = f:read("*a"); f:close()
	rec("rss_" .. tag .. "_kb", s:match("VmRSS:%s*(%d+)"))
end

local P1, P2 = vector.new(-256, -64, -256), vector.new(255, 63, 255) -- 32x8x32 = 8192 blocks

local function phase_lua()
	-- get_node/set_node API overhead over loaded area
	local t = now()
	local n = 0
	for x = -64, 63 do for y = -16, 15 do for z = -64, 63 do
		local node = core.get_node(vector.new(x, y, z))
		if node.name ~= "ignore" then n = n + 1 end
	end end end
	rec("get_node_524k_ms", (now() - t) / 1e3)

	-- VoxelManip read-modify-write whole region
	t = now()
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(P1, P2)
	local data = vm:get_data()
	local air = core.get_content_id("air")
	local stone = core.get_content_id("basenodes:stone")
	local cnt = 0
	for i = 1, #data do
		if data[i] == stone then cnt = cnt + 1 end
	end
	for i = 1, #data, 7 do data[i] = air end
	vm:set_data(data)
	vm:write_to_map(true)
	rec("vmanip_rmw_ms", (now() - t) / 1e3)
	rec("stone_count", cnt)
	data = nil; vm = nil
	collectgarbage("collect")

	-- find_nodes_in_area
	t = now()
	local found = core.find_nodes_in_area(vector.new(-128, -32, -128), vector.new(127, 31, 127), {"basenodes:stone", "basenodes:dirt"})
	rec("find_nodes_ms", (now() - t) / 1e3)
	rec("find_nodes_count", #found)
	found = nil
	collectgarbage("collect")

	-- entities
	t = now()
	for i = 1, 2000 do
		core.add_entity(vector.new((i % 50) * 2, 20, math.floor(i / 50) * 2), "benchmod:dummy")
	end
	rec("spawn_2000_ents_ms", (now() - t) / 1e3)
end

local abm_hits, abm_time, abm_last, abm_cstart = 0, 0, 0, 0
core.register_abm({
	label = "benchmod counter",
	nodenames = {"basenodes:dirt_with_grass", "basenodes:stone"},
	neighbors = {"air"},
	interval = 1.0, chance = 1,
	action = function(pos, node)
		-- ABM cycles run back to back; a gap > 20 ms starts a new cycle
		local t = now()
		if t - abm_last > 20000 then
			abm_time = abm_time + (abm_last - abm_cstart)
			abm_cstart = t
		end
		abm_last = t
		abm_hits = abm_hits + 1
	end,
})

local function forceload_area()
	for x = -5, 5 do for y = -2, 2 do for z = -5, 5 do
		core.forceload_block(vector.new(x * 16, y * 16, z * 16), true)
	end end end
end

core.register_entity("benchmod:dummy", {
	initial_properties = {physical = true, collide_with_objects = false, visual = "cube", static_save = false},
	on_step = function(self, dtime) end,
})

local step_t, steps, ent_phase = 0, 0, false
local function run_steps(dtime)
	steps = steps + 1
	if steps >= 200 then
		rec("entity_200_steps_ms", (now() - step_t) / 1e3)
		rec("abm_hits", abm_hits)
		rec("abm_ns_per_hit", string.format("%.1f", (abm_time + abm_last - abm_cstart) * 1000 / abm_hits))
		rec("lua_mem_kb", math.floor(collectgarbage("count")))
		rss("end")
		local f = io.open(core.get_worldpath() .. "/bench_result.txt", "w")
		f:write(table.concat(out, "\n") .. "\n"); f:close()
		core.request_shutdown("bench done", false, 0)
		ent_phase = false
	end
end
core.register_globalstep(function(dtime)
	if ent_phase then run_steps(dtime) end
end)

core.after(0, function()
	local t = now()
	core.emerge_area(P1, P2, function(bp, action, remaining)
		if remaining == 0 then
			rec("emerge_8192_blocks_ms", (now() - t) / 1e3)
			collectgarbage("collect")
			rss("after_emerge")
			core.after(0.1, function()
				phase_lua()
				collectgarbage("collect")
				rss("after_lua")
				forceload_area()
				step_t = now(); steps = 0; ent_phase = true
			end)
		end
	end)
end)
