---
title: StaticBodyBuilder
layout: default
parent: Builders
nav_order: 3
permalink: /docs/guides/builders/static-body-builder/
description: Build static rigid or trigger bodies (sphere, capsule) at runtime.
tags: [builders, static, trigger, runtime]
---

# StaticBodyBuilder

**`StaticBodyBuilder`** adds **`PhysicsBodyComponent`** and **`PhysicsBodyUpdateComponent`** for a **static** body — fixed geometry that either **pushes dynamics** (rigid) or **records overlaps** (trigger). Runtime equivalent of [`StaticBodyAuthoring`]({% link docs/guides/settings/static/index.md %}).

Static bodies support **sphere** and **capsule** only. They are registered in the spatial map **once** (`TimeElapsed = -1`), unlike kinematic or dynamic bodies.

## Required chaining

**`StaticBodyBuilder`** has no parameterless constructor with baked defaults. Always chain at least:

1. **`.WithCollider(...)`** — shape and size
2. **`.AsRigidBody(...)`** or **`.AsTrigger()`** — mode and material

Calling **`Build`** without **`WithCollider`** leaves **`ColliderScale`** at **`0`**. Calling **`Build`** without **`AsRigidBody`** / **`AsTrigger`** leaves **`IsTrigger = false`** with zero material values.

## Fluent methods

| Method | Description |
|--------|-------------|
| **`.WithCollider(StaticBodyAuthoring.ColliderType colliderType, float colliderScale, float3 colliderLocalPosition = default)`** | Sphere or capsule shape, scale, and local offset |
| **`.AsRigidBody(float bounciness, float friction, float hardness)`** | Rigid static — pushes dynamics when dynamics or kinematics pair against it |
| **`.AsTrigger()`** | Trigger static — overlap data only, no push-out |

There is no update interval on static triggers — static bodies are placed once in **`StaticMap`**. Dynamic and kinematic bodies initiate overlap tests when they query those cells.

## Build

```csharp
public void Build(EntityCommandBuffer commandBuffer, Entity entity)
```

Sets **`PhysicsBodyComponent.Main`** to **`entity`**. **`Layer`** defaults to **`0`**.

## Examples

**Runtime wall** (capsule rigid):

```csharp
using LittlePhysics;
using Unity.Entities;
using Unity.Mathematics;

new StaticBodyBuilder()
    .WithCollider(
        StaticBodyAuthoring.ColliderType.Capsule,
        colliderScale: 1.5f,
        colliderLocalPosition: new float3(0f, 1f, 0f))
    .AsRigidBody(bounciness: 0f, friction: 0.5f, hardness: 1f)
    .Build(commandBuffer, entity);
```

**Pickup zone** (sphere trigger):

```csharp
new StaticBodyBuilder()
    .WithCollider(StaticBodyAuthoring.ColliderType.Sphere, colliderScale: 2f)
    .AsTrigger()
    .Build(commandBuffer, entity);
```

Ensure the entity has a **`LocalTransform`** at the final world pose before import — static bodies do not move after map insertion.

## Components written

| Component | Rigid | Trigger |
|-----------|-------|---------|
| **`PhysicsBodyComponent`** | **`BodyType.Static`**, **`IsTrigger = false`**, shape + material | **`IsTrigger = true`** |
| **`PhysicsBodyUpdateComponent.TimeElapsed`** | **`-1`** (insert once) | **`-1`** |
| **`PhysicsBodyUpdateComponent.Interval`** | **`0`** | **`0`** |

Statics are **not** tested against [surfaces]({% link docs/guides/settings/surface/index.md %}) in the built-in surface pass. For large ground planes, prefer a baked surface body.

## Static vs kinematic at runtime

| Need | Builder |
|------|---------|
| Fixed collider, never moves | **`StaticBodyBuilder`** |
| Moves every frame (platform, door) | **`KinematicBodyBuilder`** |
| Moving overlap volume | **`KinematicBodyBuilder`** with **`.AsTrigger`** |

## Related

- [Builders overview]({% link docs/guides/builders/index.md %})
- [Static body type]({% link docs/guides/settings/static/index.md %})
- [Spatial map — StaticMap]({% link docs/guides/settings/spatial-map/index.md %})
