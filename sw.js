const CACHE='nouradine-agriculture-v4';
const APP_SHELL=['./','./index.html','./manifest.webmanifest','./icon.svg'];

self.addEventListener('install',event=>{
  event.waitUntil(
    caches.open(CACHE)
      .then(cache=>Promise.all(APP_SHELL.map(url=>cache.add(url).catch(()=>null))))
      .then(()=>self.skipWaiting())
  );
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(url.origin!==location.origin)return;

  if(request.mode==='navigate'||url.pathname.endsWith('/index.html')){
    // Serve the saved page immediately, then refresh the cache quietly.
    event.respondWith((async()=>{
      const cache=await caches.open(CACHE);
      const saved=await cache.match('./index.html');
      const refresh=fetch(request).then(response=>{
        if(response.ok)cache.put('./index.html',response.clone());
        return response;
      }).catch(()=>null);
      if(saved){
        event.waitUntil(refresh);
        return saved;
      }
      return (await refresh)||cache.match('./')||Response.error();
    })());
    return;
  }

  // Static files are cache-first for faster repeat visits and offline use.
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    const saved=await cache.match(request);
    if(saved)return saved;
    try{
      const response=await fetch(request);
      if(response.ok)cache.put(request,response.clone());
      return response;
    }catch(error){
      return saved||Response.error();
    }
  })());
});
