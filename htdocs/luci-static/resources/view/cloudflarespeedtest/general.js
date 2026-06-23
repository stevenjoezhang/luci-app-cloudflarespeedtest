'use strict';
'require view';
'require form';
'require poll';
'require rpc';
'require ui';
'require uci';

const callStatus = rpc.declare({
	object: 'cloudflarespeedtest',
	method: 'status',
	expect: {}
});

const callStart = rpc.declare({
	object: 'cloudflarespeedtest',
	method: 'start',
	expect: {}
});

const callStop = rpc.declare({
	object: 'cloudflarespeedtest',
	method: 'stop',
	expect: {}
});

const callHistory = rpc.declare({
	object: 'cloudflarespeedtest',
	method: 'get_history',
	expect: { history: [] }
});

const callBestResult = rpc.declare({
	object: 'cloudflarespeedtest',
	method: 'get_best_result',
	expect: { content: '' }
});

function script(src) {
	return new Promise(function(resolve, reject) {
		const existing = document.querySelector('script[src="%s"]'.format(src));

		if (existing && existing.dataset.loaded == 'true') {
			resolve();
			return;
		}

		const el = existing || E('script', { src: src });
		el.addEventListener('load', resolve, { once: true });
		el.addEventListener('error', reject, { once: true });
		el.onload = function() {
			el.dataset.loaded = 'true';
		};
		el.onerror = reject;

		if (!existing)
			document.head.appendChild(el);
	});
}

function chartCss() {
	return E('style', {}, `
.cloudflarespeedtest-chart-container {
	--card-bg: #f8f8f8;
	--text-color: #222;
	--card-shadow: 0 2px 6px rgba(0,0,0,0.1);
	width: 100%;
	margin: 20px auto;
	background: var(--card-bg);
	padding: 20px;
	border-radius: 8px;
	box-shadow: var(--card-shadow);
	color: var(--text-color);
	box-sizing: border-box;
}

@media (prefers-color-scheme: dark) {
	.cloudflarespeedtest-chart-container {
		--card-bg: #282828;
		--text-color: #e6eef6;
		--card-shadow: 0 2px 6px rgba(0,0,0,0.6);
	}
}

.cloudflarespeedtest-chart-row {
	display: flex;
	gap: 30px;
}

@media (max-width: 767px) {
	.cloudflarespeedtest-chart-row {
		flex-direction: column;
	}
}

.cloudflarespeedtest-chart-container canvas {
	display: block;
	width: 100%;
	height: 300px;
}
`);
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('cloudflarespeedtest'),
			callStatus(),
			callBestResult(),
			callHistory()
		]);
	},

	updateStatus: function(node, status) {
		if (!node)
			return;

		const running = status && status.running;
		const cron = status && status.cron;

		node.replaceChildren(
			E('em', {}, [
				E('b', { style: 'color:%s'.format(running ? 'green' : 'red') },
					_('Cloudflare Speed Test') + ' ' + (running ? _('RUNNING') : _('NOT RUNNING')))
			]),
			' ',
			E('em', {}, [
				E('b', { style: 'color:%s'.format(cron ? 'green' : 'red') },
					cron ? _('Crontab enabled') : _('Crontab disabled'))
			])
		);
	},

	pollStatus: function(node, button) {
		return callStatus().then(L.bind(function(status) {
			this.updateStatus(node, status);
			this.updateButton(button, status && status.running);
		}, this));
	},

	updateButton: function(button, running) {
		if (!button)
			return;

		if (button.classList) {
			button.value = running ? _('Stop') : _('Start');
			button.textContent = running ? _('Stop') : _('Start');
			button.classList.toggle('cbi-button-reset', !!running);
			button.classList.toggle('cbi-button-apply', !running);
		}
		else {
			button.inputtitle = running ? _('Stop') : _('Start');
			button.inputstyle = running ? 'reset' : 'apply';
		}
	},

	drawCharts: function(root, dataPoints) {
		if (!root || !window.Chart || !dataPoints || !dataPoints.length)
			return;

		const latencyCanvas = root.querySelector('#cloudflarespeedtest-latency-chart');
		const speedCanvas = root.querySelector('#cloudflarespeedtest-speed-chart');

		if (!latencyCanvas || !speedCanvas)
			return;

		const labels = dataPoints.map(d => d.time);
		const latencyData = dataPoints.map(d => d.latency);
		const speedData = dataPoints.map(d => d.speed);

		const tooltip = unitText => ({
			mode: 'index',
			intersect: false,
			callbacks: {
				title: ctx => _('Time') + ': ' + ctx[0].label,
				beforeBody: ctx => {
					const d = dataPoints[ctx[0].dataIndex];
					return 'IP: %s, %s: %s'.format(d.ip, _('Region'), d.region);
				},
				label: ctx => '%s: %s %s'.format(ctx.dataset.label, ctx.parsed.y, unitText)
			}
		});

		const timeScale = {
			type: 'time',
			time: {
				parser: 'yyyy-MM-dd HH:mm:ss',
				tooltipFormat: 'yyyy-MM-dd HH:mm:ss',
				unit: 'hour',
				displayFormats: { hour: 'MM-dd HH:mm' }
			},
			title: { display: true, text: _('Time') },
			offset: true,
			ticks: {
				autoSkip: true,
				maxTicksLimit: 6,
				maxRotation: 45,
				minRotation: 0
			}
		};

		new Chart(latencyCanvas, {
			type: 'line',
			data: {
				labels: labels,
				datasets: [{
					label: _('Latency'),
					data: latencyData,
					borderColor: 'rgba(75, 192, 192, 1)',
					backgroundColor: 'rgba(75, 192, 192, 0.2)',
					tension: 0.3,
					fill: false,
					pointRadius: 4
				}]
			},
			options: {
				responsive: true,
				interaction: tooltip('ms'),
				plugins: {
					tooltip: tooltip('ms'),
					legend: { position: 'top' }
				},
				scales: {
					x: timeScale,
					y: {
						type: 'linear',
						title: { display: true, text: _('Latency') + ' (ms)' }
					}
				}
			}
		});

		new Chart(speedCanvas, {
			type: 'line',
			data: {
				labels: labels,
				datasets: [{
					label: _('Download speed'),
					data: speedData,
					borderColor: 'rgba(255, 159, 64, 1)',
					backgroundColor: 'rgba(255, 159, 64, 0.2)',
					tension: 0.3,
					fill: false,
					pointRadius: 4
				}]
			},
			options: {
				responsive: true,
				interaction: tooltip('MB/s'),
				plugins: {
					tooltip: tooltip('MB/s'),
					legend: { position: 'top' }
				},
				scales: {
					x: timeScale,
					y: {
						type: 'linear',
						title: { display: true, text: _('Speed') + ' (MB/s)' }
					}
				}
			}
		});
	},

	render: function(data) {
		let m, s, o;
		let actionButton;
		const status = data[1] || {};
		const bestResult = data[2] || '';
		const history = data[3] || [];

		m = new form.Map('cloudflarespeedtest', _('Cloudflare Speed Test'),
			_('Schedules and runs CloudflareSpeedTest with the selected IP list, automatically applying the fastest IPs to supported integrations') +
			'<br><a href="https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest" target="_blank">⭐ ' + _('Star on GitHub') + '</a>');

		s = m.section(form.NamedSection, 'global', 'global');
		s.addremove = false;

		s.tab('basic', _('Basic Settings'));

		o = s.taboption('basic', form.Button, '_speedtest', _('Speed test'),
			_('Test latency and speed for all IPs in the selected CDN or website list, then apply the fastest IP (IPv4 + IPv6 supported)'));
		this.updateButton(o, status.running);
		actionButton = o;
		o.onclick = L.bind(function(ev, sectionId) {
			const button = ev.currentTarget;
			button.disabled = true;

			return callStatus().then(function(st) {
				return st.running ? callStop() : callStart().then(function() {
					window.setTimeout(function() {
						window.location = L.url('admin/services/cloudflarespeedtest/logread');
					}, 500);
				});
			}).then(L.bind(function() {
				return this.pollStatus(document.getElementById('cloudflarespeedtest-status'), button);
			}, this)).catch(function(e) {
				ui.addNotification(null, E('p', {}, e.message));
			}).finally(function() {
				button.disabled = false;
			});
		}, this);

		o = s.taboption('basic', form.ListValue, 'ip_source', _('IP list source'),
			_('Select the IP list used by CloudflareSpeedTest'));
		o.value('builtin_ipv4', _('Built-in IPv4 list'));
		o.value('builtin_ipv6', _('Built-in IPv6 list'));
		o.value('custom_file', _('Custom file'));
		o.default = 'builtin_ipv4';
		o.rmempty = false;
		o.cfgvalue = function(sectionId) {
			const value = uci.get('cloudflarespeedtest', sectionId, 'ip_source');

			if (value)
				return value;

			return uci.get('cloudflarespeedtest', sectionId, 'ipv6_enabled') == '1'
				? 'builtin_ipv6'
				: 'builtin_ipv4';
		};

		o = s.taboption('basic', form.Value, 'custom_ip_file', _('Custom IP list file'),
			_('Enter a local file path, for example: /etc/cloudflarespeedtest/ip.txt'));
		o.depends('ip_source', 'custom_file');
		o.rmempty = true;
		o.validate = function(sectionId, value) {
			const ipSource = this.section.formvalue(sectionId, 'ip_source');

			if (ipSource == 'custom_file' && !value)
				return _('Custom IP list file is required when using Custom file');

			return true;
		};

		o = s.taboption('basic', form.Flag, 'custom_allip', _('Scan all IPs in each /24'),
			_('Only applies to custom IP lists. Disabled by default, which means CloudflareSpeedTest will randomly test one IP from each /24. Enable this to pass -allip and scan every IP in each /24'));
		o.depends('ip_source', 'custom_file');
		o.default = o.disabled;
		o.rmempty = false;

		o = s.taboption('basic', form.Value, 'speed_limit', _('Speed threshold (MB/s)'),
			_('Only IPs with a download speed greater than this threshold will be retained. Please note, do not set this value too high — if no IP meets the requirement, CloudflareSpeedTest may waste excessive time and resources'));
		o.datatype = 'uinteger';
		o.rmempty = false;

		o = s.taboption('basic', form.Value, 'custom_url', _('Custom URL'),
			_('<a href="https://github.com/XIU2/CloudflareSpeedTest/issues/168" target="_blank">How to create</a>'));
		o.rmempty = false;
		o.default = 'https://download.parallels.com/desktop/v15/15.1.5-47309/ParallelsDesktop-15.1.5-47309.dmg';
		o.value('https://speed.cloudflare.com/__down?bytes=99000000', 'speed.cloudflare.com (99M Max)');
		o.value('https://download.parallels.com/desktop/v15/15.1.5-47309/ParallelsDesktop-15.1.5-47309.dmg', 'Parallels Desktop v15');
		o.value('https://download.parallels.com/desktop/v17/17.1.1-51537/ParallelsDesktop-17.1.1-51537.dmg', 'Parallels Desktop v17');
		o.value('https://w.7rs.net/speedtest/200mb.test', 'w.7rs.net (200M)');
		o.value('https://t1.geigei.gq', 't1.geigei.gq');
		o.value('https://t2.geigei.gq', 't2.geigei.gq');

		o = s.taboption('basic', form.ListValue, 'proxy_mode', _('Proxy mode'),
			_('Switch to the selected proxy mode during the speed test'));
		o.value('nil', _('HOLD'));
		o.value('gfw', _('GFW List'));
		o.value('close', _('CLOSE'));
		o.default = 'gfw';

		o = s.taboption('basic', form.ListValue, 'github_proxy', _('GitHub Mirror'),
			_('Only used when downloading the CloudflareSpeedTest core from GitHub releases'));
		o.value('direct', _('Direct'));
		o.value('ghfast', 'ghfast.top');
		o.value('ghproxy', 'ghproxy.cc');
		o.value('custom', _('Custom'));
		o.default = 'direct';

		o = s.taboption('basic', form.Value, 'github_proxy_custom', _('Custom GitHub Mirror'),
			_('Enter a GitHub mirror prefix, for example: https://ghfast.top/'));
		o.depends('github_proxy', 'custom');
		o.rmempty = true;

		s.tab('cron', _('Crontab Settings'));

		o = s.taboption('cron', form.Flag, 'enabled', _('Enabled'),
			_('Enable scheduled task to test the selected IP list'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.taboption('cron', form.Flag, 'custom_cron_enabled', _('Enable custom cron'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.taboption('cron', form.Value, 'custom_cron', _('Custom Cron'), _('Example: 0 */3 * * *'));
		o.depends('custom_cron_enabled', '1');

		o = s.taboption('cron', form.ListValue, 'hour', _('Interval'));
		o.depends('custom_cron_enabled', '0');
		[1, 2, 3, 4, 6, 8, 12, 24].forEach(function(hour) {
			o.value(hour, _('Every %d hour(s)').format(hour));
		});
		o.default = '24';

		s.tab('advanced', _('Advanced'));

		o = s.taboption('advanced', form.Flag, 'advanced', _('Advanced'), _('Not recommended'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'threads', _('Thread Count'));
		o.datatype = 'uinteger';
		o.default = '200';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 'tl', _('Average latency cap'));
		o.datatype = 'uinteger';
		o.default = '200';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 'tll', _('Average latency lower bound'));
		o.datatype = 'uinteger';
		o.default = '40';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 't', _('Delayed speed measurement time'));
		o.datatype = 'uinteger';
		o.default = '4';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 'dt', _('Download speed test time'));
		o.datatype = 'uinteger';
		o.default = '10';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 'dn', _('Number of download speed tests'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Flag, 'dd', _('Disable download speed test'));
		o.default = o.disabled;
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 'tp', _('Port'));
		o.datatype = 'port';
		o.default = '443';
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Flag, 'httping', _('Use HTTP for latency test'));
		o.default = o.disabled;
		o.rmempty = true;
		o.depends('advanced', '1');

		o = s.taboption('advanced', form.Value, 'cfcolo', _('Cloudflare colo code'));
		o.datatype = 'string';
		o.default = '';
		o.rmempty = true;
		o.depends('httping', '1');

		s = m.section(form.NamedSection, 'global', 'global', _('Best IP'));
		s.addremove = false;
		o = s.option(form.TextValue, '_best_result');
		o.rows = 8;
		o.readonly = true;
		o.wrap = 'off';
		o.cfgvalue = function() {
			return typeof bestResult == 'string' ? bestResult : (bestResult.content || '');
		};
		o.write = function() {};

		return m.render().then(L.bind(function(formNode) {
			const statusNode = E('p', { id: 'cloudflarespeedtest-status' }, _('Collecting data...'));
			this.updateStatus(statusNode, status);

			const chartNode = E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('History Charts')),
				chartCss(),
				E('div', { 'class': 'cloudflarespeedtest-chart-row' }, [
					E('div', { 'class': 'cloudflarespeedtest-chart-container' }, [
						E('canvas', { id: 'cloudflarespeedtest-latency-chart' })
					]),
					E('div', { 'class': 'cloudflarespeedtest-chart-container' }, [
						E('canvas', { id: 'cloudflarespeedtest-speed-chart' })
					])
				])
			]);

			const root = E([], [
				E('div', { 'class': 'cbi-section' }, [ statusNode ]),
				formNode
			]);

			const formActions = formNode.querySelector('.cbi-page-actions');

			if (formActions && formActions.parentNode)
				formActions.parentNode.insertBefore(chartNode, formActions);
			else
				formNode.appendChild(chartNode);

			poll.add(L.bind(this.pollStatus, this, statusNode, actionButton), 3);

			script(L.resource('cloudflarespeedtest/chart.js')).then(function() {
				return script(L.resource('cloudflarespeedtest/chartjs-adapter-date-fns.js'));
			}).then(L.bind(function() {
				this.drawCharts(chartNode, history);
			}, this));

			return root;
		}, this));
	}
});
