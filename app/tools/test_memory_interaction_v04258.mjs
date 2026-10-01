import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';

const source = await readFile(new URL('../assets/memory_galaxy/memory_interaction.js', import.meta.url));
const {MEMORY_DOMAIN_COLORS, nearestProjectedMemory, bindMemorySelection} =
  await import('data:text/javascript;base64,' + source.toString('base64'));
const rect = {left: 20, top: 40, width: 1000, height: 400};
const point = (index, x, y, other = {}) => ({index, x, y, z: 0, ...other});

test('five project categories have distinct display colors with template pink', () => {
  assert.equal(new Set(Object.values(MEMORY_DOMAIN_COLORS)).size, 5);
  assert.equal(MEMORY_DOMAIN_COLORS['共同经历'], '#ff7ec4');
  assert.equal(MEMORY_DOMAIN_COLORS['用户资料'], '#7ed9cc');
  assert.equal(MEMORY_DOMAIN_COLORS['记忆'], '#ffa18f');
});
test('nearest uses screen pixels and has no distance cap', () => {
  const points = [point(0, -.8, .7), point(1, .8, .7)];
  assert.equal(nearestProjectedMemory(points, 1010, 45, rect), 1);
  // Aspect ratio matters: normalized-coordinate proximity is not pixel proximity.
  assert.equal(nearestProjectedMemory([point(0, .2, 0), point(1, 0, .3)], 520, 240, rect), 1);
});
test('empty, hidden, behind, clipped and nonfinite points are never selected', () => {
  const points = [point(0, 0, 0, {behind: true}), point(1, 0, 0, {visible: false}),
    point(2, 0, 0, {z: 2}), point(3, 1.1, 0), point(4, NaN, 0), point(5, -.8, -.8)];
  assert.equal(nearestProjectedMemory(points, 520, 240, rect), 5);
  assert.equal(nearestProjectedMemory([], 520, 240, rect), null);
  assert.equal(nearestProjectedMemory(points.slice(0, -1), 520, 240, rect), null);
  assert.equal(nearestProjectedMemory(points, 520, 240, {...rect, width: 0}), null);
});

function fixture() {
  const canvas = new EventTarget(), tasks = new Map(), taps = [], holds = [];
  let now = 0, next = 0, enabled = true;
  const binding = bindMemorySelection(canvas, {
    enabled: () => enabled,
    onTap: (...p) => taps.push(p), onLongPress: (...p) => holds.push(p),
    setTimer(fn, ms) { const id = ++next; tasks.set(id, {fn, time: now + ms}); return id; },
    clearTimer(id) { tasks.delete(id); },
  });
  return {taps, holds, binding, setEnabled(v) { enabled = v; },
    event(type, props = {}) {
      const e = new Event(type, {cancelable: true});
      Object.assign(e, {pointerId: 1, pointerType: 'touch', button: 0, clientX: 200, clientY: 200}, props);
      canvas.dispatchEvent(e); return e;
    },
    advance(ms) {
      now += ms;
      for (const [id, task] of [...tasks]) if (task.time <= now) { tasks.delete(id); task.fn(); }
    },
  };
}
test('ordinary short tap keeps the release position and never fires a hold', () => {
  const f = fixture(); f.event('pointerdown'); f.advance(100);
  f.event('pointerup', {clientX: 203}); f.advance(1000);
  assert.deepEqual(f.taps, [[203, 200]]); assert.deepEqual(f.holds, []);
});
test('stationary long press fires once at down position and consumes release', () => {
  const f = fixture(); f.event('pointerdown'); f.advance(549);
  assert.equal(f.holds.length, 0); f.advance(1); f.advance(1000); f.event('pointerup');
  assert.deepEqual(f.holds, [[200, 200]]); assert.deepEqual(f.taps, []);
});
test('drag returning to its origin remains a drag', () => {
  const f = fixture(); f.event('pointerdown'); f.event('pointermove', {clientX: 230});
  f.event('pointermove'); f.advance(1000); f.event('pointerup');
  assert.equal(f.holds.length + f.taps.length, 0);
});
test('a final large move without pointermove also cancels tap', () => {
  const f = fixture(); f.event('pointerdown'); f.advance(100); f.event('pointerup', {clientY: 230});
  assert.equal(f.holds.length + f.taps.length, 0);
});
test('pinch cancels selection until both pointers finish, then a new tap works', () => {
  const f = fixture(); f.event('pointerdown'); f.event('pointerdown', {pointerId: 2});
  f.advance(1000); f.event('pointerup', {pointerId: 2}); f.event('pointerup');
  assert.equal(f.holds.length + f.taps.length, 0);
  f.event('pointerdown'); f.event('pointerup'); assert.equal(f.taps.length, 1);
});
test('pointer cancellation and lost capture cancel pending holds', () => {
  for (const kind of ['pointercancel', 'lostpointercapture']) {
    const f = fixture(); f.event('pointerdown'); f.event(kind); f.advance(1000); f.event('pointerup');
    assert.equal(f.holds.length + f.taps.length, 0);
  }
});
test('pausing cancels selection and cannot turn an old press into a new tap', () => {
  const f = fixture(); f.event('pointerdown'); f.binding.cancel(); f.setEnabled(false);
  f.advance(1000); f.setEnabled(true); f.event('pointerup');
  assert.equal(f.holds.length + f.taps.length, 0);
});
test('disabled selection at timer expiry stays cancelled after reenabling', () => {
  const f = fixture(); f.event('pointerdown'); f.setEnabled(false); f.advance(550);
  f.setEnabled(true); f.event('pointerup'); assert.equal(f.holds.length + f.taps.length, 0);
});
test('right click does not select and long press context menu is suppressed', () => {
  const f = fixture(); f.event('pointerdown', {pointerType: 'mouse', button: 2});
  f.advance(1000); f.event('pointerup', {pointerType: 'mouse', button: 2});
  assert.equal(f.holds.length + f.taps.length, 0);
  assert.equal(f.event('contextmenu').defaultPrevented, true);
});
test('disposing removes listeners and scheduled holds', () => {
  const f = fixture(); f.event('pointerdown'); f.binding.dispose(); f.advance(1000);
  f.event('pointerup'); f.event('pointerdown'); f.event('pointerup');
  assert.equal(f.holds.length + f.taps.length, 0);
});
