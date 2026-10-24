#!/usr/bin/env node
/*
	Runs a Heaps game compiled to JavaScript in headless Chromium, plays a script of inputs,
	takes screenshots and reports the console, the page errors and how much the picture moves.

	node run.js <folder> [options] [steps...]

	<folder>          served over HTTP; the page is <folder>/index.html (or --page)
	--page <file>     the page to open, relative to the folder (default index.html)
	--size <WxH>      size of the window (default 800x600)
	--port <n>        port of the local server (default: a free one)
	--quiet           only print the errors and the steps' results, not every console line
	--steps <file>    reads more steps from a file, one per line (blank lines and # comments ignored)

	Steps, run in order (each one is a separate argument; quote the ones with spaces):
	wait <ms>                 let the game run
	key <Key> [ms]            press and release a key (Playwright names: ArrowLeft, Space, Enter,
	                          Escape, KeyZ, Digit1...), held for ms (default 100)
	down <Key> / up <Key>     hold or release a key
	type <text>               type characters
	click <x> <y>             click at a point of the page (CSS pixels)
	move <x> <y>              move the mouse there without clicking (hover, :hover in DomKit)
	pad                       connect a fake standard gamepad (index 0); needed before the pad steps
	pad <button> [ms] [index] press a gamepad button: A B X Y LB RB LT RT BACK START LS RS
	                          UP DOWN LEFT RIGHT, held for ms (default 120)
	stick <x> <y> [ms] [index]  move the left stick (-1..1), back to 0 after ms (default: stays)
	shot <file.png>           screenshot of the page
	motion [ms] [x y w h]     compares two screenshots ms apart (default 500): prints the number
	                          of changed pixels (0 = the picture is frozen), in the whole page or
	                          in the given rectangle (CSS pixels)
	until <ms> <js>           waits until the JavaScript expression is true (at most ms)
	log <ms> <text>           waits until a console line contains the text (at most ms)
	eval <js>                 runs JavaScript in the page and prints the result
	reload                    reloads the page (the game restarts; localStorage, so hxd.Save, is kept)

	Exit code: 1 if the page threw an error (uncaught exception) or a file of the page could not be
	loaded (HTTP error), 0 otherwise.

	Needs the playwright package (global or local) and a Chromium: the one of Playwright, or
	/opt/pw-browsers/chromium if present, or the path in $CHROMIUM_PATH.
*/
const http = require('http'), fs = require('fs'), path = require('path'), { execSync } = require('child_process');

function loadPlaywright() {
	try { return require('playwright'); } catch (e) {}
	try { return require(path.join(execSync('npm root -g').toString().trim(), 'playwright')); } catch (e) {}
	console.error('playwright not found: npm install -g playwright (or npm install playwright)');
	process.exit(2);
}

const args = process.argv.slice(2);
if (args.length == 0 || args[0].startsWith('--')) {
	console.error('usage: node run.js <folder> [--page index.html] [--size 800x600] [--quiet] [steps...]');
	process.exit(2);
}
const root = path.resolve(args.shift());
let page = 'index.html', size = [800, 600], port = 0, quiet = false;
const steps = [];
while (args.length) {
	const a = args.shift();
	if (a == '--page') page = args.shift();
	else if (a == '--size') size = args.shift().split('x').map(Number);
	else if (a == '--port') port = Number(args.shift());
	else if (a == '--quiet') quiet = true;
	else if (a == '--steps') steps.push(...fs.readFileSync(args.shift(), 'utf8').split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('#')));
	else steps.push(a);
}

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json', '.wasm': 'application/wasm' };
const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split('?')[0]);
	if (url == '/favicon.ico') { res.writeHead(204); res.end(); return; }
	const file = path.join(root, url);
	if (!file.startsWith(root)) { res.writeHead(403); res.end(); return; }
	fs.readFile(file, (err, data) => {
		if (err) { res.writeHead(404); res.end(); return; }
		res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
		res.end(data);
	});
});

// Standard mapping of the Gamepad API: the button indices hxd.Pad reads in the browser.
const BUTTONS = { A: 0, B: 1, X: 2, Y: 3, LB: 4, RB: 5, LT: 6, RT: 7, BACK: 8, START: 9, LS: 10, RS: 11, UP: 12, DOWN: 13, LEFT: 14, RIGHT: 15 };

// Fake gamepads, installed before the game starts: navigator.getGamepads() returns them.
function fakePads() {
	const make = i => ({ id: 'Fake pad ' + i + ' (STANDARD GAMEPAD)', index: i, connected: true, mapping: 'standard', timestamp: 0,
		buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })), axes: [0, 0, 0, 0] });
	window.__pads = [];
	navigator.getGamepads = () => window.__pads;
	window.__padConnect = i => {
		while (window.__pads.length <= i) window.__pads.push(make(window.__pads.length));
		const e = new Event('gamepadconnected');
		e.gamepad = window.__pads[i];
		window.dispatchEvent(e);
	};
	window.__padButton = (i, b, down) => { window.__pads[i].buttons[b] = { pressed: down, touched: down, value: down ? 1 : 0 }; window.__pads[i].timestamp++; };
	window.__padStick = (i, x, y) => { window.__pads[i].axes[0] = x; window.__pads[i].axes[1] = y; window.__pads[i].timestamp++; };
}

// Number of different pixels between two PNG screenshots, decoded by the browser itself.
async function changedPixels(p, a, b) {
	return p.evaluate(async ([a, b]) => {
		const decode = async s => {
			const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + s)).blob());
			const c = new OffscreenCanvas(img.width, img.height), g = c.getContext('2d');
			g.drawImage(img, 0, 0);
			return g.getImageData(0, 0, img.width, img.height).data;
		};
		const x = await decode(a), y = await decode(b);
		let n = 0;
		for (let i = 0; i < x.length; i += 4)
			if (x[i] != y[i] || x[i + 1] != y[i + 1] || x[i + 2] != y[i + 2]) n++;
		return n;
	}, [a.toString('base64'), b.toString('base64')]);
}

(async () => {
	await new Promise(r => server.listen(port, '127.0.0.1', r));
	const url = 'http://127.0.0.1:' + server.address().port + '/' + page;
	const { chromium } = loadPlaywright();
	const opts = { args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] };
	const exe = process.env.CHROMIUM_PATH || (fs.existsSync('/opt/pw-browsers/chromium') ? '/opt/pw-browsers/chromium' : null);
	if (exe) opts.executablePath = exe;
	const browser = await chromium.launch(opts);
	const p = await browser.newPage({ viewport: { width: size[0], height: size[1] } });
	let errors = 0;
	p.on('pageerror', e => { errors++; console.log('PAGE ERROR: ' + (e.stack || e)); });
	// A Haxe `throw "text"` reaches the page as a haxe.ValueException: print the thrown value and
	// the stack, which the page error alone does not show.
	await p.addInitScript(() => window.addEventListener('error', ev => {
		const e = ev.error;
		if (e && e.value !== undefined) console.error('thrown value: ' + (typeof e.value == 'object' ? JSON.stringify(e.value) : e.value) + '\n' + (e.stack || ''));
	}));
	const logs = [];
	p.on('console', m => {
		// The software renderer of the headless browser reports its slow paths: not the game's business.
		if (m.text().includes('GL Driver Message')) return;
		logs.push(m.text());
		if (!quiet || m.type() == 'error') console.log('console.' + m.type() + ': ' + m.text());
	});
	p.on('requestfailed', r => console.log('REQUEST FAILED: ' + r.url()));
	// A file of the page that cannot be loaded (a wrong -js path, a missing resource) fails the run too.
	p.on('response', r => { if (r.status() >= 400) { errors++; console.log('HTTP ' + r.status() + ': ' + r.url()); } });
	await p.addInitScript(fakePads);
	await p.goto(url);
	console.log('opened ' + url);
	// The game starts on load; give it a moment before the first step.
	await p.waitForTimeout(500);
	const canvas = await p.$('canvas');
	if (!canvas) console.log('WARNING: no <canvas> in the page (Heaps draws in <canvas id="webgl">)');
	// Heaps listens to the keyboard on the canvas (unless it has globalEvents="1"): focus it, as a
	// player clicking on the game would.
	else await canvas.focus();

	const n = s => s === undefined ? undefined : Number(s);
	for (const step of steps) {
		const [cmd, ...a] = step.split(' ');
		switch (cmd) {
		case 'wait': await p.waitForTimeout(n(a[0])); break;
		case 'key': await p.keyboard.down(a[0]); await p.waitForTimeout(n(a[1]) || 100); await p.keyboard.up(a[0]); await p.waitForTimeout(50); break;
		case 'down': await p.keyboard.down(a[0]); break;
		case 'up': await p.keyboard.up(a[0]); break;
		case 'type': await p.keyboard.type(a.join(' '), { delay: 50 }); break;
		case 'click': await p.mouse.click(n(a[0]), n(a[1])); await p.waitForTimeout(50); break;
		case 'move': await p.mouse.move(n(a[0]), n(a[1]), { steps: 5 }); await p.waitForTimeout(50); break;
		case 'pad':
			if (a.length == 0) { await p.evaluate(() => window.__padConnect(0)); await p.waitForTimeout(100); break; }
			{
				const b = BUTTONS[a[0].toUpperCase()], i = n(a[2]) || 0;
				if (b === undefined) throw new Error('unknown gamepad button ' + a[0]);
				await p.evaluate(([i, b]) => window.__padButton(i, b, true), [i, b]);
				await p.waitForTimeout(n(a[1]) || 120);
				await p.evaluate(([i, b]) => window.__padButton(i, b, false), [i, b]);
				await p.waitForTimeout(80);
			}
			break;
		case 'stick': {
			const i = n(a[3]) || 0;
			await p.evaluate(([i, x, y]) => window.__padStick(i, x, y), [i, n(a[0]), n(a[1])]);
			if (a[2]) { await p.waitForTimeout(n(a[2])); await p.evaluate(i => window.__padStick(i, 0, 0), i); }
			break;
		}
		case 'shot': await p.screenshot({ path: a[0] }); console.log('screenshot ' + path.resolve(a[0])); break;
		case 'motion': {
			const ms = n(a[0]) || 500;
			const opts = a.length >= 5 ? { clip: { x: n(a[1]), y: n(a[2]), width: n(a[3]), height: n(a[4]) } } : {};
			const s1 = await p.screenshot(opts);
			await p.waitForTimeout(ms);
			const s2 = await p.screenshot(opts);
			console.log('motion: ' + await changedPixels(p, s1, s2) + ' pixels changed in ' + ms + ' ms' + (opts.clip ? ' (area ' + a.slice(1, 5).join(' ') + ')' : ''));
			break;
		}
		case 'until': {
			const ms = n(a[0]), expr = a.slice(1).join(' ');
			const start = Date.now();
			let ok = false;
			while (Date.now() - start < ms) {
				try { ok = await p.evaluate(expr); } catch (e) { ok = false; }
				if (ok) break;
				await p.waitForTimeout(100);
			}
			if (ok) console.log('until: true after ' + (Date.now() - start) + ' ms: ' + expr);
			else { errors++; console.log('TIMEOUT: ' + expr + ' still false after ' + ms + ' ms'); }
			break;
		}
		case 'log': {
			const ms = n(a[0]), text = a.slice(1).join(' ');
			const start = Date.now();
			while (Date.now() - start < ms && !logs.some(l => l.includes(text)))
				await p.waitForTimeout(100);
			if (logs.some(l => l.includes(text))) console.log('log: "' + text + '" seen after ' + (Date.now() - start) + ' ms');
			else { errors++; console.log('TIMEOUT: no console line with "' + text + '" after ' + ms + ' ms'); }
			break;
		}
		case 'eval': console.log('eval: ' + JSON.stringify(await p.evaluate(a.join(' ')))); break;
		case 'reload': {
			await p.reload();
			await p.waitForTimeout(500);
			const c = await p.$('canvas');
			if (c) await c.focus();
			console.log('reloaded');
			break;
		}
		default: throw new Error('unknown step: ' + step);
		}
	}
	console.log(errors ? errors + ' error(s)' : 'no error');
	await browser.close();
	server.close();
	process.exit(errors ? 1 : 0);
})().catch(e => { console.error(e); server.close(); process.exit(2); });
