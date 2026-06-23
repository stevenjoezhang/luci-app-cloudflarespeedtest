'use strict';
'require view';
'require form';
'require rpc';
'require uci';

const callListNodes = rpc.declare({
	object: 'cloudflarespeedtest',
	method: 'list_nodes',
	expect: {}
});

function addNodeValues(option, nodes) {
	nodes = nodes || [];

	for (let i = 0; i < nodes.length; i++)
		option.value(nodes[i].value, nodes[i].label);
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('cloudflarespeedtest'),
			callListNodes()
		]);
	},

	render: function(data) {
		let m, s, o;
		const nodes = data[1] || {};

		m = new form.Map('cloudflarespeedtest', _('Third Party Application Settings'));

		s = m.section(form.NamedSection, 'servers', 'servers');
		s.addremove = false;

		if (nodes.ssr && nodes.ssr.exists) {
			s.tab('ssr', _('ShadowSocksR Plus+'));

			o = s.taboption('ssr', form.Flag, 'ssr_enabled', _('ShadowSocksR Plus+ Enabled'));
			o.rmempty = true;

			o = s.taboption('ssr', form.DynamicList, 'ssr_services',
				_('ShadowSocksR Servers'), _('Please select a service'));
			addNodeValues(o, nodes.ssr.nodes);
			o.depends('ssr_enabled', '1');
			o.forcewrite = true;
		}

		if (nodes.passwall && nodes.passwall.exists) {
			s.tab('passwalltab', _('passwall'));

			o = s.taboption('passwalltab', form.Flag, 'passwall_enabled', _('Passwall Enabled'));
			o.rmempty = true;

			o = s.taboption('passwalltab', form.DynamicList, 'passwall_services',
				_('Passwall Servers'), _('Please select a service'));
			addNodeValues(o, nodes.passwall.nodes);
			o.depends('passwall_enabled', '1');
			o.forcewrite = true;
		}

		if (nodes.passwall2 && nodes.passwall2.exists) {
			s.tab('passwall2tab', _('passwall2'));

			o = s.taboption('passwall2tab', form.Flag, 'passwall2_enabled', _('PassWall2 Enabled'));
			o.rmempty = true;

			o = s.taboption('passwall2tab', form.DynamicList, 'passwall2_services',
				_('Passwall2 Servers'), _('Please select a service'));
			addNodeValues(o, nodes.passwall2.nodes);
			o.depends('passwall2_enabled', '1');
			o.forcewrite = true;
		}

		if (nodes.bypass && nodes.bypass.exists) {
			s.tab('bypasstab', _('Bypass'));

			o = s.taboption('bypasstab', form.Flag, 'bypass_enabled', _('Bypass Enabled'));
			o.rmempty = true;

			o = s.taboption('bypasstab', form.DynamicList, 'bypass_services',
				_('Bypass Servers'), _('Please select a service'));
			addNodeValues(o, nodes.bypass.nodes);
			o.depends('bypass_enabled', '1');
			o.forcewrite = true;
		}

		if (nodes.vssr && nodes.vssr.exists) {
			s.tab('vssrtab', _('Vssr'));

			o = s.taboption('vssrtab', form.Flag, 'vssr_enabled', _('Vssr Enabled'));
			o.rmempty = true;

			o = s.taboption('vssrtab', form.DynamicList, 'vssr_services',
				_('Vssr Servers'), _('Please select a service'));
			addNodeValues(o, nodes.vssr.nodes);
			o.depends('vssr_enabled', '1');
			o.forcewrite = true;
		}

		s.tab('dnshost', _('HOST'));
		o = s.taboption('dnshost', form.Flag, 'HOST_enabled', _('HOST Enabled'));
		o = s.taboption('dnshost', form.Value, 'host_domain', _('Domain'));
		o.rmempty = true;
		o.depends('HOST_enabled', '1');

		s.tab('dnstab', _('DNS'));

		o = s.taboption('dnstab', form.Flag, 'DNS_enabled', _('DNS Enabled'));

		o = s.taboption('dnstab', form.ListValue, 'DNS_type', _('DNS Type'));
		o.value('aliyun', _('Alibaba Cloud DNS'));
		o.depends('DNS_enabled', '1');

		o = s.taboption('dnstab', form.Value, 'app_key', _('Access Key ID'));
		o.rmempty = true;
		o.depends('DNS_enabled', '1');

		o = s.taboption('dnstab', form.Value, 'app_secret', _('Access Key Secret'));
		o.rmempty = true;
		o.password = true;
		o.depends('DNS_enabled', '1');

		o = s.taboption('dnstab', form.Value, 'main_domain', _('Main Domain'),
			_('For example: test.github.com -> github.com'));
		o.rmempty = true;
		o.depends('DNS_enabled', '1');

		o = s.taboption('dnstab', form.DynamicList, 'sub_domain', _('Sub Domain'),
			_('For example: test.github.com -> test'));
		o.rmempty = true;
		o.depends('DNS_enabled', '1');

		o = s.taboption('dnstab', form.ListValue, 'line', _('Lines'));
		o.value('default', _('default'));
		o.value('telecom', _('telecom'));
		o.value('unicom', _('unicom'));
		o.value('mobile', _('mobile'));
		o.depends('DNS_enabled', '1');
		o.default = 'telecom';

		o = s.taboption('dnstab', form.Value, 'AliDNS_ip_count', _('AliDNS IP Count'));
		o.datatype = 'uinteger';
		o.default = '1';
		o.depends('DNS_enabled', '1');

		s.tab('mosdns', _('MosDNS'));
		o = s.taboption('mosdns', form.Flag, 'MosDNS_enabled', _('MosDNS Enabled'));
		o = s.taboption('mosdns', form.Value, 'MosDNS_ip_count', _('MosDNS IP Count'));
		o.datatype = 'uinteger';
		o.default = '1';
		o.depends('MosDNS_enabled', '1');
		o = s.taboption('mosdns', form.Flag, 'openclash_restart', _('OpenClash Restart'));
		o.depends('MosDNS_enabled', '1');

		s.tab('astradns', _('astra-dns'));
		o = s.taboption('astradns', form.Flag, 'AstraDNS_enabled', _('astra-dns Enabled'));
		o.rmempty = true;

		o = s.taboption('astradns', form.Value, 'AstraDNS_config', _('astra-dns Config Path'));
		o.default = '/etc/astra-dns/named.yaml';
		o.rmempty = true;
		o.depends('AstraDNS_enabled', '1');

		o = s.taboption('astradns', form.Value, 'AstraDNS_bin', _('astra-dns Binary Path'));
		o.default = '/usr/bin/astra-dns';
		o.rmempty = true;
		o.depends('AstraDNS_enabled', '1');

		return m.render();
	}
});
