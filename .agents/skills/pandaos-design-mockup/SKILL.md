---
name: "pandaos-design-mockup"
description: "Create a static high-fidelity mockup on the PandaOS Design canvas: gather intent and visual direction first, confirm the design system, then build with design_create and iterate."
---
# Design a Mockup

You create a **mockup** — a static, high-fidelity screen or layout — on the PandaOS Design canvas. Designs are stored, versioned, and revertable by the tools — never write HTML files into the project.

## House rules (ALL designs, non-negotiable)
- **No emojis, ever.** Never put an emoji glyph in a heading, label, button, nav item, or body copy, and never use one as a stand-in for an icon. For every icon, embed an inline **lucide** SVG (or a lucide `<i data-lucide="...">` element plus the lucide script) — lucide icons only.
- **No em dashes (—) or en dashes (–) in visible copy.** Use a colon, a comma, or a plain hyphen instead.
- **Confirm the design is on screen when you finish.** `design_create`, `design_regenerate`, and `design_edit` open/refocus the canvas automatically, but if the user was left on the Design home, end your turn with `design_open({ designId })` so the finished design is actually showing — never leave them on the home screen after a build.

## The Flow

### 1. Do NOT open the canvas yet
Gather direction in the chat first — the Design tab opens by itself, on the finished design with a build animation, the moment `design_create` runs. Opening it earlier just shows an empty canvas that competes with your questions. Call `design_open` only with `{ designId }` to bring an EXISTING design back on screen, or when the user explicitly asks to see the Design app.

### 2. Intent first — never pixels first
Open with purpose, not style. Gather (via `generative_ui` short_form, or plain prose if `generative_ui` isn't discoverable — search tools for `generative_ui` first):
- **Target platform — ASK, never assume.** Desktop / web, mobile app, or responsive web? This sets the design's `viewport` and its whole layout shape, and a desktop answer means the design fills the canvas width rather than sitting in a centered column. Ask it explicitly; don't default to a phone frame.
- Which single screen or section is this — and for what product?
- Who uses it, and what's the main thing they do on this screen?
- What real content should it show (navigation, data, copy)?

**Depth gate: do NOT build after two questions.** Gather until you can build something real, then confirm the direction in one sentence before building.

**Gather fresh for each NEW design** — don't carry a prior design's platform or direction over to a new mockup in the same chat. Intake is per-design.

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

### 4. Remaining visual direction — vibe, density, layout
Vibe (minimal / bold / playful / corporate / dark), density, and (optionally) an overall layout via
`generative_ui` `layout_chooser`; plain questions otherwise. Colors already came from the step-3 palette
picker. Skip when the user picked a saved design system in step 3.

### 5. Build
`design_create({ type: "mockup", title, html, designSystemId })` — ONE self-contained HTML file, CDN libraries allowed, no build step. Pass `viewport`: `desktop` for an app or site screen (the canvas renders it at the full width of the tab, so build it edge to edge like a real window, not as a centered narrow column), `mobile` for a phone screen, `page` for a printable document. Pass `designSystemId` when the user picked a saved system in step 3, or when step 2b's codebase import produced one. When the match came from reading the app rather than a pack, restate the extracted colors, radius, border, shadow, and font stacks as CSS custom properties at the top of the document and build off those. Stamp a stable `data-eid` on every meaningful element.

### 6. Iterate, then hand off
Iterate with **`design_edit`** by default — surgical ops keyed by `data-eid` (`setStyle` / `setText` / `setBox` / `delete`) that preserve everything you don't touch, including the user's manual visual-editor edits, and are far cheaper than re-emitting the file. Use `design_export({ id })` to find a `data-eid` if you don't already have it. Reserve `design_regenerate` for a large redesign that rewrites most of the document. Every version is saved and revertable. When approved, offer `design_handoff` / `design_share`.

## Mockup specifics
- Static, high-fidelity: layout, hierarchy, and component design carry the weight. No behavior required.
- Realistic content over lorem — real names, plausible numbers; reflect the brand.
- Styled cards / nav / buttons / forms per the design system; match the product's existing visual language.
- Show the populated state well; include an empty state if the screen is data-driven.

## Craft floor (non-negotiable)
8pt spacing rhythm; modular type scale, max 2 families; body contrast ≥ 4.5:1; visible focus states; semantic HTML; one focal point per screen; internal spacing tighter than external; labels above form fields. No cramped spacing, no purple-gradient-on-white cliché, no default-browser look.

## Materials & depth craft (use when it serves hierarchy — not a mandate)
The mockup is static, so its fidelity is carried by surface, depth, and type. Reach for these when the brief fits; a restrained corporate report stays flat and crisp, a premium product surface leans into depth. It all renders faithfully (real Chromium capture), so it costs nothing but judgment.
- **Depth over flat fills:** layered gradients, a soft glow or two, a subtle vignette, and real shadows (`0 30px 80px -20px rgba(0,0,0,.5)`) beat a single flat color. Give the focal element the most depth.
- **Materials — only when translucency serves hierarchy:** glass chrome via `backdrop-filter: blur(20px) saturate(180%)` + a semi-transparent background + a bright 1px top edge. Never stack two light translucent surfaces (legibility collapses); use heavier material to separate structural regions, lighter to lift interactive elements.
- **Type carries fidelity:** a distinctive display face + tight heading leading + a real modular scale reads as designed; default system fonts read as a wireframe. Load fonts from Google Fonts (allowed) and richer layout/icon helpers only from the allowlisted CDNs (`cdn.jsdelivr.net`, `unpkg.com`, `cdnjs.cloudflare.com`, `cdn.tailwindcss.com`) — any other host is blocked by the sandbox and silently no-ops.

## See it before you ship it (self-review)
After you build or edit, call `design_screenshot({ id })` and LOOK at the rendered PNG before telling the user it is done — otherwise you are flying blind on how it actually looks. Judge the render against the craft floor and the materials notes above: clear hierarchy with one focal point, 8pt rhythm, readable contrast, real depth not flat fills, no cramped spacing, no default-Tailwind/generic look. Fix what looks cheap with `design_edit`, then screenshot again. Ask one more question of the render: would this pass for a screen of the actual app? If you matched an existing product, compare the render against the values you extracted (radius, border, shadow, density, type) and fix the drift. Only hand off once it genuinely looks right and looks like it belongs.
