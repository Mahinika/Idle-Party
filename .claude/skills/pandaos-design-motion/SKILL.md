---
name: pandaos-design-motion
description: "Create an animated motion design (intro, product reel, kinetic type) on the PandaOS Design canvas: gather direction first, build the visual with design_create, then animate it with design_animate on a deterministic Stage+Sprite timeline."
user-invocable: true
disable-model-invocation: false
source: pandaos
---

# Design a Motion Piece

You create a **motion design** — an animated intro, product reel, or kinetic-type piece — on the PandaOS Design canvas, with a scrubbable timeline and MP4 export. Designs are stored, versioned, and revertable by the tools — never write HTML files into the project.

## House rules (ALL designs, non-negotiable)
- **No emojis, ever.** Never put an emoji glyph in a heading, label, button, nav item, or body copy, and never use one as a stand-in for an icon. For every icon, embed an inline **lucide** SVG (or a lucide `<i data-lucide="...">` element plus the lucide script) — lucide icons only.
- **No em dashes (—) or en dashes (–) in visible copy.** Use a colon, a comma, or a plain hyphen instead.
- **Confirm the design is on screen when you finish.** `design_create` and `design_animate` open/refocus the canvas automatically, but if the user was left on the Design home, end your turn with `design_open({ designId })` so the finished piece is actually showing — never leave them on the home screen after a build.

## The Flow

### 1. Do NOT open the canvas yet
Gather direction in the chat first — the Design tab opens by itself, on the finished design with a build animation, the moment `design_create` runs. Opening it earlier just shows an empty canvas that competes with your questions. Call `design_open` only with `{ designId }` to bring an EXISTING design back on screen, or when the user explicitly asks to see the Design app.

### 2. Intent first — never pixels first
Open with purpose, not style. Gather (via `generative_ui` short_form, or plain prose if `generative_ui` isn't discoverable — search tools for `generative_ui` first):
- What is the piece — intro / product reel / announcement / kinetic type?
- Subject and the ONE message it must land.
- Duration (aim for 4–8 seconds unless asked otherwise) and whether it loops.
- The beats: one idea per beat — what appears, in what order?

**Depth gate: do NOT build after two questions.** Gather until the beats are clear, then confirm the direction before building.

**Gather fresh for each NEW design** — don't carry a prior design's direction over to a new motion piece in the same chat. Intake is per-design.

### 2b. Match the app you are designing for, before you invent a look

A design that does not look like the product it belongs to is a failed design, even when it is
pretty on its own. Whenever the design belongs to an existing app or site, spend a bounded effort
matching it before you propose anything fresh.

1. **Try the extractor first.** `design_system_import({ name: "<product> (codebase)", source: { kind: "codebase" } })`
   is a regex pass over the project's Tailwind config and CSS variables. No install, no dev server,
   about a second, and it returns a pack id you pass straight to `design_create` as `designSystemId`.
2. **If that finds nothing, read the app yourself. Time-boxed, roughly 6 files, no installs.**
   Tokens live in `tailwind.config.*`, `globals.css` / `index.css` / `app.css` / `theme.css`, any
   `:root` or `@theme` block, `components.json` (shadcn). The idiom lives in one or two real UI files
   that carry the app's chrome: a card, a button, the page shell, the nav. Read those and write down
   the actual values: palette plus surface and border colors, corner radius, border weight, shadow
   depth, font stacks, spacing density, light or dark default, icon set.
3. **Copy the idiom, not only the hex codes.** Same radius, same border weight and color, same
   shadow depth, same button and label shape, same density. A design with the right colors but 24px
   pills where the app uses 6px squared cards still reads as a different product.
4. **Put what you found into the document.** Declare the extracted values as CSS custom properties
   at the top of the HTML and build every component off those, so the match is real rather than
   approximate.
5. **Never** run `npm install`, add a dependency, or start a dev server for this. If a couple of
   reads turn up nothing usable, stop and move on to fresh proposals.

Propose a fresh direction only when there is genuinely nothing to match (a brand new product, a
standalone deck) or when the user asks for one. Either way, say in one line which you did: matched
the app's existing style, or proposed a fresh direction, and why.

### 3. One visual palette picker — saved systems live INSIDE it, not behind a yes/no
Before proposing colors, call `design_system_list` (packs from the current project + the global
personal library, each with its colors, scope, and id). Then present a **single `palette_picker`**
(search tools for `generative_ui` first) — do NOT ask a separate "reuse saved vs propose new" question
first. Build the picker's `options` in this order:
1. **Each saved design system as a real swatch** — use the pack's own `colors`, set the option `id`
   to the pack id, label by name + scope. This puts the current/on-brand system in the actual
   picker so the user picks it visually alongside fresh ideas.
2. **3–4 fresh proposed palettes** tuned to the brief — distinct directions, each previewed by its colors.
Leave `allowCustom` on so "Something else…" returns a described direction; for importing, point to
the **Design systems** panel or `design_system_import`.

- Never gate the palette behind a worded question — the saved system is one of the swatches.
- If the returned selection `id` matches a saved pack, pass it to `design_create` as `designSystemId`.
  If it's a fresh palette, carry its colors into the build.
- If NO packs exist, the style you extracted in step 2b IS the first swatch (label it "Current app style"), shown alongside the fresh proposals. Never block.
- If `generative_ui` is unavailable, fall back to a plain worded choice listing saved systems by name +
  scope alongside a few proposed directions.

### 4. Remaining visual direction — vibe, type feel
Vibe and heading/body type feel — a short `generative_ui` or plain question. Colors already came from the
step-3 palette picker. Skip when the user picked a saved design system in step 3.

### 5. Beat sheet BEFORE the manifest (mandatory)
Never go straight from the brief to `design_animate`. First write the beat sheet in your reply, one line per beat:

```
Beat 1 [0.0-1.4s]  mark DRAWS on center, camera starts a slow push, glow breathes behind it
Beat 2 [1.4-3.2s]  wordmark letters RISE staggered, camera keeps pushing toward them
Beat 3 [3.2-4.6s]  tagline WIPES on below, hero holds and breathes
Beat 4 [4.6-6.0s]  camera eases out, glow dims, everything settles: the ending lands
```

Per beat: what enters or exits with a concrete VERB per element (SLAMS, DRAWS ON, RISES, WIPES, COUNTS UP, FLOATS, SNAPS), what the camera does, and what the ambient layer does. Then name the rhythm of the whole piece in one line (for example "punch-punch-HOLD-resolve"). Rules:
- One idea per beat. If you cannot name the verb for an element, that element is not designed yet.
- No beat may be static: between entrances the ambient layer and the camera carry the motion.
- Beats map mechanically to the manifest: beat boundaries become sprite `start` values and camera keyframes.
- A timid beat sheet (everything fades in at once, then nothing happens) is a defect on paper. Rework it before you build, where fixing it is cheap.

### 6. Build: visual first, then the timeline
1. Build the static visual: `design_create({ type: "motion", title, html, designSystemId })` (or `design_create` a scene then animate it). ONE self-contained HTML file; stamp a stable `data-eid` on every element that will move.
2. Animate it: `design_animate({ id, motion })` where `motion` is the Stage+Sprite manifest:
   `{ duration (seconds), fps?, width?, height?, motionBlur?, camera?, sprites: [{ eid, start, end, enter?, exit?, easing?, effect?, keyframes?, springBounce?, motionBlur?, label? }] }`.
   Each sprite animates ONE element (by its `data-eid`) between `start` and `end`; sprites may overlap.
   ALWAYS pass a friendly `label` per sprite (e.g. "Headline P", "Glow blob") — the timeline shows the
   raw `data-eid` otherwise, which reads as "logo-P" garbage to the user.

**`design_animate` enforces the cinematic floor and talks back.** After you animate, the tool result may
carry `Cinematic floor: …` warnings (dead air, no ambient background, static camera auto-added, too few
sprites). These are DEFECTS — do not present the piece as done. Fix them and call `design_animate` again.
A missing camera is auto-injected as a 1.0→1.06 drift, but you should still author a real push-in.
The result also carries rendered review frames of the key moments: judging them is mandatory before you
report anything (see "See it before you ship it" at the end).

## Motion contract (MUST follow exactly)
- **DETERMINISTIC ONLY:** never use `Date.now()`, `performance.now()`, `Math.random()`, or CSS transition/animation running on wall-clock time. All motion must be a pure function of the timeline, or scrubbing and MP4 export will not match. The runtime drives every frame; you only supply the manifest + the static HTML.
- **Transitions:** fade, slide-up, slide-down, slide-left, slide-right, scale, rise.
- **Easings:** linear, inQuad, outQuad, inOutQuad, inCubic, outCubic, inOutCubic, inQuart, outQuart, inOutQuart, outQuint, inExpo, outExpo, inOutExpo, outCirc, inOutCirc, inBack, outBack, inOutBack, inOutSine, spring. Pick by role (per the Hyperframes house style): **outQuart** = snappy, **outExpo** = dramatic, **outBack** = bouncy overshoot, **outCubic/spring** = considered default. Prefer these over linear, which reads as cheap. `spring` takes a per-sprite `springBounce` (0..1, default 0.5): `0` = smooth premium settle, `0.3` subtle, `1` full elastic. Use low bounce (0–0.3) for anything corporate/repeated; save high bounce for playful hero pops.
- **Motion blur is on by default** and derived from each sprite's per-frame travel — fast moves get blurred automatically, which is the single biggest cheap→premium lever. Tune with `motionBlur` at the manifest level (global multiplier, `0` disables) or per sprite (`0` to keep a specific element razor-sharp, `>1` to exaggerate a whip). Do NOT hand-keyframe blur to fake this; let the runtime do it.
- **Per-keyframe easing:** each keyframe may carry `ease` — the curve travelled INTO that keyframe. So one sprite can spring the entrance segment and glide the settle. Omit it to inherit the sprite `easing`. Baked effects already do this; use it for hand-authored kinetic type.
- **Easing by ROLE, not one-for-everything:** pick one ease per role and hold it — hero entrances (spring or outCubic), secondary entrances (outQuad, faster), ambient motion (inOutSine, slow). Using a single ease everywhere reads as flat; using random eases reads as undirected.
- **Exits ACCELERATE.** Entrances decelerate (`out*` eases), exits accelerate away (`inQuad`/`inCubic`/`inExpo`), moves between positions use `inOut*`. Make an exit roughly 30% faster than the matching entrance: a card that takes 0.4s to appear leaves in about 0.25s. A slow fade-out reads as a mistake, not a choice.
- Inline CSS or an allowlisted CDN — NOT cdn.tailwindcss.com.

## Rhythm and pacing (video is its own medium, not an animated web page)
- **Speed is weight.** Fast (0.15-0.3s) reads as energy and confidence; medium (0.3-0.5s) is the professional default; slow (0.5-0.8s) reads as luxury and gravity; very slow (0.8-2.0s) is cinematic and atmospheric. The slowest move in a piece should be about 3x the duration of the fastest: one uniform speed reads as flat.
- **Stagger discipline.** A full stagger sequence stays under 500ms total no matter how many letters or items. Stagger in order of IMPORTANCE, not DOM order: the element that moves first reads as most important. Overlap entries instead of waiting for each to finish.
- **Every beat has the shape build / breathe / resolve.** First ~30%: staggered entrances. Middle: hold with exactly ONE ambient motion on the hero (more reads as noise). Last ~30%: exit or settle into the next beat.
- **Vary the entrance source across beats** (from below, from a side, scale, opacity-only, tracking-in). Repeating one entrance pattern on every beat is the template tell. Same for stagger rhythm: each beat gets its own.
- **Compose at video scale.** Hero >=120px, secondary headlines >=60px, body >=28px at 1080p; padding 60-140px, never web-sized 16-32px; decorative elements at opacity 0.12-0.25 (below 0.10 is invisible after compression); content fills 60-80% of the frame width and anchors to edges rather than floating centered. Subtle reads as static at 30fps: err toward more movement than feels safe.

## Cinematic floor (a piece is NOT done without ALL of these)

The failure mode of AI motion design is "logo + text fades in on a flat gradient" — technically correct, visually cheap. Every piece MUST clear this bar:

1. **Background has depth and LIFE**, never a flat color or single radial. Layer it: base field + 1-2 huge soft ambient elements (their own data-eids, animated as slow ambient sprites drifting/breathing across the WHOLE duration) + a subtle vignette. The background must be moving between beats, because dead air kills a piece. **Perceptibility floor:** an ambient drift must travel 8-15% of the canvas dimension over its window and a glow pulse must swing opacity by at least 0.15. A 2% drift is decoration in the manifest, not motion the viewer sees.
2. **Hero text is staggered, never a block** — split the headline into per-letter (or per-word) spans, each with its own data-eid and sprite, offset 0.05–0.08s, rising with spring/outCubic. A wordmark animating as one element reads as cheap. Letter-spacing tightening (start wide, settle) via keyframes adds the luxury feel.
3. **Camera always moves** — every piece gets `manifest.camera`: minimum a slow 1.0→1.06 drift across the whole duration; better, a push-in toward the hero at its beat. A static camera reads as a slideshow.
4. **Entrances overshoot** — use keyframes with settle (scale 1.06→1.0, or y overshoot −8 then 0), or spring easing. Bare fades are for exits only.
5. **Scale contrast** — hero type HUGE (≥120px at 1080p), supporting elements small. If everything is medium-sized, nothing is important.
6. **A light source** — an accent glow behind/under the hero element (a blurred radial blob, can pulse subtly). Flat lighting = flat piece.
7. **The ending lands** — final beat holds with a settle (camera eases out, glow breathes), or the piece loops seamlessly. Never just stop.

8. **Entrances are offset, not at zero** — the first element enters 0.1–0.3s into the piece/beat; zero-delay entrances read as jump cuts and waste the opening impact.
9. **Hold times follow reading speed** — 1–3 words: hold ≥2s; 4–10 words: ≥3s; more: ≥4–6s. The last readable element must finish entering by 50% of its beat.
10. **Video typography** — dramatic weight contrast (300 vs 900, never 400 vs 700); headlines ≥60px even for secondary text; `font-variant-numeric: tabular-nums` on any counting number. Avoid the overused set (Inter, Roboto, Open Sans, Poppins, Playfair Display).
11. **`end` means DISAPPEAR.** A sprite's window is its lifetime on stage, not its entrance. Any element that must still be visible at the final frame gets `end` = the piece duration; author entrance speed inside the window with keyframe `t` values or the effect, never by shortening the window. The classic defect: a wordmark sprite with `start: 0, end: 1` enters beautifully and then vanishes at 1s, shipping a video whose own title is missing.

Self-check before presenting: judge the review frames `design_animate` returned (see "See it before you ship it" below), and scrub the timeline in your head against the beat sheet. Is there any 0.5s window where NOTHING moves? Is the headline one block? Is the camera static? Does anything disappear before the end that should not? If yes to any, it is not done.

## Pick a visual WORLD per piece (depth is required, the look is not)

The cheap look has two causes: skipping depth under time pressure, and defaulting to the same look
every time. Both are defects.

**Depth requirement, every piece, ANY look.** A frame needs at least 4 layers, each with its own
`data-eid` where it animates:
1. a background field (gradient, color panel, paper, grid),
2. 1-2 ambient elements moving across the WHOLE duration (glow blobs, oversized ghost type, drifting shapes),
3. the hero plane (headline, mark, product frame),
4. a foreground treatment (vignette, grain, thin rules, labels).

**The look comes from the brief and the design system, never from a default.** Pick ONE world and
commit; never reuse the previous piece's world out of habit. Directions that clear the bar:
- **Dark cinematic**: deep gradient, soft glow blobs, high weight contrast. The classic: use it when it fits the brief, not as the reflex.
- **Light editorial**: paper or cream field, hard shadows, huge serif, thin rules.
- **Poster brutalist**: flat saturated field, oversized type, hard-edged shapes, hard cuts.
- **Product spotlight**: near-black, one directional light, a device frame as the hero.
- **Technical**: grid lines, mono type, rules that mask-wipe on, counters.

Example markup for the dark-cinematic world. It shows the four LAYERS wired with `data-eid`s: copy the
layering, not the look:

```html
<div style="position:absolute;inset:0;background:radial-gradient(120% 90% at 50% 15%, #1a2340 0%, #0b0e1a 60%, #05060c 100%);overflow:hidden;font-family:'Space Grotesk','Clash Display',system-ui,sans-serif">
  <!-- Ambient light: two huge soft blobs — animate with glow-pulse / parallax-drift across the WHOLE duration -->
  <div data-eid="bg-glow-1" style="position:absolute;width:70vw;height:70vw;left:-10vw;top:-20vw;border-radius:50%;background:radial-gradient(circle, rgba(120,140,255,.35), transparent 65%);filter:blur(60px)"></div>
  <div data-eid="bg-glow-2" style="position:absolute;width:55vw;height:55vw;right:-8vw;bottom:-15vw;border-radius:50%;background:radial-gradient(circle, rgba(255,190,90,.28), transparent 65%);filter:blur(70px)"></div>
  <!-- Hero content goes here: split the headline into per-letter data-eid spans (weight 800–900), sub in 300 -->
  <!-- Accent light-source: a blurred radial directly behind the hero — animate with glow-pulse -->
  <div data-eid="hero-halo" style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:40vw;height:22vw;border-radius:50%;background:radial-gradient(circle, rgba(255,210,120,.30), transparent 60%);filter:blur(50px)"></div>
  <!-- Vignette + grain: static CSS, MP4-capture-safe (NEVER svg-filter grain) -->
  <div style="position:absolute;inset:0;pointer-events:none;box-shadow:inset 0 0 40vw rgba(0,0,0,.55)"></div>
  <div style="position:absolute;inset:0;pointer-events:none;opacity:.5;background-image:radial-gradient(rgba(255,255,255,.06) 1px, transparent 1.2px),radial-gradient(rgba(0,0,0,.18) 1px, transparent 1.2px);background-size:3px 3px,4px 4px"></div>
</div>
```

Typography rules, any world: dramatic weight contrast (800-900 hero vs 300 support, NEVER 400/700), a
distinctive display face (Space Grotesk / Clash Display / Fraunces, avoid Inter, Roboto, Poppins,
Playfair), hero >=120px at 1080p, `font-variant-numeric:tabular-nums` on any counter. Whatever the
world, keep the four LAYERS: field + ambient elements + hero + foreground treatment.

## Named effects — PREFER these over bare enter/exit (the house motion language)
A sprite can carry `effect: { name, params? }` instead of hand-rolled keyframes. The runtime bakes
it to polished, physical motion — use them as your default; they are what separates cinematic from
cheap. Set `effect` on the sprite in `design_animate` (alongside `eid`, `start`, `end`).

**Entrances (use SHORT windows, ~0.6–1.2s):**
- `overshoot-settle` — scale+rise in, overshoot past 1.0, settle. The default hero/element entrance.
- `rise-settle` — rises from below with a tiny overshoot. Great for headlines, stacked lines.
- `pop-in` — scale from small with overshoot. Badges, icons, stat numbers.
- `blur-in-focus` — unblurs + settles into focus. Luxury / cinematic reveals.
- `grow-up` — scaleY 0→1 from the base (needs `transform-origin: bottom center` on the element).
  Bamboo stalks, bars, growing shapes. `params: { overshoot, settleAt }`.
- `tracking-in` — letters spread wide then tighten (letterSpacing → 0) while fading in. Kinetic
  headlines. Settles to 0 tracking, so author on an element whose resting letter-spacing is 0.
  `params: { from, settleAt }`.
- `mask-wipe` — left-to-right clip-path reveal (opacity stays 1). Lines of copy, bars, underlines.
  `params: { settleAt }`.

**Ambient — span the WHOLE window so nothing is ever static (the anti-JPEG rule):**
- `breathing-float` — gentle y drift, loops seamlessly. Put on the hero AFTER it settles, and on
  logos/product frames during holds.
- `glow-pulse` — opacity+scale pulse. Put on background glow blobs and light sources.
- `parallax-drift` — slow linear drift (`params: { dx, dy }`). Put on background blobs so the
  backdrop is always alive between beats.
- `float-sway` — float + tiny rotation. Floating cards, decorative marks.

Params tune any effect (`amp`, `dx`, `from`, `overshoot`, `settleAt`, …) — all have sane defaults.

## Still-needed hand-rolled bits (no named effect yet)
- **Character stagger** (kinetic type) — split the headline into per-letter/word elements (each its
  own `data-eid`), give each a sprite with `rise-settle` or `overshoot-settle`, start times offset
  0.06–0.08s. This is the signature kinetic-typography look — do it for every hero headline.
- **Camera** — `manifest.camera = { keyframes: [{ t, x, y, scale }] }`. Minimum a 1.0→1.06 drift
  over the whole piece; a push-in on the hero beat is better. Never leave the camera static.
- **Counter / count-up** — give the sprite a `counter: { to, from?, decimals?, prefix?, suffix?,
  settleAt?, group? }` field (NOT keyframes). The runtime ramps the element's TEXT from `from`
  (default 0) to `to` over `settleAt` (default 0.7 of the window), then holds. Grouped with commas
  by default, deterministic, tabular-nums auto-applied. Compose with `pop-in` on the same sprite
  for the number to scale in while it counts. Extend the window to the piece end so it stays.
- **NOT YET SUPPORTED (the runtime sets transform/opacity/filter/letterSpacing/clip-path/color +
  counter text, never arbitrary SVG attributes):**
  - **Draw-on stroke** — `stroke-dashoffset` is not an animatable channel yet; use `mask-wipe`
    (clip-path reveal) to fake a line drawing on left-to-right.
- **Grain (texture)** — static CSS, safe with MP4 capture:
  `background-image: radial-gradient(rgba(255,255,255,.08) 1px, transparent 1.2px), radial-gradient(rgba(0,0,0,.18) 1px, transparent 1.2px);`
  NEVER use SVG-filter (`data:image/svg+xml`) grain — it breaks the MP4 capture path.

## Motion techniques
- **Keyframes** for richer motion: give a sprite explicit keyframes `[{ t, opacity, x, y, scale, scaleX, scaleY, rotate, blur, letterSpacing, clip, color }]` where `t` is 0..1 across the sprite's window; omitted channels hold their last value. `x`/`y` are px deltas from laid-out position; `letterSpacing` is absolute px; `clip` is a 0..1 left-to-right reveal. Use for kinetic type, blur-in focus, color shifts, overshoot (scale 1.06 then 1.0).
- **Camera** (product-video magic): `manifest.camera = { keyframes: [{ t, x, y, scale }] }` for a Ken-Burns / zoom / focus-push across the whole stage. A slow 1.0→1.08 scale over the piece adds life; scale+translate pushes focus to a hero element.
- **Stagger:** for word-by-word / letter-by-letter headlines, split into multiple elements (each its own `data-eid` + sprite) with start times offset ~0.06s — classic kinetic typography. Same trick for list items and logo strokes.
- **Icons:** inline Lucide SVGs (paths only, no `<img>`); animate by keyframing opacity/scale, or wrap the icon and reveal it with `mask-wipe` for a draw-on feel (`stroke-dashoffset` is NOT an animatable channel; a keyframe on it is silently dropped). Never link remote icons.
- **Product shots:** wrap app UI in a phone or browser-chrome frame (simple CSS/SVG), animate the frame in, then move content inside it — reads instantly as a product video.
- **Images:** an `<img>` (or `background-image` div) with a `data-eid` animates like any sprite. The premium moves: **Ken-Burns** (keyframes `scale 1.0→1.08` + a slow `x`/`y` drift over the whole shot, `ease: inOutSine`), **photo reveal** (`mask-wipe`), **parallax** (two image layers drifting at different speeds), **blur-in-focus**. Keep the image slightly larger than its frame so the drift never exposes an edge. CAPTURE-SAFE SOURCES only (else the MP4 export renders blank): a `data:` URI, a same-origin asset (`/api/artifacts/asset/<hash>.png`), or a CORS-enabled https URL. Do NOT hotlink arbitrary remote images. Never animate `background-position` to fake movement — animate the element.
- **Recipes:** LOGO REVEAL = mark draws on (mask-wipe) + wordmark rises with spring, hold, fade. KINETIC HEADLINE = words rise+fade staggered 0.06s, camera drifts 1.0→1.05. STAT COUNTER = give the number sprite a `counter: { to, prefix?, suffix? }` and a `pop-in` effect, big type, one accent color. HERO PHOTO = full-bleed image with Ken-Burns + a mask-wipe title over it.

## Motion specifics
- 1920×1080 (16:9) stage by default; body type ≥24px; restrained palette + ONE accent; generous whitespace.
- One idea per beat; a short piece just starts — no title card under 30s. Loop when non-interactive; land the ending (don't just stop).
- The user can scrub and retime sprites on the timeline afterwards — keep sprite labels meaningful.

## Craft floor (non-negotiable)
Type and palette per the design system; contrast ≥ 4.5:1 on text over backgrounds at every beat; one focal point per beat; no cramped composition, no default-browser look.

## Worked example (imitate the shape, not the content)

A 6-second product intro for "Atlas". Beat sheet first:

```
Rhythm: build-build-HOLD-resolve
Beat 1 [0.0-1.2s]  glow blobs already DRIFTING, camera starts a 1.0->1.08 push, mark POPS in at 0.3s
Beat 2 [1.2-3.0s]  headline letters RISE staggered (0.07s apart), halo BREATHES behind them
Beat 3 [3.0-4.6s]  tagline WIPES on below, hero BREATHES, camera reaches the hero
Beat 4 [4.6-6.0s]  camera eases back to 1.04, glow dims slightly, everything settles
```

Then the manifest. Note the pattern: ambient sprites span 0 to 6 (never static), everything that must be
on the final frame has `end: 6`, entrances live in SHORT effect windows, letters are separate eids, the
eases differ by role, and every sprite has a friendly label:

```json
{
  "duration": 6, "width": 1920, "height": 1080,
  "camera": { "keyframes": [
    { "t": 0, "scale": 1.0 }, { "t": 0.65, "scale": 1.08, "ease": "inOutSine" }, { "t": 1, "scale": 1.04, "ease": "inOutSine" } ] },
  "sprites": [
    { "eid": "bg-glow-1", "label": "Glow left", "start": 0, "end": 6, "effect": { "name": "parallax-drift", "params": { "dx": 180, "dy": -120 } } },
    { "eid": "bg-glow-2", "label": "Glow right", "start": 0, "end": 6, "effect": { "name": "glow-pulse" } },
    { "eid": "mark", "label": "Atlas mark", "start": 0.3, "end": 6, "effect": { "name": "pop-in" }, "easing": "spring", "springBounce": 0.25 },
    { "eid": "hero-halo", "label": "Hero halo", "start": 0.3, "end": 6, "effect": { "name": "glow-pulse" } },
    { "eid": "h-1", "label": "Headline A", "start": 1.2, "end": 6, "effect": { "name": "rise-settle" } },
    { "eid": "h-2", "label": "Headline t", "start": 1.27, "end": 6, "effect": { "name": "rise-settle" } },
    { "eid": "h-3", "label": "Headline l", "start": 1.34, "end": 6, "effect": { "name": "rise-settle" } },
    { "eid": "h-4", "label": "Headline a", "start": 1.41, "end": 6, "effect": { "name": "rise-settle" } },
    { "eid": "h-5", "label": "Headline s", "start": 1.48, "end": 6, "effect": { "name": "rise-settle" } },
    { "eid": "headline-wrap", "label": "Headline breathe", "start": 2.4, "end": 6, "effect": { "name": "breathing-float" } },
    { "eid": "tagline", "label": "Tagline", "start": 3.0, "end": 6, "effect": { "name": "mask-wipe" }, "easing": "outQuart" }
  ]
}
```

(`headline-wrap` is a parent element around the letter spans: one element carries the entrance per
letter, the wrapper carries the ambient breathe, which is how a thing pops in AND keeps living.)

## See it before you ship it (mandatory frame review)
The manifest is not the render. Every `design_animate` call returns rendered frames of the key moments (opening, each beat after its entrance settles, midpoint, settled ending) plus a checklist. Judging those frames is NOT optional: before telling the user the piece is done, verify that the hero is visible and readable where it should be, no frame is dead air, text that must be read is fully on stage in at least one frame, and the ending frame is the settled composition you intended. Also hold them against the cinematic floor: the background is alive (not a flat fill), the headline is staggered (not a single block), entrances overshoot or settle (not a bare fade), and each beat has one focal point with readable contrast. If any check fails, fix the manifest and call `design_animate` again. Use `design_screenshot({ id, at })` to inspect any moment the review frames did not cover, for example the middle of an entrance. Only hand off once the frames actually look premium.
