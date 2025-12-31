-- Copyright (C) 2020 mingxiaoyu <fengying0347@163.com>
-- Licensed to the public under the GNU General Public License v3.
module("luci.controller.cloudflarespeedtest",package.seeall)

function index()

	if not nixio.fs.access('/etc/config/cloudflarespeedtest') then
		return
	end

	local page
	page = entry({"admin", "services", "cloudflarespeedtest"}, firstchild(), _("Cloudflare Speed Test"), 99)
	page.dependent = false
	page.acl_depends = { "luci-app-cloudflarespeedtest" }

	entry({"admin", "services", "cloudflarespeedtest", "general"}, cbi("cloudflarespeedtest/base"), _("Plugin Settings"), 1)
	entry({"admin", "services", "cloudflarespeedtest", "third-party"}, cbi("cloudflarespeedtest/third-party"), _("Third Party Settings"), 2)
	entry({"admin", "services", "cloudflarespeedtest", "logread"}, form("cloudflarespeedtest/logread"), _("Logs"), 3)

	entry({"admin", "services", "cloudflarespeedtest", "status"}, call("act_status")).leaf = true
	entry({"admin", "services", "cloudflarespeedtest", "stop"}, call("act_stop"))
	entry({"admin", "services", "cloudflarespeedtest", "start"}, call("act_start"))
	entry({"admin", "services", "cloudflarespeedtest", "getlog"}, call("get_log"))
	entry({"admin", "services", "cloudflarespeedtest", "gethistory"}, call("get_history"))
end

function act_status()
	local e = {}
	local uci = require "luci.model.uci".cursor()
	local cron = uci:get("cloudflarespeedtest", "global", "enabled") or "0"
	e.running = luci.sys.call("pgrep cdnspeedtest >/dev/null") == 0
	e.cron = cron == "1"
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function act_stop()
	luci.sys.call("pgrep cdnspeedtest | xargs kill -9 >/dev/null 2>&1")
	luci.http.prepare_content("application/json")
	luci.http.write("{}")
end

function act_start()
	act_stop()
	luci.sys.call("/usr/bin/cloudflarespeedtest/cloudflarespeedtest.sh start &")
	luci.http.prepare_content("application/json")
	luci.http.write("{}")
end

function get_log()
	local fs = require "nixio.fs"
	local fpath = "/tmp/cloudflarespeedtest.log"
	local pos = tonumber(luci.http.formvalue("pos")) or 0
	local content = ""
	local newpos = pos

	if fs.access(fpath) then
		local fh = io.open(fpath, "r")
		if fh then
			fh:seek("set", pos)
			local raw = fh:read(1048576) or ""
			newpos = fh:seek()
			fh:close()

			-- apply existing filtering logic on the chunk
			content = raw:gsub("%[[^%]]*%]", "\n")
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ pos = newpos, content = content })
end

function get_history()
	local fs = require "nixio.fs"
	local history = {}
	local base_file = "/usr/share/CloudflareSpeedTest/result.csv"

	-- 解析单个CSV文件的函数
	local function parse_csv_file(filepath)
		local content = fs.readfile(filepath)
		if not content then
			return nil
		end

		local lines = {}
		for line in content:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end

		local best_ip = nil
		local test_time = nil

		-- 查找时间戳（从文件末尾开始查找）
		for i = #lines, 1, -1 do
			local line = lines[i]
			if line:match("^# Speed test time:") then
				test_time = line:match("# Speed test time: (.+)")
				break
			end
		end

		-- 查找最佳IP（第二行，跳过表头）
		for i = 2, #lines do
			local line = lines[i]
			-- 跳过注释行
			if not line:match("^#") and line:match(",") then
				local parts = {}
				for part in line:gmatch("([^,]+)") do
					table.insert(parts, part)
				end

				if #parts >= 7 then
					best_ip = {
						ip = parts[1],
						latency = tonumber(parts[5]) or 0,
						speed = tonumber(parts[6]) or 0,
						region = parts[7]
					}
					break
				end
			end
		end

		if best_ip and test_time then
			return {
				time = test_time,
				ip = best_ip.ip,
				region = best_ip.region,
				latency = math.floor(best_ip.latency * 100) / 100,
				speed = math.floor(best_ip.speed * 100) / 100
			}
		end

		return nil
	end

	-- 解析主文件
	local main_result = parse_csv_file(base_file)
	if main_result then
		table.insert(history, main_result)
	end

	-- 解析历史文件 (.1 到 .9)
	for i = 1, 9 do
		local hist_file = base_file .. "." .. i
		if fs.access(hist_file) then
			local hist_result = parse_csv_file(hist_file)
			if hist_result then
				table.insert(history, hist_result)
			end
		end
	end

	-- 按时间排序（最新的在前）
	table.sort(history, function(a, b)
		return a.time > b.time
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json(history)
end
