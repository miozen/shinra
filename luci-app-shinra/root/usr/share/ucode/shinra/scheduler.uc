/**
 * Shinra | scheduler.uc | v1.0
 */

'use strict';

import { PATH } from 'shinra.core.constants';
import { Success, Fail } from 'shinra.core.result';
import { ERR } from 'shinra.core.error';
import { read_text, parse_json_object } from 'shinra.core.utils';
import { path_exists, now_utc, current_hour, current_run_key, current_year, boot_id, scheduler_read_state, write_scheduler_state, scheduler_health, with_scheduler_lock } from 'shinra.core.scheduler_state';
import { normalize_subscriptions_policy } from 'shinra.subscription_policy_schema';
import { ruleset_policy_config } from 'shinra.ruleset_policy';
import { subscriptions_refresh_start } from 'shinra.subscription';
import { ruleset_download_required_start } from 'shinra.ruleset';

const SCHEDULER_TYPE = "auto-resource";
const SUB_TASK = "subscription.refresh";
const RULE_TASK = "ruleset.sync";
const TASK_DEFS = [
	{
		task_type: SUB_TASK,
		defaults: {
			strategy: "saved"
		}
	},
	{
		task_type: RULE_TASK,
		defaults: {}
	}
];

function read_scheduler_state() {
	return scheduler_read_state(SCHEDULER_TYPE, TASK_DEFS);
}

function load_policies() {
	return {
		subscription_policy: normalize_subscriptions_policy(parse_json_object(read_text(PATH.SUBSCRIPTIONS), "Subscriptions")),
		ruleset_policy: ruleset_policy_config().policy
	};
}

function push_task(list, task_type, decision) {
	push(list, {
		task_type: task_type,
		decision: decision || ""
	});
}

function mark_skip(state, task_type, task, decision, error) {
	task.decision = decision || "skipped";
	task.due_now = false;
	task.last_trigger_result = decision || "skipped";
	task.last_error = error || "";
	push_task(state.skipped_tasks, task_type, task.decision);
}

function mark_trigger(state, task_type, task, now, run_key, result) {
	task.due_now = true;
	task.decision = result && result.data && result.data.started == false ? "already_running" : "triggered";
	task.last_run_key = run_key;
	task.last_run_at = now;
	task.last_trigger_result = task.decision;
	task.last_error = "";
	if (task.decision == "already_running")
		push_task(state.skipped_tasks, task_type, task.decision);
	else
		push_task(state.triggered_tasks, task_type, task.decision);
}

function trigger_subscription(trace_id, strategy) {
	if (strategy == "direct" || strategy == "proxy")
		return subscriptions_refresh_start(trace_id, { strategy: strategy, notify_intent: true });
	return subscriptions_refresh_start(trace_id, { notify_intent: true });
}

function trigger_ruleset(trace_id) {
	return ruleset_download_required_start(trace_id, { notify_intent: true, scheduler_intent: true, auto_apply_intent: true });
}

function evaluate_hourly(state, task_type, task, enabled, scheduled_hour, now, run_key, time_ok, trigger_fn) {
	task.enabled = enabled == true;
	task.scheduled_hour = scheduled_hour;
	task.due_now = false;
	task.last_error = "";

	if (task.last_run_key == run_key && (task.last_trigger_result == "boot_triggered" || task.last_trigger_result == "boot_already_running"))
		return;

	if (!task.enabled) {
		mark_skip(state, task_type, task, "disabled", "");
		return;
	}

	if (!time_ok) {
		mark_skip(state, task_type, task, "time_unreliable", "");
		return;
	}

	if (scheduled_hour != state.current_hour) {
		task.decision = "waiting";
		task.last_trigger_result = "waiting";
		push_task(state.skipped_tasks, task_type, "waiting");
		return;
	}

	if (task.last_run_key == run_key) {
		mark_skip(state, task_type, task, "already_ran", "");
		return;
	}

	let result = trigger_fn();
	if (!result || result.ok != true) {
		mark_skip(state, task_type, task, "failed_to_start", result ? (result.detail || result.message || result.code || "") : "failed_to_start");
		return;
	}

	mark_trigger(state, task_type, task, now, run_key, result);
}

function evaluate_boot(state, task, policy, now, run_key, boot, trace_id) {
	if (policy.run_on_boot != true)
		return;
	if (boot == "") {
		task.decision = "boot_id_unavailable";
		task.last_trigger_result = "boot_id_unavailable";
		task.last_error = "boot_id_unavailable";
		push_task(state.skipped_tasks, SUB_TASK, "boot_id_unavailable");
		return;
	}
	if (state.boot_checked == true && state.boot_id == boot)
		return;

	let result = trigger_subscription(trace_id, policy.strategy);
	if (!result || result.ok != true) {
		task.decision = "boot_failed_to_start";
		task.last_trigger_result = "boot_failed_to_start";
		task.last_error = result ? (result.detail || result.message || result.code || "") : "failed_to_start";
		push_task(state.skipped_tasks, SUB_TASK, "boot_failed_to_start");
		return;
	}

	task.decision = result && result.data && result.data.started == false ? "boot_already_running" : "boot_triggered";
	task.last_run_key = run_key;
	task.last_run_at = now;
	task.last_trigger_result = task.decision;
	task.last_error = "";
	if (task.decision == "boot_already_running")
		push_task(state.skipped_tasks, SUB_TASK, task.decision);
	else
		push_task(state.triggered_tasks, SUB_TASK, task.decision);
	state.boot_checked = true;
	state.boot_id = boot;
}

function scheduler_tick(trace_id, req) {
	try {
		let locked = with_scheduler_lock(function() {
			let policies = load_policies();
			let subscription_policy = policies.subscription_policy;
			let ruleset_policy = policies.ruleset_policy;
			let now = now_utc(trace_id);
			let run_key = current_run_key(trace_id);
			let year = current_year(trace_id);
			let time_ok = year >= 2024;
			let boot = boot_id();
			let state = read_scheduler_state();
			let previous_boot_id = state.boot_id;
			let previous_boot_checked = state.boot_checked;

			state.schema_version = 1;
			state.scheduler_type = SCHEDULER_TYPE;
			state.last_checked_at = now;
			state.current_hour = current_hour(trace_id);
			state.run_key = run_key;
			state.trace_id = trace_id;
			state.triggered_tasks = [];
			state.skipped_tasks = [];
			state.boot_id = boot;
			state.boot_checked = previous_boot_id == boot ? previous_boot_checked : false;

			let sub = state.tasks[SUB_TASK];
			let rules = state.tasks[RULE_TASK];
			sub.strategy = subscription_policy.subscription_update.strategy || "saved";
			sub.notify_intent = true;
			rules.notify_intent = true;

			time_ok = time_ok && state.current_hour >= 0 && state.current_hour <= 23 && run_key != "";

			evaluate_boot(state, sub, subscription_policy.subscription_update, now, run_key, boot, trace_id);
			evaluate_hourly(state, SUB_TASK, sub, subscription_policy.subscription_update.auto_update, subscription_policy.subscription_update.update_hour, now, run_key, time_ok, function() {
				return trigger_subscription(trace_id, subscription_policy.subscription_update.strategy);
			});
			evaluate_hourly(state, RULE_TASK, rules, ruleset_policy.auto_update, ruleset_policy.update_hour, now, run_key, time_ok, function() {
				return trigger_ruleset(trace_id);
			});

			return write_scheduler_state(state);
		});

		if (locked == null) {
			let state = read_scheduler_state();
			push_task(state.skipped_tasks, "scheduler", "already_running");
			state.trace_id = trace_id;
			state.last_checked_at = now_utc(trace_id);
			write_scheduler_state(state);
			return Success({ path: PATH.SCHEDULER_STATE, state: state }, 200, trace_id, "Scheduler already running");
		}

		return Success({ path: PATH.SCHEDULER_STATE, state: locked }, 200, trace_id, "Scheduler tick completed");
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_INTERNAL, "Scheduler tick failed", trace_id, err);
	}
}

function scheduler_status(trace_id, req) {
	try {
		let state = read_scheduler_state();
		return Success({
			path: PATH.SCHEDULER_STATE,
			exists: path_exists(PATH.SCHEDULER_STATE),
			state: state,
			scheduler: scheduler_health(trace_id)
		}, 200, trace_id, "Scheduler status loaded");
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_INTERNAL, "Failed to load Scheduler status", trace_id, err);
	}
}

export { scheduler_tick, scheduler_status };
