"""Patch signature ClassAbilityDefs missing AbilityVfxSpec."""

from __future__ import annotations

import re
from pathlib import Path

path = Path('lib/models/class_ability.dart')
text = path.read_text(encoding='utf-8')

# aid -> (style, castArgb, groundDisc, life, groundArgb, radius)
SPECS: dict[str, tuple] = {
    'shockwave': ('weapon', 0xFFFFC070, True, 1.6, 0x88FFE08A, 2.4),
    'combustion': ('fire', 0xFFFF6020, False, None, None, None),
    'pyroblast': ('fire', 0xFFFF4010, False, None, None, None),
    'killingSpree': ('weapon', 0xFFFFD080, True, 2.0, 0x88FFE08A, 2.2),
    'armsExecute': ('weapon', 0xFFFFB050, False, None, None, None),
    'deathWish': ('weapon', 0xFFFF7070, False, None, None, None),
    'furyExecute': ('weapon', 0xFFFF9050, False, None, None, None),
    'divineFavor': ('holy', 0xFFFFF0A8, False, None, None, None),
    'holyWrath': ('holy', 0xFFFFE080, True, 2.2, 0x88FFE8A0, 2.6),
    'handOfReckoning': ('holy', 0xFFFFE8A0, False, None, None, None),
    'templarsVerdict': ('holy', 0xFFFFF0C0, False, None, None, None),
    'beastWithin': ('arrow', 0xFFFFB060, False, None, None, None),
    'trueshot': ('arrow', 0xFFFFE080, False, None, None, None),
    'blackArrow': ('shadow', 0xFF9060C0, False, None, None, None),
    'vendetta': ('nature', 0xFF70D070, False, None, None, None),
    'mindBlast': ('shadow', 0xFFB060E0, False, None, None, None),
    'dancingRuneWeapon': ('weapon', 0xFF90C0FF, False, None, None, None),
    'darkCommand': ('shadow', 0xFF8050A0, False, None, None, None),
    'hungeringCold': ('frost', 0xFF90D8FF, True, 2.2, 0x6690D8FF, 2.8),
    'gargoyle': ('shadow', 0xFFA080C0, False, None, None, None),
    'armyOfDead': ('shadow', 0xFF706090, True, 2.5, 0x66706090, 2.6),
    'earthShock': ('lightning', 0xFFB8F0FF, False, None, None, None),
    'shamanisticRage': ('lightning', 0xFFFF9040, False, None, None, None),
    'spiritLink': ('nature', 0xFF70D070, True, 3.0, 0x6670D070, 2.8),
    'arcanePower': ('arcane', 0xFFC070FF, False, None, None, None),
    'summonWaterElemental': ('frost', 0xFF90D8FF, False, None, None, None),
    'hauntBurst': ('shadow', 0xFFB060E0, False, None, None, None),
    'metamorphosis': ('shadow', 0xFF8040C0, False, None, None, None),
    'chaosBoltDemo': ('fire', 0xFFFF5020, False, None, None, None),
    'chaosBolt': ('fire', 0xFFFF5020, False, None, None, None),
    'berserk': ('weapon', 0xFFFF8050, False, None, None, None),
    'berserkGuard': ('weapon', 0xFFFF8050, False, None, None, None),
    'growl': ('weapon', 0xFFFFD070, False, None, None, None),
    'tranquility': ('nature', 0xFF90E090, True, 5.5, 0x6690E090, 3.2),
}


def vfx_block(style: str, cast: int, disc: bool, life, argb, radius) -> str:
    lines = [
        f'      boltStyle: SpellBoltStyle.{style},',
        '      vfx: AbilityVfxSpec(',
        f'        boltStyle: SpellBoltStyle.{style},',
        f'        castArgb: 0x{cast:08X},',
    ]
    if disc:
        lines += [
            '        groundDisc: true,',
            f'        groundLife: {life},',
            f'        groundArgb: 0x{argb:08X},',
            f'        groundRadius: {radius},',
        ]
    lines += ['      ),']
    return '\n'.join(lines)


parts = re.split(r'(ClassAbilityDef\()', text)
out: list[str] = [parts[0]]
patched = 0
for i in range(1, len(parts), 2):
    head = parts[i]
    body = parts[i + 1]
    m = re.match(r'(\s*id:\s*AbilityId\.(\w+),[\s\S]*?)(\n\s*\),)', body)
    if not m:
        out.append(head + body)
        continue
    pre, aid, close = m.group(1), m.group(2), m.group(3)
    rest = body[m.end() :]
    if aid not in SPECS or 'AbilityVfxSpec(' in pre:
        out.append(head + body)
        continue
    pre2 = re.sub(r'\n\s*boltStyle:\s*SpellBoltStyle\.\w+,', '', pre)
    style, cast, disc, life, argb, radius = SPECS[aid]
    insert = '\n' + vfx_block(style, cast, disc, life, argb, radius)
    if not pre2.rstrip().endswith(','):
        pre2 = pre2.rstrip() + ','
    out.append(head + pre2 + insert + close + rest)
    patched += 1

path.write_text(''.join(out), encoding='utf-8')
print('patched', patched)
