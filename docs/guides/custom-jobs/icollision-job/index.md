---
title: ICollisionJob
layout: default
parent: Custom jobs
nav_order: 3
permalink: /docs/guides/custom-jobs/icollision-job/
description: Per object-to-object collision slot parallel custom job interface.
tags: [custom-jobs, icollision-job, collision]
---

# ICollisionJob

Parallel job callbacks over [`CollisionDataMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — one invocation per **filled collision slot**. Schedule inside **`LittlePhysicsUserSystemGroup`** after internal detection and velocity resolution populate pair data.

## Nested interfaces

| Interface | `Execute` signature | Access |
|-----------|---------------------|--------|
| **`ICollisionJob`** (base) | `Execute(in int index, in CollisionData collision)` | Body index + collision slot only |
| **`ICollisionJob.IReadBody`** | `Execute(in PhysicsBodyData body, in CollisionData collision)` | Owning body read-only |
| **`ICollisionJob.IWriteBody`** | `Execute(ref PhysicsBodyData body, in CollisionData collision)` | Owning body read-write |
| **`ICollisionJob.IReadBodies`** | `Execute(in PhysicsBodyData body1, in PhysicsBodyData body2, in CollisionData collision)` | Both bodies read-only |
| **`ICollisionJob.IWriteBodies`** | `Execute(ref PhysicsBodyData body1, in PhysicsBodyData body2, in CollisionData collision)` | Owning body read-write, other read-only |
| **`ICollisionJob.IEntities`** | `Execute(in Entity entity1, in Entity entity2, in CollisionData collision)` | Entity IDs + collision slot |

The **owning body** is the body whose outer index in **`CollisionDataMap`** matches the iteration index. The **other body** comes from **`collision.OtherIndex`** in **`BodiesList`**.

Extension classes: **`ICollisionJobExtensions`**, **`ICollisionReadBodyExtensions`**, **`ICollisionWriteBodyExtensions`**, **`ICollisionReadBodiesExtensions`**, **`ICollisionWriteExtensions`**, **`ICollisionEntitiesExtensions`**.

## Iteration rules

For each body index **`0 … ActiveBodiesCount - 1`**:

1. Skip if **`body.Main == Entity.Null`**.
2. Iterate collision slots **`0 … GetCount(index) - 1`**.
3. Skip slots where **`!collision.HasValue`**.

Write variants (**`IWriteBody`**, **`IWriteBodies`**) persist changes to the owning body only — **`body1`** at the map index. They do not write **`body2`**.

## CollisionData fields

Each slot carries contact geometry and optional impulse data. See [Supporting body and collision structs — CollisionData]({% link docs/guides/physics-singleton/supporting-body-collision-structs/index.md %}).

Key fields for custom logic:

| Field | Use |
|-------|-----|
| **`OtherIndex`** | Index of the other body in **`BodiesList`** |
| **`HasValue`** | Whether the slot contains a contact this substep |
| **`ContactPoint`**, **`Normal`**, **`PenetrationDepth`** | Overlap geometry |
| **`LinearVelocityChange`**, **`AngularVelocityChange`** | Impulse deltas from internal resolution (zero for pure trigger overlaps) |

Triggers still receive slots when overlaps occur — filter on **`body.IsTrigger`** / **`body.IsDynamic`** in your callback.

## Scheduling

```csharp
new TriggerAttractionJob { Velocity = power * deltaTime }
    .ScheduleAndChain(ref state, in structures, ref simulation);
```

## Example — trigger attraction

From **Scene 4 — Trigger**. Pulls dynamic bodies toward kinematic triggers when a pair slot fires:

```csharp
[BurstCompile]
[UpdateInGroup(typeof(LittlePhysicsUserSystemGroup))]
public partial struct TriggerAttractionSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state)
    {
        state.RequireForUpdate<PhysicsReadyTag>();
        state.RequireForUpdate<TriggerAttractionComponent>();
    }

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;
        var attraction = SystemAPI.GetSingleton<TriggerAttractionComponent>();
        var deltaTime = SystemAPI.GetSingleton<LittlePhysicsTimeComponent>().DeltaTime;

        new TriggerAttractionJob
        {
            Velocity = attraction.Power * deltaTime,
        }.ScheduleAndChain(ref state, in structures, ref simulation);
    }

    [BurstCompile]
    private struct TriggerAttractionJob : ICollisionJob.IWriteBodies
    {
        public float Velocity;

        public void Execute(ref PhysicsBodyData body1, in PhysicsBodyData body2, in CollisionData collision)
        {
            if (body1.IsTrigger || !body1.IsDynamic || !body2.IsTrigger)
            {
                return;
            }

            float3 toTrigger = body2.PositionData.Position - body1.PositionData.Position;
            float distance = math.length(toTrigger);

            if (distance < 0.001f)
            {
                return;
            }

            var velocity = body1.VelocityData;
            velocity.Linear += (toTrigger / distance) * Velocity;
            body1.VelocityData = velocity;
        }
    }
}
```

## Example — entity-only gameplay events

Use **`IEntities`** when you only need entity IDs to enqueue events, without modifying body data:

```csharp
[BurstCompile]
private struct CollisionEventJob : ICollisionJob.IEntities
{
    public NativeQueue<EntityPairEvent>.ParallelWriter Events;

    public void Execute(in Entity entity1, in Entity entity2, in CollisionData collision)
    {
        Events.Enqueue(new EntityPairEvent { A = entity1, B = entity2 });
    }
}
```

## When to use

| Use **`ICollisionJob`** | Consider instead |
|-------------------------|------------------|
| Per-pair forces, trigger gameplay, custom separation | **`ISurfaceJob`** for ground/surface contact |
| Reading pair geometry after internal resolution | **`IBodiesJob`** for body-wide logic unrelated to pairs |
| Entity-level collision events | [Pairs debug window]({% link docs/guides/pairs-debug-window/index.md %}) for runtime inspection |

## Related

- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — buffer layout and update cycle
- [Settings — triggers]({% link docs/guides/settings/index.md %}) — trigger vs rigid pair behavior
- [ISurfaceJob]({% link docs/guides/custom-jobs/isurface-job/index.md %}) — surface contact callbacks
