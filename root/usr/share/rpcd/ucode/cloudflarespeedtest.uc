'use strict';

const fs = require('fs');
const uci = require('uci');

const LOG_FILE = '/tmp/cloudflarespeedtest.log';
const RESULT_FILE = '/tmp/CloudflareSpeedTest/result.csv';
const RUN_SCRIPT = '/usr/bin/cloudflarespeedtest/cloudflarespeedtest.sh';

function command(cmd) {
	let rc = system(cmd);

	return {
		code: rc
	};
}

function command_output(cmd) {
	let pipe = fs.popen(cmd, 'r');
	let out = '';
	let rc = -1;

	if (pipe) {
		out = pipe.read('all') || '';
		rc = pipe.close();
	}

	return {
		code: rc,
		stdout: out
	};
}

function shquote(value) {
	return "'" + replace("" + value, "'", "'\\''") + "'";
}

function read_file(path) {
	if (!fs.access(path, 'f'))
		return '';

	let fd = fs.open(path, 'r');
	let data = '';

	if (fd) {
		data = fd.read('all') || '';
		fd.close();
	}

	return data;
}

function read_lines(path) {
	let content = read_file(path);

	if (content == '')
		return [];

	return split(replace(content, /\r/g, ''), '\n');
}

function file_size(path) {
	let res = command_output('wc -c < ' + shquote(path) + ' 2>/dev/null');
	let size = int(trim(res.stdout || '') || 0);

	return size > 0 ? size : 0;
}

function read_file_chunk(path, pos) {
	if (!fs.access(path, 'f'))
		return { pos: 0, content: '' };

	let size = file_size(path);
	pos = int(pos || 0);

	if (pos < 0 || pos > size)
		pos = 0;

	let pipe = fs.popen('dd if=' + shquote(path) + ' bs=1 skip=' + pos + ' count=1048576 2>/dev/null', 'r');
	let content = '';

	if (pipe) {
		content = pipe.read('all') || '';
		pipe.close();
	}

	return {
		pos: pos + length(content),
		content: content
	};
}

function status() {
	let cur = uci.cursor();
	let enabled = '0';

	try {
		cur.load('cloudflarespeedtest');
		enabled = cur.get('cloudflarespeedtest', 'global', 'enabled') || '0';
	}
	catch (e) {}

	return {
		running: command('pgrep cdnspeedtest >/dev/null 2>&1').code == 0,
		cron: enabled == '1'
	};
}

function start() {
	command('pgrep cdnspeedtest | xargs kill -9 >/dev/null 2>&1');
	command(shquote(RUN_SCRIPT) + ' start >/dev/null 2>&1 &');

	return {};
}

function stop() {
	command('pgrep cdnspeedtest | xargs kill -9 >/dev/null 2>&1');

	return {};
}

function get_log(req) {
	let chunk = read_file_chunk(LOG_FILE, req.args.pos);

	return {
		pos: chunk.pos,
		content: replace(chunk.content, /\[[^\]]*\]/g, '\n')
	};
}

function parse_csv_file(path) {
	let lines = read_lines(path);

	if (!length(lines))
		return null;

	let test_time = null;
	let best_ip = null;

	for (let i = length(lines) - 1; i >= 0; i--) {
		let m = match(trim(lines[i]), /^# Speed test time: (.+)$/);

		if (m) {
			test_time = m[1];
			break;
		}
	}

	for (let i = 1; i < length(lines); i++) {
		let line = trim(lines[i]);

		if (line == '' || substr(line, 0, 1) == '#')
			continue;

		let parts = split(line, ',');

		if (length(parts) >= 7) {
			best_ip = {
				ip: parts[0],
				latency: +parts[4] || 0,
				speed: +parts[5] || 0,
				region: parts[6]
			};
			break;
		}
	}

	if (!best_ip || !test_time)
		return null;

	return {
		time: test_time,
		ip: best_ip.ip,
		region: best_ip.region,
		latency: best_ip.latency,
		speed: best_ip.speed
	};
}

function get_history() {
	let history = [];
	let item = parse_csv_file(RESULT_FILE);

	if (item)
		push(history, item);

	for (let i = 1; i <= 9; i++) {
		item = parse_csv_file(RESULT_FILE + '.' + i);

		if (item)
			push(history, item);
	}

	sort(history, (a, b) => b.time > a.time ? 1 : (b.time < a.time ? -1 : 0));

	return {
		history: history
	};
}

function get_best_result() {
	let lines = read_lines(RESULT_FILE);
	let start = length(lines) > 100 ? length(lines) - 100 : 0;
	let out = [];

	for (let i = start; i < length(lines); i++)
		if (lines[i] != null)
			push(out, lines[i]);

	return {
		content: join('\n', out)
	};
}

function add_node(nodes, name, label) {
	if (name)
		push(nodes, { value: name, label: label || name });
}

function load_config(cur, name) {
	if (!fs.access('/etc/config/' + name, 'f'))
		return false;

	try {
		cur.load(name);
		return true;
	}
	catch (e) {
		return false;
	}
}

function sorted_nodes(nodes) {
	sort(nodes, (a, b) => a.value > b.value ? 1 : (a.value < b.value ? -1 : 0));
	return nodes;
}

function list_nodes() {
	let cur = uci.cursor();
	let result = {};
	let nodes;

	nodes = [];
	if (load_config(cur, 'shadowsocksr')) {
		cur.foreach('shadowsocksr', 'servers', s => {
			let proto = uc(s.v2ray_protocol || s.type || '');

			if (s.alias)
				add_node(nodes, s['.name'], `[${proto}]:${s.alias}`);
			else if (s.server && s.server_port)
				add_node(nodes, s['.name'], `[${proto}]:${s.server}:${s.server_port}`);
		});
		result.ssr = { exists: true, nodes: sorted_nodes(nodes) };
	}
	else {
		result.ssr = { exists: false, nodes: [] };
	}

	nodes = [];
	if (load_config(cur, 'passwall')) {
		cur.foreach('passwall', 'nodes', s => {
			if (s.remarks)
				add_node(nodes, s['.name'], `[${uc(s.protocol || s.type || '')}]:${s.remarks}`);
		});
		result.passwall = { exists: true, nodes: sorted_nodes(nodes) };
	}
	else {
		result.passwall = { exists: false, nodes: [] };
	}

	nodes = [];
	if (load_config(cur, 'passwall2')) {
		cur.foreach('passwall2', 'nodes', s => {
			if (s.remarks)
				add_node(nodes, s['.name'], `[${uc(s.protocol || s.type || '')}]:${s.remarks}`);
		});
		result.passwall2 = { exists: true, nodes: sorted_nodes(nodes) };
	}
	else {
		result.passwall2 = { exists: false, nodes: [] };
	}

	nodes = [];
	if (load_config(cur, 'bypass')) {
		cur.foreach('bypass', 'servers', s => {
			let proto = uc(s.protocol || s.type || '');

			if (s.alias)
				add_node(nodes, s['.name'], `[${proto}]:${s.alias}`);
			else if (s.server && s.server_port)
				add_node(nodes, s['.name'], `[${proto}]:${s.server}:${s.server_port}`);
		});
		result.bypass = { exists: true, nodes: sorted_nodes(nodes) };
	}
	else {
		result.bypass = { exists: false, nodes: [] };
	}

	nodes = [];
	if (load_config(cur, 'vssr')) {
		cur.foreach('vssr', 'servers', s => {
			let proto = uc(s.protocol || s.type || '');

			if (s.alias)
				add_node(nodes, s['.name'], `[${proto}]:${s.alias}`);
			else if (s.server && s.server_port)
				add_node(nodes, s['.name'], `[${proto}]:${s.server}:${s.server_port}`);
		});
		result.vssr = { exists: true, nodes: sorted_nodes(nodes) };
	}
	else {
		result.vssr = { exists: false, nodes: [] };
	}

	return result;
}

return {
	cloudflarespeedtest: {
		status: {
			call: function() {
				return status();
			}
		},

		start: {
			call: function() {
				return start();
			}
		},

		stop: {
			call: function() {
				return stop();
			}
		},

		get_log: {
			args: {
				pos: 0
			},
			call: function(req) {
				return get_log(req);
			}
		},

		get_history: {
			call: function() {
				return get_history();
			}
		},

		get_best_result: {
			call: function() {
				return get_best_result();
			}
		},

		list_nodes: {
			call: function() {
				return list_nodes();
			}
		}
	}
};
