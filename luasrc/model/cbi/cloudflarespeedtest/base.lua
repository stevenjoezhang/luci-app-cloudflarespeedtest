require("luci.sys")

local uci = luci.model.uci.cursor()

m = Map("cloudflarespeedtest", translate("Cloudflare Speed Test"))
m.description = translate("Schedules and runs CloudflareSpeedTest, automatically selecting and applying the fastest Cloudflare IPs to outbound proxy setups").."<br/>"..translate("<a href=\"https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest\" target=\"_blank\">⭐ Star on GitHub</a>")
m:section(SimpleSection).template = "cloudflarespeedtest/status"

s = m:section(TypedSection, "global")
s.addremove = false
s.anonymous = true

-- [[ 基本设置 ]]--

s:tab("basic", translate("Basic Settings"))

o = s:taboption("basic", Button,"speedtest",translate("Speed test"))
o.inputtitle=translate("Start")
o.template = "cloudflarespeedtest/actions"
o.description = translate("Test the speed of Cloudflare IP and apply the best IP to the system")

o=s:taboption("basic", Flag,"ipv6_enabled",translate("Enable IPv6"))
o.description = translate("Only one protocol can be tested. If IPv6 is enabled, IPv4 will not be tested.")
o.default = 0
o.rmempty=false

o=s:taboption("basic", Value,"speed_limit",translate("Speed threshold (MB/s)"))
o.description =translate("Only IPs with a download speed greater than this threshold will be retained. Please note, do not set this value too high — if no IP meets the requirement, CloudflareSpeedTest may waste excessive time and resources");
o.datatype ="uinteger"
o.rmempty=false

o=s:taboption("basic", Value,"custom_url",translate("Custom URL"))
o.description = translate("<a href=\"https://github.com/XIU2/CloudflareSpeedTest/issues/168\" target=\"_blank\">How to create</a>")
o.rmempty=false
o.default = "https://speed.cloudflare.com/__down?bytes=99000000"
o:value("https://speed.cloudflare.com/__down?bytes=99000000", "speed.cloudflare.com (99M Max)")
o:value("https://download.parallels.com/desktop/v15/15.1.5-47309/ParallelsDesktop-15.1.5-47309.dmg", "Parallels Desktop v15")
o:value("https://download.parallels.com/desktop/v17/17.1.1-51537/ParallelsDesktop-17.1.1-51537.dmg", "Parallels Desktop v17")
o:value("https://w.7rs.net/speedtest/200mb.test", "w.7rs.net (200M)")
o:value("https://t1.geigei.gq", "t1.geigei.gq")
o:value("https://t2.geigei.gq", "t2.geigei.gq")

o = s:taboption("basic", ListValue, "proxy_mode", translate("Proxy mode"))
o.description = translate("Switch to the selected proxy mode during the speed test")
o:value("nil", translate("HOLD"))
o:value("gfw", translate("GFW List"))
o:value("close", translate("CLOSE"))
o.default = "gfw"

-- [[ Cron设置 ]]--

s:tab("cron", translate("Crontab Settings"))

o=s:taboption("cron", Flag,"enabled",translate("Enabled"))
o.description = translate("Enabled scheduled task to test Cloudflare IP")
o.rmempty=false
o.default = 0

o=s:taboption("cron", Flag,"custom_cron_enabled",translate("Enable custom cron"))
o.default = 0
o.rmempty=false

o = s:taboption("cron", Value, "custom_cron", translate("Custom Cron"))
o.description = translate("Example: 0 */3 * * *")
o:depends("custom_cron_enabled", 1)

o = s:taboption("cron", ListValue, "hour", translate("Interval"))
o:depends("custom_cron_enabled", 0)
for _, hour in ipairs({1, 2, 3, 4, 6, 8, 12, 24}) do
    o:value(hour, translatef("Every %d hour(s)", hour))
end
o.default = 24

-- [[ 高级设置 ]]--

s:tab("advanced", translate("Advanced"))

o = s:taboption("advanced", Flag, "advanced", translate("Advanced"))
o.description = translate("Not recommended")
o.default = 0
o.rmempty=false

o = s:taboption("advanced", Value, "threads", translate("Thread Count"))
o.datatype ="uinteger"
o.default = 200
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Value, "tl", translate("Average latency cap"))
o.datatype ="uinteger"
o.default = 200
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Value, "tll", translate("Average latency lower bound"))
o.datatype ="uinteger"
o.default = 40
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Value, "t", translate("Delayed speed measurement time"))
o.datatype ="uinteger"
o.default = 4
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Value, "dt", translate("Download speed test time"))
o.datatype ="uinteger"
o.default = 10
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Value, "dn", translate("Number of download speed tests"))
o.datatype ="uinteger"
o.default = 5
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Flag, "dd", translate("Disable download speed test"))
o.default = 0
o.rmempty=true
o:depends("advanced", 1)

o = s:taboption("advanced", Value, "tp", translate("Port"))
o.rmempty=true
o.default = 443
o.datatype ="port"
o:depends("advanced", 1)

s=m:section(TypedSection, "global")
s.title = translate("Best IP")
s.anonymous=true
local a="/usr/share/CloudflareSpeedTest/result.csv"
tvIPs=s:option(TextValue,"syipstext")
tvIPs.rows=8
tvIPs.readonly="readonly"
tvIPs.wrap="off"

function tvIPs.cfgvalue(e,e)
	sylogtext=""
	if a and nixio.fs.access(a) then
		sylogtext=luci.sys.exec("tail -n 100 %s"%a)
	end
	return sylogtext
end
tvIPs.write=function(e,e,e)
end

s = m:section(SimpleSection)
s.title = translate("History Charts")
s.template = "cloudflarespeedtest/chart"

return m
