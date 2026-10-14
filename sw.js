// старый адрес: снимаем кэш и отправляем на новый адрес приложения
const NEW='https://vikagladysheva07-source.github.io/wikki-app/';
const map=u=>{const x=new URL(u);return NEW+x.pathname.replace(/^\/12-weeks\/?/,'')+x.search+x.hash};
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>{e.waitUntil((async()=>{const ks=await caches.keys();await Promise.all(ks.map(k=>caches.delete(k)));await self.registration.unregister();const cs=await self.clients.matchAll({type:'window'});cs.forEach(c=>c.navigate(map(c.url)))})())});
self.addEventListener('fetch',e=>{if(e.request.mode==='navigate')e.respondWith(Response.redirect(map(e.request.url),302))});
