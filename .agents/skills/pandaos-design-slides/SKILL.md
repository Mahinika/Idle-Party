---
name: "pandaos-design-slides"
description: "Create a slide deck in the PandaOS Design app: gather the deck's purpose, audience, and outline first, confirm the design system, then build with design_slides_create (the structured slide engine, NOT design_create's HTML path)."
---
# Design a Slide Deck

You create a **slide deck** in the PandaOS Design app. Decks use the **structured slide engine** — build them with `design_slides_create` / `design_slides_modify`, **NOT** `design_create`'s HTML path and NOT hand-written HTML. They appear in the Design library as the Slides type and export to PPTX. (These tools sit in the `design_*` namespace alongside `design_create` / `design_animate`.)

## House rules (ALL designs, non-negotiable)
- **No emojis, ever.** Never put an emoji glyph in a heading, label, button, nav item, or body copy, and never use one as a stand-in for an icon. For every icon, embed an inline **lucide** SVG (or a lucide `<i data-lucide="...">` element plus the lucide script) — lucide icons only.
- **No em dashes (—) or en dashes (–) in visible copy.** Use a colon, a comma, or a plain hyphen instead.
- **Confirm the design is on screen when you finish.** The deck tools open/refocus the canvas automatically, but if the user was left on the Design home, end your turn with `design_open({ designId })` so the finished deck is actually showing — never leave them on the home screen after a build.

## The Flow

### 1. Do NOT open the canvas yet
Gather direction in the chat first — the Design tab opens by itself, on the finished design with a build animation, the moment `design_slides_create` runs. Opening it earlier just shows an empty canvas that competes with your questions. Call `design_open` only with `{ designId }` to bring an EXISTING design back on screen, or when the user explicitly asks to see the Design app.

### 2. Intent first — the outline is the spec
Open with purpose, not style. Gather (via `generative_ui` short_form, or plain prose if `generative_ui` isn't discoverable — search tools for `generative_ui` first):
- What is the deck for — pitch / report / training / talk?
- Who is the audience, and what should they decide or remember?
- Rough outline: which sections, roughly how many slides?
- Tone — formal / energetic / minimal?

**Depth gate: do NOT build after two questions.** A deck needs an outline first — propose one, get it confirmed, THEN build. Never generate slides from a one-line ask.

**Gather fresh for each NEW deck** — don't carry a prior design's direction over to a new deck in the same chat. Intake is per-design.

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
2. **3–4 fresh proposed palettes** tuned to the brief — distinct directions, each previewed by its
   colors.
Leave `allowCustom` on so "Something else…" returns a described direction; for importing, point to
the **Design systems** panel or `design_system_import`.

- Never gate the palette behind a worded question — the saved system is one of the swatches.
- If the returned selection `id` matches a saved pack, pass it to `design_slides_create` as
  `designSystemId`. If it's a fresh palette, carry its colors into the deck style.
- If NO packs exist, the style you extracted in step 2b IS the first swatch (label it "Current app style"), shown alongside the fresh proposals. Never block.
- If `generative_ui` is unavailable, fall back to a plain worded choice listing saved systems by name +
  scope alongside a few proposed directions.

### 4. Type direction
After the palette, confirm the heading/body type direction (a short `generative_ui` or plain question).
Skip this when the user picked a saved design system — it already defines its fonts.

### 5. Build
`design_slides_create` with the confirmed outline and the chosen direction. When the user picked a
saved system in step 3, pass its id as `designSystemId` so the deck theme starts on-brand. The
deck opens in the deck editor on the Design canvas (a saved system also appears under "Your design
systems" in the deck's Theme picker for one-click reapply).

### 6. Iterate, then export
Iterate with `design_slides_modify` (targeted slide changes). Offer `design_slides_export` (PPTX / PDF) or `design_slides_export_google` when approved.

## Deck specifics
- One idea per slide; the headline states the takeaway (assertion-evidence), not a topic label.
- Big type, generous margins; visuals over bullet walls — max ~5 bullets when bullets are unavoidable.
- A clear arc: hook → context → argument/content → takeaway → ask.
- Real content over lorem; consistent slide-to-slide layout rhythm per the design system.

## Compose — do NOT fill the same three templates (this is what makes decks boring)
The engine has ~28 layouts. A deck built almost entirely from `title-body`, `two-column`, and `stats`
reads as flat and template-y — that is the #1 failure. Actively reach across the full palette and
match the layout to the *shape of the idea*, not the other way round:

- **Openers / breaks** — `cover`, `section` (use `section` as a full-bleed divider between acts, not just slide 1).
- **One number that matters** → `big-number`, not a `stats` row. A single stat gets a whole slide.
- **A claim worth landing** → `callout` or `quote` — give it the frame, don't bury it in `title-body`.
- **A set of capabilities / benefits** → `feature-rows` (icon + heading + blurb, 3–4) or `card-grid`
  (4 or 6 icon cards). These beat a bullet wall — each point gets an icon and breathing room.
- **Evidence / trends** → `chart` (bar/line/pie/area) over a table of numbers; `stats` only for 3–4 peer metrics.
- **Two things opposed** → `comparison` (before/after, us/them), not two neutral columns.
- **Sequence / roadmap / how-it-works** → `process` (numbered steps) or `timeline` (dated). **People** → `team`.
- **Anything visual** → `image-full`, `image-left/right`, `image-quote`, `image-stats`. A pitch/story deck
  with zero imagery is a red flag — pass a real `imageUrl`, or call `design_slides_add_image` (URL or
  data-URL → durable `asset://`) when you need a background photo (background images require an `asset://`).

**Icons** on `feature-rows` / `card-grid` are lucide names (e.g. `sparkles`, `trending-up`, `shield`,
`zap`, `target`, `rocket`, `users`, `lock`, `globe`, `check-circle`, `lightbulb`, `bar-chart`). An
unknown name falls back gracefully — prefer a real, on-topic icon per item.

**Rhythm rule:** vary the layout every 1–2 slides and break the light background with a dark or
accent-colored slide at each section boundary. Use per-slide `setSlideStyle` overrides for drama —
`appearance: 'dark'` section dividers, an `accent`/`background` emphasis slide, `backgroundImage` for
hero moments. A deck that never changes background or layout is the boring default you are avoiding.

**Anti-void rule (critical):** NEVER drop a short paragraph into `title-body` — its body fills the slide,
so thin text leaves 60%+ dead space (exactly the "boring" look). If content is thin, pick a layout that
*fills* the frame with meaning (`big-number`, `section`, `quote`, `callout`, an image layout) or add a
supporting visual/chart. A near-empty slide is never acceptable — either give it presence or merge it.

**Match richness to deck type — do NOT over-decorate everything.** The right amount of visual is set
by what you learned in step 2:
- **Pitch / marketing / talk / story** → high richness. Every content slide should earn a *visual or
  structural device* (an image, chart, `big-number`, `callout`, `comparison`, `timeline`) — never a
  bare title + paragraph. Lean on imagery and dark/accent section breaks.
- **Report / research / training / internal** → restraint reads as clarity. Structured layouts
  (`stats`, `comparison`, `chart`, `table`) and disciplined whitespace beat decoration; skip
  full-bleed imagery and heavy accent slides. Variety still applies — vary *structure*, not ornament.
When no real imagery is available, do NOT fall back to `title-body`; reach for the structural layouts
(`big-number`, `callout`, `comparison`, `timeline`, `stats`, `quote`) that create presence from text alone.

## Craft floor (non-negotiable)
Consistent type scale across slides, max 2 families; contrast ≥ 4.5:1 for body text; one focal point per slide; restrained palette led by the design system; no cramped slides, no default-template look. No deck where more than ~half the slides share one layout, and no slide left mostly empty.
