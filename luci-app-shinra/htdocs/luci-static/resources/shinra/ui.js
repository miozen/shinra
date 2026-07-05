'use strict';
'require baseclass';

function mergeStyle(base, extra) {
	if (!extra)
		return base;
	return base + (base.slice(-1) === ';' ? ' ' : '; ') + extra;
}

function dataOf(result) {
	if (result && result.ok && result.data)
		return result.data;
	return {};
}

function valueText(value) {
	if (value == null || value === '')
		return '-';
	return String(value);
}

function sectionStyle(extra) {
	return mergeStyle('border: 1px solid #dfe3e8; border-radius: 8px; padding: .75rem 1rem; margin: 0 0 .75rem; background: #fff;', extra);
}

function mutedStyle(extra) {
	return mergeStyle('color: #667; line-height: 1.35; overflow-wrap: anywhere;', extra);
}

function section(children, options) {
	options = options || {};
	return E('div', {
		'id': options.id || null,
		'class': options.class || null,
		'style': sectionStyle(options.style)
	}, children || []);
}

function pageHeader(title, description) {
	return section([
		E('h2', { 'style': 'margin: 0 0 .35rem; line-height: 1.25;' }, title),
		E('p', { 'style': mutedStyle('margin: 0;') }, description)
	]);
}

function sectionTitle(title) {
	return E('h3', { 'style': 'margin: 0 0 .45rem; line-height: 1.25;' }, title);
}

function sectionDescription(text) {
	return E('div', { 'style': mutedStyle('margin: 0 0 .6rem;') }, text);
}

function fieldLabel(text) {
	return E('div', { 'style': 'font-size: 12px; color: #667; font-weight: 700; margin: 0 0 .25rem; line-height: 1.25;' }, text);
}

function formField(label, input, help, options) {
	options = options || {};
	return E('label', {
		'style': mergeStyle('display: block; margin-bottom: .75rem;', options.style)
	}, [
		fieldLabel(label),
		input,
		help ? E('div', { 'style': mutedStyle('font-size: 12px; margin-top: .25rem;') }, help) : ''
	]);
}

function actionRow(children, options) {
	options = options || {};
	return E('div', {
		'id': options.id || null,
		'class': options.class || null,
		'style': mergeStyle('display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; margin-top: .7rem;', options.style)
	}, children || []);
}

function toneColors(tone) {
	if (tone === 'ok' || tone === true)
		return { border: '#bbf7d0', bg: '#f0fdf4', color: '#166534' };
	if (tone === 'warning')
		return { border: '#f59e0b', bg: '#fffbeb', color: '#92400e' };
	if (tone === 'info')
		return { border: '#bfdbfe', bg: '#eff6ff', color: '#1e40af' };
	if (tone === 'error' || tone === false)
		return { border: '#fecaca', bg: '#fef2f2', color: '#991b1b' };
	return { border: '#dfe3e8', bg: '#f8fafc', color: '#475569' };
}

function statusBox(id, text, tone, options) {
	options = options || {};
	let colors = toneColors(tone);
	return E('div', {
		'id': id || null,
		'class': options.class || null,
		'style': mergeStyle('display: %s; border: 1px solid %s; border-radius: 8px; padding: %s; margin: %s; background: %s; color: %s; overflow-wrap: anywhere;'.format(
			text ? 'block' : 'none',
			colors.border,
			options.padding || '.65rem',
			options.margin || '0 0 .75rem',
			colors.bg,
			colors.color
		), options.style)
	}, text || '');
}

function paintStatus(nodeOrId, text, tone) {
	let node = typeof nodeOrId === 'string' ? document.getElementById(nodeOrId) : nodeOrId;
	if (!node)
		return;

	let colors = toneColors(tone);
	node.textContent = text || '';
	node.style.display = text ? 'block' : 'none';
	node.style.borderColor = colors.border;
	node.style.background = colors.bg;
	node.style.color = colors.color;
}

function resultMessage(result, fallback) {
	if (result && result.ok)
		return fallback || result.message || _('Done');
	if (result && (result.message || result.code))
		return '%s: %s'.format(result.message || result.code || _('Unknown error'), result.detail || result.code || _('No detail'));
	return fallback || _('Operation failed');
}

function pill(text, tone) {
	let color = '#475569';
	let bg = '#f1f5f9';

	if (tone === 'ok' || tone === true) {
		color = '#166534';
		bg = '#dcfce7';
	} else if (tone === 'warning') {
		color = '#92400e';
		bg = '#fef3c7';
	} else if (tone === 'error' || tone === false) {
		color = '#991b1b';
		bg = '#fee2e2';
	} else if (tone === 'info') {
		color = '#1e40af';
		bg = '#dbeafe';
	}

	return E('span', {
		'style': 'display: inline-flex; align-items: center; min-height: 22px; padding: 0 .55rem; border-radius: 999px; font-size: 12px; font-weight: 700; color: %s; background: %s; white-space: nowrap;'.format(color, bg)
	}, text);
}

function statCard(label, value, options) {
	options = options || {};
	return E('div', {
		'class': options.class || null,
		'style': mergeStyle('border: 1px solid #e5e7eb; border-radius: 8px; padding: .65rem; background: #f8fafc;', options.style)
	}, [
		E('div', { 'style': 'font-size: 12px; color: #667; font-weight: 700;' }, label),
		E('div', { 'style': mergeStyle('font-size: 20px; font-weight: 800; margin-top: .25rem; overflow-wrap: anywhere;', options.valueStyle) }, valueText(value))
	]);
}

function checkboxInput(options) {
	options = options || {};
	let attrs = {};
	let box = null;
	let mark = null;
	let input = null;

	Object.keys(options).forEach(function(key) {
		if (key !== 'style')
			attrs[key] = options[key];
	});

	attrs.type = 'checkbox';
	attrs.style = mergeStyle('position: absolute; opacity: 0; width: 24px; height: 24px; margin: 0; pointer-events: none;', options.style);

	function paint() {
		let checked = !!(input && input.checked);
		if (box) {
			box.style.borderColor = checked ? '#2563eb' : '#94a3b8';
			box.style.background = checked ? '#2563eb' : '#fff';
			box.style.boxShadow = checked ? 'inset 0 0 0 1px #2563eb' : 'inset 0 0 0 1px #fff';
		}
		if (mark)
			mark.style.display = checked ? 'block' : 'none';
	}

	input = E('input', attrs);
	box = E('span', {
		'aria-hidden': 'true',
		'style': 'display: inline-flex; align-items: center; justify-content: center; width: 18px; height: 18px; min-width: 18px; box-sizing: border-box; border: 1px solid #94a3b8; border-radius: 4px; background: #fff; color: #fff; font-size: 14px; font-weight: 700; line-height: 1; vertical-align: middle;'
	}, [
		mark = E('span', { 'style': 'display: none; transform: translateY(-1px);' }, '\u2713')
	]);

	let wrapper = E('span', {
		'style': 'position: relative; display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; min-width: 24px; cursor: pointer; touch-action: manipulation; vertical-align: middle;',
		'click': function(ev) {
			ev.preventDefault();
			ev.stopPropagation();
			input.checked = !input.checked;
			paint();
			input.dispatchEvent(new Event('change', { bubbles: true }));
		}
	}, [ input, box ]);

	input.addEventListener('change', paint);
	window.setTimeout(paint, 0);
	return wrapper;
}

function defer(fn) {
	window.setTimeout(fn, 0);
}

return baseclass.extend({
	dataOf: dataOf,
	valueText: valueText,
	sectionStyle: sectionStyle,
	mutedStyle: mutedStyle,
	section: section,
	pageHeader: pageHeader,
	sectionTitle: sectionTitle,
	sectionDescription: sectionDescription,
	fieldLabel: fieldLabel,
	formField: formField,
	actionRow: actionRow,
	statusBox: statusBox,
	paintStatus: paintStatus,
	resultMessage: resultMessage,
	pill: pill,
	statCard: statCard,
	checkboxInput: checkboxInput,
	defer: defer
});
