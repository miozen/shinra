/**
 * Shinra | api_status.uc | v1.0
 */

'use strict';

import { PATH } from 'shinra.core.constants';
import { Success, Fail } from 'shinra.core.result';
import { ERR } from 'shinra.core.error';
import { read_optional_text, parse_json_object, file_exists } from 'shinra.core.utils';
import { observe_runtime } from 'shinra.runtime';
import { read_dashboard_source } from 'shinra.dashboard_config';
import { clash_api_url, api_available } from 'shinra.clash';

function runtime_config() {
	if (!file_exists(PATH.RUNTIME_CONFIG))
		return {};

	let content = read_optional_text(PATH.RUNTIME_CONFIG);
	if (content == "")
		return {};
	return parse_json_object(content, "Runtime Config");
}

function dashboard_host(listen) {
	if (listen == "0.0.0.0" || listen == "::")
		return "<router-host>";
	return listen;
}

function dashboard_url(source) {
	return "http://" + dashboard_host(source.listen) + ":" + source.listen_port + "/dashboard/";
}

function api_url(source) {
	return "http://" + dashboard_host(source.listen) + ":" + source.listen_port + "/";
}

function runtime_has_official_api(config, source) {
	if (type(config.services) != "array")
		return false;

	for (let service in config.services) {
		if (type(service) != "object" || service == null)
			continue;
		if (service.type == "api" && service.tag == "shinra-api")
			return int(service.listen_port || 0) == int(source.listen_port || 0);
		if (service.type == "api" && int(service.listen_port || 0) == int(source.listen_port || 0))
			return true;
	}

	return false;
}

function runtime_clash_api(config) {
	if (type(config.experimental) != "object" || config.experimental == null || type(config.experimental) == "array")
		return null;
	if (type(config.experimental.clash_api) != "object" || config.experimental.clash_api == null || type(config.experimental.clash_api) == "array")
		return null;
	return config.experimental.clash_api;
}

function official_status(source, config, running) {
	let configured = source.enabled == true;
	let runtime_configured = runtime_has_official_api(config, source);
	let available = configured && runtime_configured && running;
	let reason = "ok";

	if (!configured)
		reason = "disabled";
	else if (!running)
		reason = "runtime_not_running";
	else if (!runtime_configured)
		reason = "runtime_service_missing";

	return {
		configured: configured,
		runtime_configured: runtime_configured,
		running: running,
		available: available,
		listen: source.listen,
		listen_port: source.listen_port,
		api_url: api_url(source),
		dashboard_url: dashboard_url(source),
		dashboard_enabled: type(source.dashboard) == "object" && source.dashboard != null && source.dashboard.enabled == true,
		secret_configured: source.secret != "",
		reason: reason
	};
}

function clash_status(trace_id, source, config, running) {
	let runtime_api = runtime_clash_api(config);
	let configured = type(runtime_api) == "object" && runtime_api != null;
	let source_enabled = type(source.clash_api) == "object" && source.clash_api != null && source.clash_api.enabled == true;
	let external_controller = configured && type(runtime_api.external_controller) == "string" ? runtime_api.external_controller : "";
	let available = false;
	let reason = "ok";

	if (!source_enabled)
		reason = "disabled";
	else if (!configured)
		reason = "runtime_config_missing";
	else if (!running)
		reason = "runtime_not_running";
	else {
		available = api_available(trace_id, clash_api_url("/proxies"));
		if (!available)
			reason = "unreachable";
	}

	return {
		configured: configured,
		source_enabled: source_enabled,
		running: running,
		available: available,
		external_controller: external_controller,
		secret_configured: configured && type(runtime_api.secret) == "string" && runtime_api.secret != "",
		reason: reason
	};
}

function api_status(trace_id, req) {
	try {
		let source = read_dashboard_source();
		let config = runtime_config();
		let observed = observe_runtime(trace_id);
		let running = observed.running == true;

		return Success({
			official_api: official_status(source, config, running),
			clash_api: clash_status(trace_id, source, config, running)
		}, 200, trace_id, "API status observed");
	} catch (e) {
		let err = "" + e;
		return Fail(ERR.E_API_STATUS_FAILED, "Failed to observe API status", trace_id, err);
	}
}

export { api_status };
