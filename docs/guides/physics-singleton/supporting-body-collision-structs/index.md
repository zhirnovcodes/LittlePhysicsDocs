---
title: Supporting body and collision structs
layout: default
parent: Physics singleton
nav_order: 13
permalink: /docs/guides/physics-singleton/supporting-body-collision-structs/
description: RigidbodyData, VelocityData, PositionData, CollisionData, SurfaceCollisionData, and collision helper structs.
tags: [struct, body, collision, native]
---

# Supporting body and collision structs

Little Physics stores simulation state in small **value types** rather than scattering fields across many ECS components inside the fixed-step loop. Most body fields live inside [`PhysicsBodyData`]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) on [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}); collision results live in [`CollisionsSingleton`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}).

This page documents those nested and result structs. Use it when reading or writing native buffers from custom jobs, or when tracing how import and export map between ECS components and simulation memory.

## Overview

| Struct | Used in | Role |
|--------|---------|------|
| **`PositionData`** | **`PhysicsBodyData.PositionData`** | World pose and shape size for collision |
| **`VelocityData`** | **`PhysicsBodyData.VelocityData`** | Linear and angular velocity; rotation block flag |
| **`RigidbodyData`** | **`PhysicsBodyData.RigidbodyData`** | Mass and material coefficients |
| **`SurfaceCollisionData`** | **`CollisionsSingleton.SurfaceCollisionMap`** | Per-body contact with the scene surface |
| **`CollisionData`** | **`CollisionsSingleton.CollisionDataMap`** | Per-slot object-to-object contact |
| **`BodyCollisionResult`** | **`CollisionMethods.ResolvePair`** output | Impulse deltas before they are packed into **`CollisionData`** |
| **`IntersectionData`** | Intersection tests in **`CollisionMethods`** | Raw overlap geometry between two shapes |

## PositionData

Simulation pose derived from **`LocalToWorld`** during import (via **`CollisionMethods.ToPositionData`**). Collision, broad-phase AABB, and export all read this struct — not the raw ECS transform.

| Field | Type | Description |
|-------|------|-------------|
| **`Position`** | **`float3`** | World-space collider center |
| **`Scale`** | **`float`** | Uniform radius or primary size (spheres, capsules, reverse spheres) |
| **`Up`** | **`float3`** | Capsule axis direction (bottom cap → top cap). Unused for spheres. |
| **`RotationOffset`** | **`float3`** | Euler rotation accumulated during simulation. Export applies this back to **`LocalTransform.Rotation`**. |

Shape-specific mapping from the transform matrix:

| **`ShapeType`** | **`Position`** | **`Scale`** | **`Up`** |
|-----------------|----------------|-------------|----------|
| **`Sphere`** | Matrix translation | Length of column 0 | — |
| **`Capsule`** | Matrix translation | Length of column 0 | Computed capsule axis |
| **`SimplePlane`** | Plane height (**`c3.y`**) | — | — |
| **`SimpleBox`** | Matrix translation | **`c0.x`** | Per-axis extents in **`Up`** |
| **`ReverseSphere`** | Matrix translation | **`c0.x`** | — |

## VelocityData

Populated for **dynamic** bodies during import from [`PhysicsVelocityComponent`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}) and updated throughout the fixed step. Kinematic and static bodies may carry default values; only dynamics integrate velocity each substep.

| Field | Type | Description |
|-------|------|-------------|
| **`Linear`** | **`float3`** | World linear velocity |
| **`Angular`** | **`float3`** | World angular velocity |
| **`IsRotationBlocked`** | **`bool`** | When **`true`**, angular integration and collision-induced spin are skipped. Set from **`!PhysicsBodyComponent.ShouldRotateOnCollision`** at import. |

Export copies **`Linear`** and **`Angular`** back to **`PhysicsVelocityComponent`** for dynamic bodies only.

## RigidbodyData

Material and mass data copied from [`PhysicsBodyComponent`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}) or [`CollisionSurfaceComponent`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}) at import. Internal impulse and friction systems read these fields during resolution.

| Field | Type | Description |
|-------|------|-------------|
| **`Mass`** | **`float`** | Body mass. Dynamics only; surfaces and zero-mass kinematics use defaults. |
| **`Bounciness`** | **`float`** | Restitution — how much velocity reflects off this body |
| **`Friction`** | **`float`** | Contact friction coefficient |
| **`Hardness`** | **`float`** | Push-out weighting — stiffer bodies displace softer ones |
| **`AngularDrag`** | **`float`** | Angular damping when in contact with a surface. Set on surface bodies via **`SurfaceBodyAuthoring`**. |

## SurfaceCollisionData

One entry per body index in **`SurfaceCollisionMap`**. **`SurfaceCollisionSystem`** clears and refills this array each substep; every **dynamic** body is tested against the scene surface regardless of LOD or spatial map membership.

| Field | Type | Description |
|-------|------|-------------|
| **`IsColliding`** | **`bool`** | **`true`** when the body contacts the surface this substep |
| **`ContactPoint`** | **`float3`** | Contact point on the surface |
| **`Normal`** | **`float3`** | Outward surface normal at the contact |

**`FrictionSystem`** reads **`IsColliding`** and **`Normal`** when applying surface friction. Custom [`ISurfaceJob`]({% link docs/guides/custom-jobs/isurface-job/index.md %}) callbacks receive this struct per body index — only colliding entries invoke **`Execute`** (body variants filter on **`IsColliding`** automatically).

## CollisionData

One slot in a per-body list inside **`CollisionDataMap`**. **`CollisionDetectionSystem`** writes slots after pair collection; **`CollisionVelocitySystem`** sums **`LinearVelocity`** and **`AngularVelocity`** deltas into body velocity for solid pairs.

| Field | Type | Description |
|-------|------|-------------|
| **`HasValue`** | **`bool`** | **`true`** when this slot contains a valid contact |
| **`OtherIndex`** | **`uint`** | Index of the other body in **`BodiesList`** |
| **`ContactPoint`** | **`float3`** | World contact point |
| **`Normal`** | **`float3`** | Outward normal on **this** body at the contact |
| **`LinearVelocity`** | **`float3`** | Linear velocity **delta** from impulse resolution (not absolute velocity) |
| **`AngularVelocity`** | **`float3`** | Angular velocity **delta** from impulse resolution |
| **`PenetrationDepth`** | **`float`** | Raw overlap depth between shapes |
| **`PushOutWeight`** | **`float`** | This body's share of positional push-out |

{: .note }
> For **trigger** overlaps or pairs where neither side is dynamic, slots still record geometry (**`ContactPoint`**, **`Normal`**, **`PenetrationDepth`**) but leave velocity deltas at zero. Use triggers in [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) by reading overlap data without expecting impulse fields.

Each body can hold up to **`CollisionPerEntity`** slots for its active LOD tier. Iterate with [`ListsArray<CollisionData>`]({% link docs/guides/physics-singleton/lists-array/index.md %}) — see [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) for examples.

## BodyCollisionResult

Intermediate output from **`CollisionMethods.ResolveCollision`** before results are copied into **`CollisionData`**. Useful when calling **`CollisionMethods`** directly (custom collision tests, tooling, or extensions).

| Field | Type | Description |
|-------|------|-------------|
| **`LinearVelocityChange`** | **`float3`** | Linear impulse delta to apply |
| **`AngularVelocityChange`** | **`float3`** | Angular impulse delta to apply |
| **`Normal`** | **`float3`** | Outward normal at the contact for this body |

These map to **`CollisionData.LinearVelocity`**, **`CollisionData.AngularVelocity`**, and **`CollisionData.Normal`** when **`ResolvePair`** builds collision slots for solid dynamic pairs.

## IntersectionData

Geometric overlap result from shape-pair tests inside **`CollisionMethods`**. Does not include material or impulse data.

| Field | Type | Description |
|-------|------|-------------|
| **`ContactPoint`** | **`float3`** | World contact point |
| **`PenetrationDepth`** | **`float`** | Overlap depth |
| **`Normal1`** | **`float3`** | Outward normal for body 1 |
| **`Normal2`** | **`float3`** | Outward normal for body 2 |

Call **`Inverse()`** to swap **`Normal1`** and **`Normal2`** when reversing the pair order.

## Related

- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — parent record containing **`PositionData`**, **`VelocityData`**, and **`RigidbodyData`**
- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — buffers holding **`CollisionData`** and **`SurfaceCollisionData`**
- [Other public ECS components]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}) — ECS-side source fields baked into these structs
- [Settings]({% link docs/guides/settings/index.md %}) — which body types populate velocity and collision results
