require("luci.sys")

local uci = luci.model.uci.cursor()

m = Map('cloudflarespeedtest', translate("Third Party Application Settings"))

s = m:section(TypedSection, "servers")
s.addremove = false
s.anonymous = true

-- [[ 第三方应用设置 ]]--

if nixio.fs.access("/etc/config/shadowsocksr") then
	s:tab("ssr", translate("ShadowSocksR Plus+"))

	o=s:taboption("ssr", Flag, "ssr_enabled",translate("ShadowSocksR Plus+ Enabled"))
	o.rmempty=true

	local ssr_server_table = {}
	uci:foreach("shadowsocksr", "servers", function(s)
		if s.alias then
			ssr_server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.v2ray_protocol or s.type), s.alias}
		elseif s.server and s.server_port then
			ssr_server_table[s[".name"]] = "[%s]:%s:%s" % {string.upper(s.v2ray_protocol or s.type), s.server, s.server_port}
		end
	end)

	local ssr_key_table = {}
	for key, _ in pairs(ssr_server_table) do
		table.insert(ssr_key_table, key)
	end

	table.sort(ssr_key_table)

	o = s:taboption("ssr", DynamicList, "ssr_services",
			translate("ShadowSocksR Servers"),
			translate("Please select a service"))

	for _, key in pairs(ssr_key_table) do
		o:value(key, ssr_server_table[key])
	end
	o:depends("ssr_enabled", 1)
	o.forcewrite = true

end


if nixio.fs.access("/etc/config/passwall") then
	s:tab("passwalltab", translate("passwall"))

	o=s:taboption("passwalltab", Flag, "passwall_enabled",translate("Passwall Enabled"))
	o.rmempty=true

	local passwall_server_table = {}
	uci:foreach("passwall", "nodes", function(s)
		if s.remarks then
			passwall_server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.protocol or s.type), s.remarks}
		end
	end)

	local passwall_key_table = {}
	for key, _ in pairs(passwall_server_table) do
		table.insert(passwall_key_table, key)
	end

	table.sort(passwall_key_table)

	o = s:taboption("passwalltab", DynamicList, "passwall_services",
			translate("Passwall Servers"),
			translate("Please select a service"))

	for _, key in pairs(passwall_key_table) do
		o:value(key, passwall_server_table[key])
	end
	o:depends("passwall_enabled", 1)
	o.forcewrite = true

end

if nixio.fs.access("/etc/config/passwall2") then
	s:tab("passwall2tab", translate("passwall2"))

	o=s:taboption("passwall2tab", Flag, "passwall2_enabled",translate("PassWall2 Enabled"))
	o.rmempty=true

	local passwall2_server_table = {}
	uci:foreach("passwall2", "nodes", function(s)
		if s.remarks then
			passwall2_server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.protocol or s.type), s.remarks}
		end
	end)

	local passwall2_key_table = {}
	for key, _ in pairs(passwall2_server_table) do
		table.insert(passwall2_key_table, key)
	end

	table.sort(passwall2_key_table)

	o = s:taboption("passwall2tab", DynamicList, "passwall2_services",
			translate("Passwall2 Servers"),
			translate("Please select a service"))

	for _, key in pairs(passwall2_key_table) do
		o:value(key, passwall2_server_table[key])
	end
	o:depends("passwall2_enabled", 1)
	o.forcewrite = true

end

if nixio.fs.access("/etc/config/bypass") then
	s:tab("bypasstab", translate("Bypass"))

	o=s:taboption("bypasstab", Flag, "bypass_enabled",translate("Bypass Enabled"))
	o.rmempty=true

	local bypass_server_table = {}
	uci:foreach("bypass", "servers", function(s)
		if s.alias then
			bypass_server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.protocol or s.type), s.alias}
		elseif s.server and s.server_port then
			bypass_server_table[s[".name"]] = "[%s]:%s:%s" % {string.upper(s.protocol or s.type), s.server, s.server_port}
		end
	end)

	local bypass_key_table = {}
	for key, _ in pairs(bypass_server_table) do
		table.insert(bypass_key_table, key)
	end

	table.sort(bypass_key_table)

	o = s:taboption("bypasstab", DynamicList, "bypass_services",
			translate("Bypass Servers"),
			translate("Please select a service"))

	for _, key in pairs(bypass_key_table) do
		o:value(key, bypass_server_table[key])
	end
	o:depends("bypass_enabled", 1)
	o.forcewrite = true

end

if nixio.fs.access("/etc/config/vssr") then
	s:tab("vssrtab", translate("Vssr"))

	o=s:taboption("vssrtab", Flag, "vssr_enabled",translate("Vssr Enabled"))
	o.rmempty=true

	local vssr_server_table = {}
	uci:foreach("vssr", "servers", function(s)
		if s.alias then
			vssr_server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.protocol or s.type), s.alias}
		elseif s.server and s.server_port then
			vssr_server_table[s[".name"]] = "[%s]:%s:%s" % {string.upper(s.protocol or s.type), s.server, s.server_port}
		end
	end)

	local vssr_key_table = {}
	for key, _ in pairs(vssr_server_table) do
		table.insert(vssr_key_table, key)
	end

	table.sort(vssr_key_table)

	o = s:taboption("vssrtab", DynamicList, "vssr_services",
			translate("Vssr Servers"),
			translate("Please select a service"))

	for _, key in pairs(vssr_key_table) do
		o:value(key, vssr_server_table[key])
	end
	o:depends("vssr_enabled", 1)
	o.forcewrite = true

end

s:tab("dnshost", translate("HOST"))
o=s:taboption("dnshost", Flag, "HOST_enabled",translate("HOST Enabled"))
o=s:taboption("dnshost", Value,"host_domain",translate("Domain"))
o.rmempty=true
o:depends("HOST_enabled", 1)

s:tab("dnstab", translate("DNS"))

o=s:taboption("dnstab", Flag, "DNS_enabled",translate("DNS Enabled"))

o=s:taboption("dnstab", ListValue, "DNS_type", translate("DNS Type"))
o:value("aliyun", translate("Alibaba Cloud DNS"))
o:depends("DNS_enabled", 1)

o=s:taboption("dnstab", Value,"app_key",translate("Access Key ID"))
o.rmempty=true
o:depends("DNS_enabled", 1)
o=s:taboption("dnstab", Value,"app_secret",translate("Access Key Secret"))
o.rmempty=true
o:depends("DNS_enabled", 1)

o=s:taboption("dnstab", Value,"main_domain",translate("Main Domain"),translate("For example: test.github.com -> github.com"))
o.rmempty=true
o:depends("DNS_enabled", 1)
o=s:taboption("dnstab", DynamicList,"sub_domain",translate("Sub Domain"),translate("For example: test.github.com -> test"))
o.rmempty=true
o:depends("DNS_enabled", 1)

o=s:taboption("dnstab", ListValue, "line", translate("Lines"))
o:value("default", translate("default"))
o:value("telecom", translate("telecom"))
o:value("unicom", translate("unicom"))
o:value("mobile", translate("mobile"))
o:depends("DNS_enabled", 1)
o.default ="telecom"

s:tab("mosdns", translate("MosDNS"))
o=s:taboption("mosdns", Flag, "MosDNS_enabled",translate("MosDNS Enabled"))
o=s:taboption("mosdns", Value, "MosDNS_ip_count",translate("MosDNS IP Count"))
o.datatype ="uinteger"
o.default = 1
o:depends("MosDNS_enabled", 1)
o=s:taboption("mosdns", Flag, "openclash_restart",translate("OpenClash Restart"))
o:depends("MosDNS_enabled", 1)

return m
