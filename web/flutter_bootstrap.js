{{flutter_js}}
{{flutter_build_config}}

// Cache only build-time application assets. Never cache authenticated API calls.
// Do not activate an updated application under an unfinished fight.
window.timerOfflineReady = (async () => {
  if (!('serviceWorker' in navigator)) return false;
  try {
    await navigator.serviceWorker.register(
      new URL('timer_offline_worker.js', document.baseURI),
      { scope: new URL('.', document.baseURI).pathname, updateViaCache: 'none' }
    );
    const registration = await navigator.serviceWorker.ready;
    if (!registration.active?.scriptURL.includes('timer_offline_worker.js')) return false;
    if (!navigator.serviceWorker.controller) {
      await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once:true}));
    }
    return navigator.serviceWorker.controller?.scriptURL.includes('timer_offline_worker.js') === true;
  } catch (_) { return false; }
})();
_flutter.loader.load({
  config: { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString() }
});
