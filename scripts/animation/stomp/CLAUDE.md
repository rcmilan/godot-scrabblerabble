# Stomp Animation

Dramatic placement confirmation with multi-phase animation and particle effects.

## Files

| File | Class | Extends |
|------|-------|---------|
| `stomp_tile_animation.gd` | `StompTileAnimation` | `TileAnimationStrategy` |
| `stomp_animation_executor.gd` | `StompAnimationExecutor` | `AnimationExecutor` |

## Visual Effect

Four-phase animation when a word is played:

1. **Rise** (0.15s) -- Tile scales up to 1.35 and lifts 15px
2. **Slam** (0.08s) -- Tile squishes down (1.1x, 0.9y) back to original y
3. **Particles** -- Impact particles burst from 5 edge positions on slam
4. **Recover** (0.12s) -- Tile bounces back to normal scale with elastic ease

## Strategy Properties

- `rise_scale`: Vector2(1.35, 1.35), `rise_offset`: -15.0
- `squish_scale`: Vector2(1.1, 0.9)
- `particle_count`: 12, `particle_speed`: 80.0, `particle_lifetime`: 0.5

## StompAnimationExecutor

Batch executor with complex multi-phase logic. Key details:

- Sets `pivot_offset` to tile center for symmetric scaling
- Spawns `CPUParticles2D` emitters at 5 edge positions (bottom-center, bottom-left, bottom-right, left, right)
- Uses `WeakRef` for safe particle cleanup after lifetime expires
- Tiles are staggered with `stagger_delay` between starts
