'use strict';
'require view';
'require rpc';
'require shinra.ui as shinraUi';

const callNotifySettingsGet = rpc.declare({
	object: 'shinra',
	method: 'notify_settings_get',
	expect: { '': {} }
});

const callNotifySettingsSave = rpc.declare({
	object: 'shinra',
	method: 'notify_settings_save',
	params: [ 'content' ],
	expect: { '': {} }
});

const callNotifyTestTelegram = rpc.declare({
	object: 'shinra',
	method: 'notify_test_telegram',
	expect: { '': {} }
});

let settingsResult = null;
let actionStatus = '';
let actionStatusOk = true;

function setStatus(message, ok) {
	actionStatus = message || '';
	actionStatusOk = ok !== false;
	const node = document.getElementById('shinra-notify-status');
	if (!node)
		return;

	node.textContent = actionStatus;
	node.style.display = actionStatus ? 'block' : 'none';
	node.style.borderColor = actionStatusOk ? '#bbf7d0' : '#fecaca';
	node.style.background = actionStatusOk ? '#f0fdf4' : '#fef2f2';
	node.style.color = actionStatusOk ? '#166534' : '#991b1b';
}

function dataOf(result) {
	if (result && result.ok && result.data)
		return result.data;
	return {};
}

function notifySettings() {
	const data = dataOf(settingsResult);
	const settings = data.settings || {};
	const telegram = settings.telegram || {};

	return {
		schema_version: 1,
		telegram: {
			enabled: telegram.enabled === true,
			mode: telegram.mode === 'all' ? 'all' : 'fail_only',
			bot_token: typeof telegram.bot_token === 'string' ? telegram.bot_token : '',
			chat_id: typeof telegram.chat_id === 'string' ? telegram.chat_id : '',
			location_name: typeof telegram.location_name === 'string' && telegram.location_name !== '' ? telegram.location_name : 'Shinra',
			fetch_strategy: telegram.fetch_strategy === 'direct' ? 'direct' : 'proxy',
			timeout_sec: Number(telegram.timeout_sec || 15)
		}
	};
}

function sectionStyle() {
	return 'border: 1px solid #dfe3e8; border-radius: 8px; padding: .75rem 1rem; margin: 0 0 .75rem; background: #fff;';
}

function mutedStyle() {
	return 'color: #667; line-height: 1.35; overflow-wrap: anywhere;';
}

function pageHeader(title, description) {
	return E('div', { 'style': sectionStyle() }, [
		E('h2', { 'style': 'margin: 0 0 .35rem; line-height: 1.25;' }, title),
		E('p', { 'style': mutedStyle() + ' margin: 0;' }, description)
	]);
}

function sectionTitle(title) {
	return E('h3', { 'style': 'margin: 0 0 .45rem; line-height: 1.25;' }, title);
}

function field(label, input, help) {
	return E('label', { 'style': 'display: block; margin-bottom: .75rem;' }, [
		E('div', { 'style': 'font-size: 12px; color: #667; font-weight: 700; margin-bottom: .25rem;' }, label),
		input,
		help ? E('div', { 'style': 'font-size: 12px; color: #667; margin-top: .25rem;' }, help) : ''
	]);
}

function settingsFromInputs() {
	return {
		schema_version: 1,
		telegram: {
			enabled: document.getElementById('shinra-notify-enabled') ? document.getElementById('shinra-notify-enabled').checked : false,
			mode: document.getElementById('shinra-notify-mode') ? document.getElementById('shinra-notify-mode').value : 'fail_only',
			bot_token: document.getElementById('shinra-notify-token') ? document.getElementById('shinra-notify-token').value : '',
			chat_id: document.getElementById('shinra-notify-chat') ? document.getElementById('shinra-notify-chat').value : '',
			location_name: document.getElementById('shinra-notify-location') ? document.getElementById('shinra-notify-location').value : 'Shinra',
			fetch_strategy: document.getElementById('shinra-notify-fetch-strategy') && document.getElementById('shinra-notify-fetch-strategy').value === 'direct' ? 'direct' : 'proxy',
			timeout_sec: document.getElementById('shinra-notify-timeout') ? Number(document.getElementById('shinra-notify-timeout').value || 15) : 15
		}
	};
}

function refreshPage() {
	return callNotifySettingsGet().then(function(result) {
		settingsResult = result;
		redraw();
		return result;
	});
}

function saveSettings() {
	setStatus(_('正在保存通知设置...'), true);
	return callNotifySettingsSave(JSON.stringify(settingsFromInputs())).then(function(result) {
		if (result && result.ok) {
			settingsResult = {
				ok: true,
				data: result.data || {}
			};
			setStatus(_('通知设置已保存。自动任务会使用这些设置。'), true);
			return result;
		}
		setStatus('%s: %s'.format(result && (result.message || result.code) || _('保存失败'), result && (result.detail || result.code) || _('无详细信息')), false);
		return result;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function testTelegram() {
	setStatus(_('测试前正在保存设置...'), true);
	return saveSettings().then(function(saveResult) {
		if (!(saveResult && saveResult.ok))
			return saveResult;
		setStatus(_('正在发送 Telegram 测试...'), true);
		return callNotifyTestTelegram();
	}).then(function(result) {
		if (!(result && result.ok !== undefined))
			return result;
		if (result && result.ok)
			setStatus(_('Telegram 测试已发送。'), true);
		else {
			setStatus('%s: %s'.format(result && (result.message || result.code) || _('Telegram 测试失败'), result && (result.detail || result.code) || _('无详细信息')), false);
		}
		return result;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function renderPage() {
	const settings = notifySettings();
	const tg = settings.telegram;

	return E('div', { 'id': 'shinra-notify-root', 'class': 'cbi-map' }, [
		pageHeader(_('通知'), _('Telegram 通知仅用于无人值守的自动资源更新，例如订阅刷新和规则集同步失败。手工操作不会发送通知。')),
		E('div', { 'style': sectionStyle() }, [
			sectionTitle(_('Telegram')),
			E('div', {
				'id': 'shinra-notify-status',
				'style': 'display: %s; border: 1px solid %s; border-radius: 8px; padding: .65rem; margin-bottom: .75rem; background: %s; color: %s;'.format(
					actionStatus ? 'block' : 'none',
					actionStatusOk ? '#bbf7d0' : '#fecaca',
					actionStatusOk ? '#f0fdf4' : '#fef2f2',
					actionStatusOk ? '#166534' : '#991b1b'
				)
			}, actionStatus),
			E('label', { 'style': 'display: flex; align-items: center; gap: .5rem; margin-bottom: .75rem;' }, [
				shinraUi.checkboxInput({
					'id': 'shinra-notify-enabled',
					'checked': tg.enabled ? 'checked' : null
				}),
				E('span', {}, _('为自动资源任务启用 Telegram 通知'))
			]),
			field(_('通知'), E('select', { 'id': 'shinra-notify-mode', 'class': 'cbi-input-select', 'style': 'min-width: 220px;' }, [
				E('option', { 'value': 'fail_only', 'selected': tg.mode === 'fail_only' ? 'selected' : null }, _('仅失败')),
				E('option', { 'value': 'all', 'selected': tg.mode === 'all' ? 'selected' : null }, _('所有结果'))
			]), _('无人值守更新建议只通知失败。')),
			E('div', { 'style': 'display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: .75rem;' }, [
				field(_('机器人 Token'), E('input', {
					'id': 'shinra-notify-token',
					'class': 'cbi-input-password',
					'type': 'password',
					'style': 'width: 100%; box-sizing: border-box;',
					'value': tg.bot_token || '',
					'placeholder': _('123456:ABC...')
				}), _('可带 bot 前缀。')),
				field(_('会话 ID'), E('input', {
					'id': 'shinra-notify-chat',
					'class': 'cbi-input-text',
					'style': 'width: 100%; box-sizing: border-box;',
					'value': tg.chat_id || ''
				}), _('用户、群组或频道的 Chat ID。')),
				field(_('位置名称'), E('input', {
					'id': 'shinra-notify-location',
					'class': 'cbi-input-text',
					'style': 'width: 100%; box-sizing: border-box;',
					'value': tg.location_name || 'Shinra'
				}), _('显示在消息标题中。')),
				field(_('请求策略'), E('select', {
					'id': 'shinra-notify-fetch-strategy',
					'class': 'cbi-input-select',
					'style': 'width: 100%; box-sizing: border-box;'
				}, [
					E('option', { 'value': 'proxy', 'selected': tg.fetch_strategy === 'proxy' ? 'selected' : null }, _('代理')),
					E('option', { 'value': 'direct', 'selected': tg.fetch_strategy === 'direct' ? 'selected' : null }, _('直连'))
				]), _('Telegram 默认建议走代理。')),
				field(_('超时时间'), E('input', {
					'id': 'shinra-notify-timeout',
					'class': 'cbi-input-text',
					'type': 'number',
					'min': '5',
					'max': '60',
					'style': 'width: 100%; box-sizing: border-box;',
					'value': tg.timeout_sec || 15
				}), _('单位：秒。'))
			]),
			E('div', { 'style': 'display: flex; gap: .5rem; flex-wrap: wrap; margin-top: .85rem;' }, [
				E('button', { 'class': 'btn cbi-button cbi-button-save', 'click': function(ev) { ev.preventDefault(); return saveSettings(); } }, _('保存通知设置')),
				E('button', { 'class': 'btn cbi-button cbi-button-apply', 'click': function(ev) { ev.preventDefault(); return testTelegram(); } }, _('保存并发送测试'))
			])
		])
	]);
}

function redraw() {
	const root = document.getElementById('shinra-notify-root');
	if (root)
		root.parentNode.replaceChild(renderPage(), root);
}

return view.extend({
	load: function() {
		return callNotifySettingsGet();
	},

	render: function(result) {
		settingsResult = result;
		return renderPage();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
