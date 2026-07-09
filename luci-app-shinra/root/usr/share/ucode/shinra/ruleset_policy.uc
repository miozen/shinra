/**
 * Shinra | ruleset_policy.uc | v1.0
 */

'use strict';

import { PATH } from 'shinra.core.constants';
import { Success, Fail } from 'shinra.core.result';
import { ERR } from 'shinra.core.error';
import { lock_acquire, lock_release } from 'shinra.core.lock';
import { normalize_ruleset_policy } from 'shinra.ruleset_policy_schema';
import { read_text, write_text_atomic, parse_json_object, request_content, request_keys, json_stringify } from 'shinra.core.utils';

function normalize_ruleset_policy_object(policy) {
	return normalize_ruleset_policy(policy);
}

function normalize_ruleset_policy_content(content) {
	if (content == "")
		die("Missing Rule Set policy content");

	return normalize_ruleset_policy_object(parse_json_object(content, "Rule Set policy"));
}

function ruleset_policy_config() {
	return {
		policy: normalize_ruleset_policy_object(parse_json_object(read_text(PATH.RULESET_POLICY), "Rule Set policy")),
		source: "ruleset-policy",
		path: PATH.RULESET_POLICY
	};
}

function ruleset_policy_get(trace_id, req) {
	try {
		let config = ruleset_policy_config();
		return Success({
			path: PATH.RULESET_POLICY,
			source_path: config.path,
			source: config.source,
			policy: config.policy,
			content: json_stringify(config.policy)
		}, 200, trace_id, "Rule Set policy loaded");
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_RULESET_POLICY_FAILED, "Failed to load Rule Set policy", trace_id, err);
	}
}

function ruleset_policy_save(trace_id, req) {
	let lock = null;
	try {
		let content = request_content(req);
		if (content == "")
			die("Missing Rule Set policy content; request keys: " + request_keys(req));

		let policy = normalize_ruleset_policy_content(content);
		lock = lock_acquire("ruleset-policy", trace_id);
		write_text_atomic(PATH.RULESET_POLICY, json_stringify(policy));
		lock_release(lock);
		return Success({
			path: PATH.RULESET_POLICY,
			policy: policy
		}, 200, trace_id, "Rule Set policy saved");
	} catch (e) {
		if (lock != null)
			lock_release(lock);
		let err = "" + e;
		return Fail(ERR.E_RULESET_POLICY_FAILED, "Failed to save Rule Set policy", trace_id, err);
	}
}

function ruleset_policy_get_impl(trace_id, req) {
	return ruleset_policy_get(trace_id, req);
}

function ruleset_policy_save_impl(trace_id, req) {
	return ruleset_policy_save(trace_id, req);
}

export { normalize_ruleset_policy_object, normalize_ruleset_policy_content, ruleset_policy_config, ruleset_policy_get, ruleset_policy_save, ruleset_policy_get_impl, ruleset_policy_save_impl };
