'use strict';

const fs = require('fs');

const LOG_FILE = '/tmp/cloudflarespeedtest.log';
const ENDPOINT = 'https://alidns.aliyuncs.com/';

function command_output(cmd) {
	let pipe = fs.popen(cmd, 'r');
	let out = '';

	if (pipe) {
		out = pipe.read('all') || '';
		pipe.close();
	}

	return out;
}

function shquote(value) {
	return "'" + replace('' + value, "'", "'\\''") + "'";
}

function now_local() {
	return trim(command_output('date "+%Y-%m-%d %H:%M:%S"'));
}

function now_utc() {
	return trim(command_output('date -u "+%Y-%m-%dT%H:%M:%SZ"'));
}

function echolog(message) {
	let fd = fs.open(LOG_FILE, 'a');

	if (fd) {
		fd.write(now_local() + ': ' + message + '\n');
		fd.close();
	}
}

function urlencode(value) {
	value = '' + (value ?? '');

	return replace(value, /([^A-Za-z0-9._~-])/g, (m, c) => sprintf('%%%02X', ord(c)));
}

function u32(value) {
	return value & 0xffffffff;
}

function rol(value, bits) {
	return u32((value << bits) | (value >> (32 - bits)));
}

function word_to_bytes(word) {
	return chr((word >> 24) & 255) +
		chr((word >> 16) & 255) +
		chr((word >> 8) & 255) +
		chr(word & 255);
}

function sha1(message) {
	let bit_length = length(message) * 8;

	message += chr(0x80);
	while ((length(message) % 64) != 56)
		message += chr(0);

	message += word_to_bytes(0) + word_to_bytes(bit_length);

	let h0 = 0x67452301;
	let h1 = 0xefcdab89;
	let h2 = 0x98badcfe;
	let h3 = 0x10325476;
	let h4 = 0xc3d2e1f0;

	for (let chunk = 0; chunk < length(message); chunk += 64) {
		let w = [];

		for (let i = 0; i < 16; i++) {
			let pos = chunk + i * 4;
			w[i] = u32((ord(substr(message, pos, 1)) << 24) |
				(ord(substr(message, pos + 1, 1)) << 16) |
				(ord(substr(message, pos + 2, 1)) << 8) |
				ord(substr(message, pos + 3, 1)));
		}

		for (let i = 16; i < 80; i++)
			w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);

		let a = h0;
		let b = h1;
		let c = h2;
		let d = h3;
		let e = h4;

		for (let i = 0; i < 80; i++) {
			let f, k;

			if (i < 20) {
				f = (b & c) | ((~b) & d);
				k = 0x5a827999;
			}
			else if (i < 40) {
				f = b ^ c ^ d;
				k = 0x6ed9eba1;
			}
			else if (i < 60) {
				f = (b & c) | (b & d) | (c & d);
				k = 0x8f1bbcdc;
			}
			else {
				f = b ^ c ^ d;
				k = 0xca62c1d6;
			}

			let temp = u32(rol(a, 5) + f + e + k + w[i]);
			e = d;
			d = c;
			c = rol(b, 30);
			b = a;
			a = temp;
		}

		h0 = u32(h0 + a);
		h1 = u32(h1 + b);
		h2 = u32(h2 + c);
		h3 = u32(h3 + d);
		h4 = u32(h4 + e);
	}

	return word_to_bytes(h0) + word_to_bytes(h1) + word_to_bytes(h2) + word_to_bytes(h3) + word_to_bytes(h4);
}

function hmac_sha1(key, message) {
	if (length(key) > 64)
		key = sha1(key);

	while (length(key) < 64)
		key += chr(0);

	let ipad = [];
	let opad = [];

	for (let i = 0; i < 64; i++) {
		let byte = ord(substr(key, i, 1));
		push(ipad, chr(byte ^ 0x36));
		push(opad, chr(byte ^ 0x5c));
	}

	return sha1(join('', opad) + sha1(join('', ipad) + message));
}

function bytes_to_hex(data) {
	let out = [];

	for (let i = 0; i < length(data); i++)
		push(out, sprintf('%02x', ord(substr(data, i, 1))));

	return join('', out);
}

function make_nonce() {
	let nonce = trim(fs.readfile('/proc/sys/kernel/random/uuid') || '');

	if (nonce != '')
		return nonce;

	let random = command_output('dd if=/dev/urandom bs=16 count=1 2>/dev/null');

	if (length(random) >= 16)
		return bytes_to_hex(substr(random, 0, 16));

	return '' + time();
}

function add_param(params, key, value) {
	if (value != null && ('' + value) != '')
		push(params, { key: key, value: '' + value });
}

function canonicalize(params) {
	let encoded = [];

	for (let p in params)
		push(encoded, urlencode(p.key) + '=' + urlencode(p.value));

	sort(encoded);
	return join('&', encoded);
}

function alidns_request(ak_id, ak_secret, action, extra_params) {
	let params = [];

	add_param(params, 'AccessKeyId', ak_id);
	add_param(params, 'Action', action);
	add_param(params, 'Format', 'json');
	add_param(params, 'SignatureMethod', 'HMAC-SHA1');
	add_param(params, 'SignatureNonce', make_nonce());
	add_param(params, 'SignatureVersion', '1.0');
	add_param(params, 'Timestamp', now_utc());
	add_param(params, 'Version', '2015-01-09');

	for (let p in extra_params)
		add_param(params, p.key, p.value);

	let canonical = canonicalize(params);
	let string_to_sign = 'GET&%2F&' + urlencode(canonical);
	let signature = b64enc(hmac_sha1(ak_secret + '&', string_to_sign));
	let url = ENDPOINT + '?' + canonical + '&Signature=' + urlencode(signature);
	let response = command_output('curl -sSL --connect-timeout 5 ' + shquote(url) + ' 2>&1');

	try {
		return {
			raw: response,
			body: json(response)
		};
	}
	catch (e) {
		return {
			raw: response,
			body: null
		};
	}
}

function record_ids(body) {
	let records = body?.DomainRecords?.Record || [];
	let ids = [];

	if (body?.RecordId)
		push(ids, '' + body.RecordId);

	if (type(records) == 'object')
		records = [ records ];

	for (let record in records)
		if (record.RecordId)
			push(ids, '' + record.RecordId);

	sort(ids, (a, b) => a > b ? -1 : (a < b ? 1 : 0));
	return ids;
}

function log_response_error(action, result) {
	let body = result.body;

	if (body && (body.Code || body.Message))
		echolog(action + ' failed: ' + (body.Code || 'unknown') + ' ' + (body.Message || ''));
	else if (!result.raw)
		echolog(action + ' failed: empty response');
	else
		echolog(action + ' failed: ' + result.raw);
}

function has_error(result) {
	return result.body && result.body.Code;
}

function main(argv) {
	if (length(argv) < 7) {
		echolog('# ERROR, Missing arguments');
		return 1;
	}

	if (system('command -v curl >/dev/null 2>&1') != 0) {
		echolog('# ERROR, curl command not found');
		return 1;
	}

	let ak_id = argv[0];
	let ak_secret = argv[1];
	let main_domain = argv[2];
	let sub_domain = argv[3];
	let line = argv[4];
	let is_ipv6 = argv[5];
	let record_type = (is_ipv6 == '1') ? 'AAAA' : 'A';
	let full_domain = (sub_domain == '@') ? main_domain : sub_domain + '.' + main_domain;

	let query = alidns_request(ak_id, ak_secret, 'DescribeSubDomainRecords', [
		{ key: 'DomainName', value: main_domain },
		{ key: 'Line', value: line },
		{ key: 'SubDomain', value: full_domain },
		{ key: 'Type', value: record_type }
	]);

	if (has_error(query)) {
		log_response_error('QUERY record ' + record_type + ' ' + full_domain, query);
		return 1;
	}

	let ids = record_ids(query.body);
	let failed = false;
	let ip_count = 0;

	for (let i = 6; i < length(argv); i++) {
		let ip = argv[i];

		if (!ip)
			continue;

		let record_id = ids[ip_count++];

		if (record_id) {
			let result = alidns_request(ak_id, ak_secret, 'UpdateDomainRecord', [
				{ key: 'Line', value: line },
				{ key: 'RR', value: sub_domain },
				{ key: 'RecordId', value: record_id },
				{ key: 'Type', value: record_type },
				{ key: 'Value', value: ip }
			]);

			if (has_error(result)) {
				log_response_error('UPDATE record ' + record_id + ' ' + record_type + ' ' + ip, result);
				failed = true;
			}
			else {
				echolog('UPDATE record ' + record_id + ' ' + record_type + ' ' + ip);
			}
		}
		else {
			let result = alidns_request(ak_id, ak_secret, 'AddDomainRecord', [
				{ key: 'DomainName', value: main_domain },
				{ key: 'Line', value: line },
				{ key: 'RR', value: sub_domain },
				{ key: 'Type', value: record_type },
				{ key: 'Value', value: ip }
			]);
			let new_id = result.body ? record_ids(result.body)[0] : null;

			if (new_id) {
				echolog('ADD record ' + new_id + ' ' + record_type + ' ' + ip);
			}
			else {
				log_response_error('ADD record ' + record_type + ' ' + ip, result);
				failed = true;
			}
		}
	}

	if (ip_count == 0) {
		echolog('# ERROR, No IP provided');
		return 1;
	}

	return failed ? 1 : 0;
}

exit(main(ARGV));
