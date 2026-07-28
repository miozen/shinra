/**
 * Shinra | generator_manual_selector.uc | v1.0
 */

'use strict';

import { append_unique, upper_text, tag_contains_keyword } from 'shinra.generator_util';

const MANUAL_SELECTOR_TAG = "🍭 手动选择";

function collect_manual_selector_consumers(profile) {
	let consumers = {};

	for (let outbound in profile.outbounds) {
		if (type(outbound) != "object" || outbound == null || type(outbound.tag) != "string" || type(outbound.outbounds) != "array")
			continue;

		for (let tag in outbound.outbounds) {
			if (tag == MANUAL_SELECTOR_TAG) {
				consumers[outbound.tag] = true;
				break;
			}
		}
	}

	return consumers;
}

function restore_manual_selector_references(profile, consumers) {
	for (let outbound in profile.outbounds) {
		if (type(outbound) != "object" || outbound == null || !consumers[outbound.tag])
			continue;
		if (type(outbound.outbounds) != "array")
			outbound.outbounds = [];
		append_unique(outbound.outbounds, MANUAL_SELECTOR_TAG);
	}
}

function node_matches_keywords(node, keywords) {
	if (type(node.tag) != "string")
		return false;

	let tag_upper = upper_text(node.tag);
	for (let keyword in keywords) {
		if (tag_contains_keyword(tag_upper, keyword))
			return true;
	}
	return false;
}

function generate_manual_selector(config, nodes, direct_tag, profile_tags, node_tags) {
	if (profile_tags[MANUAL_SELECTOR_TAG])
		die("Generated manual selector tag conflicts with Profile outbound tag: " + MANUAL_SELECTOR_TAG);
	if (node_tags[MANUAL_SELECTOR_TAG])
		die("Generated manual selector tag conflicts with Node outbound tag: " + MANUAL_SELECTOR_TAG);

	let outbounds = [];
	let policy = config.manual_selector;
	let keywords = type(policy) == "object" && policy != null && type(policy.keywords) == "array" ? policy.keywords : [];

	for (let node in nodes) {
		if (node_matches_keywords(node, keywords))
			append_unique(outbounds, node.tag);
	}

	if (length(outbounds) == 0)
		append_unique(outbounds, direct_tag);

	return {
		type: "selector",
		tag: MANUAL_SELECTOR_TAG,
		outbounds: outbounds,
		interrupt_exist_connections: true
	};
}

export { MANUAL_SELECTOR_TAG, collect_manual_selector_consumers, restore_manual_selector_references, generate_manual_selector };
