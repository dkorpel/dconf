// Hosting a second wasm module in the page: the env.dbg* bridge the debugger loads a game
// through (see source/debugger/jsbridge.d), plus the child-instance variants of the window and
// sound imports. The debugger is itself a wasm module and wasm cannot instantiate wasm, so
// these imports are how it fetches, drives and inspects a guest.
//
// OPTIONAL: glue.js works without this file, it just cannot host anything - a module importing
// env.dbg* then fails to instantiate. Include it after glue.min.js in pages that need it; it
// builds on makeCtx / makeEnvExports / instantiateModuleAsync there and adds no globals of its
// own beyond the registries below.
//
// Per-instance state this file hangs on a ctx: parent, depth, path, trapped, padOverride.

// The builds the page offers in the debugger's target list, one path per entry.
var dbgTargetPaths = [];

// How many levels of hosting are allowed (?depth=N). A debugger can host a debugger, so the
// list has to stop offering the builds already open somewhere up the chain, or booting would
// recurse until memory ran out - every level auto-loads its first target.
var dbgMaxDepth = 3;

const dbgFetches = [];
const dbgInstances = [];

// Called by glue.js's initWasm if this file is loaded; returns the URL params consumed here so
// they are not also forwarded to the module as -name=value arguments.
function dbgConfigure(params) {
	if (params.get('targets'))
		dbgTargetPaths = params.get('targets').split(',');
	if (params.get('depth'))
		dbgMaxDepth = Number(params.get('depth'));
	return ['targets', 'depth'];
}

// The builds an instance may load: everything, until it sits at the depth limit, where the
// builds already in its own ancestry drop out. That leaves exactly the non-recursing ones.
function targetsFor(ctx) {
	if (ctx.depth < dbgMaxDepth)
		return dbgTargetPaths;
	const ancestry = new Set();
	for (let c = ctx; c; c = c.parent)
		if (c.path)
			ancestry.add(c.path);
	return dbgTargetPaths.filter(p => !ancestry.has(p));
}

// What a hosted module gets: no canvas or event listeners of its own, no microphone, but the
// full debug bridge - so a hosted debugger can host in turn.
function makeChildImports(ctx, path) {
	return {
		...makeEnvExports(ctx, makeChildWindowExports),
		...makeChildSoundExports(ctx),
		...makeDebugHostExports(ctx, path),
	};
}

function makeChildWindowExports(ctx) {
	return {
		jsInitWindow: (windowPtr, canvasLen, canvasPtr, desiredAspect, antialias) => { ctx.windowPtr = windowPtr; },
		jsLoopWindow: (windowPtr, fps, lockstep) => { ctx.windowPtr = windowPtr; ctx.fps = fps; },
		jsSetMouseCapture: () => {},
		jsSetClipboard: () => {},
		jsOpenUrl: () => {},
		jsRequestClipboard: () => {},
		jsToggleFullscreen: () => {},
		jsCloseWindow: () => { ctx.windowClosed = true; },
	};
}

// A hosted game renders audio the same way a top-level one does - its own worklet node over its
// own module and memory. Only the microphone is withheld, so hosting can't trigger a mic prompt.
function makeChildSoundExports(ctx) {
	return {
		...makeSoundEngineExports(ctx),
		jsSoundInputInit: () => {},
	};
}

// `host` is the ctx of the module these imports belong to; `path` is the build it was loaded
// from, which together with its depth decides what it may host in turn.
function makeDebugHostExports(host, path = null) {
	host.path = path;
	host.depth = host.parent ? host.parent.depth + 1 : 0;
	const inst = (h) => dbgInstances[h] || null;
	// Every call into a hosted module can trap; a trap arrives here as a thrown exception and
	// is latched on the instance, which is what the debugger's WasmHost.trapped reports.
	const guard = (ctx, fn) => {
		if (!ctx || ctx.trapped)
			return 0;
		try {
			return fn();
		} catch (e) {
			console.error('hosted wasm trapped:', e);
			ctx.trapped = true;
			return 0;
		}
	};
	return {
		dbgTargetList: (len, ptr) => wasmStoreJsString(targetsFor(host).join('\n'), ptr, len, host.memory),

		dbgFetchBegin: (len, ptr) => {
			const path = toJsString(ptr, len, host.memory);
			const slot = dbgFetches.length;
			dbgFetches.push({ state: 0, ctx: null });
			WebAssembly.compileStreaming(fetch(path))
				.then(m => {
					const ctx = makeCtx();
					ctx.trapped = false;
					ctx.parent = host;
					return instantiateModuleAsync(m, makeChildImports(ctx, path), ctx).then(() => ctx);
				})
				.then(ctx => { dbgFetches[slot].ctx = ctx; dbgFetches[slot].state = 1; })
				.catch(e => { console.error('could not load', path, e); dbgFetches[slot].state = 2; });
			return slot;
		},
		dbgFetchPoll: (slot) => dbgFetches[slot] ? dbgFetches[slot].state : 2,

		dbgInstantiate: (slot) => {
			const f = dbgFetches[slot];
			if (!f || f.state !== 1 || !f.ctx)
				return -1;
			dbgInstances.push(f.ctx);
			f.ctx = null;
			return dbgInstances.length - 1;
		},
		dbgRelease: (h) => {
			const ctx = inst(h);
			if (ctx) {
				detachChildAudio(ctx);
				releaseGlState(ctx.glState);
			}
			dbgInstances[h] = null;
		},
		dbgDetachAudio: (h) => detachChildAudio(inst(h)),
		dbgSetAudioRun: (h, run) => setChildAudioRun(inst(h), run),

		dbgHasExport: (h, len, ptr) => {
			const ctx = inst(h);
			return ctx && typeof ctx.wasm.exports[toJsString(ptr, len, host.memory)] === 'function' ? 1 : 0;
		},
		dbgCall: (h, nameLen, namePtr, argsLen, argsPtr) => {
			const ctx = inst(h);
			const name = toJsString(namePtr, nameLen, host.memory);
			const args = Array.from(new Float64Array(host.memory.buffer, argsPtr, argsLen));
			return guard(ctx, () => ctx.wasm.exports[name](...args) || 0);
		},
		dbgTrapped: (h) => { const ctx = inst(h); return ctx && ctx.trapped ? 1 : 0; },

		dbgMemSize: (h) => { const ctx = inst(h); return ctx ? ctx.memory.buffer.byteLength : 0; },
		dbgMemRead: (h, addr, len, ptr) => {
			const ctx = inst(h);
			if (!ctx || addr + len > ctx.memory.buffer.byteLength)
				return;
			new Uint8Array(host.memory.buffer, ptr, len).set(new Uint8Array(ctx.memory.buffer, addr, len));
		},
		dbgMemWrite: (h, addr, len, ptr) => {
			const ctx = inst(h);
			if (!ctx || addr + len > ctx.memory.buffer.byteLength)
				return;
			new Uint8Array(ctx.memory.buffer, addr, len).set(new Uint8Array(host.memory.buffer, ptr, len));
		},

		// Forwarded into the guest's debugPlace export: the guest's own executor places its
		// output, and a hosted debugger composes this placement into what it hands its guests.
		dbgSetView: (h, x, y, scale, cx, cy, cw, ch) => {
			const ctx = inst(h);
			if (!ctx || ctx.trapped || !ctx.wasm.exports.debugPlace)
				return;
			guard(ctx, () => ctx.wasm.exports.debugPlace(x, y, scale, cx, cy, cw, ch));
		},
		// The hosting debugger writes the pads it rebuilt from input events; jsGetGamepadState
		// serves these instead of polling the page, so the hosted run stays deterministic.
		dbgSetPad: (h, index, len, ptr) => {
			const ctx = inst(h);
			if (!ctx)
				return;
			if (!ctx.padOverride)
				ctx.padOverride = [];
			ctx.padOverride[index] = new Uint8Array(new Uint8Array(host.memory.buffer, ptr, len));
		},
		dbgWindowPtr: (h) => { const ctx = inst(h); return ctx ? (ctx.windowPtr || 0) : 0; },
		dbgTakeClose: (h) => {
			const ctx = inst(h);
			if (!ctx || !ctx.windowClosed)
				return 0;
			ctx.windowClosed = false;
			return 1;
		},
	};
}

// Silence a hosted instance: the worklet keeps calling audioRender over its memory otherwise, so
// a reloaded or released game would go on playing from a heap the debugger has moved on from.
function detachChildAudio(ctx) {
	if (!ctx || !ctx.audioNode)
		return;
	ctx.audioNode.disconnect();
	ctx.audioNode = null;
}

// Bind a hosted instance to the debugger's time controls: a disconnected worklet node is not
// pulled, so the guest's audioRender stops and its clock freezes where it stood.
function setChildAudioRun(ctx, run) {
	if (!ctx || !ctx.audioNode)
		return;
	if (run)
		ctx.audioNode.connect(audioContext.destination);
	else
		ctx.audioNode.disconnect();
}

// Drop the GL objects a released instance can no longer reach (the native host does the same
// in HostGlue.releaseGlObjects); they are ids in this page's one shared context.
function releaseGlState(gs) {
	for (const b of Object.values(gs.bufferMap)) gl.deleteBuffer(b);
	for (const v of Object.values(gs.vaoMap)) gl.deleteVertexArray(v);
	for (const p of Object.values(gs.programMap)) gl.deleteProgram(p);
	for (const t of Object.values(gs.textureMap)) gl.deleteTexture(t);
	for (const f of Object.values(gs.fbMap)) gl.deleteFramebuffer(f);
	for (const r of Object.values(gs.rbMap)) gl.deleteRenderbuffer(r);
}

// Host a second module without a debugger driving it: the multiinstance e2e test uses this to
// exercise the same per-instance GL / memory isolation the debugger relies on.
async function hostChildWasm(fileName) {
	const ctx = makeCtx();
	await loadWasm(fileName, makeChildImports(ctx, fileName), ctx);
	startInstance(ctx);
	ctx.step = () => ctx.wasm.exports.windowStep(ctx.windowPtr);
	ctx.draw = () => ctx.wasm.exports.windowDraw(ctx.windowPtr);
	return ctx;
}
