---
name: pandaos-design
description: "Design UI on the PandaOS Design canvas: open the canvas, gather direction with generative_ui, build a saved, revertable prototype/mockup, and hand it off — applying frontend UX craft (hierarchy, 8pt spacing, type scale, WCAG contrast, empty/loading/error states, accessible interaction). Use for any UI design work in PandaOS — not standalone HTML files."
user-invocable: true
disable-model-invocation: false
source: pandaos
---

# PandaOS Design

You design UI on the **PandaOS Design canvas** using the design tools. Designs are stored, versioned, and revertable by the tools themselves — never write mockup HTML into the project (`.pandaos/ux/`, temp files, project root).

**Route to the per-type skill first.** Each design type has a dedicated skill carrying its full flow and technical contract — prefer it over this generic one when the type is known:

* **App development / clickable UI** → `pandaos-design-prototype`
* Static high-fidelity screen → `pandaos-design-mockup`
* One-pager / report / brief → `pandaos-design-document`
* Deck / presentation → `pandaos-design-slides` (structured slide engine — `design_slides_create`, NOT `design_create`)
* Animated intro / product reel → `pandaos-design-motion`
* Product demo / screen recording (record, auto-zoom on clicks, MP4 export) → `pandaos-design-product-demo` (no direction gathering: create it immediately with `design_create type "product-demo"`, the user records on the canvas)

This skill is the shared reference: the flow below plus the Design Craft section the per-type skills build on.

## House rules (ALL designs, non-negotiable)
- **No emojis, ever.** Never put an emoji glyph in a heading, label, button, nav item, or body copy, and never use one as a stand-in for an icon. For every icon, embed an inline **lucide** SVG (or a lucide `<i data-lucide="...">` element plus the lucide script) — lucide icons only.
- **No em dashes (—) or en dashes (–) in visible copy.** Use a colon, a comma, or a plain hyphen instead.
- **Confirm the design is on screen when you finish.** `design_create`, `design_regenerate`, and `design_edit` open/refocus the canvas automatically, but if the user was left on the Design home, end your turn with `design_open({ designId })` so the finished design is actually showing — never leave them on the home screen after a build.

## The Flow

### 1. Do NOT open the canvas yet

For a NEW design, don't call `design_open` up front — the Design tab opens by itself, on the finished design with a build animation, the moment `design_create` (or `design_slides_create`) runs. Opening it earlier just shows an empty canvas that competes with your questions in chat. `design_open({ designId })` is for bringing an EXISTING design back on screen (or when the user explicitly asks to see the Design app). Iterating on one you already made? Skip to step 3 and edit it with `design_edit` (see the iterate rule below).

### 2. Gather direction with `generative_ui`

Before building, if the color, font, or layout direction is unclear, ask for it with the `generative_ui` tool so the user picks from real, interactive UI and their selection comes straight back to you. Never hand-write an inline \`\`\`html swatch block or wireframe for this.

Use `generative_ui` only where the component previews the design itself:

* Color palette → **palette\_picker** (real swatches)
* Page / screen layout → **layout\_chooser** (wireframe thumbnails)
* Font pairing → **type\_pairing\_picker** (live type specimens)

Do NOT use `generative_ui` sliders for spacing, type scale, or border radius — abstract numbers have no visual feedback out of context. Set those on the design itself where they render, or offer a few named steps (Compact / Comfortable / Spacious) as a normal worded question.

`generative_ui` isn't in the default tool list — discover it with tool search (search `generative_ui`) before calling. Use one card per question, and only when it beats a plain worded question. Gather direction up front, before you build — once the design is on the canvas, the user reacts to the real thing.

### 2a. Match the app you are designing for, before you invent a look

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

### 2b. One visual palette picker — saved systems live INSIDE it, not behind a yes/no

Handle the design system as part of the palette step — do NOT ask a separate "reuse saved vs
propose new" question first. Call `design_system_list` (packs from the project + the global personal
library, each with its colors, scope, and id). Then present a **single `palette_picker`** whose
`options` are, in order:

1. **Each saved design system as a real swatch** — use the pack's own `colors`, set the option `id`
   to the pack id, label by name + scope. The current/on-brand system sits in the actual picker so
   the user picks it visually alongside fresh ideas.
2. **3–4 fresh proposed palettes** tuned to the brief — distinct directions, each previewed by its colors.

Leave `allowCustom` on so "Something else…" returns a described direction; for importing, point to
the **Design systems** panel or `design_system_import`.

* Never gate the palette behind a worded question — the saved system is one of the swatches.
* If the returned selection `id` matches a saved pack, pass it to `design_create` as `designSystemId`
  and skip the fresh type picker (the pack defines its fonts). If it's a fresh palette, carry its
  colors into the build.
* If NO packs exist, the style extracted from the codebase (step 2a) IS the first swatch, labelled "Current app style", shown alongside the fresh proposals. Never block.
* If `generative_ui` is unavailable, fall back to a plain worded choice listing saved systems by name +
  scope alongside a few proposed directions.

### 3. Build it

Build a single self-contained HTML document and pass it to the tools:

* First version → `design_create({ type, title, html })`
* Iterate → **prefer `design_edit({ id, ops })`** (surgical, by `data-eid`). Reserve `design_regenerate({ id, html })` for a full redesign that rewrites most of the document — see the iterate rule below.

Rules for the HTML:

* Stamp a stable `data-eid` on every meaningful element so it stays editable and trackable across versions
* Inherit the project design system; pass `designSystemId` when building on a saved pack
* Pass `viewport` so the canvas sizes it right: `desktop` for an app or site screen (rendered at the full width of the tab, so lay it out edge to edge like a real window, never as a centered narrow column), `mobile` for a phone screen, `page` for a printable document
* Prototypes are interactive via the **declarative behavior format**, never arbitrary scripts — make key interactions work (toggles toggle, modals open, nav navigates)
* Use realistic data (real names, plausible numbers — no Lorem ipsum)
* Show important states (populated + empty at minimum)
* Match the project's existing visual language

Build **one** living design and shape it with the user, rather than several blind variations — you gathered direction in step 2, so you don't need to guess in triplicate.

### 4. Present, iterate, hand off

The design renders live on the canvas. Tell the user what it explores and ask for approval or changes. Do NOT treat it as final until the user approves.

**See it before you ship it.** After you build or edit, call `design_screenshot({ id })` and LOOK at the rendered PNG before telling the user it is done — you are otherwise blind to how it actually looks. It works for every visual type (prototype, mockup, document, freeform, motion, product demo; pass `{ at }` in seconds to grab a specific moment of a motion or product demo — decks are the exception, open them in the app). Judge the render against the Design Craft section below and fix what looks cheap with `design_edit`, then screenshot again. Ask one more question of the render: would this pass for a screen of the actual app? If you matched an existing product, compare the render against the values you extracted (radius, border, shadow, density, type) and fix the drift. Only hand off once it genuinely looks right and looks like it belongs.

**Iterating — edit, don't regenerate (CRITICAL).** When the user asks for a change, default to `design_edit({ id, ops })`, NOT `design_regenerate`. `design_edit` makes surgical, ordered ops keyed by `data-eid` — `setStyle` / `setText` / `setBox` / `delete` — against the current saved version, so everything you don't touch (including the user's own manual visual-editor edits) is preserved, and it's far cheaper than re-emitting the whole file. To find the target `data-eid`, recall the ones you stamped at build time, or call `design_export({ id })` to read the current HTML and locate it. Reach for `design_regenerate` ONLY when the change is a large redesign or structural overhaul that rewrites most of the document. Every version is saved and revertable either way, so you can always roll back.

When approved, the design `id` is the reference: `design_handoff({ id })` returns the frozen HTML, the resolved design-system tokens, the intent/brief, and the stable-id map for the developer. `design_share({ id })` produces a public view-only link.

## Design Craft

Craft is not decoration — it is what separates a polished, trustworthy product from one that feels clumsy. Every design must satisfy the fundamentals below, then earn its aesthetic character on top. Do not ship a design that skips the states, the accessibility floor, or the spacing system.

### Visual hierarchy

Guide the eye from primary action to secondary detail using scale, weight, contrast, spacing, and alignment — not just size. One clear focal point per screen; the primary action should be the most visually prominent element. Establish 2-3 levels of hierarchy and hold them consistently.

### Layout & spacing

* Work on an **8pt grid** — dimensions, padding, and margins in multiples of 8 (use 4 for fine tuning). A spacing scale of **4, 8, 12, 16, 24, 32, 48, 64, 96** covers almost every need.
* **Internal \< external:** space *within* a group is tighter than space *between* groups — this is what makes relationships read without borders.
* Align to a **12-column grid**; consistent alignment reads as intentional. Cap body measure around 60-75 characters.
* Give elements room to breathe — generous whitespace beats cramming.

### Typography

* Use a **modular scale** (ratio \~1.2-1.33) so sizes relate rather than being picked at random.
* Line-height on a 4/8 rhythm; \~1.4-1.6 for body, tighter for headings. Limit to **2 families** (or two weights of one).
* Distinctive, context-appropriate fonts over generic defaults (avoid Inter, Roboto, Arial, Space Grotesk, system fonts unless the brief demands neutrality). Use Google Fonts.

### Color & contrast (accessibility floor — non-negotiable)

* Body text ≥ **4.5:1** contrast against its background; large text (≥24px, or ≥19px bold) ≥ **3:1**.
* UI component boundaries and states (borders, icons, focus rings) ≥ **3:1** against adjacent colors.
* Commit to a cohesive palette via CSS variables; dominant colors with sharp accents beat timid, evenly-distributed ones. Never rely on color alone to convey meaning — pair with icon, text, or shape.

### Accessibility

* Semantic HTML: real `<button>`, `<nav>`, `<label>`, headings in order. Icon-only controls need `aria-label`; images need `alt`.
* **Visible focus states** on every interactive element — focus ring ≥ 3:1 contrast and at least a 2px perimeter; never `outline: none` without a replacement.
* **Touch targets** ≥ 24×24px (AA); aim for **44×44px** on touch surfaces, with spacing so neighbors aren't mis-tapped.
* Fully keyboard operable; logical tab order; Escape closes overlays; modals trap focus. Respect `prefers-reduced-motion`.

### The three states (the ones AI usually forgets)

Design every data-driven view for all of these, not just the happy path:

* **Empty:** explain what goes here and give a clear call-to-action to create the first item — never a blank void.
* **Loading:** prefer **skeleton screens** that mirror the final layout over spinners (they cut perceived wait and preserve structure). Show feedback within \~50ms of any action.
* **Error:** say what went wrong in plain language and how to recover; keep the user's input. Also consider offline and permission-denied.

### Interaction & feedback

* Every action gets immediate, visible feedback (hover, active, pressed, selected, disabled). Design all of these states, not just the default.
* **Microinteractions** confirm "something happened" — a toggle that animates, a button that depresses, a checkmark on success.
* Make destructive actions confirm; make undo available where you can.

### Forms

* **Labels above fields**, always visible — placeholders are format hints, not labels. Mark required with `*`, or label optional fields "optional".
* **Single-column** layout; group related fields. Match input types (`email`, `tel`, `number`) and set `autocomplete`.
* **Inline validation** after a field is completed, with the message next to the offending field — not a summary dumped at the top on submit.

### Target platform (confirm it — never assume mobile)

* **Always design for the platform the user confirmed** — a desktop app, a mobile app, or a responsive web page are different shapes. Never default to a phone frame because it wasn't stated; if the target is unclear, ask (see the per-type skills' platform step) before building.
* **Desktop / web app:** design for a wide viewport first — multi-column layouts, sidebars, hover affordances, denser information. Do not cram it into a single phone column.
* **Mobile app:** then design thumb-first — primary actions within thumb reach, single-column, larger tap targets, bottom-anchored nav.
* **Responsive web:** use fluid layouts and test the real breakpoints; content reflows across sizes, it doesn't just shrink.

### Aesthetics — resist "AI slop"

Once the fundamentals hold, give the design genuine character:

* **Motion:** CSS-first micro-interactions; one well-orchestrated page load with staggered reveals (`animation-delay`) delights more than scattered effects.
* **Backgrounds:** create atmosphere and depth — layered gradients, geometric patterns, contextual effects instead of flat solids.
* **Lean on real libraries — don't hand-roll generic CSS.** The sandbox allows CDN scripts, so USE them for a polished, non-generic result: **Tailwind CDN** (`<script src="https://cdn.tailwindcss.com"></script>`) is the fastest path to a competent, consistent layout system — configure the theme inline (`tailwind.config = { theme: { extend: {...} } }`) with the project's real fonts/colors so it never looks like default Tailwind. Pull **icons** from a set (Lucide/Heroicons via CDN or inline SVG) instead of emoji or unicode. Reach for established component *patterns* (a proper card, a real data table, a segmented control, a toast) rather than reinventing each — a recognizable, well-built component reads as premium; a bespoke half-built one reads as AI slop.
* **Draw from** IDE themes and cultural aesthetics for a point of view.
* **Avoid clichés:** purple gradients on white, generic hero + three-cards layouts, cookie-cutter components, design with no context-specific character. Using Tailwind is encouraged; using it with its *default* palette/fonts and no theme config is exactly the generic look to avoid — always theme it.

Interpret creatively and make unexpected choices — but never at the cost of the fundamentals above. Each design should feel genuinely made for *this* product, and be usable by everyone.