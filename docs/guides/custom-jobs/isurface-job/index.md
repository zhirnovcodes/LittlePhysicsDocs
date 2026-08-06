---
title: ISurfaceJob
layout: default
parent: Custom jobs
nav_order: 4
permalink: /docs/guides/custom-jobs/isurface-job/
description: Per-body surface collision parallel custom job interface.
tags: [custom-jobs, isurface-job, surface]
---

# ISurfaceJob

Parallel job callbacks over [`SurfaceCollisionMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — one entry per active body index. Schedule inside **`LittlePhysicsUserSystemGroup`** after **`SurfaceCollisionSystem`** fills contact data.

Every **dynamic** body is tested against the scene surface **each substep**, independent of LOD or spatial map bounds.

## Nested interfaces

| Interface | `Execute` signature | Access |
|-----------|---------------------|--------|
| **`ISurfaceJob`** (base) | `Execute(in int index, in SurfaceCollisionData collision)` | Body index + surface hit |
| **`ISurfaceJob.IReadBody`** | `Execute(in PhysicsBodyData body, in SurfaceCollisionData collision)` | Body read-only |
| **`ISurfaceJob.IWriteBody`** | `Execute(ref PhysicsBodyData body, in SurfaceCollisionData collision)` | Body read-write |
| **`ISurfaceJob.IEntity`** | `Execute(in Entity entity, in SurfaceCollisionData collision)` | Entity ID + surface hit |

Extension classes: **`ISurfaceJobExtensions`**, **`ISurfaceReadExtensions`**, **`ISurfaceWriteExtensions`**, **`ISurfaceEntityExtensions`**.

## Iteration rules

For each index **`0 … ActiveBodiesCount - 1`**:

1. Read **`SurfaceCollisionMap[index]`**.
2. **Skip** if **`!collision.IsColliding`** — body variants and the base interface only invoke your callback for active contacts.
3. Skip if **`body.Main == Entity.Null`** (body variants only).
4. Write variants persist changes back to **`BodiesList[index]`**.

## SurfaceCollisionData fields

See [Supporting body and collision structs — SurfaceCollisionData]({% link docs/guides/physics-singleton/supporting-body-collision-structs/index.md %}).

| Field | Use |
|-------|-----|
| **`IsColliding`** | Whether the body contacts the surface this substep |
| **`ContactPoint`** | World-space contact location |
| **`Normal`** | Outward surface normal at contact — used by **`FrictionSystem`** |

## Scheduling

```csharp
new SurfaceTangentDampJob { Damping = 0.9f }
    .ScheduleAndChain(ref state, in structures, ref simulation);
```

## Example — tangent velocity damping

Reduces velocity along the surface plane when a dynamic body is in contact:

```csharp
[BurstCompile]
[UpdateInGroup(typeof(LittlePhysicsUserSystemGroup))]
public partial struct SurfaceTangentDampSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state) =>
        state.RequireForUpdate<PhysicsReadyTag>();

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

        new SurfaceTangentDampJob { Damping = 0.9f }
            .ScheduleAndChain(ref state, in structures, ref simulation);
    }

    [BurstCompile]
    private struct SurfaceTangentDampJob : ISurfaceJob.IWriteBody
    {
        public float Damping;

        public void Execute(ref PhysicsBodyData body, in SurfaceCollisionData collision)
        {
            if (!body.IsDynamic)
            {
                return;
            }

            var velocity = body.VelocityData;
            float3 tangent = velocity.Linear
                - math.dot(velocity.Linear, collision.Normal) * collision.Normal;
            velocity.Linear = tangent * Damping;
            body.VelocityData = velocity;
        }
    }
}
```

Non-colliding bodies are filtered out before **`Execute`** runs — you do not need to check **`IsColliding`** in body variants, though checking **`body.IsDynamic`** is still recommended.

## Example — entity gameplay hook

Use **`IEntity`** to fire events without touching **`PhysicsBodyData`**:

```csharp
[BurstCompile]
private struct SurfaceTouchEventJob : ISurfaceJob.IEntity
{
    public NativeQueue<Entity>.ParallelWriter TouchEvents;

    public void Execute(in Entity entity, in SurfaceCollisionData collision)
    {
        TouchEvents.Enqueue(entity);
    }
}
```

## When to use

| Use **`ISurfaceJob`** | Consider instead |
|-----------------------|------------------|
| Custom slide, stick, or bounce against the scene surface | **`ICollisionJob`** for body-to-body contacts |
| Gameplay that triggers on ground contact | **`IBodiesJob`** when contact data is irrelevant |
| Inspecting surface hits in debug builds | [Pairs debug window]({% link docs/guides/pairs-debug-window/index.md %}) — object-to-object only, not surface |

Surface results are **not** shown in the pairs debug window.

## Related

- [CollisionsSingleton — SurfaceCollisionMap]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}#surfacecollisionmap)
- [Types of bodies — Surface]({% link docs/guides/types-of-bodies/surface/index.md %}) — how surface bodies participate in simulation
- [ICollisionJob]({% link docs/guides/custom-jobs/icollision-job/index.md %}) — object-to-object collision callbacks
