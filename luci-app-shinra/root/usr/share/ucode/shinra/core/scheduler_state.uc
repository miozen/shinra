/**
 * Shinra | core/scheduler_state.uc | v1.0
 */

'use strict';

import { mkdir, rmdir, stat } from 'fs';
import { PATH, AUTO_TASK } from 'shinra.core.constants';
import { read_optional_text, write_text_atomic, parse_json_object, json_stringify, ExecResult } from 'shinra.core.utils';

function path_exists(path) {
	let info = stat(path);
	return type(info) == "object" && info != null;
}

function ensure_dir(path) {
	if (path_exists(path))
		return;
	if (!mkdir(path, 0700))
		die("Failed to create directory: " + path);
}

function ensure_scheduler_dir() {
	ensure_dir(PATH.RUN_DIR);
	ensure_dir(PATH.SCHEDULER_DIR);
}

function trim_line(value) {
	value = "" + value;
	value = replace(value, "\r", "");
	value = replace(value, "\n", "");
	return value;
}

function now_utc(trace_id) {
	let result = ExecResult(trace_id || "shinra-scheduler", [ "date", "-u", "+%Y-%m-%dT%H:%M:%SZ" ]);
	if (result.code != 0)
		return "";
	return trim_line(result.stdout);
}

function current_hour(trace_id) {
	let result = ExecResult(trace_id || "shinra-scheduler", [ "date", "+%H" ]);
	if (result.code != 0)
		return -1;
	return int(trim_line(result.stdout));
}

function current_run_key(trace_id) {
	let result = ExecResult(trace_id || "shinra-scheduler", [ "date", "+%Y-%m-%dT%H" ]);
	if (result.code != 0)
		return "";
	return trim_line(result.stdout);
}

function current_year(trace_id) {
	let result = ExecResult(trace_id || "shinra-scheduler", [ "date", "+%Y" ]);
	if (result.code != 0)
		return 0;
	return int(trim_line(result.stdout));
}

function boot_id() {
	return trim_line(read_optional_text("/proc/sys/kernel/random/boot_id"));
}

function bool_field(obj, key) {
	return type(obj) == "object" && obj != null && obj[key] == true;
}

function string_field(obj, key) {
	if (type(obj) == "object" && obj != null && type(obj[key]) == "string")
		return obj[key];
	return "";
}

function int_field(obj, key) {
	if (type(obj) == "object" && obj != null && obj[key] != null)
		return int(obj[key]);
	return 0;
}

function task_state(task_type, defaults) {
	defaults = defaults || {};
	return {
		enabled: bool_field(defaults, "enabled"),
		scheduled_hour: int_field(defaults, "scheduled_hour"),
		due_now: bool_field(defaults, "due_now"),
		decision: string_field(defaults, "decision"),
		last_run_key: string_field(defaults, "last_run_key"),
		last_run_at: string_field(defaults, "last_run_at"),
		last_trigger_result: string_field(defaults, "last_trigger_result"),
		last_error: string_field(defaults, "last_error"),
		strategy: string_field(defaults, "strategy"),
		notify_intent: bool_field(defaults, "notify_intent")
	};
}

function task_defs_object(task_defs) {
	let tasks = {};
	if (type(task_defs) != "array")
		return tasks;

	for (let def in task_defs) {
		if (type(def) != "object" || def == null || type(def) == "array")
			continue;
		if (type(def.task_type) != "string" || def.task_type == "")
			continue;
		tasks[def.task_type] = task_state(def.task_type, def.defaults || {});
	}

	return tasks;
}

function scheduler_empty_state(scheduler_type, task_defs) {
	return {
		schema_version: 1,
		scheduler_type: scheduler_type || "",
		last_checked_at: "",
		current_hour: 0,
		run_key: "",
		boot_id: "",
		boot_checked: false,
		trace_id: "",
		triggered_tasks: [],
		skipped_tasks: [],
		tasks: task_defs_object(task_defs)
	};
}

function scheduler_normalize_state(raw, scheduler_type, task_defs) {
	let state = scheduler_empty_state(scheduler_type, task_defs);
	if (type(raw) != "object" || raw == null || type(raw) == "array")
		return state;

	state.last_checked_at = string_field(raw, "last_checked_at");
	state.current_hour = int_field(raw, "current_hour");
	state.run_key = string_field(raw, "run_key");
	state.boot_id = string_field(raw, "boot_id");
	state.boot_checked = bool_field(raw, "boot_checked");
	state.trace_id = string_field(raw, "trace_id");
	state.triggered_tasks = type(raw.triggered_tasks) == "array" ? raw.triggered_tasks : [];
	state.skipped_tasks = type(raw.skipped_tasks) == "array" ? raw.skipped_tasks : [];

	let raw_tasks = type(raw.tasks) == "object" && raw.tasks != null && type(raw.tasks) != "array" ? raw.tasks : {};
	if (type(task_defs) == "array") {
		for (let def in task_defs) {
			if (type(def) != "object" || def == null || type(def) == "array")
				continue;
			if (type(def.task_type) != "string" || def.task_type == "")
				continue;
			state.tasks[def.task_type] = task_state(def.task_type, raw_tasks[def.task_type] || def.defaults || {});
		}
	}

	return state;
}

function read_raw_scheduler_state() {
	if (!path_exists(PATH.SCHEDULER_STATE))
		return {};
	return parse_json_object(read_optional_text(PATH.SCHEDULER_STATE), "Scheduler State");
}

function scheduler_read_state(scheduler_type, task_defs) {
	return scheduler_normalize_state(read_raw_scheduler_state(), scheduler_type, task_defs);
}

function write_scheduler_state(state) {
	ensure_scheduler_dir();
	write_text_atomic(PATH.SCHEDULER_STATE, json_stringify(state) + "\n");
	return state;
}

function scheduler_health(trace_id) {
	let script_info = stat(PATH.AUTO_TASK_SCRIPT);
	let cron_info = stat(PATH.CRON_ROOT);
	let cron_content = read_optional_text(PATH.CRON_ROOT);
	let cron = ExecResult(trace_id + "-cron", [ "/etc/init.d/cron", "status" ]);
	let script_exists = type(script_info) == "object" && script_info != null;
	let script_executable = script_exists && (int(script_info.mode || 0) & 0111) != 0;
	let cron_file_exists = type(cron_info) == "object" && cron_info != null;
	let cron_installed = index(cron_content, PATH.AUTO_TASK_SCRIPT) >= 0;

	return {
		script_path: PATH.AUTO_TASK_SCRIPT,
		script_exists: script_exists,
		script_executable: script_executable,
		cron_file: PATH.CRON_ROOT,
		cron_file_exists: cron_file_exists,
		cron_installed: cron_installed,
		cron_running: cron.code == 0,
		cron_status_code: cron.code,
		cron_status_stdout: cron.stdout || "",
		cron_status_stderr: cron.stderr || "",
		cron_entry: AUTO_TASK.CRON_ENTRY,
		healthy: script_exists && script_executable && cron_installed && cron.code == 0
	};
}

function with_scheduler_lock(fn) {
	ensure_scheduler_dir();
	let lock = PATH.SCHEDULER_DIR + "/tick.lock";
	if (!mkdir(lock, 0700))
		return null;
	try {
		let result = fn();
		rmdir(lock);
		return result;
	} catch (e) {
		rmdir(lock);
		die("" + e);
	}
}

export {
	path_exists,
	ensure_scheduler_dir,
	now_utc,
	current_hour,
	current_run_key,
	current_year,
	boot_id,
	bool_field,
	string_field,
	int_field,
	task_state,
	scheduler_empty_state,
	scheduler_normalize_state,
	read_raw_scheduler_state,
	scheduler_read_state,
	write_scheduler_state,
	scheduler_health,
	with_scheduler_lock
};
