part of 'spatial_dungeon_view.dart';

extension DungeonPaintActors on _TileRoomPainter {
  void paintDungeonActors(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    void drawSprite(
      ui.Image image,
      Offset c,
      double scale, {
      double alpha = 1,
      Color? tint,
      bool flipX = false,
    }) {
      final s = tile * scale;
      final dst = Rect.fromCenter(center: c, width: s, height: s);
      if (flipX) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(-1, 1);
        canvas.translate(-c.dx, -c.dy);
        _drawImage(canvas, image, dst, alpha: alpha, tint: tint);
        canvas.restore();
      } else {
        _drawImage(canvas, image, dst, alpha: alpha, tint: tint);
      }
    }

    void drawBar(Offset c, int hp, int maxHp, double width) {
      final frac = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
      final top = c.dy - tile * 0.55;
      final left = c.dx - width / 2;
      final cb = SpatialCombat.colorblindMode;
      final Color fill;
      if (hp <= 0) {
        fill = cb ? const Color(0xFFD55E00) : const Color(0xFFE05050);
      } else if (frac <= 0.35) {
        fill = cb ? const Color(0xFFE69F00) : const Color(0xFFE87850);
      } else {
        fill = cb ? const Color(0xFF009E73) : const Color(0xFFE05050);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, 4),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width * frac, 4),
          const Radius.circular(1),
        ),
        Paint()..color = fill,
      );
    }

    for (final enemy in world.enemies) {
      if (enemy.dormant || !_inView(enemy.x, enemy.y)) continue;
      final img = enemies.isEmpty
          ? null
          : enemies[enemy.assetIndex.clamp(0, enemies.length - 1)];
      if (img == null) continue;
      final flash = enemy.attackFlash;
      final hit = enemy.hitFlash;
      final isBoss = enemy.role == EnemyRole.boss;
      final isElite = enemy.role == EnemyRole.elite;
      final zoneTint = DungeonEnvironment.projectileTint(dungeonId);
      var c = center(enemy.x, enemy.y);
      final scale =
          (isBoss ? 1.42 : (isElite ? 1.18 : 0.9)) *
          (1 + flash * 0.18 + hit * 0.12);
      final moving = enemy.vx.abs() > 0.05 || enemy.vy.abs() > 0.05;
      if (moving && enemy.isAlive) {
        final phase = ((enemy.x + enemy.y).abs() * 2.5 + visualFrame * 0.08) % 1.0;
        c += CharacterVisualPainter.clipMotion(
          HeroAnimKind.walk,
          phase,
          tile * scale,
        );
      }
      if (isBoss && enemy.isAlive) {
        canvas.drawCircle(
          c,
          tile * 0.58,
          Paint()..color = const Color(0x55000000),
        );
        canvas.drawCircle(
          c,
          tile * 0.52,
          Paint()
            ..color = zoneTint.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.8, tile * 0.07),
        );
      }
      drawSprite(img, c, scale, alpha: enemy.isAlive ? 1 : 0.2);
      if (hit > 0.02 && enemy.isAlive) {
        canvas.drawCircle(
          c,
          tile * (isBoss ? 0.42 : 0.34) * (0.55 + hit),
          Paint()
            ..color = zoneTint.withValues(alpha: 0.55 * hit.clamp(0.0, 1.0)),
        );
      }
      if (enemy.isAlive &&
          enemy.fireCooldown > 0 &&
          enemy.fireCooldown < 0.45 &&
          enemy.attackCooldown > 0) {
        final wind = (1.0 - (enemy.fireCooldown / 0.45)).clamp(0.0, 1.0);
        final reach = isBoss ? 0.72 : (isElite ? 0.5 : 0.38);
        final job = switch (enemy.archetype) {
          EnemyArchetype.swarm => const Color(0xFFE8E040),
          EnemyArchetype.brute => const Color(0xFFE07040),
          EnemyArchetype.tank => const Color(0xFFE8C060),
          EnemyArchetype.ranged => const Color(0xFF40C8E8),
          EnemyArchetype.glass => const Color(0xFFE060C0),
          EnemyArchetype.support => const Color(0xFF70E090),
        };
        final tell = Color.lerp(job, zoneTint, 0.22)!;
        canvas.drawCircle(
          c,
          tile * (reach + wind * (isBoss ? 0.28 : 0.12)),
          Paint()
            ..color = tell.withValues(alpha: 0.35 + wind * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(
              isBoss ? 2.4 : 1.6,
              tile * (isBoss ? 0.09 : 0.05),
            ),
        );
      }
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.35 * flash,
          Paint()..color = const Color(0x66FFE8A0),
        );
      }
      if (enemy.isAlive) {
        if (enemy.livingBombTimer > 0) {
          final pulse = 0.85 + 0.15 * math.sin(enemy.livingBombTimer * 10);
          canvas.drawCircle(
            c,
            tile * 0.5 * pulse,
            Paint()..color = const Color(0x66FF5020),
          );
          canvas.drawCircle(
            c,
            tile * 0.5 * pulse,
            Paint()
              ..color = const Color(0xCCFF7030)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.07),
          );
          // Fuse spark
          canvas.drawCircle(
            Offset(c.dx, c.dy - tile * 0.42),
            tile * 0.1,
            Paint()..color = const Color(0xFFFFF0A0),
          );
        }
        if (enemy.sunderStacks > 0 && enemy.sunderTimer > 0) {
          canvas.drawCircle(
            c,
            tile * 0.4,
            Paint()
              ..color = const Color(0x88C0A070)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, tile * 0.05),
          );
        }
        if (enemy.rootTimer > 0) {
          canvas.drawCircle(
            c,
            tile * 0.36,
            Paint()..color = const Color(0x6680D0FF),
          );
          // Stun stars
          for (var i = 0; i < 3; i++) {
            final a = enemy.rootTimer * 4 + i * 2.1;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * tile * 0.42,
                c.dy + math.sin(a) * tile * 0.28 - tile * 0.35,
              ),
              tile * 0.07,
              Paint()..color = const Color(0xFFFFF0A0),
            );
          }
        }
        if (showAuras && enemy.enrageTimer > 0) {
          final pulse = 0.9 + 0.1 * math.sin(enemy.enrageTimer * 12);
          canvas.drawCircle(
            c,
            tile * 0.52 * pulse,
            Paint()
              ..color = const Color(0xAAFF3030)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08),
          );
          canvas.drawCircle(
            c,
            tile * 0.28,
            Paint()..color = const Color(0x44FF5020),
          );
        }
        if (SpatialCombat.alwaysShowEnemyHp ||
            enemy.hp < enemy.maxHp ||
            enemy.hp <= 0) {
          drawBar(c, enemy.hp, enemy.maxHp, tile * 0.85);
        }
      }
    }

    for (final hero in world.heroes) {
      final idx = hero.assetIndex
          .clamp(0, math.max(0, party.length - 1))
          .toInt();
      final partyHero = party.isEmpty ? null : party[idx];
      final flash = hero.attackFlash;
      var c = center(hero.x, hero.y);
      // Prefer smoothed face aim; fall back to attack punch aim.
      final aimX = (hero.faceAimX != 0 || hero.faceAimY != 0)
          ? hero.faceAimX
          : hero.attackAimX;
      final aimY = (hero.faceAimX != 0 || hero.faceAimY != 0)
          ? hero.faceAimY
          : hero.attackAimY;
      // Melee lunge toward the target while attacking (warrior especially).
      if (flash > 0.02 && (aimX != 0 || aimY != 0)) {
        final adx = aimX - hero.x;
        final ady = aimY - hero.y;
        final alen = math.sqrt(adx * adx + ady * ady);
        if (alen > 0.05) {
          final punch = hero.heroRole == HeroRole.warrior ? 0.38 : 0.22;
          c = Offset(
            c.dx + (adx / alen) * tile * punch * flash,
            c.dy + (ady / alen) * tile * punch * flash,
          );
        }
      } else if (aimX != 0 || aimY != 0) {
        // Tiny lean toward facing so idle kits don't look glued forward.
        final adx = aimX - hero.x;
        final ady = aimY - hero.y;
        final alen = math.sqrt(adx * adx + ady * ady);
        if (alen > 0.08) {
          c = Offset(
            c.dx + (adx / alen) * tile * 0.06,
            c.dy + (ady / alen) * tile * 0.04,
          );
        }
      }
      final flipX = (aimX - hero.x) < -0.15;
      final alpha = hero.isAlive ? 1.0 : 0.25;
      final paintAlpha = hero.vanishTimer > 0 ? 0.35 : alpha;
      if (partyHero != null) {
        final moving = hero.vx.abs() > 0.05 || hero.vy.abs() > 0.05;
        final signals = HeroAnimSignals(
          moving: moving,
          attacking: flash > 0.02,
          casting: hero.castFlash > 0.02 || hero.castingTimer > 0.05,
          hit: hero.hitFlash > 0.02,
          dead: !hero.isAlive,
          blocking: hero.shieldBlockTimer > 0,
          attackFlash: flash,
          castFlash: hero.castFlash,
          hitFlash: hero.hitFlash,
        );
        final walkPhase =
            ((hero.x + hero.y).abs() * 2.5 + visualFrame * 0.08) % 1.0;
        final anim = HeroAnimController.snapshot(
          signals,
          walkPhase: walkPhase,
        );
        // Unique form PNG (Druid forms / Shadow) → owned paper-doll → class PNG.
        final useFormSprite =
            CustomAssets.hasUniqueHeroSprite(partyHero.specId);
        final formImg =
            useFormSprite ? heroesBySpec[partyHero.specId] : null;
        final bodyPath = BodyFamilyCatalog.assetFor(partyHero, anim.kind);
        ui.Image? bodyImg =
            useFormSprite ? null : bodyByPath[bodyPath];
        final usingOwnedBody = bodyImg != null;
        Color? tint;
        if (bodyImg == null && formImg == null) {
          bodyImg = heroesBySpec[partyHero.specId] ??
              heroesByClass[HeroIdentity.spriteClassFor(partyHero.specId)];
          final argb = HeroIdentity.tintArgb(partyHero.specId);
          if (argb != null) tint = Color(argb);
        }
        bodyImg ??= heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
        // Form sprites are 96px; owned denser bodies read larger than Kenney.
        // Plate reads broader than leather at HUD size; forms keep their PNG.
        final read = usingOwnedBody
            ? BodyFamilyCatalog.hudReadScale(
                BodyFamilyCatalog.familyFor(partyHero),
              )
            : 1.0;
        final scale = (formImg != null
                ? 1.42
                : (usingOwnedBody ? 1.72 * read : 0.95)) *
            (1 + flash * (hero.heroRole == HeroRole.warrior ? 0.32 : 0.2));
        final motion = CharacterVisualPainter.clipMotion(
          anim.kind,
          anim.progress,
          tile * scale,
          flipX: flipX,
        );
        if (formImg != null) {
          // Persistent form bodies — no gear overlays (silhouette is the kit).
          // Same step bob as the paper doll so a walk is not a frozen PNG.
          drawSprite(
            formImg,
            c + motion,
            scale,
            alpha: paintAlpha,
            flipX: flipX,
          );
        } else if (bodyImg != null) {
          if (usingOwnedBody) {
            final ownedPose = CharacterVisualPoseCache.resolve(
              heroId: hero.id,
              hero: partyHero,
              anim: anim,
              flipX: flipX,
              partyIndex: idx,
              owned: true,
            );
            CharacterVisualPainter.paintOwnedHero(
              canvas,
              c,
              tile * scale,
              body: bodyImg,
              images: bodyByPath,
              pose: ownedPose,
              alpha: paintAlpha,
            );
          } else {
            drawSprite(
              bodyImg,
              c,
              scale,
              alpha: paintAlpha,
              tint: tint,
              flipX: flipX,
            );
          }
        } else {
          final img = heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
          if (img != null) {
            final scale = 0.95 *
                (1 +
                    flash *
                        (hero.heroRole == HeroRole.warrior ? 0.32 : 0.2));
            drawSprite(img, c, scale, alpha: paintAlpha, flipX: flipX);
          }
        }
      }
      // WoW-style persistent auras
      if (showAuras && hero.iceBlockTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.62,
          Paint()..color = const Color(0x5540B0FF),
        );
        canvas.drawCircle(
          c,
          tile * 0.62,
          Paint()
            ..color = const Color(0xCCA0E8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.1),
        );
      }
      // Power Word: Shield — physical bubble around the target (WoW-style).
      if (showAuras && hero.absorbShield > 0) {
        final pulse =
            0.92 + 0.08 * math.sin(hero.x * 3 + hero.absorbShield * 0.2);
        final br = tile * 0.72 * pulse;
        // Soft filled dome
        canvas.drawCircle(c, br, Paint()..color = const Color(0x5548A0E8));
        canvas.drawCircle(
          c,
          br * 0.82,
          Paint()..color = const Color(0x3340B0FF),
        );
        // Outer rim
        canvas.drawCircle(
          c,
          br,
          Paint()
            ..color = const Color(0xEE90D8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.5, tile * 0.1),
        );
        // Specular highlight (top-left) like a glass bubble
        canvas.drawArc(
          Rect.fromCircle(
            center: c.translate(-br * 0.15, -br * 0.2),
            radius: br * 0.55,
          ),
          -2.4,
          1.2,
          false,
          Paint()
            ..color = const Color(0xAAF0FFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (showAuras && hero.combustionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.5,
          Paint()
            ..color = const Color(0x88FF5020)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
      }
      if (showAuras && hero.painSuppressionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.52,
          Paint()
            ..color = const Color(0x88FF8080)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
      }
      if (showAuras && hero.fortitudeTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.44,
          Paint()
            ..color = const Color(0x55FFE8A0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, tile * 0.05),
        );
      }
      if (showAuras && hero.bladeFlurryTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.7,
          Paint()
            ..color = const Color(0x55FF8060)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.05),
        );
      }
      if (showAuras && hero.killingSpreeTimer > 0) {
        final pulse = 0.9 + 0.1 * math.sin(hero.killingSpreeTimer * 14);
        canvas.drawCircle(
          c,
          tile * 0.65 * pulse,
          Paint()
            ..color = const Color(0x88FF3030)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      }
      if (showAuras && hero.powerInfusionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.58,
          Paint()
            ..color = const Color(0x88C070FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
        canvas.drawCircle(
          c,
          tile * 0.35,
          Paint()..color = const Color(0x44E0A0FF),
        );
      }
      if (showAuras && hero.pomCharges > 0) {
        for (var i = 0; i < hero.pomCharges.clamp(0, 5); i++) {
          final a = hero.x + i * 1.25 + hero.pomCharges;
          canvas.drawCircle(
            Offset(
              c.dx + math.cos(a) * tile * 0.48,
              c.dy + math.sin(a) * tile * 0.48,
            ),
            tile * 0.08,
            Paint()..color = const Color(0xFFFFF0A0),
          );
        }
      }
      if (showAuras &&
          hero.innerFireActive &&
          hero.heroRole == HeroRole.healer) {
        canvas.drawCircle(
          c,
          tile * 0.38,
          Paint()
            ..color = const Color(0x55FFE8A0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, tile * 0.05),
        );
      }
      if (showAuras && hero.sliceAndDiceTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.46,
          Paint()
            ..color = const Color(0x88FFD070)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, tile * 0.05),
        );
      }
      if (showAuras && hero.sprintTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.4,
          Paint()..color = const Color(0x44FFFFA0),
        );
      }
      if (showAuras && hero.shieldWallTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.55,
          Paint()
            ..color = const Color(0x8890B8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      } else if (showAuras && hero.shieldBlockTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.48,
          Paint()
            ..color = const Color(0x779AD0FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
      }
      if (showAuras && hero.lastStandTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.6,
          Paint()
            ..color = const Color(0x88FFA040)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      }
      // Generic kit buffTimers (shield / buff) when no dedicated aura fired.
      if (showAuras) {
        final shieldT = hero.buffTimers['shield'] ?? 0;
        final buffT = hero.buffTimers['buff'] ?? 0;
        if (shieldT > 0 &&
            hero.shieldBlockTimer <= 0 &&
            hero.shieldWallTimer <= 0 &&
            hero.absorbShield <= 0) {
          canvas.drawCircle(
            c,
            tile * 0.5,
            Paint()
              ..color = const Color(0x7790C0FF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.06),
          );
        }
        if (buffT > 0 &&
            hero.combustionTimer <= 0 &&
            hero.powerInfusionTimer <= 0) {
          canvas.drawCircle(
            c,
            tile * 0.46,
            Paint()
              ..color = const Color(0x66E0A060)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.4, tile * 0.05),
          );
        }
      }
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.42 * flash,
          Paint()
            ..color = hero.heroRole == HeroRole.warrior
                ? const Color(0x99FFE080)
                : const Color(0x77FFF0C0),
        );
      }
      if (hero.isAlive &&
          showGuide &&
          hero.castingTimer > 0.02 &&
          hero.castingDuration > 0.05) {
        final progress =
            (1.0 - (hero.castingTimer / hero.castingDuration)).clamp(0.0, 1.0);
        final ringR = tile * 0.52;
        final rect = Rect.fromCircle(center: c, radius: ringR);
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2,
          false,
          Paint()
            ..color = const Color(0x55FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * progress,
          false,
          Paint()
            ..color = const Color(0xEEFFE08A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.2, tile * 0.09)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (hero.isAlive) {
        drawBar(c, hero.hp, hero.effectiveMaxHp, tile * 0.8);
      }
    }

    for (final pet in world.pets) {
      final flash = pet.attackFlash;
      final c = center(pet.x, pet.y);
      final isClass = pet.id.startsWith('classpet_');
      final isTemp = pet.id.startsWith('temppet_');
      final petPath = isClass || isTemp
          ? CustomAssets.petForCombatActorId(pet.id, pet.name)
          : CustomAssets.petForInstanceId(
              pet.id.startsWith('pet_') ? pet.id.substring(4) : pet.id,
            );
      final petImg = petsByPath[petPath];
      final ringArgb = isTemp
          ? 0xAA90D8FF
          : isClass
          ? 0xAA50E0A8
          : 0xAAFFE08A;
      canvas.drawCircle(
        c,
        tile * 0.4,
        Paint()
          ..color = Color(ringArgb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, tile * 0.055),
      );
      final scale =
          (isClass ? 0.78 : isTemp ? 0.72 : 0.68) * (1 + flash * 0.22);
      drawSprite(petImg ?? coin, c, scale);
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.32 * flash,
          Paint()..color = const Color(0x66FFE8A0),
        );
      }
    }
  }
}
