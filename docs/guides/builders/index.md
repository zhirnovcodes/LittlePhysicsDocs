---
title: Builders
layout: default
nav_order: 9
has_children: true
permalink: /docs/guides/builders/
description: Runtime helpers for spawning physics bodies without scene authorings.
tags: [guides, builders, runtime, spawning]
---

# Builders

**Builders** are fluent structs that add Little Physics ECS components through an **`EntityCommandBuffer`**. Use them when you spawn or instantiate entities at runtime instead of baking bodies from scene authorings.

Each builder mirrors what its matching authoring baker writes:

| Builder | Authoring equivalent | Body type |
|---------|---------------------|-----------|
| [`DynamicBodyBuilder`]({% link docs/guides/builders/dynamic-body-builder/index.md %}) | [`DynamicBodyAuthoring`]({% link docs/guides/types-of-bodies/dynamic/index.md %}) | Dynamic sphere |
| [`KinematicBodyBuilder`]({% link docs/guides/builders/kinematic-body-builder/index.md %}) | [`KinematicBodyAuthoring`]({% link docs/guides/types-of-bodies/kinematic/index.md %}) | Kinematic sphere or capsule |
| [`StaticBodyBuilder`]({% link docs/guides/builders/static-body-builder/index.md %}) | [`StaticBodyAuthoring`]({% link docs/guides/types-of-bodies/static/index.md %}) | Static sphere or capsule |

Builders do **not** replace surfaces or scene singletons — use [`SurfaceBodyAuthoring`]({% link docs/guides/types-of-bodies/surface/index.md %}), [`SpacialMapAuthoring`]({% link docs/getting-started/index.md %}), and [`PhysicsSettingsAuthoring`]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) in the subscene as usual.

## When to use builders

| Use **authorings** when… | Use **builders** when… |
|--------------------------|-------------------------|
| Level geometry and prefabs baked in a subscene | Spawning particles, debris, or projectiles from systems |
| Designers tune colliders in the Inspector | Procedural placement (crowds, asteroids, pickups) |
| You need GameObject **layer** copied at bake time | You control layer and transform from code after instantiate |

## Runtime workflow

1. **Instantiate** or create an entity that already has **`LocalTransform`** (or will receive it in the same command buffer playback).
2. **Call `Build`** on the builder with an **`EntityCommandBuffer`** and the target entity.
3. On the next **`LateSimulation`** pass, **`ImportPhysicsDataSystem`** copies the entity into [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}) if it has **`LocalToWorld`**, **`PhysicsBodyComponent`**, and **`PhysicsBodyUpdateComponent`**.

Qualifying entities are counted toward **`MaxEntitiesCount`**. Excess bodies are disabled for the frame — same cap as baked authorings.

{: .note }
> Physics starts on the **import pass after** command buffer playback, not on the same frame as `Build` if playback happens late in the frame. For spawn systems, the package samples use **`BeginSimulationEntityCommandBufferSystem`**.

### Minimal dynamic spawn

```csharp
var commandBuffer = SystemAPI
    .GetSingleton<BeginSimulationEntityCommandBufferSystem.Singleton>()
    .CreateCommandBuffer(state.WorldUnmanaged);

var entity = commandBuffer.Instantiate(prefab);
commandBuffer.SetComponent(entity, LocalTransform.FromPosition(position));

new DynamicBodyBuilder(bounciness: 0f, friction: 0.5f, hardness: 1f, mass: 1f)
    .WithCollider(colliderScale: 1f)
    .WithVelocity(linearVelocity)
    .Build(commandBuffer, entity);
```

See the **Planet** and **Plane** samples (Package Manager → Little Physics → All Samples) for full spawn systems.

## What builders add

All three builders add **`PhysicsBodyComponent`** and **`PhysicsBodyUpdateComponent`**. Only **`DynamicBodyBuilder`** also adds **`PhysicsVelocityComponent`**.

| Component | Set by builders |
|-----------|-----------------|
| **`PhysicsBodyComponent`** | Body type, shape, material, `Main` entity |
| **`PhysicsBodyUpdateComponent`** | Import index, interval, `TimeElapsed` (static uses `-1`) |
| **`PhysicsVelocityComponent`** | Dynamic bodies only — initial linear and angular velocity |

Field-level detail lives on [Other public ECS components]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}).

## Differences from authorings

| Topic | Authorings | Builders |
|-------|------------|----------|
| **`Layer`** | Copied from GameObject layer | Defaults to **`0`** — set with `commandBuffer.SetComponent` if you need filtering |
| **`Main`** (kinematic) | Optional GameObject reference | Optional **`Entity`** in `KinematicBodyBuilder` constructor |
| **Initial velocity** (dynamic) | `PhysicsVelocityAuthoring` on same GameObject | `.WithVelocity` / `.WithAngVelocity` |
| **`ShouldRotateOnCollision`** (dynamic) | Default **`true`** | Default **`false`** — call `.ShouldRotateOnCollision(true)` to match authoring |

Surfaces cannot be created with builders — only dynamic, kinematic, and static bodies.

## Custom import hooks

If you need to adjust spawned entities before they enter native memory, add systems to **`LittlePhysicsImportGroup`** before **`LittlePhysicsInternalImportGroup`**. See [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}).

## Related

- [Types of bodies]({% link docs/guides/types-of-bodies/index.md %}) — behavior of each body type
- [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) — when spawned bodies join simulation
- [Physics singleton]({% link docs/guides/physics-singleton/index.md %}) — native buffers after import
