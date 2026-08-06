---
title: PhysicsBodyData
layout: default
parent: PhysicsStructuresComponent
nav_order: 6
permalink: /docs/guides/physics-singleton/physics-body-data/
description: PhysicsBodyData — simulation-side body record in BodiesList.
tags: [singleton, native, bodies, struct]
---

# PhysicsBodyData

The **simulation-side body record** stored in each slot of [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}). Import copies ECS components into this struct; internal systems and custom jobs read and write it during the fixed-step loop; export copies pose and velocity back to components.

One **`PhysicsBodyData`** exists per active body index (**`0 … ActiveBodiesCount - 1`**).

## Identity and classification

| Field | Type | Description |
|-------|------|-------------|
| **`Main`** | **`Entity`** | Root entity for the body. Used as the key in [`EntitiesMap`]({% link docs/guides/physics-singleton/entities-map/index.md %}). For kinematic or static triggers this may be a **parent** entity. |
| **`Layer`** | **`int`** | Physics layer bit — same value as Unity layer on the authoring object. |
| **`LodIndex`** | **`int`** | Active LOD tier (0 = closest / highest detail). Set during import when a camera LOD step is present, otherwise from [`PhysicsBodyUpdateComponent`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}). |
| **`IsTrigger`** | **`bool`** | **`true`** for trigger bodies (kinematic or static only). |
| **`BodyType`** | **`BodyType`** | **`Dynamic`**, **`Static`**, or **`Kinematic`**. |
| **`ShapeType`** | **`ShapeType`** | Simulation shape: **`Sphere`**, **`Capsule`**, **`SimplePlane`**, **`ReverseSphere`**, **`SimpleBox`**. |

### Body type helpers

| Property | True when |
|----------|-----------|
| **`IsStatic`** | **`BodyType == Static`** |
| **`IsKinematic`** | **`BodyType == Kinematic`** |
| **`IsDynamic`** | **`BodyType == Dynamic`** |

### Shape constraints

| Body type | Allowed **`ShapeType`** values |
|-----------|-------------------------------|
| Dynamic | **`Sphere`** only |
| Kinematic / static | **`Sphere`**, **`Capsule`** |
| Surface (via surface component) | **`SimplePlane`**, **`SimpleBox`**, **`ReverseSphere`**, etc. |

See [Types of bodies]({% link docs/guides/types-of-bodies/index.md %}) for behavior differences.

## Update cadence

| Field | Type | Description |
|-------|------|-------------|
| **`TimeElapsed`** | **`float`** | Countdown to the next map/collision update tick. |
| **`Interval`** | **`float`** | Period between update ticks for this body. |

Cadence rules (from import / ECS **`PhysicsBodyUpdateComponent`**):

- **`Interval == 0`** — update **every** substep.
- Otherwise **`TimeElapsed`** cycles **`Interval → 0 → Interval → …`**. Broad-phase and pair work run on ticks where **`TimeElapsed == 0`**.
- **`TimeElapsed == -1`** with **`IsStatic`** — static bodies register in [`CollisionMapSingleton.StaticMap`]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) **once**, then skip further map updates.

Triggers use **`Interval`** as their trigger check period.

## Nested simulation data

| Field | Type | Description |
|-------|------|-------------|
| **`PositionData`** | **`PositionData`** | World pose for collision: **`Position`**, **`Scale`**, **`Up`** (capsules), **`RotationOffset`**. |
| **`VelocityData`** | **`VelocityData`** | **`Linear`**, **`Angular`**, **`IsRotationBlocked`**. Populated for dynamics from [`PhysicsVelocityComponent`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}). |
| **`RigidbodyData`** | **`RigidbodyData`** | **`Mass`**, **`Bounciness`**, **`Friction`**, **`Hardness`**, **`AngularDrag`**. |

Field-level detail for the nested structs lives on [Supporting body and collision structs]({% link docs/guides/physics-singleton/supporting-body-collision-structs/index.md %}).

## Import and export

**Import** (`ImportPhysicsDataJob`) builds **`PhysicsBodyData`** from **`PhysicsBodyComponent.ToBodyData`**, then merges:

- **`PhysicsBodyUpdateComponent`** — **`TimeElapsed`**, **`Interval`**, index assignment
- **`PhysicsVelocityComponent`** (if present) — velocity; rotation block from **`ShouldRotateOnCollision`**
- Optional camera LOD pass — overwrites **`LodIndex`**

**Export** reads **`BodiesList[tag.Index]`** and writes **`LocalTransform`**, velocity, and related components back to ECS.

## Custom jobs

Most custom physics logic touches **`PhysicsBodyData`** through package interfaces:

| Interface | Typical use |
|-----------|-------------|
| **`IBodiesJob`** | Read or write every active body |
| **`ICollisionJob`** | React to object-to-object contacts |
| **`ISurfaceJob`** | React to surface contacts |
| **`ILineCastJob`** | Linecast hits against bodies |

Example — read-only pass over all dynamics:

```csharp
public void Execute(in PhysicsBodyData body)
{
    if (!body.IsDynamic)
    {
        return;
    }

    float3 position = body.PositionData.Position;
    float3 velocity = body.VelocityData.Linear;
}
```

Schedule through **`ScheduleAndChain`** on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}) so work chains with **`PhysicsJobHandle`**.

## Related

- [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %}) — native array holding these records
- [EntitiesMap]({% link docs/guides/physics-singleton/entities-map/index.md %}) — **`Main`** entity → index lookup
- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — collision results keyed by body index
- [IBodiesJob]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) — parallel access from custom systems
