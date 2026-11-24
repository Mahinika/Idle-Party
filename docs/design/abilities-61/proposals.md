# Förslag: alla specs till 11 abilities

Endast förslag. Inget är implementerat. Det här är balans-/designändringar — ingenting byggs utan Roberts godkännande.

Källa: `abilities.json` (282 abilities) och repo-main `7b7aedc34bad98815441113d5f965e0e44b59cab`. Counts i JSON och kits på main stämmer exakt överens. Inga kodändringar, ingen PR, ingen branch.

Motorns befintliga effect kinds: `damage`, `aoe` (former: nova, fan, rain, ground, chain), `heal`, `absorb`, `selfBuff` (haste, absorb, amp, healAmp, cleave, block), `root`, `grantResource`, `emergencyDefend`, `emergencyHeal`, `taunt`, `passive`. Redan i motorn men inte egna kinds: DoT via `maintainDot`, execute via `executeHpFrac`, tillfälliga summons (`summonCount`, t.ex. Gargoyle / Feral Spirit / Water Elemental / Army of the Dead), kanal (Penance / Mind Flay, enskilt mål) och customs som `prayerOfMending`, `charge`, `kidneyShot`.

Målet: varje spec ska ha minst 11 abilities (samma som Blood och Guardian). Protection har redan 13 och lämnas orörd. De fem tidigare förslagen (Frost DK, Arcane, BM, Resto Druid, Holy Priest) är oförändrade.

Spec-id och visningsnamn är verifierade från `HeroSpecId` / `HeroSpecDef`. Mitten-rogue är `combat` (visningsnamn **Alleyblade**), inte Outlaw.

---

## Warrior

### Arms (`arms`, Greatblade) — 8 → 11

**Idag:** Battle Stance; Mortal Strike (2.35/3 s), Overpower (1.58/3.5 s), Rend (0.9/6 s bleed); Sweeping Strikes (cleave 7 s/18 s); Bladestorm (aoe-puls 0.46/38 s, disc look-only); Execute (3.45/6.5 s vid 25 %); Rallying Cry (emergency party-absorb). Ingen Charge, ingen personlig mitt-CD-defensiv, ingen rustningsbrytare.

1. **Colossus Smash** — rustningsbrytande tung träff mellan Overpower och Mortal Strike, närmare Mortal Strike. `damage`, ca 6–8 s CD. Visuellt: tvåhands-smash som spräcker en chockvåg i marken under fienden, ingen flygande slash-boll. Befintlig `damage`.
2. **Die by the Sword** — personligt mitt-CD-försvar utöver Rallying Cry. `absorb` eller `selfBuff` block, ca 30–40 s CD, tydligt svagare än en tank-emergency. Visuellt: korslagda klingor som ett parerbur runt krigaren. Befintlig `absorb` / `selfBuff` block.
3. **Charge** — gap-close som Arms saknar, Prot har redan. Återanvänder `customId.charge` (rush, root, rage). Ca 12 s CD, samma anda som Prots Charge. Visuellt: en rusning med stoftkila bakom fötterna, inte en projektil. Befintlig Charge-custom.

### Fury (`fury`, Twinrage) — 9 → 11

**Idag:** Berserker Stance; Bloodthirst (1.3/4.5 s, rage-refund), Raging Blow (1.55/4.5 s), Whirlwind (0.60/7 s); Enrage (haste 20 s), Death Wish (amp 8 s/40 s), Recklessness (amp 8 s/50 s); Rampage (2.1/10 s — uttryckligen inte execute); Enraged Regeneration. Ingen execute, ingen pack-CC.

1. **Execute** — finisher som Fury saknar (Arms har den). `damage` + `executeHpFrac`, ca 6 s CD; mot lågt HP ungefär som Arms Execute (3.45) eller strax under. Visuellt: ett hoppande overhead-hugg i en sargad fiende, ingen flygande slash. Befintlig `damage` + execute-gate.
2. **Piercing Howl** — pack-CC. `root` på närliggande, ca 16 s CD, i samma anda som Psychic Scream / Hungering Cold (root/slow, ingen flee). Visuellt: en chockvågs-skri-ring runt krigaren. Befintlig `root`.

### Protection (`protection`, Shieldwall) — 13 → 13

Orörd (redan över 11).

---

## Paladin

### Holy Paladin (`holyPaladin`, Dawnward) — 9 → 11

**Idag:** Holy Aura; Holy Shock (1.3, heal eller smite), Flash of Light (1.1), Holy Light (1.7/7 s, 1.8 s cast); Sacred Shield (absorb 1.15); Beacon; Consecration (aoe 0.28/10 s); Divine Favor (healAmp 8 s/40 s); Lay on Hands (3.2/60 s). Ingen kon-heal, ingen CC, ingen emergencyDefend (bara emergencyHeal).

1. **Light of Dawn** — kon-heal som skiljer sig från enkelmåls-Holy Light. `heal`, ca 8–12 s CD; ungefär som Flash of Light per träffad, eller strax under Holy Shock, på flera allierade. Visuellt: en gryningsfjäder av ljus slår ut framåt från paladinen, inga heliga bollar. Befintlig `heal`.
2. **Hammer of Justice** — CC-luckan. `root` på focus, ca 16–20 s CD, ungefär som Intimidation. Visuellt: ett hammarsigill slår ner som en stun-pelare. Befintlig `root`. (Samma typiska paladin-spell föreslås också för Ret.)

### Protection Paladin (`protPaladin`, Oathwall) — 9 → 11

**Idag:** Righteous Fury; Avenger's Shield (1.1/8 s), Shield of Righteousness (1.25/5.5 s); Holy Shield (block 6 s/10 s); Hammer of the Righteous (nova 0.7/6 s), Consecration (0.32/9 s); Holy Wrath (stun-aoe 0.95/22 s); Divine Protection (55 s); Hand of Reckoning (taunt 8 s). Ingen självheal, bara en emergency (Prot Warrior har två).

1. **Ardent Defender** — andra emergency, samma mönster som Last Stand + Shield Wall. `emergencyDefend`, ca 45–60 s CD, i samma anda som Last Stand (inte lika hård som Shield Wall / Divine Shield). Visuellt: ett sista-stånd-halo, ett hammarsvalv slår ner runt paladinen. Befintlig `emergencyDefend`.
2. **Word of Glory** — själv/lägsta-heal som tanken saknar. `heal`, ca 9–12 s CD, ungefär som Sacred Shield (1.15) eller Flash of Light (1.1), långt under Lay on Hands (3.2). Visuellt: ljus spricker ut från skölden/bröstet. Befintlig `heal`. (Samma spell föreslås också för Ret.)

### Retribution (`retribution`, Sunstrike) — 8 → 11

**Idag:** Seal of Command (mycket stark passive); Crusader Strike (2.15/4 s), Judgment (1.90/6 s), Hammer of Wrath (1.75/7 s execute); Divine Storm (0.50/9 s puls, disc look-only); Zealotry (amp 8 s/35 s); Templar's Verdict (3.30/8 s); Divine Shield (60 s). Ingen mark-aoe (Consecration finns på Holy/Prot), ingen CC, ingen heal.

1. **Consecration** — varaktig mark-aoe utöver Divine Storm-pulsen. `aoe` ground, ca 9–10 s CD, ungefär som Holy/Prot-varianten (0.28–0.32). Visuellt: brinnande helig mark under fötterna. Befintlig `aoe` ground.
2. **Hammer of Justice** — CC-luckan. `root` på focus, ca 16–20 s CD, ungefär som Intimidation. Visuellt: hammarsigill som stun-pelare. Befintlig `root`.
3. **Word of Glory** — en liten heal på lägsta allierad. `heal`, ca 12–15 s CD, ungefär som Flash of Light (1.1), inte Lay on Hands. Visuellt: ljusbur från bröstet, ingen helig boll. Befintlig `heal`.

---

## Hunter

### Beast Mastery (`beastMastery`, Packbond) — 8 → 11

*Oförändrat mot förslaget 2026-11-24.*

**Idag:** Aspect of the Hawk; två skador (Arcane Shot 1.08/4 s, Kill Command 1.48/5.5 s — *du* slår, starkare om pet lever, arrow-bolt); Multi-Shot (fan); Bestial Wrath (haste); Intimidation (root); The Beast Within (amp 8 s/40 s); Feign Death. En stående class-companion autoattackar redan, men ingen ability är en synlig pet-special.

1. **Stampede** — synlig pet-burst som inte är ännu en jägarbuff. `selfBuff` + `summonCount` (som Feral Spirit / Army of the Dead), ca 40–45 s CD; tillfälliga djur i ca 12–16 s med svagare träffar än Kill Command. Visuellt: en flock djur stormar över packen. Befintlig summon-mekanik.
2. **Kill Shot** — execute som BM saknar. `damage` med befintlig `executeHpFrac`-gate, ca 8–10 s CD; mot lågt HP ungefär som Marksmanships Aimed Shot (1.72), annars avsevärt svagare eller avstår. Visuellt: en genomskjutande pilstråle, inte en ljusboll. Befintlig `damage` + execute-gate.
3. **Claw** — fyller luckan att peten aldrig syns använda en special. `damage`, ca 6–7 s CD, ungefär som Kill Command (1.48) eller strax under. Visuellt: companionen hoppar in och river focus, ingen pil. Skadenumerär kan vara vanlig `damage`, men **needs new mechanic** för att companionen ska vara ursprung för VFX/träffen (Kill Command är idag en jägar-pil).

### Marksmanship (`marksmanship`, Longshot) — 9 → 11

**Idag:** Trueshot Aura; Steady Shot (1.05/5 s), Aimed Shot (1.72/6.5 s, 1.5 s cast), Chimera Shot (1.35/8 s, nature-bolt); Volley (rain 0.78/9 s), Multi-Shot (fan 0.88/8 s, pack ≥ 2); Rapid Fire (haste); Trueshot (amp 8 s/45 s); Deterrence. Ingen execute, ingen CC.

1. **Kill Shot** — samma typiska jägarexecute som i BM-förslaget. `damage` + `executeHpFrac`, ca 8–10 s CD; mot lågt HP ungefär som Aimed Shot (1.72). Visuellt: genomskjutande pilstråle. Befintlig `damage` + execute-gate.
2. **Binding Shot** — CC-luckan. `root` på packen runt en planterad pil, ca 16 s CD, i samma anda som en Frost Nova på avstånd. Visuellt: pilen slår ner en run-cirkel som kedjar fast fiender. Befintlig `root` + ground disc; en zon som rotar den som *senare går in* **needs new mechanic**.

### Survival (`survival`, Snarebow) — 9 → 11

**Idag:** Trap Mastery; Explosive Shot (1.25/5 s — uttryckligen *en* eldbolt, inte en explosion); Serpent Sting (DoT 0.85); Explosive Trap (0.48/12 s puls, disc look-only); Freezing Trap (root 16 s); Mongoose Bite (1.3/5 s, melee-range); Multi-Shot (fan 0.50); Black Arrow (1.4/14 s, ingen DoT); Disengage (25 s). Ingen riktig bomb, ingen melee-cleave.

1. **Wildfire Bomb** — den explosion Explosive Shot inte är. `aoe` ground, ca 8–10 s CD; på en fiende ungefär som Explosive Shot (1.25), bättre mot pack och tydligt starkare än Explosive Trap (0.48). Visuellt: en kastad bomb (granat, inte en eldboll) som blommar ut till en eldpöl. Befintlig `aoe` ground.
2. **Harpoon** — inåtgående gap-close mot Disengage som kitar ut. `root` på focus, ca 12–16 s CD, ungefär som Freezing Trap. Visuellt: en harpunkedja slår i fienden. Root på avstånd = befintlig `root`; en dash/pull som flyttar jägaren eller fienden **needs new mechanic** (eller återbruk av Charge-lik custom).

---

## Rogue

Mitten-spec är `combat` (visningsnamn **Alleyblade**).

### Assassination (`assassination`, Venomcut) — 9 → 11

**Idag:** Improved Poisons (passive, applicerar inte poison); Mutilate (1.45/4 s), Envenom (1.55/5 s, combo ≥ 3); Garrote och Rupture (bleeds); Fan of Knives (0.95/6 s); Cold Blood (amp 6 s/35 s), Vendetta (amp 8 s/45 s); Cloak of Shadows. Ingen stun, ingen självheal. Sinister/Kidney/Vanish sitter på andra rogue-specs.

1. **Kidney Shot** — stun-finisher som Assa saknar, Combat har redan custom. `root` (stun) med combo-gate, ca 14 s CD, samma anda som Combats Kidney Shot. Visuellt: ett precist fäste-slag, inget kastat knivblad. Återanvänder gärna `customId.kidneyShot` — befintlig mekanik.
2. **Crimson Vial** — själv-sustain. `heal`, ca 30 s CD, en måttlig puls (tydligt under Flash Heal 1.55, mer som en liten Renew-nivå på sig själv). Visuellt: roguen dricker en röd vial, karmosin dimma runt kroppen. Befintlig `heal` (helst på caster; `casterHpMax`-gate finns). Ren själv-only-targeting utöver det är en liten gate, inte ny effect kind.

### Combat (`combat`, Alleyblade) — 9 → 11

**Idag:** Sinister Strike är *passive* (vita slag bygger combo), inte en aktiv knapp; Slice and Dice; Eviscerate (1.18); Kidney Shot; Blade Flurry (cleave); Sprint (förflyttning); Fan of Knives (0.16, bara pack ≥ 4); Killing Spree (signature aoe); Vanish (emergency). Ingen haste-skadewindow, ingen aktiv builder.

1. **Adrenaline Rush** — haste-fönster som inte är Sprint (rörelse) eller Killing Spree (aoe-dash). `selfBuff` haste, ca 30–40 s CD, i samma anda som Bestial Wrath / Rapid Fire. Visuellt: roguen blir en rörelseoskärpa av hugg, efterbilder runt kroppen. Befintlig `selfBuff` haste.
2. **Revealing Strike** — aktiv builder (Sinister Strike är bara passive). `damage`, ca 4 s CD, tydligt under Eviscerate (1.18) per träff men oftare, mer som en lätt Mutilate-nivå. Visuellt: ett djupt stöt-hugg som lämnar ett glödande sår, inget kastat knivblad. Befintlig `damage`.

### Subtlety (`subtlety`, Nightstep) — 10 → 11

**Idag:** Master of Subtlety; Hemorrhage (1.28/3.5 s), Backstab (1.60/5 s, sidsteg); Eviscerate (1.65); Shadowstep (haste); Premeditation (grant 2 combo); Shadow Dance (signature vanish/haste/amp); Fan of Knives (0.95/6 s); Cheap Shot; Preparation (emergency CD-reset). Ingen clone-burst, ingen extra pack-CD utöver FoK.

1. **Secret Technique** — clone-burst mot pack. `aoe` nova, ca 20–25 s CD, tydligt starkare än Fan of Knives (0.95) som CD-knapp. Visuellt: tre skuggkloner snurrar genom packen, inga kastade shurikens som bollar. Befintlig `aoe` nova (kloner look-only); riktiga attackerande kloner = befintlig kort `summonCount`.

---

## Priest

### Discipline (`discipline`, Aegislight) — 8 → 11

**Idag:** Inner Fire; Power Word: Shield (absorb 2.0/6.5 s); Prayer of Mending (bounce 1.0/9 s); Penance (signature-kanal 0.62/7.5 s, heal eller bränn+heal); Flash Heal (1.55/4.5 s); Power Word: Fortitude; Pain Suppression; Power Infusion (55 s). Ingen grupp-absorb, ingen halo/ring, ingen fiend-pet; enda skadan sitter i Penance.

1. **Power Word: Barrier** — grupp-absorb-kupol utöver enskilda PWS. `absorb`, ca 30–40 s CD; per person tydligt svagare än PWS (2.0), mer mot Sacred Shield (1.15). Visuellt: en lysande kupol över gruppen. Enskild absorb finns; en samtidig parti-kupol **needs new mechanic**.
2. **Halo** — expanderande ljusring. `heal`, ca 15–20 s CD, ungefär som Chain Heal (1.35) utslaget på gruppen, eller lite under. Visuellt: en helig ring som växer ut från prästen. Befintlig `heal`. Extra fiendeskada på samma ring (hybrid) **needs new mechanic**.
3. **Shadowfiend** — mana/skade-pet som Disc saknar. `selfBuff` + `summonCount` 1, ca 45 s CD, i samma anda som Water Elemental / Gargoyle (svagare träffar än en hero-nukes). Visuellt: ett skuggfiende stiger upp ur en reva och attackerar. Befintlig summon. (Samma typiska priest-spell föreslås också för Shadow.)

### Holy Priest (`holyPriest`, Hymnward) — 8 → 11

*Oförändrat mot förslaget 2026-11-24.*

**Idag:** Spirit of Redemption; fyra healer (Renew 1.35/5 s, Flash Heal 1.55/4 s, Circle of Healing 1.4/8 s, Holy Nova 0.85/10 s — Nova gör ingen fiendeskada); Guardian Spirit (emergencyDefend 45 s); Divine Hymn (signature 1.6/40 s); Desperate Prayer (emergencyHeal 2.4/50 s). I princip bara heals — ingen skada, ingen bounce, ingen utility utöver GS.

1. **Holy Fire** — en skade-/utility-knapp när gruppen är frisk. `damage` (gärna med `maintainDot`), ca 7–8 s CD; måttlig skada runt Arcane Blast (1.1). Visuellt: en helig eldpelare faller ner på fienden, inte en gul boll. Befintlig `damage` + ev. `maintainDot` (samma mönster som Howling Blast / Living Bomb).
2. **Holy Word: Sanctify** — markzon som skiljer sig från Circle of Healing. `heal`, ca 12–15 s CD, ungefär som Circle of Healing (1.4) eller lite starkare. Visuellt: en ljus-cirkel på marken under gruppen. Befintlig `heal` + ground disc (som CoH / Tranquility). En tickande zon (inte bara en puls + liggande disc) **needs new mechanic**.
3. **Prayer of Mending** — interaktiv utility-heal som Holy saknar, Disc har redan. `heal` med `onHitBounce`, ca 9 s CD, samma ungefärliga styrka som Disc (coeff 1.0). Visuellt: en fjäderlik helig gnista som hoppar mellan allierade. Återanvänder redan befintlig `customId.prayerOfMending` — ingen ny mekanik.

### Shadow (`shadow`, Duskcant) — 9 → 11

**Idag:** Shadowform; Mind Flay (1.05/4 s kanal); Vampiric Touch (1.15 DoT, mana-refund), Devouring Plague (1.35), Shadow Word: Pain (0.85); Mind Sear (rain 0.76/9 s); Psychic Scream (root 18 s); Mind Blast (1.75/7 s, 1.5 s cast); Dispersion. Ingen execute, ingen shadowfiend, ingen skade-amp.

1. **Shadow Word: Death** — execute. `damage` + `executeHpFrac`, ca 8 s CD; mot lågt HP ungefär som Mind Blast (1.75) eller strax under. Visuellt: en mörk spik/glyf som spricker på den sargade fienden, ingen skuggboll. Befintlig `damage` + execute-gate. (WoW-backfire på caster utelämnas, eller vore ny mekanik.)
2. **Shadowfiend** — samma typiska priest-summon som i Disc-förslaget. `summonCount` 1, ca 45 s CD, i samma anda som Water Elemental / Gargoyle. Visuellt: skuggfiende ur en reva. Befintlig summon.

---

## Death Knight

### Blood (`blood`, Graveward) — 11 → 11

Orörd (redan 11).

### Frost DK (`frostDk`, Rimeblade) — 8 → 11

*Oförändrat mot förslaget 2026-11-24.* Frozen Orb läggs här, inte på Frost Mage (som får Cone of Cold + Ice Barrier i stället).

**Idag:** Frost Presence; två enkelmålsskador (Obliterate 2.10/5 s, Frost Strike 1.90/4 s och starkare mot rootad fiende); Howling Blast (aoe 1.25/7 s, disease); två roots (Chains of Ice 12 s, Hungering Cold 35 s); Pillar of Frost (amp 8 s/30 s); Icebound Fortitude. Ingen resource-reset, ingen absorb, ingen kon/stråle.

1. **Frozen Orb** — pack-AoE som inte är en till Howling Blast-puls. `aoe` (rain/ground), ca 15–20 s CD; varje puls lite svagare än Howling Blast, totalt ungefär Howling Blast plus lite till. Visuellt: ett svävande isklot som pulserar över packen, inte en kastad boll. Befintlig `aoe` rain/ground; en orb som själv rullar över golvet behöver ny mekanik.
2. **Breath of Sindragosa** — burst-fönster med tydlig frostidentitet. `aoe` fan/kon, ca 25–35 s CD; total skada ungefär som två Obliterate över andningen. Visuellt: en bred isdrake-ande som konar ut från DK. Kort konburst = befintlig `aoe` fan. En tickande resurskanal (som Penance/Mind Flay, men i kon) behöver en utökning av channel-pathen — needs new mechanic om den ska kanaliseras.
3. **Empower Rune Weapon** — håller rotationen igång när runorna är tomma. `grantResource`, ca 30–40 s CD, i samma anda som Tiger's Fury / Shamanistic Rage. Visuellt: runorna tänds i en cirkel runt DK, ingen projektil. Befintlig `grantResource`.

### Unholy (`unholy`, Blightblade) — 9 → 11

**Idag:** Unholy Presence; Scourge Strike (1.12/4.5 s, disease), Death Coil (1.04/5.5 s); Blood Boil, Death and Decay; Summon Gargoyle (signature, summon + haste); Anti-Magic Shell (absorb 1.0/30 s); Army of the Dead (aoe 0.55/50 s + 4 ghouls); Icebound Fortitude. En class-companion autoattackar redan. Ingen execute, ingen skade-amp (Gargoyle/Army är summons).

1. **Soul Reaper** — execute. `damage` + `executeHpFrac`, ca 6–8 s CD; mot lågt HP tydligt över Scourge Strike (1.12), mer mot en mini-Obliterate. Visuellt: en lie-skära av skugga skördar den sargade, inte ännu en Death Coil-boll. Befintlig `damage` + execute-gate.
2. **Dark Transformation** — amp-fönster plus pet-identitet. `selfBuff` amp, ca 40–45 s CD, i samma anda som Zealotry / The Beast Within (ca 8 s). Visuellt: ghoul-companionen sväller till ett monstruöst odödt. Självaampen är befintlig `selfBuff` amp; en riktig pet-modelltransform **needs new mechanic** (annars look-only aura på companionen).

---

## Shaman

### Elemental (`elemental`, Stormcall) — 10 → 11

**Idag:** Elemental Focus; Lightning Bolt (1.15), Flame Shock (DoT), Lava Burst (1.55), Earth Shock (1.4 signature, fördröjer special); Chain Lightning, Thunderstorm (rain), Earthquake (ground, pack ≥ 3); Elemental Mastery (haste); Astral Shift. Ingen elemental-summon (Frost Mage har Water Elemental, Enh har vargar).

1. **Fire Elemental** — den saknade elemental-summonen. `selfBuff` + `summonCount` 1, ca 40–45 s CD, i samma anda som Water Elemental (28 s, atkScale 0.40) / Gargoyle. Visuellt: en eld-elemental reser sig ur en lavaspricka, ingen eldboll. Befintlig summon-mekanik.

### Enhancement (`enhancement`, Totemstrike) — 9 → 11

**Idag:** Enhanced Weapons; Stormstrike (1.35/5 s), Lava Lash (1.25/6 s); Fire Nova (0.50/9 s puls), Magma Totem (0.48/12 s, pack ≥ 3, inte en summoned totem); Feral Spirit (2 vargar/35 s); Frost Shock (root 12 s); Shamanistic Rage (grantResource + DR, 30 s); Astral Shift. Ingen blixt-cleave, ingen heal.

1. **Crash Lightning** — blixt-cleave utöver Fire Nova-pulsen. `aoe` chain eller fan, ca 8 s CD; på en fiende ungefär som Lava Lash (1.25), starkare än Fire Nova (0.50) mot pack. Visuellt: blixtar slår ner i en linje/kon genom packen, ingen kastad kula. Befintlig `aoe` chain/fan.
2. **Healing Surge** — en liten heal som Enh saknar helt. `heal`, ca 12 s CD, ungefär som Flash of Light (1.1) eller strax under Riptide (1.15). Visuellt: en vattensvall runt lägsta allierad, ingen grön boll. Befintlig `heal`.

### Restoration Shaman (`restorationShaman`, Tidecall) — 8 → 11

**Idag:** Ancestral Awakening; Riptide (1.15/5.5 s), Healing Wave (1.55/5 s, 1.6 s cast), Chain Heal (1.35/7 s); Earth Shield (absorb 1.4/10 s); Healing Rain (1.1/12 s, rain-disc look-only); Spirit Link (1.85/40 s, utjämnar inte HP); Nature's Swiftness (2.2/55 s). Ingen CC, ingen mana-totem, ingen större tide-heal.

1. **Healing Tide Totem** — större grupp-heal mellan Healing Rain och Spirit Link. `heal`, ca 20–30 s CD, tydligt över Healing Rain (1.1) och under Spirit Link (1.85). Visuellt: en vatten-totem sprutar en fontän. Befintlig `heal` + liggande fontän-disc (som Healing Rain). En tickande totem **needs new mechanic**.
2. **Earthbind Totem** — CC-luckan. `root` på fiender runt totemen, ca 16 s CD, ungefär som Frost Shock / Chains of Ice. Visuellt: en jord-totem med stötvågsringar i marken. Befintlig `root` + ground disc.
3. **Mana Tide Totem** — mana-utility. `grantResource`, ca 45 s CD, i samma anda som Shamanistic Rage / Innervate. Visuellt: en blå mana-totem med stigande motes. Befintlig `grantResource` som självmål; parti-mana till andra casters skulle behöva ny targeting.

---

## Mage

### Arcane (`arcane`, Prismcast) — 8 → 11

*Oförändrat mot förslaget 2026-11-24.*

**Idag:** Arcane Brilliance; två enkelmålsskador (Arcane Blast 1.1/5 s med 1.4 s cast, Arcane Missiles 1.18/6 s som kräver 2 Arcane Charges); Arcane Explosion (aoe 1.46/5 s vid pack ≥ 2); Slow; Presence of Mind (haste); Arcane Power (amp 7 s/40 s); Ice Block. Ingen charge-dump, ingen absorb, ingen mana-återställare.

1. **Arcane Barrage** — instant charge-dump, tredje skadeknappen. `aoe` chain, ca 5–6 s CD; ungefär som Arcane Missiles, lite hårdare när charges är inne. Visuellt: violett kedje-blixt som hoppar mellan fiender, inte fler lila bollar. Befintlig `aoe` chain (samma form som Chain Lightning).
2. **Prismatic Barrier** — mitt-CD-försvar utöver Ice Block. `absorb` på sig själv, ca 20–25 s CD, ungefär som Unholys Anti-Magic Shell (coeff 1.0). Visuellt: ett prismatiskt kristallskal runt magikern. Befintlig `absorb`.
3. **Evocation** — mana så Blast/Missiles inte tystnar. `grantResource`, ca 40–45 s CD, i samma anda som Shamanistic Rage. Visuellt: en mana-virvel/stråle ovanifrån, magikern står i ett siphon. Befintlig `grantResource`.

### Fire (`fire`, Cinderweft) — 10 → 11

**Idag:** Arcane Intellect; Fireball (0.95/5.8 s, 1.8 s cast), Living Bomb (0.65/8 s), Pyroblast (1.45, bara Hot Streak); Frost Nova; Blast Wave (0.85/8 s), Flamestrike (1.28/10 s, pack ≥ 2); Blink; Combustion (amp 4 s/55 s); Ice Block. Ingen stor meteor, nästan allt reseskädespel är bollar eller mark-discs.

1. **Meteor** — den stora slam-AoE:n som Fire saknar. `aoe` ground, ca 30–40 s CD, tydligt tyngre än Flamestrike (1.28) mot pack. Visuellt: en stor brinnande meteor kraschar ner i packen, inte en kastad Fireball. Befintlig `aoe` ground.

### Frost Mage (`frostMage`, Glacecast) — 9 → 11

**Idag:** Frost Armor; Frostbolt (1.15/3.5 s, 1.5 s cast), Ice Lance (1.25/4 s, shatter mot rootad); Frost Disc (1.20/6 s), Frost Rain (0.78/8 s); Frost Nova; Icy Veins (haste); Water Elemental (signature summon 28 s); Ice Block. Ingen absorb, ingen kon (två ground/rain-AoE redan). Frozen Orb föreslås inte här — den sitter på Frost DK sedan tidigare.

1. **Ice Barrier** — mitt-CD-absorb utöver Ice Block. `absorb` på sig själv, ca 20–25 s CD, ungefär som Anti-Magic Shell / Prismatic Barrier (coeff 1.0). Visuellt: ett roterande is-skärveskal runt magikern. Befintlig `absorb`.
2. **Cone of Cold** — kon som skiljer sig från Frost Disc och Frost Rain. `aoe` fan, ca 8–10 s CD; svagare än Frost Disc (1.20) på en fiende, bra mot en klunga rakt fram. Visuellt: en vidgad frost-ande/kon. Befintlig `aoe` fan.

---

## Warlock

### Affliction (`affliction`, Hexrot) — 9 → 11

**Idag:** Soul Siphon; Corruption, Unstable Affliction, Curse of Agony (DoTs); Haunt (1.38/8 s), Drain Life (1.05/6 s, instant siphon + självheal); Seed of Corruption (aoe 0.76/10 s); Haunt Burst (1.75/18 s, poppar inte DoTs); Soulburn (emergency shield). Ingen skade-amp, ingen CC (många DoT-knappar redan).

1. **Dark Soul** — amp-fönster som Affliction saknar. `selfBuff` amp, ca 35–40 s CD, i samma anda som Combustion / Vendetta (ca 8 s, inte lika kort som Combustion 4 s). Visuellt: warlocken omges av virvlande själar, ingen skuggboll. Befintlig `selfBuff` amp.
2. **Howl of Terror** — CC-luckan. `root` på närliggande, ca 18 s CD, i samma anda som Psychic Scream (root/slow, ingen flee). Visuellt: en ring av skrikande ansikten som expanderar från castern. Befintlig `root`.

### Demonology (`demonology`, Pactimp) — 9 → 11

**Idag:** Demonic Knowledge (pet-lean); Shadow Bolt (0.95/5 s, 1.5 s cast), Immolate (DoT), Chaos Bolt (1.62/10 s); Hand of Gul'dan (ground 0.78), Hellfire (0.58, pack ≥ 2); Metamorphosis (amp 8 s/45 s — inte en demonform); Demon Charge (haste); Demonic Sacrifice (emergency absorb). En class-companion autoattackar redan. Ingen extra demon-summon, ingen meteor-nukle utöver Chaos Bolt.

1. **Call Dreadstalkers** — synliga extra-pets. `summonCount` 2, ca 20–25 s CD, i samma anda som Feral Spirit men kortare (svagare träffar än Chaos Bolt). Visuellt: två demonhundar spränger ut ur en fel-portal och hugger. Befintlig summon.
2. **Soul Fire** — tung fel-nukle mellan Shadow Bolt (0.95) och Chaos Bolt (1.62), närmare Chaos Bolt. `damage`, ca 8 s CD. Visuellt: en fel-meteor/pelare faller över målet, inte en eldboll. Befintlig `damage`.

### Destruction (`destruction`, Ashburst) — 9 → 11

**Idag:** Cataclysm (passive); Incinerate (1.00/5 s), Conflagrate (1.16/6 s), Immolate (DoT 0.80); Rain of Fire (0.62/8 s), Shadowfury (stun-aoe 0.7/16 s); Backdraft (haste); Chaos Bolt (1.45/10 s, 2.0 s cast); Shadow Ward. Ingen infernal-summon, ingen execute.

1. **Summon Infernal** — stor demon in i packen. `aoe` ground + `summonCount` 1 (samma mönster som Army of the Dead), ca 45 s CD; landningen ungefär som en tyngre Rain of Fire-puls, infernalen själv i samma anda som Gargoyle men kortare. Visuellt: en meteor-infernal slår ner och lämnar en fel-krater. Befintlig aoe + summon.
2. **Shadowburn** — execute. `damage` + `executeHpFrac`, ca 6–8 s CD; mot lågt HP ungefär som Chaos Bolt (1.45) eller strax under, men instant. Visuellt: ett kort fel-brand/blixtmärke på den döende, ingen skuggboll. Befintlig `damage` + execute-gate.

---

## Druid

### Balance (`balance`, Moonweft) — 9 → 11

**Idag:** Moonkin Form; Wrath (1.15/5 s, 1.4 s cast), Starfire (1.45/6 s instant); Moonfire och Insect Swarm (DoTs); Hurricane (rain 0.92/12 s), Starfall (rain 1.0/40 s); Typhoon (root 16 s); Barkskin. Ingen instant nukes-CD utöver Starfire, ingen treant-summon, ingen skade-amp.

1. **Starsurge** — instant astral-nukle. `damage`, ca 8–10 s CD, ungefär som Starfire (1.45) eller lite över som CD-knapp. Visuellt: en taggig astral-lans/stråle, inte ännu en Wrath/Starfire-boll. Befintlig `damage`.
2. **Force of Nature** — treant-summon. `summonCount` 3, ca 40 s CD, i samma anda som Feral Spirit (träffar svagare än Starfire). Visuellt: tre treants reser sig ur marken. Befintlig summon.

### Feral (`feral`, Clawdance) — 10 → 11

**Idag:** Cat Form; Shred (1.25/3.5 s), Rake, Rip (bleeds), Ferocious Bite (1.5, combo); Tiger's Fury (grantResource 18 s); Swipe, Thrash; Berserk (haste 40 s); Survival Instincts. Ingen stun/CC (andra katter/rogues har Cheap Shot / Kidney Shot / Maim).

1. **Maim** — stun-finisher. `root` med combo-gate, ca 14 s CD, i samma anda som Kidney Shot / Cheap Shot. Visuellt: ett bedövande bett/hugg, fienden stupar tillfälligt. Befintlig `root` + `comboMin`.

### Guardian (`guardian`, Barkwall) — 11 → 11

Orörd (redan 11).

### Restoration Druid (`restorationDruid`, Bloomward) — 8 → 11

*Oförändrat mot förslaget 2026-11-24.*

**Idag:** Tree of Life; fem filler-healar (Rejuvenation 1.15, Regrowth 1.35, Wild Growth 1.25, Lifebloom 1.15, Nourish 1.55); Tranquility (signature 2.1/45 s); Nature's Swiftness (emergencyHeal 2.2/45 s, legacy-id `barkskinResto`). I princip bara heals — ingen CC, absorb, resource eller yttre defensiv.

1. **Ironbark** — yttre defensiv som Resto saknar. `absorb` eller `emergencyDefend` på lägsta allierad, ca 30–40 s CD; ett medelstarkt skydd, tydligt svagare än Disc Pain Suppression / Holy Guardian Spirit. Visuellt: barkpansar växer över allierad, ingen grön boll. Befintlig `absorb` / `emergencyDefend` (samma mönster som Power Word: Shield / Pain Suppression).
2. **Innervate** — mana-utility så de fem heal-knapparna inte tystnar. `grantResource`, ca 45 s CD, i samma anda som Tiger's Fury / Shamanistic Rage. Visuellt: lönnlöv och manapunkter regnar över druiden. Befintlig `grantResource` som självmål; Innervate på en allierad skulle behöva PI-liknande targeting (då needs new mechanic / mer custom).
3. **Entangling Roots** — enda CC-luckan. `root` på focus, ca 12–16 s CD, ungefär som Chains of Ice. Visuellt: vinrankor bryter upp ur marken runt fienden. Befintlig `root`.

---

## Before → after

Counts verifierade mot både `abilities.json` och kits på main `7b7aedc3`. Visningsnamn från `HeroSpecDef`. Protection stannar på 13.

| Klass | Spec-id | Visningsnamn | Före | Tillagda | Efter |
|---|---|---|---:|---:|---:|
| Warrior | arms | Greatblade | 8 | 3 | 11 |
| Warrior | fury | Twinrage | 9 | 2 | 11 |
| Warrior | protection | Shieldwall | 13 | 0 | 13 |
| Paladin | holyPaladin | Dawnward | 9 | 2 | 11 |
| Paladin | protPaladin | Oathwall | 9 | 2 | 11 |
| Paladin | retribution | Sunstrike | 8 | 3 | 11 |
| Hunter | beastMastery | Packbond | 8 | 3 | 11 |
| Hunter | marksmanship | Longshot | 9 | 2 | 11 |
| Hunter | survival | Snarebow | 9 | 2 | 11 |
| Rogue | assassination | Venomcut | 9 | 2 | 11 |
| Rogue | combat | Alleyblade | 9 | 2 | 11 |
| Rogue | subtlety | Nightstep | 10 | 1 | 11 |
| Priest | discipline | Aegislight | 8 | 3 | 11 |
| Priest | holyPriest | Hymnward | 8 | 3 | 11 |
| Priest | shadow | Duskcant | 9 | 2 | 11 |
| Death Knight | blood | Graveward | 11 | 0 | 11 |
| Death Knight | frostDk | Rimeblade | 8 | 3 | 11 |
| Death Knight | unholy | Blightblade | 9 | 2 | 11 |
| Shaman | elemental | Stormcall | 10 | 1 | 11 |
| Shaman | enhancement | Totemstrike | 9 | 2 | 11 |
| Shaman | restorationShaman | Tidecall | 8 | 3 | 11 |
| Mage | arcane | Prismcast | 8 | 3 | 11 |
| Mage | fire | Cinderweft | 10 | 1 | 11 |
| Mage | frostMage | Glacecast | 9 | 2 | 11 |
| Warlock | affliction | Hexrot | 9 | 2 | 11 |
| Warlock | demonology | Pactimp | 9 | 2 | 11 |
| Warlock | destruction | Ashburst | 9 | 2 | 11 |
| Druid | balance | Moonweft | 9 | 2 | 11 |
| Druid | feral | Clawdance | 10 | 1 | 11 |
| Druid | guardian | Barkwall | 11 | 0 | 11 |
| Druid | restorationDruid | Bloomward | 8 | 3 | 11 |
| **Totalt** | 31 specs | | **282** | **61** | **343** |

Orörda: Blood, Guardian, Protection. 8-ability-specs (9 st) får 3 var; 9-ability (15 st) får 2 var; 10-ability (4 st) får 1 var.

Delade typiska spells mellan specs (redan så i spelet, t.ex. Ice Block, Multi-Shot, Immolate): Kill Shot (BM + MM), Hammer of Justice (Holy Pala + Ret), Word of Glory (Ret + Prot Pala), Shadowfiend (Disc + Shadow), Consecration (Ret, finns redan på Holy/Prot), Execute (Fury, finns redan på Arms), Prayer of Mending (Holy, finns redan på Disc).

---

## Needs new mechanic

Bara den ikoniska varianten kräver ny mekanik. En enklare variant med befintlig kind finns i de flesta fall.

1. **Frozen Orb** (Frost DK) — rullande orb som rör sig själv. Svävande puls på packen = befintlig `aoe` rain/ground.
2. **Breath of Sindragosa** (Frost DK) — tickande resurskanal i kon (channel-pathen är idag enskilt mål, Penance/Mind Flay). Kort konburst = befintlig `aoe` fan.
3. **Claw** (Beast Mastery) — companionen som ursprung för VFX/träffen. Numerär kan vara vanlig `damage`.
4. **Innervate** (Resto Druid) — om den ska ligga på en *allierad* (PI-liknande targeting). Självmål = befintlig `grantResource`.
5. **Holy Word: Sanctify** (Holy Priest) — tickande heal-zon. Puls + liggande disc = befintlig `heal`.
6. **Power Word: Barrier** (Discipline) — samtidig parti-absorb-kupol. Enskild absorb finns redan.
7. **Halo** (Discipline) — bara om ringen också ska *skada fiender* (hybrid). Ren grupp-heal-ring = befintlig `heal`.
8. **Binding Shot** (Marksmanship) — zon som rotar den som *senare går in*. Root vid nedslag + ground disc = befintlig `root`.
9. **Harpoon** (Survival) — dash/pull som flyttar jägare eller fiende. Root på avstånd = befintlig `root`.
10. **Healing Tide Totem** (Resto Shaman) — tickande totem. En puls + fontän-disc = befintlig `heal`.
11. **Mana Tide Totem** (Resto Shaman) — om mana ska delas till *andra casters*. Självmål = befintlig `grantResource`.
12. **Dark Transformation** (Unholy) — riktig pet-modelltransform. Självaampen = befintlig `selfBuff` amp (aura look-only räcker annars).

---

## Att tänka på före ev. implementation

- Inga absoluta tal är föreslagna som färdig balans; coeff/CD är relativa ankare mot nuvarande spells i samma spec.
- Inget av detta ska in i kod, PR, tagg, APK eller Play utan Roberts uttryckliga ja.
- Visuellt: undvik ytterligare färgade bollar.
