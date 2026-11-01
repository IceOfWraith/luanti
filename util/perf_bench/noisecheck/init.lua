-- Hash perlin noise maps for many parameter sets; output is compared across builds
local lines = {}
local function hashmap(t)
	local parts = {}
	for i = 1, #t do parts[i] = string.format("%.9g", t[i]) end
	return core.sha1(table.concat(parts, ","))
end
core.after(0, function()
local n = 0
for _, flags in ipairs({"defaults", "eased", "noeased", "absvalue", "eased,absvalue"}) do
	for _, spread in ipairs({{x=250,y=250,z=250}, {x=33.3,y=17,z=91}, {x=1000,y=300,z=1000}, {x=5,y=5,z=5}}) do
		for _, oct in ipairs({1, 3, 5}) do
			if math.min(spread.x, spread.y, spread.z) >= 2 ^ (oct - 1) then
			for _, size in ipairs({{x=80,y=80,z=80}, {x=17,y=33,z=5}, {x=1,y=40,z=3}}) do
				for _, pos in ipairs({{x=0,y=0,z=0}, {x=-1234.5,y=77.25,z=31000}, {x=-31000,y=-31000,z=-31000}}) do
					local np = {offset = 0.1, scale = 2, spread = spread, seed = 4321 + n, octaves = oct,
						persistence = 0.6, lacunarity = 2.0, flags = flags}
					local pm = core.get_perlin_map(np, size)
					local h3 = hashmap(pm:get_3d_map_flat(pos))
					local pm2 = core.get_perlin_map(np, {x=size.x, y=size.y, z=1})
					local h2 = hashmap(pm2:get_2d_map_flat({x=pos.x, y=pos.z}))
					n = n + 1
					lines[#lines+1] = n .. " " .. h3 .. " " .. h2
				end
			end
			end
		end
	end
end
-- timing: mapgen-sized 3D/2D maps, eased and not
local function bench(flags, is3d)
	local np = {offset = 0, scale = 1, spread = {x=384,y=192,z=384}, seed = 5, octaves = 5, persistence = 0.63, lacunarity = 2.0, flags = flags}
	local pm = core.get_perlin_map(np, is3d and {x=80,y=80,z=80} or {x=80,y=80,z=1})
	local buf = {}
	local t = core.get_us_time()
	for i = 1, (is3d and 60 or 3000) do
		if is3d then pm:get_3d_map_flat({x=i*80, y=0, z=0}, buf) else pm:get_2d_map_flat({x=i*80, y=0}, buf) end
	end
	return (core.get_us_time() - t) / 1e3
end
local tf = io.open(core.get_worldpath() .. "/noise_times.txt", "w")
for _, fl in ipairs({"noeased", "eased"}) do
	tf:write(("noise3d_%s_ms=%.1f\n"):format(fl, bench(fl, true)))
	tf:write(("noise2d_%s_ms=%.1f\n"):format(fl, bench(fl, false)))
end
tf:close()
local f = io.open(core.get_worldpath() .. "/noise_hashes.txt", "w")
f:write(table.concat(lines, "\n") .. "\n"); f:close()
core.request_shutdown("noisecheck done", false, 0)
end)
