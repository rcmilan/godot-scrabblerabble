# Animation System

## Overview

Flexible, object-oriented animation system for tile movements. Uses the Strategy pattern (strategies define WHAT happens) with Executors (define HOW it runs), coordinated by the TileAnimator autoload facade.

## Structure

```
scripts/animation/
├── base/                           # Shared infrastructure
│   ├── tile_animation_strategy.gd  # Abstract base strategy (Resource)
│   ├── animation_context.gd        # Shared state for executors
│   └── animation_executor.gd       # Base executor class
├── draw/                           # Draw-from-bag animation
│   ├── draw_tile_animation.gd      # Rise + fade-in strategy
│   └── batch_animation_executor.gd # Staggered batch executor
├── glide/                          # Smooth position transitions
│   ├── glide_tile_animation.gd     # Bounce-glide strategy
│   └── return_animation_executor.gd# Return/cancel/discard executor
├── shake/                          # Illegal action feedback
│   ├── shake_tile_animation.gd     # Left-right shake strategy
│   └── shake_animation_executor.gd # Single-tile shake executor
├── stomp/                          # Play confirmation
│   ├── stomp_tile_animation.gd     # Rise-slam-particles strategy
│   └── stomp_animation_executor.gd # Multi-phase + particles executor
└── hand/                           # Hand tile layout
    └── hand_fan_layout.gd          # Fan spacing + hover effects
```

## Architecture

```
TileAnimator (autoload facade)
    │
    ├── AnimationContext (shared state)
    │
    ├── draw/  BatchAnimationExecutor  + DrawTileAnimation
    ├── glide/ ReturnAnimationExecutor + GlideTileAnimation
    ├── shake/ ShakeAnimationExecutor  + ShakeTileAnimation
    └── stomp/ StompAnimationExecutor  + StompTileAnimation

Hand (scene)
    └── hand/  HandFanLayout (independent, not managed by TileAnimator)
```

## Design Principles

- **Strategy defines WHAT**: Properties, offsets, timing, lifecycle hooks
- **Executor defines HOW**: Tween creation, reparenting, particle spawning
- **Keep together what changes together**: Each folder has its strategy + executor pair
- **Shared state via Context**: All executors share `AnimationContext` for tween tracking and signal emission

## Signal Lifecycle

```
animation_started → per-tile single_tile_animated → animation_completed
```

## Creating New Animations

1. Create a strategy in a new folder (extends `TileAnimationStrategy`)
2. Create an executor if the animation is complex (extends `AnimationExecutor`), or reuse `BatchAnimationExecutor` for simple batch tweens
3. Wire it in TileAnimator with a public `animate_*()` method

See each subfolder's AGENT.md for detailed documentation.
