---
title: KinematicBodyBuilder
layout: default
parent: Builders
nav_order: 2
permalink: /docs/guides/builders/kinematic-body-builder/
description: Build kinematic rigid or trigger bodies (sphere, capsule) at runtime.
tags: [builders, kinematic, trigger, runtime]
---

# KinematicBodyBuilder

**`KinematicBodyBuilder`** adds **`PhysicsBodyComponent`** and **`PhysicsBodyUpdateComponent`** for a **kinematic** body — either a **rigid** collider that pushes dynamics or a **trigger** that records intersections on an interval. Runtime equivalent of [`KinematicBodyAuthoring`]({% link docs/guides/types-of-bodies/kinematic/index.md %}).

Kinematic bodies support **sphere** and **capsule** shapes. They do **not** receive **`PhysicsVelocityComponent`**.

## Constructor

```csharp
new KinematicBodyBuilder(Entity main = default)
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| **`main`** | **`Entity.Null`** | Root entity for map lookup. When null, **`Build`** uses the target entity as **`Main`** — same as leaving **`Main`** empty on the authoring |

## Defaults before fluent calls

If you call **`Build`** without chaining shape or mode methods:

| Field | Default |
|-------|---------|
| Shape | **Sphere** |
| **`ColliderScale`** | **`1`** |
| **`ColliderLocalPosition`** | **`(0,0,0)`** |
| Mode | **Rigid** (`IsTrigger = false`) |
| **`Bounciness` / `Friction` / `Hardness`** | **`0.5`** each |

## Fluent methods

| Method | Description |
|--------|-------------|
| **`.WithCollider(KinematicBodyAuthoring.ColliderType colliderType, float colliderScale, float3 colliderLocalPosition = default)`** | Sphere or capsule shape, scale, and local offset |
| **`.AsRigidBody(float bounciness, float friction, float hardness)`** | Rigid mode — pushes dynamics; map update every substep (`Interval = 0`) |
| **`.AsTrigger(float updateInterval)`** | Trigger mode — overlap only; map refresh every **`updateInterval`** seconds |

Call **`.AsRigidBody`** or **`.AsTrigger`** to set mode and material behavior. **`.AsTrigger`** also sets **`IsTrigger = true`** and stores the interval on **`PhysicsBodyUpdateComponent`**.

{: .note }
> An **`updateInterval`** of **`0`** schedules trigger checks every substep (same cadence as rigid, still without physical push-out).

## Build

```csharp
public void Build(EntityCommandBuffer commandBuffer, Entity entity)
```

**`Layer`** defaults to **`0`**. Set **`PhysicsBodyComponent.Layer`** on the entity if you rely on layer-based filtering.

## Examples

**Moving rigid platform** (capsule, custom material):

```csharp
using LittlePhysics;
using Unity.Entities;
using Unity.Mathematics;

new KinematicBodyBuilder(mainEntity)
    .WithCollider(
        KinematicBodyAuthoring.ColliderType.Capsule,
        colliderScale: 2f,
        colliderLocalPosition: float3.zero)
    .AsRigidBody(bounciness: 0f, friction: 0.5f, hardness: 1f)
    .Build(commandBuffer, entity);
```

**Proximity trigger** (sphere, 0.5 s refresh):

```csharp
new KinematicBodyBuilder()
    .WithCollider(KinematicBodyAuthoring.ColliderType.Sphere, colliderScale: 3f)
    .AsTrigger(updateInterval: 0.5f)
    .Build(commandBuffer, entity);
```

**Default rigid sphere** (minimal):

```csharp
new KinematicBodyBuilder().Build(commandBuffer, entity);
```

Move kinematics by updating **`LocalTransform`** (or the **`Main`** entity’s transform) from your systems — the builder does not integrate velocity.

## Components written

| Component | Rigid | Trigger |
|-----------|-------|---------|
| **`PhysicsBodyComponent`** | **`BodyType.Kinematic`**, **`IsTrigger = false`**, shape + material | Same with **`IsTrigger = true`** |
| **`PhysicsBodyUpdateComponent.Interval`** | **`0`** | **`updateInterval`** from **`.AsTrigger`** |
| **`PhysicsBodyUpdateComponent.TimeElapsed`** | **`0`** | **`0`** |

Read trigger overlaps from [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) or collision buffers — see [Kinematic triggers]({% link docs/guides/types-of-bodies/kinematic/index.md %}#reading-trigger-overlaps).

## Related

- [Builders overview]({% link docs/guides/builders/index.md %})
- [Kinematic body type]({% link docs/guides/types-of-bodies/kinematic/index.md %})
- [StaticBodyBuilder]({% link docs/guides/builders/static-body-builder/index.md %}) — fixed counterparts
