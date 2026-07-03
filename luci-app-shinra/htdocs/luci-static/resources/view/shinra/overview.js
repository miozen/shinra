'use strict';
'require view';
'require rpc';
'require shinra.time as shinraTime';

const callRuntimeStatus = rpc.declare({
	object: 'shinra',
	method: 'runtime_status',
	expect: { '': {} }
});

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

const callSubscriptionsGet = rpc.declare({
	object: 'shinra',
	method: 'subscriptions_get',
	expect: { '': {} }
});

const callNodeSnapshotSummary = rpc.declare({
	object: 'shinra',
	method: 'node_snapshot_summary',
	expect: { '': {} }
});

const callRulesetRequiredInventory = rpc.declare({
	object: 'shinra',
	method: 'ruleset_required_inventory',
	expect: { '': {} }
});

const callRulesetPolicyGet = rpc.declare({
	object: 'shinra',
	method: 'ruleset_policy_get',
	expect: { '': {} }
});

const callDashboardStatus = rpc.declare({
	object: 'shinra',
	method: 'dashboard_status',
	expect: { '': {} }
});

const callApiStatus = rpc.declare({
	object: 'shinra',
	method: 'api_status',
	expect: { '': {} }
});

const callNotifySettingsGet = rpc.declare({
	object: 'shinra',
	method: 'notify_settings_get',
	expect: { '': {} }
});

const callAutoTaskStatusGet = rpc.declare({
	object: 'shinra',
	method: 'auto_task_status_get',
	expect: { '': {} }
});

const callSubscriptionsRefreshStatus = rpc.declare({
	object: 'shinra',
	method: 'subscriptions_refresh_status',
	expect: { '': {} }
});

const callRulesetDownloadRequiredStatus = rpc.declare({
	object: 'shinra',
	method: 'ruleset_download_required_status',
	expect: { '': {} }
});

const callGenerate = rpc.declare({
	object: 'shinra',
	method: 'config_generate',
	expect: { '': {} }
});

const callCheck = rpc.declare({
	object: 'shinra',
	method: 'config_check_candidate',
	expect: { '': {} }
});

const callApply = rpc.declare({
	object: 'shinra',
	method: 'config_apply',
	expect: { '': {} }
});

const callStop = rpc.declare({
	object: 'shinra',
	method: 'runtime_stop',
	expect: { '': {} }
});

const callRestart = rpc.declare({
	object: 'shinra',
	method: 'runtime_restart',
	expect: { '': {} }
});

const callRollback = rpc.declare({
	object: 'shinra',
	method: 'config_rollback',
	expect: { '': {} }
});

let pageResults = {};
let actionStatus = '';
let actionStatusOk = true;

function dataOf(result) {
	if (result && result.ok && result.data)
		return result.data;
	return {};
}

function stateOf() {
	const data = dataOf(pageResults.runtime);
	return data.state || {};
}

function safeJson(text) {
	try {
		return JSON.parse(text || '{}');
	} catch (e) {
		return {};
	}
}

function valueText(value) {
	if (value == null || value === '')
		return '-';
	return String(value);
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

function sectionDescription(text) {
	return E('div', { 'style': mutedStyle() + ' margin: 0 0 .6rem;' }, text);
}

function cardStyle(accent) {
	return 'border: 1px solid #dfe3e8; border-left: 4px solid %s; border-radius: 8px; padding: .65rem .75rem; background: #fff; box-sizing: border-box; min-height: 76px;'.format(accent || '#64748b');
}

function card(title, value, detail, accent) {
	return E('div', { 'style': cardStyle(accent) }, [
		E('div', { 'style': 'font-size: 11px; color: #667; text-transform: uppercase; letter-spacing: .04em;' }, title),
		E('div', { 'style': 'font-size: 19px; font-weight: 700; margin-top: .2rem; line-height: 1.15; overflow-wrap: anywhere;' }, valueText(value)),
		E('div', { 'style': 'margin-top: .35rem; color: #667; font-size: 12px; line-height: 1.3; overflow-wrap: anywhere;' }, valueText(detail))
	]);
}

function statusTone(ok, warning) {
	if (ok)
		return '#16a34a';
	if (warning)
		return '#ea580c';
	return '#dc2626';
}

function statusWord(status) {
	if (status === 'success')
		return _('成功');
	if (status === 'partial')
		return _('部分成功');
	if (status === 'fail')
		return _('失败');
	if (status === 'failed')
		return _('失败');
	if (status === 'running')
		return _('运行中');
	if (status === 'starting')
		return _('启动中');
	if (status === 'idle')
		return _('空闲');
	if (status)
		return status;
	return '-';
}

function compactMessage(text) {
	text = valueText(text);
	text = text.replace(/Required Rule Sets downloaded/g, '所需规则集已同步');
	text = text.replace(/Rule Set sync running/g, '规则集正在同步');
	text = text.replace(/Rule Set sync queued/g, '规则集同步已排队');
	text = text.replace(/Rule Set sync job started/g, '规则集同步任务已启动');
	text = text.replace(/Rule Set sync job is already running/g, '规则集同步任务正在运行');
	text = text.replace(/Rule Set sync success/g, '规则集同步成功');
	text = text.replace(/Rule Set sync partial/g, '规则集部分同步成功');
	text = text.replace(/Rule Set sync fail/g, '规则集同步失败');
	text = text.replace(/Required:/g, '需要:');
	text = text.replace(/Updated:/g, '已更新:');
	text = text.replace(/Unchanged:/g, '未变化:');
	text = text.replace(/Failed:/g, '失败:');
	text = text.replace(/Detail:/g, '详情:');
	text = text.replace(/\n/g, ' | ');
	return text;
}

function autoJobText(job, disabledText, waitingText) {
	job = job || {};
	if (job.last_status)
		return _('%s 于 %s').format(statusWord(job.last_status), shinraTime.formatMaybeTime(job.last_run_at));
	if (job.enabled)
		return waitingText || _('自动任务等待中');
	return disabledText || _('自动任务已停用');
}

function schedulerTaskText(schedulerTask, task, disabledText, waitingText) {
	schedulerTask = schedulerTask || {};
	task = task || {};
	if (task.status && task.status !== 'idle')
		return _('%s 于 %s').format(statusWord(task.status), shinraTime.formatMaybeTime(task.finished_at || task.started_at));
	if (schedulerTask.last_trigger_result && schedulerTask.last_trigger_result !== 'waiting')
		return _('%s 于 %s').format(schedulerTask.last_trigger_result, shinraTime.formatMaybeTime(schedulerTask.last_run_at));
	if (schedulerTask.enabled)
		return waitingText || _('自动任务等待中');
	return disabledText || _('自动任务已停用');
}

function autoApplySummary(task) {
	const meta = task && task.meta || {};
	const autoApply = meta.auto_apply || {};
	if (autoApply.attempted !== true)
		return '';
	if (autoApply.ok === true && autoApply.stage === 'stable_success')
		return _('自动应用：sing-box 运行正常');
	if (autoApply.stage === 'rollback_success')
		return _('自动应用：已回滚，sing-box 运行正常');
	if (autoApply.stage === 'rollback_degraded')
		return _('自动应用：异常，请检查');
	if (autoApply.ok === false)
		return _('自动应用：失败，请检查');
	return '';
}

function schedulerWarning(scheduler, enabled) {
	scheduler = scheduler || {};
	if (!enabled)
		return '';
	if (scheduler.healthy)
		return '';
	if (!scheduler.script_exists)
		return _('自动任务脚本缺失');
	if (!scheduler.script_executable)
		return _('自动任务脚本不可执行');
	if (!scheduler.cron_installed)
		return _('系统计划任务未安装');
	if (!scheduler.cron_running)
		return _('cron 未运行');
	return _('自动任务调度器异常');
}

function schedulerPlanText(enabled, hour) {
	if (!enabled)
		return _('自动任务已停用');
	if (hour == null || hour === '')
		return _('已启用，等待调度');
	hour = Number(hour);
	if (!Number.isFinite(hour))
		return _('已启用，等待调度');
	return _('每日 %s:05 检查执行').format(hour < 10 ? '0' + hour : String(hour));
}

function actionLink(label, path, primary) {
	return E('a', {
		'class': 'btn cbi-button %s'.format(primary ? 'cbi-button-apply' : 'cbi-button-neutral'),
		'href': L.url(path),
		'style': 'margin-right: .5rem; margin-bottom: .5rem; color: #fff !important; text-decoration: none;'
	}, label);
}

function operationButton(label, actionLabel, rpcCall, buttonClass, confirmText) {
	return E('button', {
		'class': 'btn cbi-button %s'.format(buttonClass || 'cbi-button-neutral'),
		'style': 'min-width: 5.5rem; padding-left: 1rem; padding-right: 1rem;',
		'click': function(ev) {
			ev.preventDefault();
			return runAction(actionLabel, rpcCall, confirmText);
		}
	}, label);
}

function setActionStatus(text, ok) {
	actionStatus = text || '';
	actionStatusOk = ok !== false;
	const node = document.getElementById('shinra-overview-action-status');
	if (!node)
		return;

	node.textContent = actionStatus;
	node.style.display = actionStatus ? 'block' : 'none';
	node.style.borderColor = actionStatusOk ? '#bbf7d0' : '#fecaca';
	node.style.background = actionStatusOk ? '#f0fdf4' : '#fef2f2';
	node.style.color = actionStatusOk ? '#166534' : '#991b1b';
}

function resultError(result, fallback) {
	if (result && (result.message || result.code))
		return '%s: %s'.format(result.message || result.code || fallback || _('操作失败'), result.detail || result.code || _('无详细信息'));
	return fallback || _('操作失败');
}

function pageLoadError() {
	const failures = [
		pageResults.runtime,
		pageResults.profile,
		pageResults.subscriptions,
		pageResults.snapshot,
		pageResults.rules,
		pageResults.panel,
		pageResults.apiStatus,
		pageResults.profileSource,
		pageResults.rulesPolicy,
		pageResults.notify,
		pageResults.autoTask,
		pageResults.subscriptionTask,
		pageResults.rulesetTask
	].filter(function(result) {
		return result && !result.ok;
	});

	if (!failures.length)
		return '';

	return failures.map(function(result) {
		return resultError(result, _('加载失败'));
	}).join(' | ');
}

function runAction(label, rpcCall, confirmText) {
	if (confirmText && !window.confirm(confirmText))
		return Promise.resolve();

	setActionStatus(_('%s 正在执行...').format(label), true);

	return rpcCall().then(function(result) {
		if (result && result.ok) {
			setActionStatus(_('%s 已完成。').format(label), true);
			return refreshPage();
		}
		setActionStatus(resultError(result, _('%s 失败').format(label)), false);
		return result;
	}).catch(function(error) {
		setActionStatus(error.message || String(error), false);
	});
}

function refreshPage() {
	return loadAll().then(function(results) {
		pageResults = results;
		redraw();
		return results;
	});
}

function loadAll() {
	return Promise.all([
		callRuntimeStatus().catch(function(e) { return { ok: false, message: _('Runtime 状态加载失败'), detail: e.message || String(e) }; }),
		callProfileGet().catch(function(e) { return { ok: false, message: _('模板加载失败'), detail: e.message || String(e) }; }),
		callSubscriptionsGet().catch(function(e) { return { ok: false, message: _('订阅加载失败'), detail: e.message || String(e) }; }),
		callNodeSnapshotSummary().catch(function(e) { return { ok: false, message: _('节点快照摘要加载失败'), detail: e.message || String(e) }; }),
		callRulesetRequiredInventory().catch(function(e) { return { ok: false, message: _('规则集清单加载失败'), detail: e.message || String(e) }; }),
		callDashboardStatus().catch(function(e) { return { ok: false, message: _('面板状态加载失败'), detail: e.message || String(e) }; }),
		callApiStatus().catch(function(e) { return { ok: false, message: _('API 状态加载失败'), detail: e.message || String(e) }; }),
		callProfileSourceGet().catch(function(e) { return { ok: false, message: _('模板源加载失败'), detail: e.message || String(e) }; }),
		callRulesetPolicyGet().catch(function(e) { return { ok: false, message: _('规则集策略加载失败'), detail: e.message || String(e) }; }),
		callNotifySettingsGet().catch(function(e) { return { ok: false, message: _('通知设置加载失败'), detail: e.message || String(e) }; }),
		callAutoTaskStatusGet().catch(function(e) { return { ok: false, message: _('自动任务状态加载失败'), detail: e.message || String(e) }; }),
		callSubscriptionsRefreshStatus().catch(function(e) { return { ok: false, message: _('订阅刷新任务状态加载失败'), detail: e.message || String(e) }; }),
		callRulesetDownloadRequiredStatus().catch(function(e) { return { ok: false, message: _('规则集任务状态加载失败'), detail: e.message || String(e) }; })
	]).then(function(results) {
		return {
			runtime: results[0],
			profile: results[1],
			subscriptions: results[2],
			snapshot: results[3],
			rules: results[4],
			panel: results[5],
			apiStatus: results[6],
			profileSource: results[7],
			rulesPolicy: results[8],
			notify: results[9],
			autoTask: results[10],
			subscriptionTask: results[11],
			rulesetTask: results[12]
		};
	});
}

function runtimeCards() {
	const state = stateOf();
	const status = dataOf(pageResults.apiStatus);
	const official = status.official_api || {};
	const clash = status.clash_api || {};
	const running = !!state.sing_box_running;
	const tun = !!state.tun_exists;
	const config = !!state.runtime_config_exists;
	const officialObserved = official.available != null || official.configured != null;
	const clashObserved = clash.available != null || clash.configured != null;
	const apiObserved = officialObserved || clashObserved;
	const officialOk = official.available === true;
	const clashOk = clash.available === true;
	let apiValue = _('未观测');
	let apiAccent = '#64748b';

	if (apiObserved) {
		if (officialOk && clashOk) {
			apiValue = _('全部可用');
			apiAccent = '#16a34a';
		} else if (officialOk || clashOk) {
			apiValue = _('部分可用');
			apiAccent = '#ea580c';
		} else {
			apiValue = _('不可用');
			apiAccent = '#dc2626';
		}
	}

	return E('div', { 'style': 'display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: .65rem;' }, [
		card(_('运行时'), running ? _('运行中') : _('已停止'), running ? _('sing-box 服务运行中') : _('服务已停止'), statusTone(running)),
		card(_('TUN'), tun ? _('存在') : _('缺失'), state.tun_name || '-', statusTone(tun, running)),
		card(_('配置'), config ? _('就绪') : _('缺失'), state.runtime_config_hash ? _('已观测到运行配置哈希') : _('运行配置缺失'), statusTone(config)),
		card(_('API'), apiValue, _('Official API: %s | Clash API: %s').format(officialObserved ? (officialOk ? _('可用') : _('不可用')) : '-', clashObserved ? (clashOk ? _('可用') : _('不可用')) : '-'), apiAccent)
	]);
}

function resourceCards() {
	const profile = dataOf(pageResults.profile);
	const subscriptions = safeJson(dataOf(pageResults.subscriptions).content || '{}');
	const snapshot = dataOf(pageResults.snapshot);
	const rules = dataOf(pageResults.rules).summary || {};
	const panel = dataOf(pageResults.panel);
	const panelSource = panel.source || {};
	const panelDashboard = panel.dashboard || panelSource.dashboard || {};
	const profileSource = dataOf(pageResults.profileSource).source || {};
	const rulesPolicy = dataOf(pageResults.rulesPolicy).policy || {};
	const notifyData = dataOf(pageResults.notify);
	const notifySettings = notifyData.settings || {};
	const notifyTelegram = notifySettings.telegram || {};
	const notifyState = notifyData.state || {};
	const autoTaskData = dataOf(pageResults.autoTask);
	const autoTask = autoTaskData.state || {};
	const scheduler = autoTaskData.scheduler || {};
	const schedulerTasks = autoTask.tasks || {};
	const subSchedulerTask = schedulerTasks['subscription.refresh'] || {};
	const rulesSchedulerTask = schedulerTasks['ruleset.sync'] || {};
	const subTask = dataOf(pageResults.subscriptionTask).task || {};
	const rulesTask = dataOf(pageResults.rulesetTask).task || {};
	const sourceCount = Array.isArray(subscriptions.sources) ? subscriptions.sources.length : 0;
	const nodeCount = Number(snapshot.node_count || 0);
	const missingRules = Number(rules.missing_count || 0);
	const requiredRules = Number(rules.required_count || 0);
	const readyRules = Number(rules.ready_count || 0);
	const extraRules = Number(rules.local_extra_count || 0);
	const profileOk = pageResults.profile && pageResults.profile.ok && profile.valid !== false;
	const profileSyncTime = profileSource.updated_at ? shinraTime.formatMaybeTime(profileSource.updated_at) : _('未记录');
	const profileSourceText = profileSource.url ? _('已配置远程源') : _('未配置远程源');
	const snapshotTime = snapshot.updated_at ? shinraTime.formatMaybeTime(snapshot.updated_at) : _('未刷新');
	const subUpdate = subscriptions.subscription_update || {};
	const subScheduleWarning = schedulerWarning(scheduler, subUpdate.auto_update === true);
	const subAutoText = subScheduleWarning || schedulerTaskText(subSchedulerTask, subTask, _('自动刷新已停用'), schedulerPlanText(true, subUpdate.update_hour));
	const rulesTimeRaw = rulesTask.finished_at || rulesTask.started_at || rulesSchedulerTask.last_run_at || '';
	const rulesTime = rulesTimeRaw ? shinraTime.formatMaybeTime(rulesTimeRaw) : _('未同步');
	const rulesScheduleWarning = schedulerWarning(scheduler, rulesPolicy.auto_update === true);
	const rulesResultText = rulesScheduleWarning || compactMessage(schedulerTaskText(rulesSchedulerTask, rulesTask, _('自动同步已停用'), schedulerPlanText(true, rulesPolicy.update_hour)));
	const rulesMode = rulesPolicy.mode || '-';
	const rulesAutoApplyText = autoApplySummary(rulesTask);
	const rulesDetailText = _('上次同步：%s | 需要 %d / 已就绪 %d / 缺失 %d / 本地多余 %d | %s | %s%s').format(
		rulesTime,
		requiredRules,
		readyRules,
		missingRules,
		extraRules,
		rulesMode,
		rulesResultText,
		rulesAutoApplyText ? ' | ' + rulesAutoApplyText : ''
	);
	const panelReady = panelSource.enabled == true && panelDashboard.enabled == true;
	const panelDetail = _('%s | %s').format(panel.dashboard_url || '-', panelDashboard.path || '-');
	const notifyEnabled = notifyTelegram.enabled == true;
	const notifyStatus = notifyState.last_status || (notifyEnabled ? _('等待中') : _('已停用'));
	const notifyResult = notifyState.last_attempt_at ? _('%s 于 %s').format(notifyState.last_sent ? _('已发送') : _('未发送'), shinraTime.formatMaybeTime(notifyState.last_attempt_at)) : (notifyEnabled ? _('未记录发送尝试') : _('Telegram 已停用'));
	let notifyAccent = '#64748b';
	if (notifyEnabled)
		notifyAccent = statusTone(notifyState.last_sent == true, !notifyState.last_attempt_at);

	return E('div', { 'style': 'display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: .65rem;' }, [
		card(_('模板'), profileOk ? _('就绪') : _('错误'), _('上次同步：%s | %s').format(profileSyncTime, profileSourceText), statusTone(profileOk)),
		card(_('订阅'), nodeCount ? _('%d 个节点').format(nodeCount) : _('无节点'), _('上次刷新：%s | %s').format(snapshotTime, subAutoText), subScheduleWarning ? '#ea580c' : statusTone(sourceCount > 0 && nodeCount > 0, sourceCount > 0)),
		card(_('规则集'), missingRules === 0 ? _('就绪') : _('需要处理'), rulesDetailText, rulesScheduleWarning ? '#ea580c' : statusTone(missingRules === 0 && requiredRules > 0, requiredRules > 0)),
		card(_('面板'), panelReady ? _('已启用') : _('未启用'), panelDetail, statusTone(panelReady)),
		card(_('Telegram'), notifyEnabled ? _('已启用') : _('已停用'), _('最近结果：%s | %s').format(notifyStatus, notifyResult), notifyAccent)
	]);
}

function runtimeStatusSection() {
	return E('div', { 'style': sectionStyle() }, [
		sectionTitle(_('运行时状态')),
		runtimeCards()
	]);
}

function resourceStatusSection() {
	return E('div', { 'style': sectionStyle() }, [
		sectionTitle(_('资源就绪状态')),
		resourceCards()
	]);
}

function operationButtons() {
	return E('div', { 'style': sectionStyle() }, [
		sectionTitle(_('运行时操作')),
		sectionDescription(_('资源准备完成后，在这里执行生成、检查、应用和回滚。策略组切换和延迟测速交给 Dashboard。')),
		E('div', {
			'id': 'shinra-overview-action-status',
			'style': 'display: %s; border: 1px solid %s; border-radius: 8px; padding: .75rem; margin-bottom: .75rem; background: %s; color: %s;'.format(
				actionStatus ? 'block' : 'none',
				actionStatusOk ? '#bbf7d0' : '#fecaca',
				actionStatusOk ? '#f0fdf4' : '#fef2f2',
				actionStatusOk ? '#166534' : '#991b1b'
			)
		}, actionStatus),
		E('div', { 'style': 'display: flex; flex-wrap: wrap; gap: .5rem;' }, [
			operationButton(_('生成'), _('生成候选配置'), callGenerate),
			operationButton(_('检查'), _('检查候选配置'), callCheck),
			operationButton(_('应用'), _('应用运行配置'), callApply, 'cbi-button-apply', _('现在将候选配置应用到运行时吗？')),
			operationButton(_('重启'), _('重启运行时'), callRestart, 'cbi-button-neutral', _('现在重启 Shinra 运行时吗？短时间内流量可能会中断。')),
			operationButton(_('停止'), _('停止运行时'), callStop, 'cbi-button-reset', _('现在停止 Shinra 运行时吗？流量将不再由 sing-box 接管。')),
			operationButton(_('回滚'), _('回滚运行配置'), callRollback, 'cbi-button-reset', _('现在回滚运行配置吗？'))
		])
	]);
}

function entryLinks() {
	return E('div', { 'style': sectionStyle() }, [
		sectionTitle(_('快捷入口')),
		E('div', { 'style': 'display: flex; flex-wrap: wrap;' }, [
			actionLink(_('打开面板'), 'admin/services/shinra/panel', true),
			actionLink(_('管理资源'), 'admin/services/shinra/resources'),
			actionLink(_('网络诊断'), 'admin/services/shinra/diagnostics')
		])
	]);
}

function renderPage() {
	const loadError = pageLoadError();

	return E('div', { 'id': 'shinra-overview-root', 'class': 'cbi-map' }, [
		pageHeader(_('Shinra'), _('概览是控制面首页。运行时策略组交互由 Dashboard 处理。')),
		loadError ? E('div', { 'style': 'border: 1px solid #fecaca; border-radius: 8px; padding: .65rem; margin: 0 0 .75rem; background: #fef2f2; color: #991b1b;' }, loadError) : '',
		runtimeStatusSection(),
		resourceStatusSection(),
		operationButtons(),
		entryLinks()
	]);
}

function redraw() {
	const root = document.getElementById('shinra-overview-root');
	if (root)
		root.parentNode.replaceChild(renderPage(), root);
}

return view.extend({
	load: function() {
		return loadAll();
	},

	render: function(results) {
		pageResults = results || {};
		return renderPage();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
