// AudioWorklet processor for the low-latency streaming audio engine (see glue.js).
//
// The worklet runs a SECOND wasm instance over the same shared memory and calls
// audioRender/audioCapture on the audio thread. wasm has no thread runtime, so the
// main thread hands it a dedicated stack + TLS block (via processorOptions) and this
// processor brings the thread up by hand before invoking any export.
//
// Without cross-origin isolation there is no shared memory to re-instantiate over, so the
// processor runs in fallback mode instead: the main thread renders the same samples and posts
// them here, and this drains them. Same audio, worse latency.
//
// Loaded by AudioContext.audioWorklet.addModule('audio-engine.js'); it ships next to
// glue.min.js and index.html in every web bundle (see the -web make targets).

// process() quanta between fill reports back to the main thread, which uses them to decide how
// far to render ahead. 8 quanta is ~21ms at 48kHz.
const reportInterval = 8;

class AudioEngine extends AudioWorkletProcessor {
	constructor(options) {
		super();
		const o = options.processorOptions;
		this.ready = false;
		this.fallback = !!o.fallback;
		if (this.fallback) {
			this.chunks = [];
			this.head = 0;
			this.fill = 0;
			this.reports = 0;
			this.port.onmessage = (e) => {
				this.chunks.push(e.data);
				this.fill += e.data.length / 2;
			};
			this.ready = true;
			return;
		}
		this.memory = o.memory;
		const env = new Proxy({ memory: o.memory }, { get: (t, p) => (p in t ? t[p] : (() => 0)) });
		const wasi = new Proxy({}, { get: () => (() => 0) });
		WebAssembly.instantiate(o.module, { env, wasi_snapshot_preview1: wasi }).then((inst) => {
			const ex = inst.exports;
			// Bring up this thread: point it at its own stack + TLS, then it is safe to call in.
			// Memory/global ctors already ran on the main thread, so don't call __wasm_call_ctors.
			ex.__stack_pointer.value = o.stackTop;
			if (ex.__wasm_init_tls) ex.__wasm_init_tls(o.tlsBase);
			this.inst = ex;
			this.outPtr = ex.audioOutBuffer();
			this.inPtr = ex.audioInBuffer();
			this.ready = true;
		}).catch((e) => { this.port.postMessage('audio worklet init failed: ' + e); });
	}
	process(inputs, outputs) {
		if (!this.ready)
			return true;
		if (this.fallback)
			return this.drain(outputs[0]);
		const ex = this.inst;
		const out = outputs[0];
		const frames = out[0].length;

		const input = inputs[0];
		if (input && input.length > 0) {
			const inView = new Float32Array(this.memory.buffer, this.inPtr, frames * 2);
			const l = input[0];
			const r = input.length > 1 ? input[1] : input[0];
			for (let i = 0; i < frames; i++) {
				inView[2 * i    ] = l[i];
				inView[2 * i + 1] = r[i];
			}
			ex.audioCapture(frames);
		}

		ex.audioRender(frames);
		const outView = new Float32Array(this.memory.buffer, this.outPtr, frames * 2);
		const lo = out[0];
		const ro = out.length > 1 ? out[1] : out[0];
		for (let i = 0; i < frames; i++)
		{
			lo[i] = outView[2 * i];
			ro[i] = outView[2 * i + 1];
		}
		return true;
	}
	// Fallback: copy out of the posted chunks, silence when they run dry, and tell the main thread
	// what is left so it knows how much to render next frame.
	drain(out) {
		const frames = out[0].length;
		const lo = out[0];
		const ro = out.length > 1 ? out[1] : out[0];
		for (let i = 0; i < frames; i++) {
			const chunk = this.chunks[0];
			if (chunk === undefined) {
				lo[i] = 0;
				ro[i] = 0;
				continue;
			}
			lo[i] = chunk[2 * this.head];
			ro[i] = chunk[2 * this.head + 1];
			this.head++;
			this.fill--;
			if (this.head * 2 >= chunk.length) {
				this.chunks.shift();
				this.head = 0;
			}
		}
		if (++this.reports >= reportInterval) {
			this.reports = 0;
			this.port.postMessage(this.fill);
		}
		return true;
	}
}
registerProcessor('audio-engine', AudioEngine);
