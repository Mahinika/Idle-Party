---
name: web-assets
description: "Optimize web assets: compress images, convert to modern formats, generate responsive variants, inline critical SVGs."
user-invocable: true
disable-model-invocation: false
model: sonnet
source: pandaos
allowed-tools: Bash, Glob, Read
---

# Web Asset Optimization

Systematic audit and optimization of web assets to reduce page weight and improve loading performance.

## STEP 1: INVENTORY ASSETS

Scan the project for static assets:
- `find public/ static/ assets/ src/assets/ -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.svg" 2>/dev/null`
- List each file with its size
- Identify files over 100KB — these are priority targets

## STEP 2: IMAGE FORMAT AUDIT

For each image file:

**PNG files**: Can they be replaced with WebP or AVIF? Check if they need transparency:
- With transparency: WebP supports it, AVIF supports it — both are better than PNG
- Without transparency: JPEG or WebP are significantly smaller

**JPEG files**: Convert to WebP (typically 25-35% smaller at same quality)

**GIF animations**: Convert to WebM video or WebP animation

**SVGs**: Check if they can be inlined (avoids HTTP request for icons used once)

## STEP 3: COMPRESSION

Run available compression tools:
- `npx sharp-cli` or `squoosh-cli` for batch conversion
- For SVGs: `npx svgo --folder public/icons/`

Target file sizes:
- Hero images: < 150KB
- Thumbnails/cards: < 30KB
- Icons: < 5KB (or inline as SVG)

## STEP 4: RESPONSIVE IMAGES

For images displayed at different sizes:
- Generate 1x, 2x variants for high-DPI screens
- Use `srcset` in HTML or Next.js `Image` component with sizes
- The `sizes` attribute must reflect actual rendered width

## STEP 5: LAZY LOADING

Confirm `loading="lazy"` on all below-the-fold images. The LCP (largest image above the fold) must NOT be lazy-loaded.

## STEP 6: SVG CLEANUP

For SVG files:
- Remove unused elements, metadata, editor attributes
- Run through SVGO with appropriate plugins
- Check for inline styles that can be moved to CSS classes

## STEP 7: REPORT

Output:
- Total before/after size savings (estimated)
- List of specific files to convert/compress
- Commands to run each optimization
- Any images that cannot be further optimized

## ANTI-PATTERNS

- Converting the LCP image to a lazy-loaded format (delays the most important paint)
- Over-compressing images to the point of visible quality loss
- Using CSS background-image for content images (prevents preloading)
- Serving the same large image to mobile and desktop
