# Shared authored 128×128 overlays (same names as live gear PNGs).
# Wins over extract/stamp via build_owned_gear_layers.maybe_authored.
#
# Shipped:
#   sword_t0_*, shield_t0_*  — warrior plate-gold (process_warrior_gen_art.py)
#   staff_t0_*, dagger_t0_*, bow_t0_*, axe_t0_*, mace_t0_*, frill_t0_*
#     — hand masters (old generators refuse to write)
#   sword_thunderfury_*, sword_warglaive_*
#     — hand masters (old generators refuse to write)
#   Named model variants stay in lib/visual/equipment_model_catalog.dart
#
# Rebuild: py tool/build_owned_gear_layers.py --publish
# See .cursor/skills/character-paper-doll/SKILL.md
