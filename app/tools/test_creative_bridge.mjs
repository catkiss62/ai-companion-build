// Run the shipped bridge JavaScript, without Android, to exercise failure cleanup.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const kotlin = readFileSync(new URL('../android/app/src/main/kotlin/com/aicompanion/localfirst/CreativeWebSandbox.kt', import.meta.url), 'utf8');
const prefix = kotlin.match(/val prefix = """([\s\S]*?)"""/)[1]
  .replaceAll('$initial', JSON.stringify('{}')).replaceAll('$preview', 'false');
const script = prefix.match(/<script>([\s\S]*)<\/script>/)[1];
const events = [];
let rejectNative = false;
const window = {addEventListener() {}};
const context = vm.createContext({window, Blob, setTimeout,
  document: {body: {innerText: ''}, title: '', querySelectorAll: () => []},
  getComputedStyle: () => ({backgroundColor: 'white', color: 'black'}),
  NativeWork: {postMessage(raw) {
    if (rejectNative) throw new Error('native unavailable');
    events.push(JSON.parse(raw));
  }},
});
vm.runInContext(script, context);
const api = window.companion;
async function observation() {
  await window.__workObserve('check');
  return events.pop().data;
}

const cyclic = {}; cyclic.self = cyclic;
await assert.rejects(api.saveState(cyclic), /circular/i);
await assert.rejects(api.saveState('雪'.repeat(24000)), /互动数据过大/);
assert.equal(events.length, 0, 'invalid writes must not reach the native bridge');
assert.equal((await observation()).pending_writes, false, 'serialization failures must not poison later chat');

rejectNative = true;
await assert.rejects(api.report({text: 'hello'}), /native unavailable/);
rejectNative = false;
assert.equal((await observation()).pending_writes, false, 'native dispatch failure must clear its pending entry');

const failed = api.saveState({round: 1});
const failedEvent = events.pop();
window.__workReply(failedEvent.id, null, 'save failed');
await assert.rejects(failed, /save failed/);
assert.equal((await observation()).pending_writes, false, 'a host rejection must clear its pending entry');

const choosing = api.choose('round1', ['rock', 'paper'], '');
const choiceEvent = events.pop();
assert.equal((await observation()).pending_writes, false, 'a normal model choice must not block observation or time out');
const saved = api.saveState({round: 1});
const savedEvent = events.pop();
setTimeout(() => window.__workReply(savedEvent.id, true, null), 25);
assert.equal((await observation()).pending_writes, false, 'observation waits for public saves');
assert.equal(await saved, true);
window.__workReply(choiceEvent.id, {committed: true}, null);
assert.equal((await choosing).committed, true);
window.__workReply(savedEvent.id, null, 'late duplicate');
assert.equal((await observation()).pending_writes, false);
console.log('Creative bridge: serialization, UTF-8 size, dispatch, host rejection, pending choice and save recovery passed.');
