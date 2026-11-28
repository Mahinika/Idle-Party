part of 'spatial_dungeon_view.dart';

extension _DungeonPaintFloaters on _TileRoomPainter {
  void paintDungeonFloaters(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    // Lite keeps enemy tells and flask rings. Minimal stays still.
    if (showBursts || showGround) {
      for (final burst in world.bursts) {
        SpellShapePaint.paintWorldBurst(canvas, burst, tile, center);
      }
    }

    paintFloaterLabels(
      canvas: canvas,
      tile: tile,
      originX: originX,
      originY: originY,
      floaters: world.floaters,
      visualFrame: visualFrame,
      showBursts: showBursts,
      showPriorityFloaters: showPriorityFloaters,
      vfxQuality: vfxQuality,
      viewWidthTiles: camera.visibleCols,
      inView: _inView,
      minLabelTop: camera.camY,
      maxLabelBottom: camera.camY + camera.visibleRows,
      avoid: [
        for (final hero in world.heroes)
          if (hero.isAlive)
            FloaterReserve.heroHead(
              x: hero.picturePoint().x,
              y: hero.picturePoint().y,
            ),
      ],
    );
  }
}
