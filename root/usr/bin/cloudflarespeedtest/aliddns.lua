local LOG_FILE = "/tmp/cloudflarespeedtest.log"
local ENDPOINT = "https://alidns.aliyuncs.com/"
local UINT32 = 4294967296

local function echolog(message)
	local file = io.open(LOG_FILE, "a")
	if file then
		file:write(os.date("%Y-%m-%d %H:%M:%S"), ": ", message, "\n")
		file:close()
	end
end

local function command_ok(command)
	local a, _, c = os.execute(command .. " >/dev/null 2>&1")
	if a == true then
		return true
	end
	if type(a) == "number" then
		return a == 0
	end
	return c == 0
end

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function read_command(command)
	local pipe = io.popen(command)
	if not pipe then
		return nil
	end
	local output = pipe:read("*a")
	pipe:close()
	return output
end

local function urlencode(value)
	value = tostring(value or "")
	return (value:gsub("([^A-Za-z0-9%._%-%~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function band(a, b)
	local result, bit = 0, 1
	a = a % UINT32
	b = b % UINT32
	while a > 0 or b > 0 do
		local aa = a % 2
		local bb = b % 2
		if aa == 1 and bb == 1 then
			result = result + bit
		end
		a = (a - aa) / 2
		b = (b - bb) / 2
		bit = bit * 2
	end
	return result
end

local function bor2(a, b)
	return (a + b - band(a, b)) % UINT32
end

local function bor(...)
	local result = 0
	for i = 1, select("#", ...) do
		result = bor2(result, select(i, ...))
	end
	return result
end

local function bxor2(a, b)
	local result, bit = 0, 1
	a = a % UINT32
	b = b % UINT32
	while a > 0 or b > 0 do
		local aa = a % 2
		local bb = b % 2
		if aa ~= bb then
			result = result + bit
		end
		a = (a - aa) / 2
		b = (b - bb) / 2
		bit = bit * 2
	end
	return result
end

local function bxor(...)
	local result = 0
	for i = 1, select("#", ...) do
		result = bxor2(result, select(i, ...))
	end
	return result
end

local function bnot(a)
	return (UINT32 - 1 - (a % UINT32)) % UINT32
end

local function rshift(a, bits)
	return math.floor((a % UINT32) / (2 ^ bits))
end

local function lshift(a, bits)
	return ((a % UINT32) * (2 ^ bits)) % UINT32
end

local function rol(a, bits)
	return (lshift(a, bits) + rshift(a, 32 - bits)) % UINT32
end

local function word_to_bytes(word)
	return string.char(
		rshift(word, 24) % 256,
		rshift(word, 16) % 256,
		rshift(word, 8) % 256,
		word % 256
	)
end

local function sha1(message)
	local length = #message
	local bit_length = length * 8
	message = message .. string.char(0x80)
	while (#message % 64) ~= 56 do
		message = message .. string.char(0)
	end
	message = message .. word_to_bytes(0) .. word_to_bytes(bit_length)

	local h0 = 0x67452301
	local h1 = 0xEFCDAB89
	local h2 = 0x98BADCFE
	local h3 = 0x10325476
	local h4 = 0xC3D2E1F0

	for chunk_start = 1, #message, 64 do
		local w = {}
		for i = 0, 15 do
			local pos = chunk_start + i * 4
			local b1, b2, b3, b4 = message:byte(pos, pos + 3)
			w[i] = (((b1 * 256 + b2) * 256 + b3) * 256 + b4) % UINT32
		end
		for i = 16, 79 do
			w[i] = rol(bxor(w[i - 3], w[i - 8], w[i - 14], w[i - 16]), 1)
		end

		local a, b, c, d, e = h0, h1, h2, h3, h4
		for i = 0, 79 do
			local f, k
			if i < 20 then
				f = bor(band(b, c), band(bnot(b), d))
				k = 0x5A827999
			elseif i < 40 then
				f = bxor(b, c, d)
				k = 0x6ED9EBA1
			elseif i < 60 then
				f = bor(band(b, c), band(b, d), band(c, d))
				k = 0x8F1BBCDC
			else
				f = bxor(b, c, d)
				k = 0xCA62C1D6
			end
			local temp = (rol(a, 5) + f + e + k + w[i]) % UINT32
			e = d
			d = c
			c = rol(b, 30)
			b = a
			a = temp
		end

		h0 = (h0 + a) % UINT32
		h1 = (h1 + b) % UINT32
		h2 = (h2 + c) % UINT32
		h3 = (h3 + d) % UINT32
		h4 = (h4 + e) % UINT32
	end

	return word_to_bytes(h0) .. word_to_bytes(h1) .. word_to_bytes(h2) .. word_to_bytes(h3) .. word_to_bytes(h4)
end

local function hmac_sha1(key, message)
	if #key > 64 then
		key = sha1(key)
	end
	key = key .. string.rep(string.char(0), 64 - #key)

	local ipad = {}
	local opad = {}
	for i = 1, 64 do
		local byte = key:byte(i)
		ipad[i] = string.char(bxor(byte, 0x36))
		opad[i] = string.char(bxor(byte, 0x5c))
	end

	return sha1(table.concat(opad) .. sha1(table.concat(ipad) .. message))
end

local function base64_encode(data)
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local result = {}

	for i = 1, #data, 3 do
		local b1 = data:byte(i) or 0
		local b2 = data:byte(i + 1) or 0
		local b3 = data:byte(i + 2) or 0
		local n = b1 * 65536 + b2 * 256 + b3
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		result[#result + 1] = alphabet:sub(c1 + 1, c1 + 1)
		result[#result + 1] = alphabet:sub(c2 + 1, c2 + 1)
		result[#result + 1] = (i + 1 <= #data) and alphabet:sub(c3 + 1, c3 + 1) or "="
		result[#result + 1] = (i + 2 <= #data) and alphabet:sub(c4 + 1, c4 + 1) or "="
	end

	return table.concat(result)
end

local function make_nonce()
	local file = io.open("/proc/sys/kernel/random/uuid", "r")
	if file then
		local nonce = file:read("*l")
		file:close()
		if nonce and nonce ~= "" then
			return nonce
		end
	end

	file = io.open("/dev/urandom", "rb")
	if file then
		local bytes = file:read(16)
		file:close()
		if bytes and #bytes > 0 then
			return (bytes:gsub(".", function(char)
				return string.format("%02x", string.byte(char))
			end))
		end
	end

	math.randomseed(os.time())
	return tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

local function add_param(params, key, value)
	if value ~= nil and tostring(value) ~= "" then
		params[#params + 1] = { key = key, value = tostring(value) }
	end
end

local function canonicalize(params)
	local encoded = {}
	for i = 1, #params do
		encoded[#encoded + 1] = urlencode(params[i].key) .. "=" .. urlencode(params[i].value)
	end
	table.sort(encoded)
	return table.concat(encoded, "&")
end

local function alidns_request(ak_id, ak_secret, action, extra_params)
	local params = {}
	add_param(params, "AccessKeyId", ak_id)
	add_param(params, "Action", action)
	add_param(params, "Format", "json")
	add_param(params, "SignatureMethod", "HMAC-SHA1")
	add_param(params, "SignatureNonce", make_nonce())
	add_param(params, "SignatureVersion", "1.0")
	add_param(params, "Timestamp", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	add_param(params, "Version", "2015-01-09")

	for i = 1, #extra_params do
		add_param(params, extra_params[i].key, extra_params[i].value)
	end

	local canonical = canonicalize(params)
	local string_to_sign = "GET&%2F&" .. urlencode(canonical)
	local signature = base64_encode(hmac_sha1(ak_secret .. "&", string_to_sign))
	local url = ENDPOINT .. "?" .. canonical .. "&Signature=" .. urlencode(signature)

	return read_command("curl -sSL --connect-timeout 5 " .. shell_quote(url) .. " 2>&1") or ""
end

local function json_string(response, key)
	local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
	return response:match(pattern)
end

local function record_ids(response)
	local ids = {}
	for id in response:gmatch('"RecordId"%s*:%s*"([^"]*)"') do
		ids[#ids + 1] = id
	end
	table.sort(ids, function(a, b)
		return a > b
	end)
	return ids
end

local function log_response_error(action, response)
	local code = json_string(response, "Code")
	local message = json_string(response, "Message")
	if code or message then
		echolog(action .. " failed: " .. (code or "unknown") .. " " .. (message or ""))
	elseif response == "" then
		echolog(action .. " failed: empty response")
	else
		echolog(action .. " failed: " .. response)
	end
end

local function has_error(response)
	return response:match('"Code"%s*:') ~= nil
end

local function main(argv)
	if #argv < 7 then
		echolog("# ERROR, Missing arguments")
		return 1
	end

	if not command_ok("curl --version") then
		echolog("# ERROR, curl command not found")
		return 1
	end

	local ak_id = argv[1]
	local ak_secret = argv[2]
	local main_domain = argv[3]
	local sub_domain = argv[4]
	local line = argv[5]
	local is_ipv6 = argv[6]
	local record_type = (is_ipv6 == "1") and "AAAA" or "A"
	local full_domain = (sub_domain == "@") and main_domain or (sub_domain .. "." .. main_domain)

	local query_response = alidns_request(ak_id, ak_secret, "DescribeSubDomainRecords", {
		{ key = "DomainName", value = main_domain },
		{ key = "Line", value = line },
		{ key = "SubDomain", value = full_domain },
		{ key = "Type", value = record_type },
	})

	if has_error(query_response) then
		log_response_error("QUERY record " .. record_type .. " " .. full_domain, query_response)
		return 1
	end

	local ids = record_ids(query_response)
	local failed = false
	local ip_count = 0

	for i = 7, #argv do
		local ip = argv[i]
		if ip and ip ~= "" then
			ip_count = ip_count + 1
			local record_id = ids[ip_count]
			if record_id then
				local response = alidns_request(ak_id, ak_secret, "UpdateDomainRecord", {
					{ key = "Line", value = line },
					{ key = "RR", value = sub_domain },
					{ key = "RecordId", value = record_id },
					{ key = "Type", value = record_type },
					{ key = "Value", value = ip },
				})
				if has_error(response) then
					log_response_error("UPDATE record " .. record_id .. " " .. record_type .. " " .. ip, response)
					failed = true
				else
					echolog("UPDATE record " .. record_id .. " " .. record_type .. " " .. ip)
				end
			else
				local response = alidns_request(ak_id, ak_secret, "AddDomainRecord", {
					{ key = "DomainName", value = main_domain },
					{ key = "Line", value = line },
					{ key = "RR", value = sub_domain },
					{ key = "Type", value = record_type },
					{ key = "Value", value = ip },
				})
				local new_record_id = record_ids(response)[1]
				if new_record_id then
					echolog("ADD record " .. new_record_id .. " " .. record_type .. " " .. ip)
				else
					log_response_error("ADD record " .. record_type .. " " .. ip, response)
					failed = true
				end
			end
		end
	end

	if ip_count == 0 then
		echolog("# ERROR, No IP provided")
		return 1
	end

	return failed and 1 or 0
end

os.exit(main(arg))
