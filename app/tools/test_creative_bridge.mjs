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
  document: {body: {innerText: '', children: []}, title: '', readyState: 'complete', querySelectorAll: () => [],
    querySelector: (selector) => selector === '#score' ? {textContent: '1', value: 'one', checked: true} : null},
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

// This exercises the shipped read-only inspection bridge, not native restore proof.
const assertions = [{selector: '#score', property: 'text'}, {selector: '#score', property: 'value'},
  {selector: '#score', property: 'checked'}, {selector: '#missing', property: 'text'}];
const inspect = () => JSON.parse(window.__workInspect(assertions));
assert.deepEqual(inspect().values, [{value: '1'}, {value: 'one'}, {value: true}, {error: 'missing_element'}]);
assert.equal(inspect().ready, true);
assert.equal(Object.getOwnPropertyDescriptor(window, '__workInspect').writable, false,
  'a generated page cannot replace the host inspection function with a success fixture');
const pendingSave = api.saveState({score: 1});
const pendingSaveEvent = events.pop();
assert.equal(inspect().pending_writes, true, 'host checkpoint must wait for the actual public save acknowledgement');
window.__workReply(pendingSaveEvent.id, true, null);
await pendingSave;
assert.equal(inspect().pending_writes, false);
assert.equal(Object.hasOwn(inspect(), 'state'), false, 'inspection does not export the initial or saved state');
console.log('Creative bridge: serialization, UTF-8 size, dispatch, host rejection, pending choice/save recovery and bounded DOM inspection passed.');
