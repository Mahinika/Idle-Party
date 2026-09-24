---
name: "pandaos-design-prototype"
description: "Create an interactive click-through prototype on the PandaOS Design canvas: gather the full spec (screens, flows, states, data) first, confirm the design system, then build with design_create using the declarative behavior format."
---
# Design a Prototype

You create a **prototype** — interactive, clickable, working client-side UI — on the PandaOS Design canvas. Designs are stored, versioned, and revertable by the tools — never write HTML files into the project.

## House rules (ALL designs, non-negotiable)
- **No emojis, ever.** Never put an emoji glyph in a heading, label, button, nav item, or body copy, and never use one as a stand-in for an icon. For every icon, embed an inline **lucide** SVG (or a lucide `<i data-lucide="...">` element plus the lucide script) — lucide icons only.
- **No em dashes (—) or en dashes (–) in visible copy.** Use a colon, a comma, or a plain hyphen instead.
- **Confirm the design is on screen when you finish.** `design_create`, `design_regenerate`, and `design_edit` open/refocus the canvas automatically, but if the user was left on the Design home, end your turn with `design_open({ designId })` so the finished prototype is actually showing — never leave them on the home screen after a build.

## The Flow

### 1. Do NOT open the canvas yet
Gather direction in the chat first — the Design tab opens by itself, on the finished design with a build animation, the moment `design_create` runs. Opening it earlier just shows an empty canvas that competes with your questions. Call `design_open` only with `{ designId }` to bring an EXISTING design back on screen, or when the user explicitly asks to see the Design app.

### 2. Intent first, then the FULL spec — prototypes go deepest
Open with purpose (via `generative_ui` short_form, or plain prose if `generative_ui` isn't discoverable — search tools for `generative_ui` first): what product, who uses it, what's the main thing they do. Then elaborate the actual spec before any build:
- **Target platform — ASK, never assume.** Is this a **desktop app**, a **mobile app**, or a **responsive web app**? This decides the design's `viewport` and the whole layout (wide multi-column filling the canvas vs. a single thumb-first column), so ask it explicitly with a `generative_ui` choice up front. Do NOT default to a phone frame just because the target wasn't stated.
- **Screen list** — every screen in the click-through.
- **Primary flows / navigation** — how screens connect; what the golden path is.
- **Key interactions** — which controls do something (tabs, modals, forms, toggles).
- **States to show** — empty / loading / active / error, per data-driven view.
- **Data** — what realistic placeholder content each screen shows.

**Depth gate: do NOT build after two questions.** This can take several form steps and/or conversational follow-up. Gather until the spec above is covered, then confirm the direction before building.

**Gather fresh for each NEW design.** If you already built a design earlier in this chat, do NOT carry its platform or direction over to a new one — re-ask for the new prototype. Intake is per-design, not per-conversation.

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
`design_create({ type: "prototype", title, html, designSystemId })` — ONE self-contained HTML file, CDN libraries allowed, no build step. Pass `viewport`: `desktop` for an app or site screen (the canvas renders it at the full width of the tab, so build it edge to edge like a real window, not as a centered narrow column), `mobile` for a phone screen, `page` for a printable document. Pass `designSystemId` when the user picked a saved system in step 3, or when step 2b's codebase import produced one. When the match came from reading the app rather than a pack, restate the extracted colors, radius, border, shadow, and font stacks as CSS custom properties at the top of the document and build off those. Stamp a stable `data-eid` on every meaningful element. Client-side only: placeholder data, no network calls.

### 6. Iterate, then hand off
Iterate with **`design_edit`** by default — surgical ops keyed by `data-eid` (`setStyle` / `setText` / `setBox` / `delete`) that preserve everything you don't touch, including the user's manual visual-editor edits, and are far cheaper than re-emitting the file. Use `design_export({ id })` to find a `data-eid` if you don't already have it. Reserve `design_regenerate` for a large redesign that rewrites most of the document. Every version is saved and revertable. When approved, offer `design_handoff` / `design_share` — the handoff bundle carries the frozen HTML, tokens, brief, and eid map for the real build.

## Interactivity — write real client-side JavaScript

Prototypes render in a **sandboxed iframe** (`allow-scripts`, no same-origin access, `connect-src 'none'`), so your JavaScript is fully contained: it can drive the UI but cannot reach the network, the parent app, or any real data. Because of that, **you may write ordinary inline `<script>` and normal event handlers** — build genuinely interactive UI: modals that overlay, conditional show/hide, tabs, forms that capture and validate input, multi-step flows, client-side state. Make the interactions the user named actually work.

Rules:
- **Client-side only.** No `fetch`/network (CSP blocks it) — use in-memory placeholder data. No real auth or persistence.
- **Keep it self-contained** in the one HTML file (inline `<script>`/`<style>` or an allowlisted CDN). **Tailwind CDN IS allowed and encouraged** (`<script src="https://cdn.tailwindcss.com"></script>`) — theme it inline with the real fonts/colors so it never looks like default Tailwind.
- **Keep `data-eid`** on every meaningful element so the visual editor and handoff still work. Prefer driving visible structure from the DOM you stamped rather than regenerating large subtrees, so element ids survive.

A lightweight **declarative behavior format** is also available if you want simple wiring without script (`data-do` = `set`/`append` state; `data-bind` mirrors `state[var]` into textContent; `data-screen` shows an element only when `state.screen` matches, switched via `data-do="set screen='<id>'"`). Use it for trivial toggles/screen-switches; reach for real JS whenever the interaction is richer than that.

## Prototype specifics
- Real interaction patterns: tabs switch, menus open, forms accept input, navigation navigates.
- Show realistic states (hover, active, empty, loading) — fidelity is "testable", not production code.
- Make the key interactions the user named actually work; don't fake the golden path.

## Craft floor (non-negotiable)
8pt spacing rhythm; modular type scale, max 2 families; body contrast ≥ 4.5:1; visible focus states ≥ 3:1; touch targets ≥ 24px; semantic HTML, keyboard operable, Escape closes overlays; one focal point per screen; empty/loading/error states designed, not skipped. No cramped spacing, no default-browser look.

## Motion & materials craft (real values — use when the brief fits, not an Apple mandate)
These are what separate a polished prototype from a cheap one. Reach for them when they serve the design; a crisp corporate dashboard stays restrained, a playful product leans in. All of this is plain CSS/inline JS and renders faithfully (the sandbox is real Chromium), so it costs nothing but judgment.
- **Easing — never `transition: all` or a bare built-in `ease-out`.** Use strong curves: `--ease-out: cubic-bezier(0.23, 1, 0.32, 1)` for UI enter/exit, `--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1)` for on-screen movement, `--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1)` for sheets. Never `ease-in` on an entrance — it delays the moment the user is watching.
- **Duration:** button press 100-160ms, tooltip 125-200ms, dropdown 150-250ms, modal/drawer 200-500ms. Keep UI motion under 300ms.
- **Physicality:** never animate from `scale(0)` — start `scale(0.96)` + `opacity: 0` (nothing appears from nothing). `:active { transform: scale(0.96) }` for press feedback (0.95-0.96 reads on large CTAs, 0.97 for dense UI). Popovers/menus/tooltips scale from their trigger via `transform-origin`; modals stay centered. Prefer CSS transitions over `@keyframes` for anything re-triggerable (transitions interrupt and retarget cleanly); use `@starting-style` for JS-free entry.
- **Asymmetric timing:** the deliberate action (a press, a hold) can be slower; the system's response snaps.
- **Materials — only when translucency serves hierarchy.** Glass chrome via `backdrop-filter: blur(20px) saturate(180%)` + a semi-transparent background + a bright 1px top edge; content scrolls underneath. Never stack two light translucent surfaces (legibility collapses). Dim-with-scrim for modal focus; translucent-offset-no-scrim for a parallel panel. Fade a scroll-edge gradient under sticky headers instead of a hard 1px divider.
- **Richer motion/effect libraries load ONLY from the allowlisted CDNs** (`cdn.jsdelivr.net`, `unpkg.com`, `cdnjs.cloudflare.com`): Motion One or GSAP for real springs & timelines, Lottie for vector micro-interactions, three.js for 3D. Any other host is blocked by the sandbox CSP and silently no-ops, so stick to those three. Default spring bounce low (0-0.2); reserve bounce for momentum-driven or playful interactions.
- **Reduced motion & hover:** honor `@media (prefers-reduced-motion: reduce)` (keep opacity/color, drop movement) and gate hover motion behind `@media (hover: hover) and (pointer: fine)`.

## See it before you ship it (self-review)
After you build or edit, call `design_screenshot({ id })` and LOOK at the rendered PNG before telling the user it is done — otherwise you are flying blind on how it actually looks. Judge the render against the craft floor and the motion/materials notes above: clear hierarchy with one focal point, 8pt rhythm, readable contrast, designed empty/loading/error states, no cramped spacing, no default-Tailwind/generic look. Fix what looks cheap with `design_edit`, then screenshot again. Ask one more question of the render: would this pass for a screen of the actual app? If you matched an existing product, compare the render against the values you extracted (radius, border, shadow, density, type) and fix the drift. Only hand off once it genuinely looks right and looks like it belongs.
