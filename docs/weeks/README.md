# Veckoplaner

En ISO-vecka, en fil i den här mappen. Filnamnet är året, `-w`, och veckonumret med två siffror. Vecka 51 år 2026 heter `2026-w51.md`.

Den filen är planen. "Vad är planen för vecka 48" läser den veckans fil.

Den här veckan är Aktiv. En full vecka har exakt 25 jobb. En kopierad rad är ett jobb, inte veckan. Nästa vecka har samma form. En senare vecka är en mening tills den blir nästa. Under varje jobb står tre klart-när. En vecka som redan är igång behåller sina rader tills du ber att den fylls om.

**Kalenderår 2026** = ISO-vecka 1–53: `2026-w01.md` … `2026-w53.md`. w01–w41 är **Historisk** retro från changelog (`tool/gen_calendar2026_retro_weeks.py`). w42 är arkiv, w43 är **Klar** (fem jobb), w44–w46 är handskrivna undantag.

**52-veckorsplanen** i `docs/YEAR_ROADMAP.md` = 2026-w44 … 2027-w42 (2027-filerna är samma mapp, annan batch). Generator: `tool/gen_year_week_plans.py` (flaggor `--year`, `--from-week`, `--to-week`; skriver om allt utom veckor i SKIP-listan).

Skill: `.cursor/skills/weekly-plan/SKILL.md`.
