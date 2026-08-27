# Proactive message notification sounds

The v0.39.6 bundled notification sounds are original synthesized test tones,
generated specifically for this project. They do not contain third-party
recordings and require no external attribution.

| Resource | UI label | Format | Duration | Peak | SHA-256 |
|---|---|---|---:|---:|---|
| `companion_chime_v2.wav` | 清脆三音 | PCM16 mono 48 kHz | 0.62 s | -4.6 dBFS | `ac4bbe754a60c23776bc3df878c739f852b28caeeb3a38c7821fe0b95f857333` |
| `companion_soft_v2.wav` | 柔和水滴 | PCM16 mono 48 kHz | 0.73 s | -5.0 dBFS | `bf73de615a434b313cadaf5211fac1d0879988f8ab26caf63f3dcd0a5e4df9c2` |
| `companion_bubble_v1.wav` | 气泡轻弹 | PCM16 mono 48 kHz | 0.57 s | -5.1 dBFS | `eb470d68ef46895e244e5198ec3be528d43635ea0072d5575197a0ad64857b6c` |

The superseded `companion_chime.ogg` and `companion_soft.ogg` are retained
only for recoverability of the historical implementation. Their measured
peaks are approximately -37.8 dBFS and -37.1 dBFS, which explains why they
were effectively inaudible on device.

Android notification-channel auditory behavior is immutable after channel
creation. v0.39.6 therefore routes the replacement sounds through new channel
IDs instead of reusing the v1 channels.
