# Veckoplaner

En ISO-vecka, en fil i den här mappen. Filnamnet är året, `-w`, och veckonumret med två siffror. Vecka 51 år 2026 heter `2026-w51.md`.

Den filen är planen. "Vad är planen för vecka 48" läser den veckans fil.

Den här veckan är Aktiv. En full vecka har exakt 25 jobb. En kopierad rad är ett jobb, inte veckan. Nästa vecka har samma form. En senare vecka är en mening tills den blir nästa. Under varje jobb står tre klart-när. En vecka som redan är igång behåller sina rader tills du ber att den fylls om.

Årsplanen i `docs/YEAR_ROADMAP.md` har 52 veckor (2026-w44 … 2027-w42). Varje rad där ska ha en fil här med 25 jobb. Generator: `tool/gen_year_week_plans.py` (skriver om allt utom veckor som redan är handskrivna).

Skill: `.cursor/skills/weekly-plan/SKILL.md`.
