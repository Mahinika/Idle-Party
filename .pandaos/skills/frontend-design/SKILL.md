---
name: frontend-design
description: "Frontend UI design review: evaluate visual hierarchy, spacing, typography, color, interaction patterns, and responsiveness."
user-invocable: true
disable-model-invocation: false
model: sonnet
source: pandaos
allowed-tools: Read, Grep, Glob
---

# Frontend Design Review

A structured review of frontend UI against design principles: visual hierarchy, consistency, accessibility basics, and responsive behavior.

## STEP 1: IDENTIFY SCOPE

Parse $ARGUMENTS for the component, page, or feature to review. If not specified, review all recently changed UI files.

## STEP 2: VISUAL HIERARCHY

Audit the structure of the UI:
- Is there a clear primary action? Does it stand out from secondary actions?
- Does the layout guide the eye naturally (top-to-bottom, left-to-right for LTR)?
- Are headings, body text, and captions visually distinct?
- Is information density appropriate — no wall of text, no excessive whitespace?

## STEP 3: SPACING AND ALIGNMENT

- Are spacing values from the design system (not arbitrary pixel values)?
- Is alignment consistent — elements align to a grid or shared baseline?
- Are interactive elements (buttons, inputs) large enough to tap on mobile (minimum 44x44px)?

## STEP 4: TYPOGRAPHY

- No more than 2-3 font weights per page
- Line length between 60-80 characters for body text
- Sufficient contrast between text and background (at minimum 4.5:1 for normal text)
- Font sizes scale appropriately between mobile and desktop

## STEP 5: COLOR USAGE

- Color is not the only indicator of state (success, error, disabled) — pair with text or icon
- Interactive states (hover, focus, active) are visible and distinct
- Dark mode support if the project uses it

## STEP 6: INTERACTION PATTERNS

- Loading states for async operations — no layout shift when content loads
- Error states are actionable (what went wrong, how to fix)
- Empty states explain why the content is missing and what to do
- Destructive actions require confirmation

## STEP 7: RESPONSIVENESS

- Layout works at 320px, 768px, and 1280px widths
- No horizontal scroll at any breakpoint
- Text is readable without zooming on mobile

## STEP 8: FINDINGS REPORT

Output a structured report:
- Issues found with file path and line reference
- Severity: Critical (blocks use) / Moderate (degrades experience) / Minor (polish)
- Specific fix recommendation for each

## COMPONENT ARCHITECTURE PATTERNS

Choose the right pattern for each component's complexity:

| Pattern | When to Use | Example |
|---------|------------|---------|
| **Simple props** | Leaf components with < 5 props | `<Button variant="primary" onClick={...}>` |
| **Compound components** | Related components sharing implicit state | `<Tabs><Tab /><TabPanel /></Tabs>` |
| **Render props / Slots** | Customizable rendering with shared logic | `<DataTable renderRow={(row) => ...}>` |
| **Custom hooks** | Reusable stateful logic without UI opinion | `useDebounce()`, `useMediaQuery()` |

Rules:
- Extract a component when it exceeds 100 lines of JSX
- Never pass more than 5 props without using a compound or options pattern
- Keep state as close to where it's used as possible

## DESIGN SYSTEM METHODOLOGY

A design system is a shared vocabulary, not a component library.

| Layer | Contains | Changes How Often |
|-------|---------|-------------------|
| **Tokens** | Colors, spacing, typography, shadows | Rarely (brand changes) |
| **Primitives** | Button, Input, Card, Badge | Occasionally (design evolution) |
| **Patterns** | Form layouts, data tables, navigation | Regularly (feature needs) |
| **Templates** | Page layouts, dashboards | Per-feature |

Rules:
- Tokens are the single source of truth - never hardcode `#3b82f6` when `--color-primary` exists
- Primitives are unopinionated about layout - they don't set margins
- Patterns compose primitives with layout and behavior

## STATE MANAGEMENT GUIDANCE

| Scope | Tool | Example |
|-------|------|---------|
| **Component** | `useState` / `useReducer` | Form input, toggle, accordion |
| **Shared (few components)** | Lift state up / Context | Theme, current user |
| **Global (app-wide)** | Zustand / Redux | Session, settings, navigation |
| **Server** | React Query / SWR | API data, cache |

Rule: Start with the smallest scope. Promote to global only when 3+ unrelated components need the same state.

## WCAG 2.1 AA COMPLIANCE

Minimum accessibility requirements for every component:

| Requirement | Standard | How to Verify |
|-------------|----------|---------------|
| Color contrast | 4.5:1 normal text, 3:1 large text | Chrome DevTools Accessibility audit |
| Keyboard navigation | All interactive elements reachable via Tab | Manual keyboard-only testing |
| Focus indicators | Visible focus ring on every interactive element | Visual inspection with keyboard nav |
| Screen reader labels | All images have alt text, all controls have labels | aXe or Lighthouse audit |
| Motion preferences | Respect `prefers-reduced-motion` | CSS media query check |

## ANTI-PATTERNS

- Relying on color alone to convey meaning
- Fixed pixel sizes that break on smaller screens
- Missing loading/error/empty states
- Inconsistent spacing that breaks the grid

## ANTI-RATIONALIZATION TABLE

| Shortcut | Why It Fails | Do This Instead |
|----------|-------------|-----------------|
| "Accessibility is a nice-to-have" | It's a legal requirement in many jurisdictions and affects 15% of users | Build accessible from the start - retrofitting is 10x harder |
| "We'll add dark mode support later" | Color values get hardcoded everywhere | Use design tokens from day one |
| "This component needs just one more prop" | Prop explosion makes components unusable | Use compound components or composition |
| "Let's build our own design system" | Custom systems are 10x more maintenance than adopting one | Extend an existing system (Radix, shadcn) unless you have dedicated design resources |

## PERFORMANCE PATTERNS

### Virtualization

For long lists or large tables, never render all rows into the DOM. Use `@tanstack/react-virtual` to render only the visible window:

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';

const rowVirtualizer = useVirtualizer({
  count: rows.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 48,   // estimated row height in px
  overscan: 5,              // extra rows above/below the visible window
});

// In JSX: map over rowVirtualizer.getVirtualItems() only
// Set the container height to rowVirtualizer.getTotalSize()
```

Rules:
- Use virtualization for any list exceeding ~100 items
- For tables with variable row heights, use `measureElement` instead of `estimateSize`
- Always set an explicit height on the scroll container — virtualization requires a bounded scroll area

### Image Optimization

| Technique | When | How |
|-----------|------|-----|
| **Modern formats** | All images | Serve WebP with AVIF for supporting browsers; keep JPEG/PNG as fallback via `<picture>` |
| **Responsive sizing** | Any image that changes size across breakpoints | Use `srcset` + `sizes`, or `next/image` with `sizes` prop |
| **Lazy loading** | Images below the fold | `loading="lazy"` on `<img>`; `priority` prop on `next/image` for LCP images |
| **Explicit dimensions** | All images | Always set `width` + `height` to prevent CLS |

### Service Worker and PWA Caching

Cache strategy by asset type:

| Asset | Strategy | Rationale |
|-------|----------|-----------|
| App shell (HTML, JS, CSS) | Cache-first with version invalidation | Fast loads; update on deploy |
| API responses | Stale-while-revalidate | Fresh data without blocking render |
| Images and fonts | Cache-first, long TTL | Immutable assets; save bandwidth |
| User data | Network-first | Consistency is critical |

Use Workbox (`vite-plugin-pwa`) rather than hand-rolling service worker logic.

### Bundle Code Splitting

- Use `React.lazy` + `Suspense` for route-level code splitting — the default starting point
- Use dynamic `import()` for heavy third-party libraries loaded conditionally (e.g., chart libraries, PDF viewers)
- Check bundle composition with `rollup-plugin-visualizer` or `webpack-bundle-analyzer` before shipping
- Never import an entire icon library — import individual icons only

```tsx
// Route-level splitting
const SettingsPage = React.lazy(() => import('./pages/SettingsPage'));

// Conditional library loading
const { Chart } = await import('chart.js');
```

## CROSS-BROWSER VERIFICATION CHECKLIST

Before marking any UI feature complete, verify across:

| Browser | Engine | Minimum Version |
|---------|--------|-----------------|
| Chrome | Blink | Last 2 releases |
| Firefox | Gecko | Last 2 releases |
| Safari | WebKit | Last 2 releases (macOS + iOS) |
| Edge | Blink | Last 2 releases |

Checklist:
- [ ] CSS Grid / Flexbox layout renders correctly
- [ ] CSS custom properties (variables) resolve
- [ ] Animations and transitions are smooth (check Safari especially for transform/opacity)
- [ ] `position: sticky` works within scroll containers
- [ ] Form inputs render consistently (Safari has heavy default styling)
- [ ] `focus-visible` polyfill or native support confirmed for focus rings
- [ ] WebP/AVIF images fall back gracefully in older Safari
- [ ] Font loading does not cause FOUT (use `font-display: swap` or `optional`)
- [ ] JS APIs used are in the project's browserslist target (check MDN or caniuse.com)
