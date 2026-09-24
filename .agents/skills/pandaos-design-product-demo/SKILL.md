---
name: "pandaos-design-product-demo"
description: "Create or edit a Product Demo (screen recording with auto-zooms, click effects, backdrop framing, timeline, MP4 export) on the PandaOS Design canvas: create it with design_create type product-demo, let the user record on the canvas, then polish it with product_demo_edit."
---
# Product Demo (Screen Recording)

You help the user create a **product demo**: a screen recording with automatic zooms on clicks, click effects and sounds, a styled backdrop frame, background music, and MP4 export. The recording itself ALWAYS happens on the Design canvas — you cannot record from chat. Your job is to open the door, then polish.

## House rules
- **No em dashes (—) or en dashes (–) in text you write about the demo.** Use a colon, a comma, or a plain hyphen.
- **Never fabricate ids or timings.** Every edit starts with `product_demo_get` — clip ids, zoom ids, and click timestamps come from its output, never from memory.
- Time semantics: clip trims and zoom windows are in **clip source seconds**; `speed` rescales them on the output timeline. Zoom `target` is normalized 0..1 on the frame.

## The Flow

### 1. Starting a new demo
When the user wants to record a demo, call `design_create({ title, type: "product-demo", html: "" })` right away — no direction gathering needed (there is nothing to design before a recording exists). The canvas opens on the recorder, which asks what is being recorded via two choice cards:
- **A web page**: records a web page. Picking one opens it in a clean, dedicated recording window (the project's browser logins carry over), and the demo happens there. Needs NO screen-recording permission (mic/camera are asked only if the user turns on narration or the camera bubble). Clicks are captured automatically for click effects; per-click auto-zooms are an OPT-IN toggle in the pre-flight step (off by default — a zoom per click overwhelms most demos). Click data is saved either way, so you can add zooms selectively afterwards with `add_zoom` or regenerate them all with `regenerate_auto_zooms`. The list shows live PandaOS-browser tabs plus recently open pages, and there is a URL field to record any address directly (no need to open the browser first); if the user's product is a web app, steer them here.
- **My screen or an app**: records the OS screen or another app. Needs the macOS Screen Recording permission (one prompt). Clicks are NOT tracked in this mode — zooms are added afterwards, manually on the timeline (+ button) or by you via `product_demo_edit` `add_zoom` ops.

### 2. While they record
You cannot see or control the recording. Do not poll. Wait for the user to come back (they will usually ask you to edit).

### 3. Editing an existing demo
1. `product_demo_get({ id })` — read the manifest: clips with trim/speed, zoom segments (with `auto` flags), cursor settings, audio tracks, and `clicksByClip` (click timestamps per clip).
2. **You can SEE the footage:** `design_screenshot({ id, at })` returns a real video frame at output-second `at` (default: the middle). Use it to check what happens around a click before zooming there, or to verify a cut point. The frame is raw footage: zooms, cursor, and click effects are applied at preview/export time, so judge composition from the manifest, content from the frame.
3. Apply the user's intent with ONE `product_demo_edit({ id, ops })` call batching all ops:
   - "zoom in on the part where I open settings (~0:12)" → find the click near 12s in `clicksByClip`, then `add_zoom` with a window around it (default: start 0.6s before, 3s total, level 1.5, inDuration/outDuration 1).
   - "make the zooms stronger / slower" → `update_zoom` per segment, or `regenerate_auto_zooms` with params for a global redo (keeps manual zooms).
   - "on every click add a ripple and a sound" → `set_cursor` with `{ clickEffect: "ripple", clickSound: true }` (one op, applies to all clicks).
   - The cursor is always the recorded one (baked into the pixels by macOS) — there is no synthetic cursor option. If the user asks to hide or replace it, say so plainly; click effects and sounds are the styling surface for clicks.
   - "remove the browser/window top bar" → `set_clip_crop { clipId, crop: { x: 0, y: TOP, w: 1, h: 1 - TOP } }` on each clip, where TOP ≈ 194 / clip.height clamped to 0.04..0.22 (typical retina chrome is ~176 px; verify with design_screenshot). Pair with `set_frame { patch: { browserChrome: true } }` to emulate a clean tab.
   - "cut the first 5 seconds" → `trim_clip { clipId, trimStart: 5 }`.
   - "cut it into three parts" / "speed up the boring middle" → `split_clip { clipId, at }` (source seconds) once or twice, then `set_clip_speed` / `reorder_clips` / `remove_clip` on the pieces. Splitting is how you speed up or delete a RANGE: isolate it as its own clip first.
   - "fade in at the start, fade out at the end" → `set_clip_fade { clipId, fadeIn, fadeOut }` (seconds, 0 = off).
   - "cut off the browser tab bar / window chrome" → `set_clip_crop { clipId, crop: {x,y,w,h} }` (normalized source rect; null clears). Use design_screenshot to see the frame first and judge where the chrome ends. Zooms, cursor, and clicks remap into the crop automatically.
   - "add my music file" → the file must be uploaded on the canvas (Media button on the timeline — one picker for music, images, and videos); you can then `update_audio` (offset/volume) or `remove_audio`.
   - "smooth the cut between these two clips" / "crossfade into this clip" / "dip to black before the next section" → `set_clip_transition { clipId, transition: "crossfade"|"dip-black"|null }` on the clip AFTER the cut (it applies at that clip's start). Fixed 0.4s, no tuning. Hard cut (null) is the default and should stay the default most of the time; crossfade is for a soft join, dip-black for a section break.
   - "put it on a nice gradient background" / "make it look produced" → `set_frame { patch: { background: { kind: "gradient", stops: ["#0ea5e9", "#6366f1"], angle: 135 }, padding: 0.06, cornerRadius: 0.025, shadow: 0.55 } }`. Backgrounds are data (color, 2-4 stop gradient, or an uploaded image with optional blur), rendered live and in the export. Always seed padding/cornerRadius/shadow along with the first background so the inset actually shows.
   - "make it vertical / square for social" → `set_frame { patch: { aspect: "9:16" } }` (or "1:1", "16:9"; "auto" follows the recording).
   - "put it in a browser window" → `set_frame { patch: { browserChrome: true } }` draws a clean synthetic browser bar above the video. Pairs well with `set_clip_crop` when real window chrome was recorded.
   - "move my face / camera bubble to the top left, make it square, bigger" / "logo to the top right, smaller" → `update_overlay { overlayId, patch: { x: 0.12, y: 0.15, shape: "square", size: 0.3 } }` (overlays are LAYERS: camera bubble, imported logos/images, imported videos; x/y are the layer center normalized 0..1 on the video; size is a fraction of the video width; shapes: circle, rounded, square, none — "none" = raw media, right for transparent logos; `mirror` flips like a selfie). `remove_overlay` deletes a layer. Camera can only be RECORDED on the canvas (Camera toggle); images/videos/music are imported with the Media button on the timeline (then you can reposition layers via ops). Narration records as its own "Narration" audio track, so speeding/trimming screen clips never distorts the voice. Corner coordinate hints (size dependent, safe defaults): top left x .12 y .15, top right x .88 y .12, bottom left x .12 y .85, bottom right x .85 y .8.
   - Narration is not only captured during the original recording: the user can also press **Narrate** on the timeline afterward to record voice (and optionally camera) OVER the existing playback, without re-recording the screen. That take lands the same way, a "Narration" audio track plus (if camera was on) a bubble overlay. You can then retime or move it like any other track or overlay with `update_audio` (offset, volume) or `update_overlay` (position, size).
   - "put a caption here saying X" / "add a lower-third with my name and title" / "big title card that says X" → `add_overlay { overlay: { kind: "title", text: "X", offset, duration, x, y, size, titleStyle, anim, enterMs, exitMs } }`. Titles are drawn directly on the video, no media file needed. Lower-third pattern: `y` around 0.82, `anim: "slide-up"`, `duration` 4 to 6s, `titleStyle.pill: true` when the footage behind it is busy (adds a dark backing for legibility). Big center title: `y` around 0.5, `titleStyle.fontSize` 0.1 to 0.14, `anim: "word-stagger"` for a punchier reveal. Research timing defaults: `enterMs` 400, `exitMs` 250, do not center-dock small captions (use lower or upper thirds instead, keep the center for big single-beat titles). Edit an existing title with `update_overlay { overlayId, patch: { text?, titleStyle?, anim?, enterMs?, exitMs?, duration? } }` — `duration` only works on titles, since (unlike camera/image/video) there is no source media bounding it.
4. Before you report done, SEE it: call `design_screenshot({ id, at })` at the moments you changed (a zoom you added, a crop, a title) and check the framing actually looks right — you author these blind otherwise. Then report what changed in user terms (times, not ids). The canvas updates live; export to MP4 is the Export button on the canvas.

### Motion intros, outros, and section cards
When the user wants an ANIMATED full-frame card that is NOT drawn over the footage (a title intro like "5s intro saying 'PandaOS' with a cool reveal", an outro/logo sting, or an interstitial section card between clips), use `product_demo_add_motion({ id, html, placement, duration, title? })`. This is different from a title overlay: an overlay sits ON the video; a motion card is its own full-screen animated clip on the timeline.

- **Author the `html` as a self-contained motion card** in the pandaos-design-motion format: one HTML file with a `<script id="__motion__">` Stage+Sprite manifest and a stable `data-eid` on every element that moves. Stage is **1920x1080**.
- **Background MUST be fully opaque** (a solid color or a gradient, never transparent) — the card is baked to an opaque MP4 and dropped in as a normal clip. A transparent background bakes to black or garbage.
- **Reveal craft** (research-backed): big type (48-72pt equivalent, hero can go larger), uniform or gradient background. Reveal verbs: mask wipe, blur-in (20px to 0), scale-settle, word slide+fade with 120-200ms word stagger (50-80ms per char). Ease-out dominant. Total card 2-5s; hold the finished frame at least 0.5s at the end. Outro: logo/wordmark scale-pop over 800-1200ms then hold on a solid brand background, tagline <= 12 words.
- **`placement`** is `"start"` (before everything), `"end"` (after everything), or a number of output-timeline seconds to splice it in at (existing clips shift right to make room). **`duration`** (1 to 30s) should match the motion manifest's own duration.
- The editor bakes the card to video on the canvas, so **the demo must be OPEN** for it to appear (it renders within a few seconds); if it is closed, it bakes the next time the demo is opened. Tell the user to keep the demo open. Undo and version history cover it like any edit.

### Judgment defaults
- Prefer fewer, calmer zooms: merge clusters, level 1.4–1.8, never zoom for a lone click unless asked.
- Keep total zoomed time under ~40% of the demo.
- When the user asks for something the ops cannot express (per-range speed, transitions), say so plainly instead of approximating badly.
