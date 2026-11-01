-- Emerge a large, mostly-air area (65536 blocks) and report RSS
local ie = core.request_insecure_environment()
local function rss()
	local f = ie.io.open("/proc/self/status", "r"); local s = f:read("*a"); f:close()
	return tonumber(s:match("VmRSS:%s*(%d+)"))
end
core.after(0, function()
	local r0 = rss()
	core.emerge_area(vector.new(-512, 240, -512), vector.new(511, 495, 511), function(_, _, rem)
		if rem > 0 then return end
		core.after(1, function()
			collectgarbage("collect")
			local ffi = ie.require("ffi")
			pcall(ffi.cdef, [[
				struct lx_mallinfo2 { size_t arena, ordblks, smblks, hblks, hblkhd, usmblks, fsmblks, uordblks, fordblks, keepcost; };
				struct lx_mallinfo2 mallinfo2(void);
				int malloc_trim(size_t pad);
			]])
			local r1 = rss()
			local nblocks, nair = 0, 0
			for bx = -40, 39 do for by = 5, 40 do for bz = -40, 39 do
				if core.compare_block_status(vector.new(bx * 16, by * 16, bz * 16), "loaded") then
					nblocks = nblocks + 1
				end
			end end end
			local mi = ffi.C.mallinfo2()
			local inuse = tonumber(mi.uordblks + mi.hblkhd) / 1024
			local free = tonumber(mi.fordblks) / 1024
			ffi.C.malloc_trim(0)
			local f = io.open(core.get_worldpath() .. "/mem.txt", "w")
			f:write(("rss_start_kb=%d\trss_air_kb=%d\theap_inuse_kb=%d\theap_free_kb=%d\trss_after_trim_kb=%d\tblocks=%d\n"):format(r0, r1, inuse, free, rss(), nblocks)); f:close()
			core.request_shutdown("", false, 0)
		end)
	end)
end)
