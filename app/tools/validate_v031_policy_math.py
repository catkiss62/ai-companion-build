#!/usr/bin/env python3
"""Independent numeric mirror of the v0.31 pure Desire policy invariants.

This is intentionally not a Dart replacement. It gives local/CI validation of
boundedness and catch-up safety even on machines without Flutter/Dart.
"""
from __future__ import annotations

import math
import random

DRIVES = ('attachment','curiosity','reflection','duty','social','libido','stress','fatigue')
DEFAULT_DRIVES = dict(attachment=.44, curiosity=.36, reflection=.34, duty=.28, social=.25, libido=.22, stress=.18, fatigue=.18)
BASE = dict(attachment=.38, curiosity=.34, reflection=.30, duty=.24, social=.22, libido=.20, stress=.14, fatigue=.16)
DECAY = dict(attachment=.010, curiosity=.018, reflection=.014, duty=.016, social=.020, libido=.015, stress=.025, fatigue=.012)


def clamp(v, lo=0.0, hi=1.0):
    return min(hi, max(lo, v))


def advance(d, elapsed_minutes, pulses=None, busy=False):
    pulses = pulses or {}
    scale = clamp(elapsed_minutes / 12.0, .15, 8.0)
    out = dict(d)
    for k in DRIVES:
        v = out[k]
        ret = 1 - (1 - .055) ** scale
        v += (BASE[k] - v) * ret
        v *= (1 - DECAY[k]) ** scale
        v += pulses.get(k, 0.0)
        out[k] = clamp(v)

    def delta(target, amount):
        out[target] = clamp(out[target] + clamp(amount * scale, -.025, .025))
    delta('libido', (out['attachment']-.5)*.012)
    delta('reflection', (out['curiosity']-.5)*.014)
    delta('attachment', (out['reflection']-.5)*.009)
    delta('stress', (out['duty']-.5)*.008)
    delta('social', (out['curiosity']-.5)*.007)
    delta('fatigue', (out['stress']-.45)*.006)
    if busy:
        out['fatigue'] = clamp(out['fatigue'] + .006*scale)
        out['stress'] = clamp(out['stress'] + .003*scale)
    return out


def main():
    rng = random.Random(31040)
    d = dict(DEFAULT_DRIVES)
    hit_upper = {k: 0 for k in DRIVES}
    for i in range(5000):
        elapsed = rng.choice([2, 5, 12, 18, 35, 90, 480])
        pulses = {}
        if rng.random() < .28:
            k = rng.choice(DRIVES)
            pulses[k] = rng.uniform(-.025, .035)
        d = advance(d, elapsed, pulses, busy=(i % 11 == 0))
        for k,v in d.items():
            assert 0.0 <= v <= 1.0, (i,k,v)
            if v >= .999999: hit_upper[k] += 1
    # A bounded policy may touch a clamp under extreme pulses, but no dimension
    # should live permanently at the ceiling in this deterministic long run.
    assert max(hit_upper.values()) < 50, hit_upper

    # Eight-hour resume catch-up is capped at scale=8. Coupling contribution to
    # a single target is still <= .025 for that tick.
    high = {k: .99 for k in DRIVES}
    after = advance(high, 480)
    assert all(0 <= v <= 1 for v in after.values())

    # With no external pulses, repeated ticks should stay near baselines rather
    # than self-excite toward 1.0.
    d = dict(DEFAULT_DRIVES)
    for _ in range(2000):
        d = advance(d, 12)
    assert max(d.values()) < .65, d
    assert min(d.values()) > 0.03, d

    print('v0.31 Desire policy numeric long-run validation passed.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
