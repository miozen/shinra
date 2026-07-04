/**
 * Shinra | notify.uc | v1.0
 */

'use strict';

import { Success, Fail } from 'shinra.core.result';
import { ERR } from 'shinra.core.error';
import { PATH } from 'shinra.core.constants';
import { read_optional_text, write_text_atomic, write_runtime_text_atomic, parse_json_object, request_content, request_keys, json_escape, json_stringify, ExecResult } from 'shinra.core.utils';
import { fetch_text } from 'shinra.resource_fetch';
import { validate_fetch_strategy } from 'shinra.subscription_policy';

const TELEGRAM_MAX_TEXT = 3900;

function default_notify_settings() {
	return {
		schema_version: 1,
		telegram: {
			enabled: false,
			mode: "fail_only",
			bot_token: "",
			chat_id: "",
			location_name: "Shinra",
			fetch_strategy: "proxy",
			timeout_sec: 15
		}
	};
}

function trim_text(value) {
	let text = "" + value;
	text = replace(text, "\r", "");
	text = replace(text, "\n", "");
	return text;
}

function normalize_mode(value) {
	if (value == "all")
		return "all";
	return "fail_only";
}

function normalize_timeout(value) {
	let n = int(value || 15);
	if (n < 5)
		return 5;
	if (n > 60)
		return 60;
	return n;
}

function normalize_notify_settings(raw) {
	if (type(raw) != "object" || raw == null || type(raw) == "array")
		die("Notify settings root must be a JSON object");

	let defaults = default_notify_settings();
	let source = type(raw.telegram) == "object" && raw.telegram != null && type(raw.telegram) != "array" ? raw.telegram : {};

	let result = {
		schema_version: 1,
		telegram: {
			enabled: source.enabled == true,
			mode: normalize_mode(source.mode),
			bot_token: type(source.bot_token) == "string" ? trim_text(source.bot_token) : defaults.telegram.bot_token,
			chat_id: type(source.chat_id) == "string" ? trim_text(source.chat_id) : defaults.telegram.chat_id,
			location_name: type(source.location_name) == "string" && source.location_name != "" ? source.location_name : defaults.telegram.location_name,
			fetch_strategy: type(source.fetch_strategy) == "string" && source.fetch_strategy != "" ? source.fetch_strategy : defaults.telegram.fetch_strategy,
			timeout_sec: normalize_timeout(source.timeout_sec)
		}
	};
	validate_fetch_strategy(result.telegram.fetch_strategy, "telegram.fetch_strategy");
	return result;
}

function read_notify_settings() {
	let content = read_optional_text(PATH.NOTIFY);
	if (!length(content))
		return default_notify_settings();
	return normalize_notify_settings(parse_json_object(content, "Notify Settings"));
}

function notify_settings_content(settings) {
	return json_stringify(normalize_notify_settings(settings)) + "\n";
}

function default_notify_state() {
	return {
		schema_version: 1,
		last_attempt_at: "",
		last_task_type: "",
		last_status: "",
		last_message: "",
		last_sent: false,
		last_reason: ""
	};
}

function now_utc(trace_id) {
	let result = ExecResult(trace_id, [ "date", "-u", "+%Y-%m-%dT%H:%M:%SZ" ]);
	if (result.code == 0)
		return trim_text(result.stdout || "");
	return "";
}

function normalize_notify_state(raw) {
	raw = type(raw) == "object" && raw != null && type(raw) != "array" ? raw : {};

	return {
		schema_version: 1,
		last_attempt_at: type(raw.last_attempt_at) == "string" ? raw.last_attempt_at : "",
		last_task_type: type(raw.last_task_type) == "string" ? raw.last_task_type : "",
		last_status: type(raw.last_status) == "string" ? raw.last_status : "",
		last_message: type(raw.last_message) == "string" ? raw.last_message : "",
		last_sent: raw.last_sent == true,
		last_reason: type(raw.last_reason) == "string" ? raw.last_reason : ""
	};
}

function read_notify_state() {
	try {
		let content = read_optional_text(PATH.NOTIFY_STATE);
		if (!length(content))
			return default_notify_state();
		return normalize_notify_state(parse_json_object(content, "Notify State"));
	} catch (e) {
		return default_notify_state();
	}
}

function write_notify_state(trace_id, task_type, status, message, sent, reason) {
	let state = {
		schema_version: 1,
		last_attempt_at: now_utc(trace_id),
		last_task_type: task_type || "",
		last_status: status || "",
		last_message: message || "",
		last_sent: sent == true,
		last_reason: reason || ""
	};
	write_runtime_text_atomic(PATH.NOTIFY_STATE, json_stringify(normalize_notify_state(state)) + "\n");
}

function plain_text(value) {
	let text = "" + value;
	text = replace(text, "<br>", "\n");
	text = replace(text, "<br/>", "\n");
	text = replace(text, "<br />", "\n");
	text = replace(text, "%0A", "\n");
	return text;
}

function truncate_text(value) {
	let text = plain_text(value);
	if (length(text) <= TELEGRAM_MAX_TEXT)
		return text;
	return substr(text, 0, TELEGRAM_MAX_TEXT - 80) + "\n...[message truncated]";
}

function redact_token(text, token) {
	let safe = "" + text;
	if (length(token))
		safe = replace(safe, token, "<redacted>");
	return safe;
}

function token_without_bot_prefix(token) {
	if (index(token, "bot") == 0)
		return substr(token, 3);
	return token;
}

function should_send(settings, status, force) {
	if (force)
		return true;
	if (!settings.telegram.enabled)
		return false;
	if (status == "success" && settings.telegram.mode == "fail_only")
		return false;
	return true;
}

function task_title(settings, task_type, status) {
	let name = settings.telegram.location_name || "Shinra";
	let task = "任务通知";
	if (task_type == "subscriptions_refresh" || task_type == "subscription.refresh")
		task = "订阅管理";
	else if (task_type == "ruleset_download_required" || task_type == "ruleset.sync")
		task = "规则集管理";
	else if (task_type == "telegram_test")
		task = "Telegram 测试";

	return "[" + name + "] " + task;
}

function send_telegram_with_settings(trace_id, settings, task_type, status, message, force) {
	let token = token_without_bot_prefix(settings.telegram.bot_token || "");
	let chat_id = settings.telegram.chat_id || "";
	let strategy = settings.telegram.fetch_strategy == "direct" ? "direct" : "proxy";

	if (!should_send(settings, status, force)) {
		write_notify_state(trace_id, task_type, status, message, false, "disabled or fail_only mode active");
		return Success({ sent: false, reason: "disabled or fail_only mode active", fetch_strategy: strategy }, 200, trace_id, "Telegram notification skipped");
	}
	if (!length(token) || !length(chat_id)) {
		write_notify_state(trace_id, task_type, status, message, false, "missing credentials");
		return Success({ sent: false, reason: "missing credentials", fetch_strategy: strategy }, 200, trace_id, "Telegram notification skipped");
	}

	let text = truncate_text(task_title(settings, task_type, status) + "\n" + message);
	let url = "https://api.telegram.org/bot" + token + "/sendMessage";
	let payload = "{" +
		"\"chat_id\":\"" + json_escape(chat_id) + "\"," +
		"\"text\":\"" + json_escape(text) + "\"," +
		"\"disable_web_page_preview\":true" +
	"}";

	let result = fetch_text(trace_id, url, strategy, {
		timeout_sec: settings.telegram.timeout_sec,
		min_bytes: 1,
		method: "POST",
		post_data: payload,
		headers: [ "Content-Type: application/json" ]
	});

	if (!result.ok) {
		let detail = redact_token(result.stderr || result.body || "Telegram request failed", token);
		write_notify_state(trace_id, task_type, status, message, false, detail);
		return Fail(ERR.E_NOTIFY_SEND_FAILED, "Telegram API request failed", trace_id, detail);
	}

	let body = parse_json_object(result.body || "{}", "Telegram API response");
	if (body.ok == true) {
		write_notify_state(trace_id, task_type, status, message, true, "");
		return Success({ sent: true, fetch_strategy: strategy }, 200, trace_id, "Telegram notification sent");
	}

	write_notify_state(trace_id, task_type, status, message, false, redact_token(result.body || "", token));
	return Fail(ERR.E_NOTIFY_SEND_FAILED, "Telegram API response rejected", trace_id, redact_token(result.body || "", token));
}

function send_telegram(trace_id, task_type, status, message) {
	try {
		let settings = read_notify_settings();
		return send_telegram_with_settings(trace_id, settings, task_type, status, message, false);
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_NOTIFY_SEND_FAILED, "Telegram notification crashed", trace_id, err);
	}
}

function result_data(result) {
	if (result && type(result.data) == "object" && result.data != null && type(result.data) != "array")
		return result.data;
	return {};
}

function object_field(obj, key) {
	if (type(obj) == "object" && obj != null && type(obj[key]) == "object" && obj[key] != null && type(obj[key]) != "array")
		return obj[key];
	return {};
}

function string_field(obj, key, fallback) {
	if (type(obj) == "object" && obj != null && type(obj[key]) == "string")
		return obj[key];
	return fallback || "";
}

function int_field(obj, key) {
	if (type(obj) == "object" && obj != null && obj[key] != null)
		return int(obj[key]);
	return 0;
}

function divider() {
	return "━━━━━━━━━━━━━━━━━━";
}

function append_limited_line(lines, text, max_items) {
	if (length(lines) < max_items) {
		push(lines, text);
		return;
	}
	if (length(lines) == max_items)
		push(lines, "🔹 ...另有 1 项已折叠");
	else
		lines[length(lines) - 1] = "🔹 ...另有 " + (length(lines) - max_items + 1) + " 项已折叠";
}

function append_section(message, title, lines) {
	if (!length(lines))
		return message;

	message = message + "\n\n" + title + ":";
	for (let line in lines)
		message = message + "\n" + line;
	return message;
}

function source_display_name(source) {
	if (type(source.name) == "string" && source.name != "")
		return source.name;
	if (type(source.id) == "string" && source.id != "")
		return source.id;
	return "未命名订阅";
}

function source_error_text(source) {
	if (type(source.error) != "string" || source.error == "")
		return "";

	let error = plain_text(source.error);
	if (length(error) > 180)
		error = substr(error, 0, 177) + "...";
	return error;
}

function source_error_reason(source, fallback) {
	let error = source_error_text(source);
	if (error != "")
		return error;
	return fallback || "未知原因";
}

function source_line(source, icon, with_error, removed) {
	let line = icon + " " + source_display_name(source);
	if (removed)
		return line;
	line = line + "：" + (source.node_count || 0) + " 个节点";
	if (with_error) {
		let status = type(source.status) == "string" && source.status != "" ? source.status : "";
		let fallback = index(status, "preserved_") == 0 ? "拉取失败，已沿用上次可用数据" : "更新失败";
		line = line + "，原因：" + source_error_reason(source, fallback);
	}
	return line;
}

function source_in_scope(source, data) {
	let target = type(data.target_source_id) == "string" ? data.target_source_id : "";
	if (target == "")
		return true;
	return type(source.id) == "string" && source.id == target;
}

function subscription_source_sections(data) {
	let sources = type(data.sources) == "array" ? data.sources : [];
	let updated = [];
	let preserved = [];
	let failed = [];
	let removed = [];

	for (let source in sources) {
		if (type(source) != "object" || source == null || type(source) == "array")
			continue;
		if (!source_in_scope(source, data))
			continue;

		let status = type(source.status) == "string" ? source.status : "";
		if (status == "updated") {
			append_limited_line(updated, source_line(source, "🔹", false, false), 20);
			continue;
		}
		if (status == "disabled_removed") {
			append_limited_line(removed, source_line(source, "🔹", false, true), 20);
			continue;
		}
		if (index(status, "preserved_") == 0) {
			append_limited_line(preserved, source_line(source, "🔹", true, false), 20);
			continue;
		}
		if (source.ok == false || status == "failed_no_previous") {
			append_limited_line(failed, source_line(source, "🔸", true, false), 20);
			continue;
		}
	}

	return {
		updated: updated,
		preserved: preserved,
		failed: failed,
		removed: removed
	};
}

function auto_apply_data(data) {
	if (type(data.auto_apply) == "object" && data.auto_apply != null && type(data.auto_apply) != "array")
		return data.auto_apply;
	return {};
}

function auto_apply_attempted(data) {
	let auto_apply = auto_apply_data(data);
	return auto_apply.attempted == true;
}

function auto_apply_status(auto_apply) {
	let stage = type(auto_apply.stage) == "string" ? auto_apply.stage : "";
	if (auto_apply.ok == true && stage == "stable_success")
		return "success";
	if (stage == "rollback_success")
		return "rolled_back";
	if (stage == "rollback_degraded")
		return "fail";
	if (auto_apply.ok == false || stage == "runtime_apply_failed" || stage == "candidate_check_failed" || stage == "candidate_generate_failed" || stage == "ruleset_confirm_failed")
		return "fail";
	return "";
}

function auto_apply_status_text(auto_apply, status) {
	if (status == "success")
		return "成功";
	if (status == "rolled_back")
		return "失败，已回滚";
	if (status == "fail")
		return "失败";
	if (auto_apply.attempted == true)
		return "已执行";
	return "未执行";
}

function auto_apply_stage_text(stage) {
	if (stage == "stable_success")
		return "稳定运行验证成功";
	if (stage == "rollback_success")
		return "回滚成功";
	if (stage == "rollback_degraded")
		return "回滚后仍异常";
	if (stage == "runtime_apply_failed")
		return "应用运行配置失败";
	if (stage == "candidate_check_failed")
		return "候选配置检查失败";
	if (stage == "candidate_generate_failed")
		return "候选配置生成失败";
	if (stage == "ruleset_confirm_failed")
		return "规则集变更确认失败";
	if (stage == "runtime_verify_timeout")
		return "运行稳定性验证超时";
	if (stage == "candidate_crashed")
		return "候选配置处理异常";
	if (stage == "decision")
		return "决策阶段";
	if (stage == "dry_run_ready")
		return "预检查通过";
	if (stage == "runtime_lock_busy")
		return "运行时锁被占用";
	if (stage == "runtime_backup_not_restored")
		return "运行配置备份未恢复";
	return stage || "-";
}

function auto_apply_detail_text(detail) {
	if (detail == "Candidate generated, checked, applied, and Runtime stability verification passed.")
		return "候选配置已生成并通过检查，已应用到运行时，且稳定性验证通过。";
	if (detail == "Runtime did not stay healthy for the required stability window.")
		return "运行时未在要求的稳定窗口内保持健康。";
	if (detail == "Runtime did not pass the stability window; rollback was attempted.")
		return "运行时未通过稳定性验证，已尝试回滚。";
	if (detail == "Auto-apply would start in a later phase.")
		return "自动应用将在后续阶段开始。";
	if (detail == "Auto-apply is limited to scheduled Rule Set updates.")
		return "自动应用仅用于定时规则集更新。";
	if (detail == "ruleset.auto_apply_after_update is false.")
		return "规则集更新后自动应用未启用。";
	if (detail == "Rule Set update has failed items.")
		return "规则集有失败项，跳过自动应用。";
	if (detail == "Rule Set update did not change any files.")
		return "规则集没有文件变化，无需自动应用。";
	if (detail == "Auto-apply only applies local Rule Set updates.")
		return "自动应用仅适用于本地规则集模式。";
	if (index(detail, "Auto-apply freeze window is busy: ") == 0)
		return "自动应用冻结窗口被占用：" + substr(detail, length("Auto-apply freeze window is busy: "));
	if (detail == "Runtime verification failed; rollback started.")
		return "运行时验证失败，已开始回滚。";
	if (detail == "Runtime apply completed; stability window verification started.")
		return "运行配置已应用，开始稳定性验证。";
	if (detail == "Applying checked candidate to Runtime.")
		return "正在将已检查的候选配置应用到运行时。";
	if (detail == "Checking candidate config.")
		return "正在检查候选配置。";
	if (detail == "Generating candidate config.")
		return "正在生成候选配置。";
	if (detail == "Auto-apply freeze window acquired.")
		return "已取得自动应用冻结窗口。";
	if (detail == "generate_candidate failed")
		return "生成候选配置失败。";
	if (detail == "check_candidate failed")
		return "检查候选配置失败。";
	if (detail == "config_apply failed")
		return "应用运行配置失败。";
	if (detail == "Rule Set transaction confirm failed")
		return "规则集变更确认失败。";
	return detail || "";
}

function auto_apply_message(auto_apply) {
	if (type(auto_apply) != "object" || auto_apply == null)
		return "";

	let stage = string_field(auto_apply, "stage", "-");
	let detail = string_field(auto_apply, "detail", "");
	let status = auto_apply_status(auto_apply);
	let message = "\n\n♻️ 自动应用：" + auto_apply_status_text(auto_apply, status);
	if (stage != "" && stage != "-")
		message = message + "\n📍 执行阶段：" + auto_apply_stage_text(stage);
	if (detail != "")
		message = message + "\n🧾 详情：" + auto_apply_detail_text(detail);

	let runtime_verify = object_field(auto_apply, "runtime_verify");
	if (runtime_verify.ok != null || int_field(runtime_verify, "attempts") > 0 || int_field(runtime_verify, "required_checks") > 0) {
		message = message +
			"\n🛡️ 运行验证：" + (runtime_verify.ok == true ? "通过" : "失败") +
			"，" + int_field(runtime_verify, "attempts") + "/" + int_field(runtime_verify, "required_checks");
	}

	let rollback = object_field(auto_apply, "rollback");
	if (string_field(rollback, "stage", "") != "" || string_field(rollback, "error", "") != "") {
		message = message +
			"\n🛟 回滚状态：" + auto_apply_stage_text(string_field(rollback, "stage", "-"));
		let rollback_error = string_field(rollback, "error", "");
		if (rollback_error != "")
			message = message + "\n🧾 回滚错误：" + auto_apply_detail_text(rollback_error);
	}

	return message;
}

function safe_auto_apply_message(auto_apply) {
	try {
		return auto_apply_message(auto_apply);
	} catch (e) {
		return "\n\n♻️ 自动应用：已执行\n🧾 通知详情生成失败：" + e;
	}
}

function subscription_status_line(status, sections) {
	if (status == "fail")
		return "❌ 订阅更新失败";
	if (length(sections.preserved) || length(sections.failed))
		return "⚠️ 订阅部分更新成功";
	return "✅ 订阅全量更新成功";
}

function subscription_runtime_note(status, sections) {
	if (status == "fail")
		return "🛡️ 运行说明：没有生成新的可用节点快照";
	if (length(sections.preserved) || length(sections.failed))
		return "🛡️ 运行说明：可用节点快照已更新，失败订阅未覆盖旧数据";
	return "🛡️ 运行说明：节点快照已更新，自动任务已完成";
}

function rule_name(item) {
	if (type(item) == "object" && item != null) {
		if (type(item.tag) == "string" && item.tag != "")
			return item.tag;
		if (type(item.path) == "string" && item.path != "")
			return item.path;
	}
	return "未知规则集";
}

function rule_error(item) {
	if (type(item) == "object" && item != null && type(item.error) == "string" && item.error != "")
		return plain_text(item.error);
	return "下载失败";
}

function rule_lines(items, icon, with_error) {
	items = type(items) == "array" ? items : [];
	let lines = [];
	for (let item in items) {
		let line = icon + " " + rule_name(item);
		if (with_error)
			line = line + "：" + rule_error(item);
		append_limited_line(lines, line, 20);
	}
	return lines;
}

function ruleset_status_line(status, data) {
	if (status == "rolled_back")
		return "❌ 规则集同步后应用失败";
	if (status == "fail")
		return "❌ 规则集同步失败";
	if (int_field(data, "failed_count") > 0)
		return "⚠️ 规则集部分同步失败";
	if (int_field(data, "updated_count") > 0)
		return "✅ 规则集同步完成";
	return "✅ 规则集已是最新";
}

function ruleset_runtime_note(status, data) {
	if (int_field(data, "failed_count") > 0)
		return "🛡️ 运行说明：失败规则集未更新，已保留现有文件";
	if (int_field(data, "updated_count") > 0)
		return "🛡️ 运行说明：规则集文件已更新";
	return "🛡️ 运行说明：规则集文件无变化";
}

function result_status(task_type, result) {
	if (!result || result.ok != true)
		return "fail";

	let data = result_data(result);
	if (task_type == "subscription.refresh") {
		if (data.status == "success")
			return "success";
		if (data.status == "partial" || data.status == "failed_preserved")
			return "partial";
		if (data.status == "failed_no_snapshot")
			return "fail";
		return (data.node_count || 0) > 0 ? "success" : "partial";
	}
	if (task_type == "ruleset.sync") {
		let auto_apply = auto_apply_data(data);
		if (auto_apply_attempted(data)) {
			let status = auto_apply_status(auto_apply);
			if (status != "")
				return status;
		}
		return int_field(data, "failed_count") > 0 ? "partial" : "success";
	}
	return "success";
}

function fallback_result_message(task_type, result, status, err) {
	let data = result_data(result);
	let message = "⚠️ 通知详情生成失败\n" + divider() + "\n\n🧾 错误详情：" + err;

	if (task_type == "ruleset.sync") {
		message = message +
			"\n\n📦 规则集结果：" +
			"\n更新：" + int_field(data, "updated_count") +
			"\n未变化：" + int_field(data, "unchanged_count") +
			"\n失败：" + int_field(data, "failed_count");

		let auto_apply = auto_apply_data(data);
		if (auto_apply_attempted(data)) {
			message = message +
				"\n\n♻️ 自动应用：" + auto_apply_status_text(auto_apply, auto_apply_status(auto_apply)) +
				"\n📍 执行阶段：" + auto_apply_stage_text(string_field(auto_apply, "stage", "-"));
			let runtime_verify = object_field(auto_apply, "runtime_verify");
			if (runtime_verify.ok != null || int_field(runtime_verify, "attempts") > 0 || int_field(runtime_verify, "required_checks") > 0)
				message = message + "\n🛡️ 运行验证：" + (runtime_verify.ok == true ? "通过" : "失败");
		} else {
			message = message + "\n\n♻️ 自动应用：未执行";
		}
	}

	return message;
}

function result_message(task_type, result, status) {
	if (!result || result.ok != true) {
		let detail = "unknown error";
		if (result != null)
			detail = result.detail || result.message || result.code || detail;
		let title = task_type == "ruleset.sync" ? "❌ 规则集同步失败" : (task_type == "subscription.refresh" ? "❌ 订阅更新失败" : "❌ 任务执行失败");
		return title + "\n" + divider() + "\n\n🧾 错误详情：" + detail;
	}

	let data = result_data(result);
	if (task_type == "subscription.refresh") {
		let sections = subscription_source_sections(data);
		let message = subscription_status_line(status, sections) + "\n" + divider();
		message = append_section(message, "📝 更新清单", sections.updated);
		message = append_section(message, "🧊 保留旧数据", sections.preserved);
		message = append_section(message, "❌ 失败清单", sections.failed);
		message = append_section(message, "🗑️ 已移除停用", sections.removed);
		return message + "\n\n" + subscription_runtime_note(status, sections);
	}

	if (task_type == "ruleset.sync") {
		let auto_apply = auto_apply_data(data);
		let message = ruleset_status_line(status, data) + "\n" + divider();
		message = append_section(message, "📝 更新清单", rule_lines(data.updated, "🔹", false));
		message = append_section(message, "❌ 失败清单", rule_lines(data.failed, "🔸", true));
		if (auto_apply_attempted(data))
			return message + safe_auto_apply_message(auto_apply);
		return message + "\n\n♻️ 自动应用：未执行\n" + ruleset_runtime_note(status, data);
	}

	return (result.message || task_type + " " + status);
}

function notify_result_best_effort(trace_id, task_type, result) {
	try {
		let status = result_status(task_type, result);
		let message = result_message(task_type, result, status);
		return send_telegram(trace_id, task_type, status, message);
	} catch (e) {
		let status = "fail";
		try {
			status = result_status(task_type, result);
		} catch (status_error) {
			let ignored_status_error = "" + status_error;
		}
		let message = fallback_result_message(task_type, result, status, "" + e);
		return send_telegram(trace_id, task_type, status, message);
	}
}

function notify_settings_get(trace_id, req) {
	try {
		let settings = read_notify_settings();
		return Success({
			path: PATH.NOTIFY,
			settings: settings,
			state: read_notify_state(),
			content: notify_settings_content(settings)
		}, 200, trace_id, "Notify settings loaded");
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_NOTIFY_SETTINGS_FAILED, "Failed to load Notify settings", trace_id, err);
	}
}

function notify_settings_save(trace_id, req) {
	try {
		let content = request_content(req);
		if (!length(content))
			die("Missing Notify settings content; request keys: " + request_keys(req));

		let settings = normalize_notify_settings(parse_json_object(content, "Notify Settings"));
		write_text_atomic(PATH.NOTIFY, notify_settings_content(settings));
		return Success({
			path: PATH.NOTIFY,
			settings: settings
		}, 200, trace_id, "Notify settings saved");
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_NOTIFY_SETTINGS_FAILED, "Failed to save Notify settings", trace_id, err);
	}
}

function notify_test_telegram(trace_id, req) {
	try {
		let settings = read_notify_settings();
		return send_telegram_with_settings(trace_id, settings, "telegram_test", "success", "✅ 通知通道可用\n" + divider() + "\n\n🛡️ 运行说明：Telegram Bot 与 Chat ID 配置正常", true);
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_NOTIFY_SEND_FAILED, "Failed to test Telegram notification", trace_id, err);
	}
}

export { notify_settings_get, notify_settings_save, notify_test_telegram, send_telegram, notify_result_best_effort };
