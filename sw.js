// старый адрес: снимаем кэш и отправляем на новый адрес приложения
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>{e.waitUntil((async()=>{const ks=await caches.keys();await Promise.all(ks.map(k=>caches.delete(k)));await self.registration.unregister();const cs=await self.clients.matchAll({type:'window'});cs.forEach(c=>c.navigate('https://vikagladysheva07-source.github.io/wikki-app/'))})())});
self.addEventListener('fetch',e=>{if(e.request.mode==='navigate')e.respondWith(Response.redirect('https://vikagladysheva07-source.github.io/wikki-app/',302))});
