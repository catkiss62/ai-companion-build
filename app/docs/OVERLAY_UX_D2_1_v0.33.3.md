# Overlay UX D2.1 — v0.33.3+58

## Scope

This increment hardens the already-real system pet overlay without starting the D3 autonomous-behavior scheduler.

- Bubble single tap remains chat; double tap opens a scrollable options panel.
- Bubble options can open chat, switch to the pet, retract into the physical left edge, or close.
- A retracted bubble keeps 24dp visible so the upper-right unread badge remains observable; one tap expands it.
- Pet options remain 190dp square but their content scrolls, and now include immediate nearest-edge docking.
- If the pet was falling when a tap/menu interrupted it, closing the menu or finishing the touch reaction resumes gravity.
- A completed overlay-originated assistant reply increments unread when the chat has already been closed.
- Pet motion uses current physical display metrics with proportional left/top/right overscan, while menus keep system-bar/cutout-safe placement.
- Portrait/landscape changes recompute all bounds; no device model list is used.

## Explicit deferrals

- Free movement, four edge-ground states, top/bottom/left/right half-screen regions, light-place versus throw classification, and orientation remapping are D2.2.
- Autonomous roaming, THINKING/TALKING/TTS and Desire/Thought/mood-driven action choice remain D3.
- Rare body/head/tail classification mismatch is unchanged until reproducible evidence identifies a stable geometry defect.
- File-picker/system-cover recovery remains a later reliability increment.

## Light-place visual contract for D2.2

Light placement will reuse the existing short `FALLING` visual followed by `LANDING`, but will not change the released coordinates. A throw will retain velocity/gravity and settle on the active region floor.
