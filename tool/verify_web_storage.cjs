// Build first with tool/build_web.sh. Requires a local Playwright installation;
// TIMER_PLAYWRIGHT_MODULE / TIMER_CHROMIUM may point at an existing test setup.
// Uses a disposable browser profile and loopback-only static server. No tokens.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const assert = require('node:assert/strict');
const {chromium} = require(process.env.TIMER_PLAYWRIGHT_MODULE || '@playwright/test');
const root = path.resolve(process.argv[2] || 'build/web');
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'timer-sqlite-browser-'));
const server = http.createServer((req, res) => {
  if (req.url === '/') return res.writeHead(200, {'content-type':'text/html'}).end('<!doctype html><title>SQLite durability test</title>');
  const file = path.join(root, req.url.split('?')[0]);
  if (!file.startsWith(root + path.sep)) return res.writeHead(403).end();
  fs.readFile(file, (error, data) => {
    if (error) return res.writeHead(404).end();
    // Fault injection is confined to this disposable test server; the built
    // production worker has no test endpoint or failure flag.
    const prefix = file.endsWith('sqflite_sw.js') ? `const originalPut = IDBObjectStore.prototype.put;
      IDBObjectStore.prototype.put = function(value, ...args) {
        const request = originalPut.call(this, value, ...args);
        if (this.name === 'filesystem' && Object.values(value).some(bytes => bytes.byteLength > 1000000)) this.transaction.abort();
        return request;
      };` : '';
    res.writeHead(200, {'content-type':file.endsWith('.wasm') ? 'application/wasm' : 'application/javascript'}).end(prefix ? Buffer.concat([Buffer.from(prefix),data]) : data);
  });
});
let context, origin;
async function launch() {
  context = await chromium.launchPersistentContext(profile, {
    headless: true,
    ...(process.env.TIMER_CHROMIUM ? {executablePath: process.env.TIMER_CHROMIUM} : {}),
    args: ['--no-sandbox'],
  });
  return attach(context.pages()[0] || await context.newPage());
}
async function attach(page) {
  await page.goto(origin);
  await page.evaluate(async () => {
    const worker = new SharedWorker('sqflite_sw.js', 'sqflite_common_ffi_web');
    window.call = data => new Promise((resolve, reject) => {
      const channel = new MessageChannel();
      const timeout = setTimeout(() => reject(Error('Storage response timed out')), window.storageCallTimeout || 15000);
      channel.port1.onmessage = e => {
        clearTimeout(timeout);
        channel.port1.close();
        if (e.data.error) reject(Error(e.data.error.message)); else resolve(e.data.result ?? e.data);
      };
      worker.port.postMessage(data, [channel.port2]);
    });
    const ready = await window.call({kind:'timer_storage_probe'});
    if (!ready.durable_shared_worker) throw Error('Not a durable SharedWorker');
    window.db = (await window.call({method:'openDatabase', arguments:{path:'/opossum-v1.sqlite', singleInstance:true}})).id;
    window.sql = (sql, extra = {}) => window.call({method:'execute', arguments:{id:window.db, sql, ...extra}});
    window.query = sql => window.call({method:'query', arguments:{id:window.db, sql}});
  });
  return page;
}
async function run() {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
  let page = await launch();
  await page.evaluate(async () => {
    await sql('CREATE TABLE evidence (id INTEGER PRIMARY KEY, value INTEGER NOT NULL, payload BLOB)');
    const {transactionId} = await sql('BEGIN IMMEDIATE', {inTransaction:true, transactionId:null});
    await sql('INSERT INTO evidence(id,value) VALUES(1,5)', {transactionId});
    await sql('COMMIT', {inTransaction:false, transactionId});
  });
  await context.close();
  page = await launch();
  assert.deepEqual((await page.evaluate(() => query('SELECT value FROM evidence WHERE id=1'))).rows, [[5]]);
  console.log('PASS: SQLite commit survives a complete browser process restart.');
  const other = await attach(await context.newPage());
  const changed = p => p.evaluate(async () => {
    const {transactionId} = await sql('BEGIN IMMEDIATE', {inTransaction:true, transactionId:null});
    await sql('UPDATE evidence SET value=6 WHERE id=1 AND value=5', {transactionId});
    const row = await call({method:'query', arguments:{id:db, sql:'SELECT changes()', transactionId}});
    await sql('COMMIT', {inTransaction:false, transactionId});
    return row.rows[0][0];
  });
  assert.deepEqual((await Promise.all([changed(page), changed(other)])).sort(), [0,1]);
  await page.evaluate(() => call({method:'closeDatabase',arguments:{id:db}}));
  await page.close();
  assert.deepEqual((await other.evaluate(() => query('SELECT value FROM evidence WHERE id=1'))).rows, [[6]]);
  console.log('PASS: competing browser tabs serialize transactions; closing one does not close the other connection.');
  await other.evaluate(async () => {
    const {transactionId} = await sql('BEGIN IMMEDIATE', {inTransaction:true, transactionId:null});
    await sql('INSERT INTO evidence(id,value) VALUES(2,99)', {transactionId});
  });
  await context.close();
  page = await launch();
  assert.deepEqual((await page.evaluate(() => query('SELECT id,value FROM evidence ORDER BY id'))).rows, [[1,6]]);
  console.log('PASS: process interruption rolls back an uncommitted SQLite transaction without losing prior evidence.');
  const waitingTab = await attach(await context.newPage());
  const interruptedId = await page.evaluate(async () => {
    const {transactionId} = await sql('BEGIN IMMEDIATE', {inTransaction:true, transactionId:null});
    await sql('INSERT INTO evidence(id,value) VALUES(4,99)', {transactionId});
    return transactionId;
  });
  await waitingTab.evaluate(() => { window.storageCallTimeout = 150000; });
  console.log('Checking the production two-minute abandoned-transaction watchdog...');
  assert.deepEqual((await waitingTab.evaluate(() => query('SELECT id,value FROM evidence ORDER BY id'))).rows, [[1,6]]);
  await assert.rejects(page.evaluate(id => sql('INSERT INTO evidence(id,value) VALUES(5,99)', {transactionId:id}), interruptedId), /transaction expired/);
  await waitingTab.close();
  console.log('PASS: abandoned transaction rolls back and its stale transaction ID cannot write outside the original transaction.');
  await assert.rejects(page.evaluate(() => sql('INSERT INTO evidence VALUES(3,7,randomblob(8000000))')), /persistence|Storage/);
  await assert.rejects(page.evaluate(() => query('SELECT value FROM evidence')), /Storage requires restart/);
  await context.close();
  page = await launch();
  assert.deepEqual((await page.evaluate(() => query('SELECT id,value FROM evidence ORDER BY id'))).rows, [[1,6]]);
  console.log('PASS: aborted IndexedDB transaction is never acknowledged; restart retains the previous atomic snapshot.');
}
run().catch(error => { console.error(error); process.exitCode = 1; }).finally(async () => {
  if (context) await context.close();
  await new Promise(resolve => server.close(resolve));
  fs.rmSync(profile, {recursive:true, force:true});
});
