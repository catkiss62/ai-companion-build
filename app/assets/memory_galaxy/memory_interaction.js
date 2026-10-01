// Display and pointer behavior only; this module has no storage or model access.
export const MEMORY_DOMAIN_COLORS = Object.freeze({
  '共同经历': '#ff7ec4',
  '用户资料': '#7ed9cc',
  'AI Self': '#b98cff',
  '偏好/边界': '#8f9fff',
  '记忆': '#ffa18f',
});

// Projected real memories only. Distances use CSS pixels, with no maximum radius.
export function nearestProjectedMemory(points, x, y, rect) {
  if (!(rect.width > 0 && rect.height > 0)) return null;
  let closest = null, distance = Infinity;
  for (const p of points) {
    if (p.visible === false || p.behind ||
        ![p.x, p.y, p.z].every(Number.isFinite) ||
        Math.abs(p.x) > 1 || Math.abs(p.y) > 1 || Math.abs(p.z) > 1) continue;
    const sx = rect.left + (p.x + 1) * rect.width / 2;
    const sy = rect.top + (1 - p.y) * rect.height / 2;
    const d = (sx - x) ** 2 + (sy - y) ** 2;
    if (d < distance) { distance = d; closest = p.index; }
  }
  return closest;
}

export function bindMemorySelection(canvas, {
  enabled, onTap, onLongPress, holdMs = 550, slop = 8,
  setTimer = setTimeout, clearTimer = clearTimeout,
}) {
  const pointers = new Set();
  let gesture = null, timer = null;
  function clearHold() {
    if (timer !== null) clearTimer(timer);
    timer = null;
  }
  function cancel() { clearHold(); gesture = null; pointers.clear(); }
  function down(e) {
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    pointers.add(e.pointerId);
    if (pointers.size !== 1 || !enabled()) { clearHold(); gesture = null; return; }
    clearHold();
    gesture = {id: e.pointerId, x: e.clientX, y: e.clientY, fired: false};
    const current = gesture;
    timer = setTimer(() => {
      timer = null;
      if (gesture !== current || pointers.size !== 1) return;
      if (!enabled()) { cancel(); return; }
      current.fired = true; // Consume pointerup even when the library is empty.
      onLongPress(current.x, current.y);
    }, holdMs);
  }
  function move(e) {
    if (!gesture || e.pointerId !== gesture.id) return;
    if (Math.abs(e.clientX - gesture.x) + Math.abs(e.clientY - gesture.y) > slop) {
      clearHold(); gesture = null;
    }
  }
  function up(e) {
    pointers.delete(e.pointerId);
    if (!gesture || e.pointerId !== gesture.id) return;
    const current = gesture;
    move(e); // Also handle a final move with no preceding pointermove event.
    clearHold();
    const tap = gesture === current && !current.fired && enabled();
    gesture = null;
    if (tap) onTap(e.clientX, e.clientY);
  }
  function cancelled(e) {
    pointers.delete(e.pointerId);
    clearHold(); gesture = null;
  }
  function contextMenu(e) { e.preventDefault(); }
  const listeners = {
    pointerdown: down, pointermove: move, pointerup: up,
    pointercancel: cancelled, lostpointercapture: cancelled, contextmenu: contextMenu,
  };
  for (const [name, listener] of Object.entries(listeners)) canvas.addEventListener(name, listener);
  return {
    cancel,
    dispose() {
      cancel();
      for (const [name, listener] of Object.entries(listeners)) canvas.removeEventListener(name, listener);
    },
  };
}
