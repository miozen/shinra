'use strict';
'require baseclass';

function mergeStyle(base, extra) {
	if (!extra)
		return base;
	return base + (base.slice(-1) === ';' ? ' ' : '; ') + extra;
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
	checkboxInput: checkboxInput,
	defer: defer
});
