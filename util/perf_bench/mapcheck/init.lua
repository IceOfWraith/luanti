-- Emerge a fixed area, then hash node content, param2 and light; written to <world>/map_hash.txt
local P1, P2 = vector.new(-160, -80, -160), vector.new(159, 79, 159)
core.after(0, function()
	local t = core.get_us_time()
	core.emerge_area(P1, P2, function(bp, action, remaining)
		if remaining > 0 then return end
		local gen_ms = (core.get_us_time() - t) / 1e3
		local vm = core.get_voxel_manip()
		vm:read_from_map(P1, P2)
		local data, light, p2 = vm:get_data(), vm:get_light_data(), vm:get_param2_data()
		local tobit = bit.tobit
		local h1, h2, h3 = 0, 0, 0
		for i = 1, #data do
			h1 = tobit(h1 * 31 + data[i])
			h2 = tobit(h2 * 31 + light[i])
			h3 = tobit(h3 * 31 + p2[i])
		end
		local f = io.open(core.get_worldpath() .. "/map_hash.txt", "w")
		f:write(("content=%d light=%d param2=%d nodes=%d gen_ms=%.0f\n"):format(h1, h2, h3, #data, gen_ms)); f:close()
		core.request_shutdown("mapcheck done", false, 0)
	end)
end)
