# Shared authored 128×128 overlays (same names as live gear PNGs).
# Wins over extract/stamp via build_owned_gear_layers.maybe_authored.
#
# Shipped:
#   sword_t0_*, shield_t0_*  — warrior plate-gold (process_warrior_gen_art.py)
#   staff_t0_*, dagger_t0_*, bow_t0_*, axe_t0_*, mace_t0_*, frill_t0_*
#     — process_shared_weapon_art.py
#   sword_thunderfury_*, sword_warglaive_*
#     — generate_weapon_model_variants.py (legacy hand variants)
#   Named model variants (12 per base, weapons + family armor):
#     — generate_item_model_variants.py (keep in sync with
#       lib/visual/equipment_model_catalog.dart)
#
# Rebuild: py tool/process_shared_weapon_art.py
# Variant models: py tool/generate_item_model_variants.py
#       then py tool/build_owned_gear_layers.py
# See .cursor/skills/character-paper-doll/SKILL.md
