"""List AoE coverage per HeroSpecId."""

from __future__ import annotations

import re
from collections import defaultdict
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
    if not (m_id and m_spec and m_eff):
        continue
    rows.append(
        (
            m_spec.group(1),
            m_id.group(1),
            m_name.group(1) if m_name else '?',
            m_eff.group(1),
            m_tier.group(1) if m_tier else '?',
        )
    )

by: dict[str, list] = defaultdict(list)
for r in rows:
    by[r[0]].append(r)

# Also flag selfBuff windows that are cleave (blade flurry / sweeping)
CLEAVE_BUFF_HINTS = ('flurry', 'sweep', 'bladestorm', 'cleave')

print(f'specs: {len(by)}')
print()
missing = []
for spec in sorted(by):
    abs_ = by[spec]
    aoes = [a for a in abs_ if a[3] == 'aoe']
    cleave_buffs = [
        a
        for a in abs_
        if a[3] == 'selfBuff'
        and any(h in a[2].lower() or h in a[1].lower() for h in CLEAVE_BUFF_HINTS)
    ]
    label = [f'{a[2]} ({a[4]})' for a in aoes] or ['—']
    extra = ''
    if cleave_buffs:
        extra = '  +cleaveBuff=' + ','.join(a[2] for a in cleave_buffs)
    print(f'{spec:22} AoE={len(aoes)}  {label}{extra}')
    if not aoes and not cleave_buffs:
        missing.append(spec)

print()
print('NO aoe AND no cleave-buff window:')
for s in missing:
    print(' ', s)
