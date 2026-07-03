/**
 * Shinra | generator_control_plane.uc | v1.0
 */

'use strict';

import { CONTROL_PLANE_PROXY } from 'shinra.core.constants';
import { dashboard_policy } from 'shinra.dashboard_config';

function ensure_object_field(parent, key) {
	if (type(parent[key]) != "object" || parent[key] == null || type(parent[key]) == "array")
		parent[key] = {};
	return parent[key];
}

function has_clash_api(profile) {
	return type(profile.experimental) == "object" &&
		profile.experimental != null &&
		type(profile.experimental) != "array" &&
		type(profile.experimental.clash_api) == "object" &&
		profile.experimental.clash_api != null &&
		type(profile.experimental.clash_api) != "array";
}

function managed_clash_api(policy) {
	let source = type(policy.clash_api) == "object" && policy.clash_api != null && type(policy.clash_api) != "array" ? policy.clash_api : {};
	return {
		external_controller: source.external_controller || "0.0.0.0:9090",
		secret: type(source.secret) == "string" ? source.secret : "",
		external_ui: type(source.external_ui) == "string" ? source.external_ui : "",
		default_mode: type(source.default_mode) == "string" && source.default_mode != "" ? source.default_mode : "rule"
	};
}

function endpoint_from_listen(listen, port) {
	return {
		host: type(listen) == "string" && listen != "" ? listen : "0.0.0.0",
		port: int(port || 0),
		valid: int(port || 0) > 0 && int(port || 0) <= 65535
	};
}

function endpoint_from_controller(controller) {
	if (type(controller) != "string" || controller == "")
		return { host: "", port: 0, valid: false };

	let parts = split(controller, ":");
	if (length(parts) < 2)
		return { host: "", port: 0, valid: false };

	let port_text = parts[length(parts) - 1];
	let port = int(port_text || 0);
	let host = substr(controller, 0, length(controller) - length(port_text) - 1);
	if (length(host) >= 2 && substr(host, 0, 1) == "[" && substr(host, length(host) - 1) == "]")
		host = substr(host, 1, length(host) - 2);

	return {
		host: host,
		port: port,
		valid: host != "" && port > 0 && port <= 65535
	};
}

function host_conflicts(a, b) {
	if (a == b)
		return true;
	if (a == "0.0.0.0" || b == "0.0.0.0")
		return true;
	if (a == "::" || b == "::")
		return true;
	return false;
}

function endpoints_conflict(a, b) {
	if (!a.valid || !b.valid)
		return false;
	return a.port == b.port && host_conflicts(a.host, b.host);
}

function dashboard_api_service(policy) {
	let service = {
		type: "api",
		tag: "shinra-api",
		listen: policy.listen,
		listen_port: policy.listen_port,
		secret: policy.secret,
		access_control_allow_origin: policy.access_control_allow_origin,
		access_control_allow_private_network: policy.access_control_allow_private_network
	};

	if (type(policy.dashboard) == "object" && policy.dashboard != null && type(policy.dashboard) != "array")
		service.dashboard = policy.dashboard;

	return service;
}

function apply_clash_api_policy(profile, policy, api_service) {
	let official_enabled = policy.enabled == true;
	let dashboard_enabled = type(policy.clash_api) == "object" &&
		policy.clash_api != null &&
		type(policy.clash_api) != "array" &&
		policy.clash_api.enabled == true;
	let profile_has = has_clash_api(profile);
	let profile_api = profile_has ? profile.experimental.clash_api : {};
	let dashboard_api = managed_clash_api(policy);
	let service_endpoint = official_enabled ? endpoint_from_listen(policy.listen, policy.listen_port) : { host: "", port: 0, valid: false };
	let profile_endpoint = endpoint_from_controller(profile_api.external_controller);
	let dashboard_endpoint = endpoint_from_controller(dashboard_api.external_controller);
	let profile_conflict = profile_has && endpoints_conflict(service_endpoint, profile_endpoint);
	let dashboard_conflict = dashboard_enabled && endpoints_conflict(service_endpoint, dashboard_endpoint);
	let result = {
		enabled: false,
		source: "none",
		external_controller: "",
		secret_configured: false,
		profile_existing: profile_has,
		profile_conflict: profile_conflict,
		dashboard_enabled: dashboard_enabled,
		dashboard_conflict: dashboard_conflict,
		conflict_resolved: false
	};

	if (profile_has && !profile_conflict) {
		result.enabled = true;
		result.source = "profile";
		result.external_controller = profile_api.external_controller || "";
		result.secret_configured = type(profile_api.secret) == "string" && profile_api.secret != "";
		api_service.preserved_clash_api = true;
		return result;
	}

	if (dashboard_enabled && !dashboard_conflict) {
		let experimental = ensure_object_field(profile, "experimental");
		experimental.clash_api = dashboard_api;
		result.enabled = true;
		result.source = "dashboard";
		result.external_controller = dashboard_api.external_controller;
		result.secret_configured = dashboard_api.secret != "";
		result.conflict_resolved = profile_conflict;
		api_service.preserved_clash_api = false;
		return result;
	}

	if (profile_conflict && dashboard_conflict)
		die("CLASH_API_PORT_CONFLICT:Profile and Dashboard Clash API endpoints both conflict with official API service " + policy.listen + ":" + policy.listen_port);
	if (profile_conflict && !dashboard_enabled)
		die("CLASH_API_PORT_CONFLICT:Profile Clash API endpoint conflicts with official API service and Dashboard Clash API is disabled");
	if (!profile_has && dashboard_conflict)
		die("CLASH_API_PORT_CONFLICT:Dashboard Clash API endpoint conflicts with official API service " + policy.listen + ":" + policy.listen_port);

	return result;
}

function apply_dashboard_api_service(profile) {
	let policy = dashboard_policy();
	let result = {
		enabled: policy.enabled == true ? true : false,
		inserted: false,
		existing: false,
		tag: "shinra-api",
		listen: policy.listen,
		listen_port: policy.listen_port,
		dashboard_enabled: type(policy.dashboard) == "object" && policy.dashboard != null && policy.dashboard.enabled == true ? true : false,
		dashboard_path: type(policy.dashboard) == "object" && policy.dashboard != null ? policy.dashboard.path : "",
		dashboard_download_url: type(policy.dashboard) == "object" && policy.dashboard != null ? policy.dashboard.download_url : "",
		secret_configured: false,
		preserved_clash_api: false,
		clash_api: null
	};

	result.clash_api = apply_clash_api_policy(profile, policy, result);

	if (!result.enabled)
		return result;

	if (type(profile.services) != "array")
		profile.services = [];

	let service = dashboard_api_service(policy);
	for (let i = 0; i < length(profile.services); i++) {
		let existing = profile.services[i];
		if (type(existing) == "object" && existing != null && existing.tag == result.tag) {
			profile.services[i] = service;
			result.existing = true;
			result.secret_configured = policy.secret != "";
			return result;
		}
	}

	push(profile.services, service);
	result.inserted = true;
	result.secret_configured = policy.secret != "";
	return result;
}

function ensure_control_plane_proxy_inbound(profile) {
	let result = {
		inserted: false,
		existing: false,
		tag: CONTROL_PLANE_PROXY.TAG,
		listen: CONTROL_PLANE_PROXY.LISTEN,
		port: CONTROL_PLANE_PROXY.PORT
	};

	if (type(profile.inbounds) != "array")
		profile.inbounds = [];

	for (let inbound in profile.inbounds) {
		if (type(inbound) != "object" || inbound == null)
			continue;

		if (inbound.tag == CONTROL_PLANE_PROXY.TAG) {
			inbound.type = "mixed";
			inbound.listen = CONTROL_PLANE_PROXY.LISTEN;
			inbound.listen_port = CONTROL_PLANE_PROXY.PORT;
			result.existing = true;
			return result;
		}

		if (inbound.listen == CONTROL_PLANE_PROXY.LISTEN && int(inbound.listen_port || 0) == CONTROL_PLANE_PROXY.PORT)
			die("Control-plane proxy endpoint is already used by inbound: " + (inbound.tag || ""));
	}

	push(profile.inbounds, {
		type: "mixed",
		tag: CONTROL_PLANE_PROXY.TAG,
		listen: CONTROL_PLANE_PROXY.LISTEN,
		listen_port: CONTROL_PLANE_PROXY.PORT
	});
	result.inserted = true;
	return result;
}

export { ensure_object_field, has_clash_api, apply_dashboard_api_service, ensure_control_plane_proxy_inbound };
