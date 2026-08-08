---
title: DynamicBodyBuilder
layout: default
parent: Builders
nav_order: 1
permalink: /docs/guides/builders/dynamic-body-builder/
description: Build dynamic sphere bodies at runtime with EntityCommandBuffer.
tags: [builders, dynamic, runtime, sphere]
---

# DynamicBodyBuilder

**`DynamicBodyBuilder`** adds **`PhysicsBodyComponent`**, **`PhysicsBodyUpdateComponent`**, and **`PhysicsVelocityComponent`** to an entity for a **dynamic sphere** body. It is the runtime equivalent of [`DynamicBodyAuthoring`]({% link docs/guides/settings/dynamic/index.md %}) plus optional initial velocity from [`PhysicsVelocityAuthoring`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}).

Dynamic bodies are **spheres only** — the builder always sets **`ColliderType.Sphere`**.

## Constructor

```csharp
new DynamicBodyBuilder(float bounciness, float friction, float hardness, float mass)
```

| Parameter | Role | Authoring default |
|-----------|------|-------------------|
| **`bounciness`** | Restitution on contact | `0` |
| **`friction`** | Material friction | `0.5` |
| **`hardness`** | Push-out weight vs other bodies | `1` |
| **`mass`** | Impulse and collision weighting | `1` |

Material values are required at construction — there is no separate “rigid vs trigger” mode for dynamics.

## Fluent methods

| Method | Default if omitted | Description |
|--------|-------------------|-------------|
| **`.WithCollider(float colliderScale, float3 colliderLocalPosition = default)`** | Scale **`1`**, offset **`(0,0,0)`** | Sphere radius scale and local offset |
| **`.WithVelocity(float3 linear)`** | **`float3.zero`** | Initial linear velocity |
| **`.WithAngVelocity(float3 angular)`** | **`float3.zero`** | Initial angular velocity |
| **`.ShouldRotateOnCollision(bool shouldRotate)`** | **`false`** | When **`true`**, angular velocity can change on impact |

{: .warning }
> **`ShouldRotateOnCollision`** defaults to **`false`** on the builder but **`true`** on **`DynamicBodyAuthoring`**. Call **`.ShouldRotateOnCollision(true)`** if you want authoring-equivalent behavior.

## Build

```csharp
public void Build(EntityCommandBuffer commandBuffer, Entity entity)
```

Adds components to **`entity`**. The entity must gain **`LocalToWorld`** (typically via **`LocalTransform`**) before or when the command buffer plays back, or import will skip it.

**`PhysicsBodyComponent.Main`** is set to **`entity`**. **`Layer`** is left at **`0`** unless you set it separately on the component.

## Example — orbit spawn

From the **Planet** sample: instantiate a prefab, set transform, then build physics:

```csharp
using LittlePhysics;
using Unity.Entities;
using Unity.Mathematics;
using Unity.Transforms;

// Inside a system OnUpdate, after creating a command buffer:
var instance = commandBuffer.Instantiate(prefab);
commandBuffer.SetComponent(
    instance,
    LocalTransform.FromPositionRotationScale(position, quaternion.identity, scale));

new DynamicBodyBuilder(Bounciness, Friction, Hardness, mass)
    .WithVelocity(velocityDirection * speed)
    .Build(commandBuffer, instance);
```

With explicit collider and rotation flag:

```csharp
new DynamicBodyBuilder(0f, 0.5f, 1f, 2f)
    .WithCollider(colliderScale: 0.5f, colliderLocalPosition: new float3(0f, 0.5f, 0f))
    .WithVelocity(new float3(1f, 0f, 0f))
    .WithAngVelocity(new float3(0f, 2f, 0f))
    .ShouldRotateOnCollision(true)
    .Build(commandBuffer, entity);
```

## Components written

| Component | Key values |
|-----------|------------|
| **`PhysicsBodyComponent`** | **`BodyType.Dynamic`**, **`ColliderType.Sphere`**, material fields, **`Main = entity`** |
| **`PhysicsBodyUpdateComponent`** | **`Interval = 0`**, **`TimeElapsed = 0`**, **`Index = -1`**, **`LodIndex = 0`** |
| **`PhysicsVelocityComponent`** | **`Linear`** / **`Angular`** from fluent methods |

Import copies these into [`PhysicsBodyData`]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) on the next **`LateSimulation`** pass. Pairwise collisions apply inside the [spatial map]({% link docs/guides/settings/spatial-map/index.md %}); surface contact runs every substep regardless of map cells.

## Related

- [Builders overview]({% link docs/guides/builders/index.md %})
- [Dynamic body type]({% link docs/guides/settings/dynamic/index.md %})
- [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %})
