'use strict';
'require view';

let activeTab = 'profile';
let modules = {};
let loaded = {};

const tabs = [
	{ id: 'profile', label: _('模板'), module: 'view.shinra.profile' },
	{ id: 'subscriptions', label: _('订阅'), module: 'view.shinra.subscriptions' },
	{ id: 'rules', label: _('规则集'), module: 'view.shinra.rulesets' },
	{ id: 'panel', label: _('面板'), module: 'view.shinra.panel_settings' },
	{ id: 'notify', label: _('通知'), module: 'view.shinra.notify' }
];

function sectionStyle() {
	return 'border: 1px solid #dfe3e8; border-radius: 8px; padding: .75rem 1rem; margin: 0 0 .75rem; background: #fff;';
}

function pageHeader(title, description) {
	return E('div', { 'style': sectionStyle() }, [
		E('h2', { 'style': 'margin: 0 0 .35rem; line-height: 1.25;' }, title),
		E('p', { 'style': 'margin: 0; color: #667; line-height: 1.35; overflow-wrap: anywhere;' }, description)
	]);
}

function tabById(id) {
	for (let i = 0; i < tabs.length; i++) {
		if (tabs[i].id === id)
			return tabs[i];
	}
	return tabs[0];
}

function loadTab(tab) {
	return L.require(tab.module).then(function(mod) {
		modules[tab.id] = mod;
		if (mod && typeof mod.load === 'function') {
			return mod.load().then(function(data) {
				loaded[tab.id] = data;
				return data;
			});
		}

		loaded[tab.id] = null;
		return null;
	}).catch(function(error) {
		modules[tab.id] = null;
		loaded[tab.id] = {
			error: error.message || String(error)
		};
		return loaded[tab.id];
	});
}

function loadAllTabs() {
	return Promise.all(tabs.map(loadTab));
}

function redraw() {
	const root = document.getElementById('shinra-resources-root');
	if (root)
		root.parentNode.replaceChild(renderPage(), root);
}

function tabButton(tab) {
	const active = activeTab === tab.id;

	return E('button', {
		'type': 'button',
		'class': 'btn cbi-button %s'.format(active ? 'cbi-button-apply' : 'cbi-button-neutral'),
		'style': 'min-width: 120px;',
		'click': function(ev) {
			ev.preventDefault();
			activeTab = tab.id;
			redraw();
		}
	}, tab.label);
}

function tabBar() {
	return E('div', {
		'style': 'display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; margin: 0 0 .75rem;'
	}, tabs.map(tabButton));
}

function renderActiveTab() {
	const tab = tabById(activeTab);
	const mod = modules[tab.id];
	const data = loaded[tab.id];

	if (data && data.error) {
		return E('div', { 'style': sectionStyle() }, [
			E('h3', { 'style': 'margin: 0 0 .45rem; line-height: 1.25;' }, tab.label),
			E('p', { 'style': 'margin: 0; color: #b91c1c; line-height: 1.35; overflow-wrap: anywhere;' }, data.error)
		]);
	}

	if (!mod || typeof mod.render !== 'function') {
		return E('div', { 'style': sectionStyle() }, [
			E('h3', { 'style': 'margin: 0 0 .45rem; line-height: 1.25;' }, tab.label),
			E('p', { 'style': 'margin: 0; color: #667; line-height: 1.35;' }, _('该资源页暂不可用。'))
		]);
	}

	return E('div', { 'class': 'shinra-resource-tab' }, [
		mod.render(data)
	]);
}

function renderPage() {
	return E('div', { 'id': 'shinra-resources-root', 'class': 'cbi-map' }, [
		pageHeader(
			_('资源管理'),
			_('管理模板、订阅源、规则集、面板和自动任务通知。保存只写入设置；刷新、同步和更新可能作为后台任务运行。')
		),
		tabBar(),
		renderActiveTab()
	]);
}

return view.extend({
	load: function() {
		return loadAllTabs();
	},

	render: function() {
		return renderPage();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
