'use strict';
'require baseclass';

const STYLE_ID = 'shinra-motion-style';

function joinClass() {
	let result = [];

	for (let i = 0; i < arguments.length; i++) {
		let value = arguments[i];
		if (typeof value !== 'string' || value === '')
			continue;
		result.push(value);
	}

	return result.join(' ');
}

function inject() {
	if (document.getElementById(STYLE_ID))
		return;

	const style = document.createElement('style');
	style.id = STYLE_ID;
	style.textContent = [
		'.shinra-motion-card {',
		'  transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease, background .16s ease, filter .16s ease;',
		'  will-change: transform;',
		'}',
		'.shinra-motion-card:hover {',
		'  transform: translateY(-2px);',
		'  border-color: #cbd5e1;',
		'  box-shadow: 0 10px 22px rgba(15, 23, 42, .08);',
		'  background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%);',
		'}',
		'.shinra-motion-card:active {',
		'  transform: translateY(0);',
		'  box-shadow: 0 4px 10px rgba(15, 23, 42, .06);',
		'}',
		'.shinra-motion-button {',
		'  transition: transform .16s ease, box-shadow .16s ease, filter .16s ease;',
		'}',
		'.shinra-motion-button:hover {',
		'  transform: translateY(-2px);',
		'  box-shadow: 0 8px 18px rgba(15, 23, 42, .14);',
		'  filter: brightness(1.03);',
		'}',
		'.shinra-motion-button:active {',
		'  transform: translateY(0);',
		'  box-shadow: 0 3px 8px rgba(15, 23, 42, .10);',
		'}',
		'.shinra-motion-row {',
		'  transition: background .16s ease, border-color .16s ease;',
		'}',
		'.shinra-motion-row:hover {',
		'  background: #f8fafc;',
		'  border-color: #dfe3e8;',
		'}',
		'.shinra-motion-icon-button {',
		'  transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease, background .16s ease, color .16s ease;',
		'}',
		'.shinra-motion-icon-button:hover {',
		'  transform: translateY(-1px);',
		'  border-color: #bfdbfe;',
		'  background: #eff6ff;',
		'  color: #1d4ed8;',
		'  box-shadow: 0 6px 14px rgba(37, 99, 235, .12);',
		'}',
		'.shinra-motion-icon-button:active {',
		'  transform: translateY(0);',
		'  box-shadow: none;',
		'}',
		'.shinra-motion-card-clickable:focus-visible, .shinra-motion-button:focus-visible, .shinra-motion-row:focus-visible, .shinra-motion-icon-button:focus-visible {',
		'  outline: 2px solid #5b6ee1;',
		'  outline-offset: 2px;',
		'}',
		'@media (prefers-reduced-motion: reduce) {',
		'  .shinra-motion-card, .shinra-motion-button, .shinra-motion-row, .shinra-motion-icon-button {',
		'    transition: none;',
		'    will-change: auto;',
		'  }',
		'  .shinra-motion-card:hover, .shinra-motion-card:active, .shinra-motion-button:hover, .shinra-motion-button:active, .shinra-motion-icon-button:hover, .shinra-motion-icon-button:active {',
		'    transform: none;',
		'  }',
		'}'
	].join('\n');

	document.head.appendChild(style);
}

function cardClass(extra, clickable) {
	return joinClass('shinra-motion-card', clickable ? 'shinra-motion-card-clickable' : '', extra || '');
}

function buttonClass(extra) {
	return joinClass('shinra-motion-button', extra || '');
}

function softRowClass(extra) {
	return joinClass('shinra-motion-row', extra || '');
}

function iconButtonClass(extra) {
	return joinClass('shinra-motion-icon-button', extra || '');
}

return baseclass.extend({
	inject: inject,
	cardClass: cardClass,
	buttonClass: buttonClass,
	softRowClass: softRowClass,
	iconButtonClass: iconButtonClass
});
