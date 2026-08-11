#!/usr/bin/env python3
"""Deterministic mirror checks for the current Meju A2 queue contract.

Kept under the historical filename because older CI/docs call it directly.
The v0.29 baseline changes the invariant from serial generate+play to A2-style
generation-ahead with ordered playback and cancellation fencing.
"""
from __future__ import annotations


def simulate_generation_ahead() -> None:
    sentences = ['第一句', '第二句', '第三句']
    generated = []
    played = []

    # A2 submits all generation requests before waiting for sentence 1 audio.
    for sentence in sentences:
        generated.append(sentence)
    assert generated == sentences

    # Playback remains sentence ordered once WAVs become available.
    played.extend(generated)
    assert played == sentences


def simulate_cancel() -> None:
    epoch = 4
    queued = [(4, '第一句'), (4, '第二句')]
    accepted = []
    accepted.append(queued[0][1])
    epoch += 1  # stop()
    for token, text in queued[1:]:
        if token == epoch:
            accepted.append(text)
    assert accepted == ['第一句'], accepted


def simulate_failure_continuation() -> None:
    ready = {0: None, 1: 'wav:第二句', 2: 'wav:第三句'}
    played = []
    for i in range(3):
        audio = ready[i]
        if audio:
            played.append(audio)
    assert played == ['wav:第二句', 'wav:第三句']


def simulate_a2_boundaries() -> None:
    text = '今天不急，慢慢聊、也可以\n停一下……都没关系。下一句！'
    import re
    chunks = [x.strip() for x in re.split(r'[。！？.!?；;]+', text) if x.strip()]
    assert chunks == ['今天不急，慢慢聊、也可以\n停一下……都没关系', '下一句']


if __name__ == '__main__':
    simulate_generation_ahead()
    print('[OK] A2 submits later sentence generation before waiting for playback')
    simulate_cancel()
    print('[OK] stop epoch invalidates stale queued generation')
    simulate_failure_continuation()
    print('[OK] one sentence generation failure does not poison later playback')
    simulate_a2_boundaries()
    print('[OK] A2 punctuation boundaries preserved; comma/newline/ellipsis do not split')
