// Cross-origin isolation via a service worker, for hosts that can't send COOP/COEP
// headers (GitHub Pages). Reinjects them on every response so the page becomes
// crossOriginIsolated, which the shared-memory (threaded) wasm build requires.
// MIT. Reimplementation of the pattern from github.com/gzuidhof/coi-serviceworker.
if (typeof window === "undefined")
{
	self.addEventListener("install", () => self.skipWaiting());
	self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
	self.addEventListener("fetch", (event) =>
	{
		const r = event.request;
		if (r.cache === "only-if-cached" && r.mode !== "same-origin")
			return;
		event.respondWith(fetch(r).then((response) =>
		{
			if (response.status === 0)
				return response;
			const headers = new Headers(response.headers);
			headers.set("Cross-Origin-Embedder-Policy", "require-corp");
			headers.set("Cross-Origin-Opener-Policy", "same-origin");
			return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
		}).catch((e) => console.error(e)));
	});
}
else
{
	(async function ()
	{
		if (window.crossOriginIsolated || !window.isSecureContext)
			return;
		const reg = await navigator.serviceWorker
			.register(window.document.currentScript.src)
			.catch((e) => console.error("COOP/COEP service worker failed:", e));
		if (!reg)
			return;
		reg.addEventListener("updatefound", () => window.location.reload());
		if (reg.active && !navigator.serviceWorker.controller)
			window.location.reload();
	})();
}
