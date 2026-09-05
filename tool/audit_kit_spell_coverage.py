"""Kit spell coverage board: count by tier/effect per spec + thin kits."""

from __future__ import annotations

import re
from collections import Counter, defaultdict
from pathlib import Path

text = Path('lib/models/class_ability.dart').read_text(encoding='utf-8')
parts = re.split(r'ClassAbilityDef\(', text)[1:]

rows = []
for p in parts:
    m_id = re.search(r'id:\s*AbilityId\.(\w+)', p)
    m_spec = re.search(r'specId:\s*HeroSpecId\.(\w+)', p)
    m_eff = re.search(r'effect:\s*AbilityEffectKind\.(\w+)', p)
    m_name = re.search(r"name:\s*'([^']+)'", p)
    m_tier = re.search(r'tier:\s*AbilityCastTier\.(\w+)', p)
    m_unlock = re.search(r'unlockLevel:\s*(\d+)', p)
    m_hud = re.search(r'showInHud:\s*false', p)
    if not (m_id and m_spec and m_eff):
        continue
    rows.append(
        {
            'spec': m_spec.group(1),
            'id': m_id.group(1),
            'name': m_name.group(1) if m_name else '?',
            'eff': m_eff.group(1),
            'tier': m_tier.group(1) if m_tier else '?',
            'unlock': int(m_unlock.group(1)) if m_unlock else 0,
            'hud': m_hud is None,
        }
    )

by = defaultdict(list)
for r in rows:
    by[r['spec']].append(r)

# Expected WotLK fantasy crumbs that are often missing (heuristic name search).
EXPECT = {
    'affliction': ['corruption', 'ua', 'haunt', 'drain', 'agony', 'seed'],
    'demonology': ['shadow bolt', 'hand', 'immolate', 'meta', 'chaos'],
    'destruction': ['incinerate', 'conflag', 'immolate', 'chaos', 'shadowfury'],
    'shadow': ['flay', 'vt', 'dp', 'sw:p', 'sear', 'blast'],
    'assassination': ['mutilate', 'envenom', 'garrote', 'rupture', 'fan'],
    'subtlety': ['hemo', 'backstab', 'shadowstep', 'dance', 'fan'],
    'combat': ['sinister', 'evis', 'flurry', 'spree'],
    'arms': ['mortal', 'overpower', 'rend', 'sweep', 'bladestorm', 'execute'],
    'fury': ['bloodthirst', 'whirlwind', 'execute', 'wish'],
    'protection': ['thunder', 'shield slam', 'shockwave', 'taunt'],
    'retribution': ['crusader', 'judgment', 'divine storm', 'tv'],
    'protPaladin': ['avenger', 'consecration', 'hammer', 'holy wrath'],
    'holyPaladin': ['holy shock', 'beacon', 'consecration', 'loh'],
    'beastMastery': ['arcane shot', 'kill command', 'multi', 'bestial'],
    'marksmanship': ['aimed', 'chimera', 'volley', 'trueshot'],
    'survival': ['explosive', 'trap', 'black arrow', 'mongoose'],
    'frostMage': ['frostbolt', 'ice lance', 'cone', 'water'],
    'fire': ['fireball', 'pyro', 'blast wave', 'combust'],
    'arcane': ['arcane blast', 'missiles', 'explosion', 'arcane power'],
    'elemental': ['lightning', 'lava', 'chain', 'thunderstorm', 'earth shock'],
    'enhancement': ['stormstrike', 'lava lash', 'fire nova', 'wolf'],
    'balance': ['wrath', 'starfire', 'moonfire', 'hurricane', 'starfall'],
    'feral': ['shred', 'rake', 'bite', 'swipe', 'rip', 'berserk'],
    'guardian': ['mangle', 'swipe', 'maul', 'frenzied'],
    'blood': ['death strike', 'heart strike', 'blood boil', 'drw'],
    'frostDk': ['obliterate', 'frost strike', 'howling', 'hungering'],
    'unholy': ['scourge', 'death coil', 'blood boil', 'gargoyle', 'army'],
    'discipline': ['shield', 'penance', 'pom', 'pain suppression'],
    'holyPriest': ['renew', 'coh', 'nova', 'hymn', 'guardian'],
    'restorationShaman': ['riptide', 'chain heal', 'healing rain', 'spirit link'],
    'restorationDruid': ['rejuv', 'regrowth', 'wild growth', 'tranquility'],
}

print(f'{"spec":22} n  hud  fill sig emg aoe heal root notes')
print('-' * 88)
thin = []
for spec in sorted(by):
    abs_ = by[spec]
    n = len(abs_)
    hud = sum(1 for a in abs_ if a['hud'] and a['eff'] != 'passive')
    tiers = Counter(a['tier'] for a in abs_)
    effs = Counter(a['eff'] for a in abs_)
    names = ' '.join(a['name'].lower() for a in abs_)
    missing_crumbs = []
    for crumb in EXPECT.get(spec, []):
        if crumb not in names and crumb.replace(':', '') not in names.replace(':', ''):
            # loose: any token
            tokens = crumb.replace(':', ' ').split()
            if not all(t in names for t in tokens):
                missing_crumbs.append(crumb)
    note = ''
    if n < 7:
        note = 'THIN'
        thin.append(spec)
    elif missing_crumbs:
        note = 'miss~' + ','.join(missing_crumbs[:3])
    print(
        f'{spec:22} {n:2} {hud:3}  {tiers.get("filler",0):4} {tiers.get("signature",0):3} '
        f'{tiers.get("emergency",0):3} {effs.get("aoe",0):3} {effs.get("heal",0):4} '
        f'{effs.get("root",0):4} {note}'
    )

print()
print('Thin kits (<7 defs):', ', '.join(thin) or 'none')

# Specs with no signature
no_sig = [s for s, abs_ in by.items() if not any(a['tier'] == 'signature' for a in abs_)]
print('No signature tier:', ', '.join(sorted(no_sig)) or 'none')

# Specs with no emergency
no_emg = [s for s, abs_ in by.items() if not any(a['tier'] == 'emergency' for a in abs_)]
print('No emergency:', ', '.join(sorted(no_emg)) or 'none')
