/**
 * Shinra | generator_nodes.uc | v1.0
 */

'use strict';

import { append_unique, upper_text, tag_contains_keyword, is_digit } from 'shinra.generator_util';

function is_reserved_node_type(node_type) {
	return node_type == "selector" || node_type == "urltest" || node_type == "direct" || node_type == "block" || node_type == "dns";
}

function is_real_node(outbound) {
	if (type(outbound) != "object" || outbound == null || type(outbound) == "array")
		return false;
	if (type(outbound.type) != "string" || outbound.type == "")
		return false;
	if (type(outbound.tag) != "string" || outbound.tag == "")
		return false;
	return !is_reserved_node_type(outbound.type);
}

function tag_matches_banned_keywords(tag, banned_keywords) {
	let tag_upper = upper_text(tag);
	for (let keyword in split(banned_keywords || "", "|")) {
		if (tag_contains_keyword(tag_upper, keyword))
			return true;
	}
	return false;
}

function digit_value(ch) {
	if (ch == "0") return 0;
	if (ch == "1") return 1;
	if (ch == "2") return 2;
	if (ch == "3") return 3;
	if (ch == "4") return 4;
	if (ch == "5") return 5;
	if (ch == "6") return 6;
	if (ch == "7") return 7;
	if (ch == "8") return 8;
	if (ch == "9") return 9;
	return -1;
}

function rate_pattern_enabled(patterns, name) {
	if (type(patterns) != "array")
		return name == "number_x";

	for (let pattern in patterns) {
		if (pattern == name)
			return true;
	}

	return false;
}

function parse_number_x_rate(value, start, include_integer_one) {
	if (start > 0) {
		let previous = substr(value, start - 1, 1);
		if (is_digit(previous) || previous == ".")
			return null;
	}

	let first = substr(value, start, 1);
	if (!is_digit(first))
		return null;

	let size = length(value);
	let j = start;
	let number = 0;
	while (j < size && is_digit(substr(value, j, 1))) {
		number = number * 10 + digit_value(substr(value, j, 1));
		j = j + 1;
	}

	let has_decimal = false;
	let fraction = 0;
	let divisor = 1.0;
	if (j < size && substr(value, j, 1) == ".") {
		j = j + 1;
		if (j >= size || !is_digit(substr(value, j, 1)))
			return null;
		has_decimal = true;
		while (j < size && is_digit(substr(value, j, 1))) {
			divisor = divisor * 10;
			fraction = fraction * 10 + digit_value(substr(value, j, 1));
			j = j + 1;
		}
	}

	if (j >= size || substr(value, j, 1) != "X")
		return null;
	if (number == 1 && !has_decimal && include_integer_one != true)
		return null;

	return {
		matched: true,
		value: number + (fraction / divisor),
		pattern: "number_x",
		start: start,
		end: j + 1
	};
}

function parse_number_times_cn_rate(value, start, include_integer_one) {
	if (start > 0) {
		let previous = substr(value, start - 1, 1);
		if (is_digit(previous) || previous == ".")
			return null;
	}

	let first = substr(value, start, 1);
	if (!is_digit(first))
		return null;

	let size = length(value);
	let j = start;
	let number = 0;
	while (j < size && is_digit(substr(value, j, 1))) {
		number = number * 10 + digit_value(substr(value, j, 1));
		j = j + 1;
	}

	let has_decimal = false;
	let fraction = 0;
	let divisor = 1.0;
	if (j < size && substr(value, j, 1) == ".") {
		j = j + 1;
		if (j >= size || !is_digit(substr(value, j, 1)))
			return null;
		has_decimal = true;
		while (j < size && is_digit(substr(value, j, 1))) {
			divisor = divisor * 10;
			fraction = fraction * 10 + digit_value(substr(value, j, 1));
			j = j + 1;
		}
	}

	let suffix = "倍";
	let suffix_size = length(suffix);
	if (j >= size || substr(value, j, suffix_size) != suffix)
		return null;
	if (number == 1 && !has_decimal && include_integer_one != true)
		return null;

	return {
		matched: true,
		value: number + (fraction / divisor),
		pattern: "number_times_cn",
		start: start,
		end: j + suffix_size
	};
}

function parse_rate_marker(tag, patterns, include_integer_one) {
	let value = upper_text(tag);
	let size = length(value);
	let best_rate = null;

	for (let i = 0; i < size; i = i + 1) {
		if (rate_pattern_enabled(patterns, "number_x")) {
			let rate = parse_number_x_rate(value, i, include_integer_one);
			if (rate != null && (best_rate == null || rate.value > best_rate.value))
				best_rate = rate;
		}

		if (rate_pattern_enabled(patterns, "number_times_cn")) {
			let rate = parse_number_times_cn_rate(value, i, include_integer_one);
			if (rate != null && (best_rate == null || rate.value > best_rate.value))
				best_rate = rate;
		}
	}

	if (best_rate != null)
		return best_rate;

	return {
		matched: false,
		value: 0,
		pattern: "",
		start: -1,
		end: -1
	};
}

function has_high_rate_marker(tag) {
	return parse_rate_marker(tag, [ "number_x" ], true).matched;
}

function rate_filter_compare(value, operator, threshold) {
	if (operator == ">")
		return value > threshold;
	return value >= threshold;
}

function tag_matches_region_keywords(tag, keywords) {
	if (type(keywords) != "array")
		return false;

	let tag_upper = upper_text(tag);
	for (let keyword in keywords) {
		if (tag_contains_keyword(tag_upper, keyword))
			return true;
	}
	return false;
}

function tag_matches_rate_filter_region(tag, policy, filter) {
	if (type(policy) != "object" || policy == null || type(policy.region_keywords) != "object" || policy.region_keywords == null)
		return false;
	if (type(filter.matched_regions) != "array")
		return false;

	for (let region in filter.matched_regions) {
		if (tag_matches_region_keywords(tag, policy.region_keywords[region]))
			return true;
	}
	return false;
}

function rate_filter_action_for_tag(tag, policy) {
	if (type(policy) != "object" || policy == null)
		return "keep";

	let filter = policy.rate_filter;
	if (type(filter) != "object" || filter == null || filter.enabled == false)
		return "keep";
	if (filter.scope == "none")
		return "keep";

	let rate = parse_rate_marker(tag, filter.patterns, filter.include_integer_one);
	if (!rate.matched)
		return "keep";
	if (!rate_filter_compare(rate.value, filter.operator, filter.threshold))
		return "keep";

	if (filter.scope == "all")
		return filter.matched_high_rate_action;

	if (tag_matches_rate_filter_region(tag, policy, filter))
		return filter.matched_high_rate_action;

	return filter.unmatched_action;
}

function rate_filter_drops_tag(tag, policy) {
	return rate_filter_action_for_tag(tag, policy) == "drop";
}

function rate_filter_excludes_from_urltest(tag, policy) {
	let action = rate_filter_action_for_tag(tag, policy);
	return action == "drop" || action == "raw";
}

function collect_profile_tags(profile) {
	let tags = {};
	for (let outbound in profile.outbounds) {
		if (type(outbound) == "object" && outbound != null && type(outbound.tag) == "string" && outbound.tag != "")
			tags[outbound.tag] = true;
	}
	return tags;
}

function enabled_source_id_map(policy) {
	let sources = {};

	if (type(policy) != "object" || policy == null || type(policy.sources) != "array")
		return sources;

	for (let source in policy.sources) {
		if (type(source) != "object" || source == null || type(source) == "array")
			continue;
		if (source.enabled == false)
			continue;
		if (type(source.id) != "string" || source.id == "")
			continue;
		sources[source.id] = true;
	}

	return sources;
}

function normalized_nodes(snapshot, profile_tags, policy) {
	let nodes = [];
	let node_tags = {};
	let skipped_banned = 0;
	let skipped_high_rate = 0;
	let skipped_inactive_source = 0;
	let enabled_sources = enabled_source_id_map(policy);

	for (let outbound in snapshot.outbounds) {
		if (!is_real_node(outbound))
			continue;

		if (type(outbound.x_shinra_source_id) != "string" || outbound.x_shinra_source_id == "" || !enabled_sources[outbound.x_shinra_source_id]) {
			skipped_inactive_source = skipped_inactive_source + 1;
			continue;
		}

		if (rate_filter_drops_tag(outbound.tag, policy)) {
			skipped_high_rate = skipped_high_rate + 1;
			continue;
		}

		if (tag_matches_banned_keywords(outbound.tag, policy.banned_keywords)) {
			skipped_banned = skipped_banned + 1;
			continue;
		}

		if (profile_tags[outbound.tag])
			die("Node tag conflicts with Profile outbound tag: " + outbound.tag);
		if (node_tags[outbound.tag])
			die("Duplicated Node Snapshot outbound tag: " + outbound.tag);

		node_tags[outbound.tag] = true;
		push(nodes, outbound);
	}

	return {
		nodes: nodes,
		skipped_banned: skipped_banned,
		skipped_high_rate: skipped_high_rate,
		skipped_inactive_source: skipped_inactive_source
	};
}

function collect_node_tags(nodes) {
	let tags = {};
	for (let node in nodes)
		tags[node.tag] = true;
	return tags;
}

function node_tag_list(nodes) {
	let tags = [];
	for (let node in nodes)
		append_unique(tags, node.tag);
	return tags;
}

export { is_reserved_node_type, is_real_node, tag_matches_banned_keywords, parse_rate_marker, has_high_rate_marker, rate_filter_action_for_tag, rate_filter_drops_tag, rate_filter_excludes_from_urltest, collect_profile_tags, enabled_source_id_map, normalized_nodes, collect_node_tags, node_tag_list };
