'use strict';
'require view';
'require rpc';
'require shinra.ui as shinraUi';
'require shinra.motion as shinraMotion';

const callProfileGet = rpc.declare({
	object: 'shinra',
	method: 'profile_get',
	expect: { '': {} }
});

const callProfileSourceGet = rpc.declare({
	object: 'shinra',
	method: 'profile_source_get',
	expect: { '': {} }
});

const callProfileSourceSave = rpc.declare({
	object: 'shinra',
	method: 'profile_source_save',
	params: [ 'content' ],
	expect: { '': {} }
});

const callProfileSyncRemote = rpc.declare({
	object: 'shinra',
	method: 'profile_sync_remote',
	expect: { '': {} }
});

const callProfileRestoreDefault = rpc.declare({
	object: 'shinra',
	method: 'profile_restore_default',
	expect: { '': {} }
});

const callProfileRollback = rpc.declare({
	object: 'shinra',
	method: 'profile_rollback',
	expect: { '': {} }
});

const DEFAULT_TEMPLATE_URL = 'https://testingcf.jsdelivr.net/gh/Vonzhen/shinra@master/profiles/main-profile.json';

let profileResult = null;
let sourceResult = null;
let actionStatus = '';
let actionStatusOk = true;

function dataOf(result) {
	if (result && result.ok && result.data)
		return result.data;
	return {};
}

function profileContent(result) {
	return result && result.ok && result.data && typeof result.data.content === 'string' ? result.data.content : '';
}

function sourceData() {
	const data = dataOf(sourceResult);
	return data.source || {};
}

function sourceInputUrl() {
	return sourceData().url || DEFAULT_TEMPLATE_URL;
}

function sourceFetchStrategy() {
	return sourceData().fetch_strategy === 'proxy' ? 'proxy' : 'direct';
}

function actionStatusBox() {
	return shinraUi.statusBox('shinra-profile-action-status', actionStatus, actionStatusOk ? 'ok' : 'error', {
		padding: '.75rem',
		margin: '.85rem 0 0'
	});
}

function setStatus(text, ok) {
	actionStatus = text || '';
	actionStatusOk = ok !== false;
	shinraUi.paintStatus('shinra-profile-action-status', actionStatus, actionStatusOk ? 'ok' : 'error');
}

function resultError(result, fallback) {
	if (result && (result.message || result.code))
		return '%s: %s'.format(result.message || result.code || fallback || _('操作失败'), result.detail || result.code || _('无详细信息'));
	return fallback || _('操作失败');
}

function refreshPage() {
	return Promise.all([
		callProfileGet(),
		callProfileSourceGet()
	]).then(function(results) {
		profileResult = results && results[0] ? results[0] : {};
		sourceResult = results && results[1] ? results[1] : {};
		redraw();
		return results;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function saveSource() {
	const input = document.getElementById('shinra-profile-source-url');
	const strategy = document.getElementById('shinra-profile-fetch-strategy');
	const source = {
		schema_version: 1,
		url: input ? input.value : '',
		fetch_strategy: strategy && strategy.value === 'proxy' ? 'proxy' : 'direct'
	};

	setStatus(_('正在保存模板源...'), true);

	return callProfileSourceSave(JSON.stringify(source)).then(function(result) {
		if (result && result.ok) {
			sourceResult = {
				ok: true,
				data: dataOf(result)
			};
			setStatus(_('模板源已保存。需要替换 main-profile.json 时，请执行同步模板。'), true);
			redraw();
		} else {
			setStatus(resultError(result, _('保存失败')), false);
		}
		return result;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function syncRemote() {
	setStatus(_('正在同步模板...'), true);

	return callProfileSyncRemote().then(function(result) {
		if (result && result.ok) {
			setStatus(_('模板已同步。准备使用新模板时，请生成候选配置。'), true);
			return refreshPage();
		}

		setStatus(resultError(result, _('同步失败')), false);
		return result;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function rollbackProfile() {
	if (!window.confirm(_('回滚到上一个模板备份吗？运行配置不会改变。')))
		return Promise.resolve();

	setStatus(_('正在回滚模板...'), true);

	return callProfileRollback().then(function(result) {
		if (result && result.ok) {
			setStatus(_('模板已回滚。准备使用时，请生成候选配置。'), true);
			return refreshPage();
		}
		setStatus(resultError(result, _('回滚失败')), false);
		return result;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function restoreDefault() {
	if (!window.confirm(_('恢复内置模板吗？当前模板会被备份。')))
		return Promise.resolve();

	setStatus(_('正在恢复内置模板...'), true);

	return callProfileRestoreDefault().then(function(result) {
		if (result && result.ok) {
			setStatus(_('内置模板已恢复。准备使用时，请生成候选配置。'), true);
			return refreshPage();
		}
		setStatus(resultError(result, _('恢复失败')), false);
		return result;
	}).catch(function(error) {
		setStatus(error.message || String(error), false);
	});
}

function sourceSettings() {
	return E('div', { 'style': shinraUi.sectionStyle() }, [
		shinraUi.sectionTitle(_('模板同步')),
		shinraUi.sectionDescription(_('设置远程 JSON 模板地址，并同步到 /etc/shinra/main-profile.json。同步会校验模板，并在替换前创建备份。')),
		E('label', {}, [
			shinraUi.fieldLabel(_('模板地址')),
			E('input', {
				'id': 'shinra-profile-source-url',
				'class': 'cbi-input-text',
				'style': 'width: 100%; max-width: 100%; box-sizing: border-box;',
				'placeholder': DEFAULT_TEMPLATE_URL,
				'value': sourceInputUrl()
			})
		]),
		E('label', { 'style': 'display: block; margin-top: .6rem;' }, [
			shinraUi.fieldLabel(_('下载策略')),
			E('select', { 'id': 'shinra-profile-fetch-strategy', 'class': 'cbi-input-select', 'style': 'min-width: 220px;' }, [
				E('option', { 'value': 'direct', 'selected': sourceFetchStrategy() === 'direct' ? 'selected' : null }, _('直连')),
				E('option', { 'value': 'proxy', 'selected': sourceFetchStrategy() === 'proxy' ? 'selected' : null }, _('代理'))
			])
		]),
		shinraUi.actionRow([
			E('button', { 'type': 'button', 'class': shinraMotion.buttonClass('btn cbi-button cbi-button-save'), 'click': function(ev) { ev.preventDefault(); return saveSource(); } }, _('保存模板源')),
			E('button', { 'type': 'button', 'class': shinraMotion.buttonClass('btn cbi-button cbi-button-apply'), 'click': function(ev) { ev.preventDefault(); return syncRemote(); } }, _('同步模板'))
		]),
		actionStatusBox()
	]);
}

function localActions() {
	return E('div', { 'style': shinraUi.sectionStyle() }, [
		shinraUi.sectionTitle(_('本地恢复')),
		shinraUi.sectionDescription(_('这些操作只修改 main-profile.json 及其备份，不会生成候选配置、应用运行配置或重启 sing-box。')),
		E('div', { 'style': 'display: flex; gap: .5rem; flex-wrap: wrap; margin-top: 0;' }, [
			E('button', { 'type': 'button', 'class': shinraMotion.buttonClass('btn cbi-button cbi-button-neutral'), 'click': function(ev) { ev.preventDefault(); return rollbackProfile(); } }, _('回滚')),
			E('button', { 'type': 'button', 'class': shinraMotion.buttonClass('btn cbi-button cbi-button-remove'), 'click': function(ev) { ev.preventDefault(); return restoreDefault(); } }, _('恢复内置模板'))
		])
	]);
}

function profilePreview() {
	const content = profileContent(profileResult);
	const valid = profileResult && profileResult.ok && dataOf(profileResult).valid !== false;

	return E('div', { 'style': shinraUi.sectionStyle() }, [
		E('div', { 'style': 'display: flex; justify-content: space-between; gap: .75rem; align-items: center; flex-wrap: wrap; margin-bottom: .6rem;' }, [
			E('h3', { 'style': 'margin: 0;' }, _('只读预览')),
			valid ? shinraUi.pill(_('有效'), 'ok') : shinraUi.pill(_('无效'), 'error')
		]),
		E('pre', {
			'style': 'max-height: 36rem; overflow: auto; padding: .85rem; margin: 0; border-radius: 8px; background: #0f172a; color: #e5e7eb; font-family: monospace; white-space: pre;'
		}, content || _('没有模板内容。'))
	]);
}

function redraw() {
	const root = document.getElementById('shinra-profile-root');
	if (root)
		root.parentNode.replaceChild(renderPage(), root);
}

function renderPage() {
	shinraMotion.inject();

	return E('div', { 'id': 'shinra-profile-root', 'class': 'cbi-map' }, [
		shinraUi.pageHeader(
			_('模板'),
			_('只读预览 main-profile.json，并支持远程模板同步。')
		),
		sourceSettings(),
		localActions(),
		profilePreview()
	]);
}

return view.extend({
	load: function() {
		return Promise.all([
			callProfileGet(),
			callProfileSourceGet()
		]);
	},

	render: function(results) {
		profileResult = results && results[0] ? results[0] : {};
		sourceResult = results && results[1] ? results[1] : {};

		return renderPage();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
