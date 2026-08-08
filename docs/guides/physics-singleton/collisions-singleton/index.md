---
title: CollisionsSingleton
layout: default
parent: PhysicsStructuresComponent
nav_order: 5
permalink: /docs/guides/physics-singleton/collisions-singleton/
description: CollisionsSingleton — per-body surface and object-to-object collision results.
tags: [singleton, native, collision, surface]
---

# CollisionsSingleton

A nested struct on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}) that stores **per-body collision results** for the current fixed substep. Internal systems write here during detection and surface checks; custom job interfaces and debug tools read the same buffers.

## Fields

| Field | Type | Keyed by | Written by |
|-------|------|----------|------------|
| **`SurfaceCollisionMap`** | **`NativeArray<SurfaceCollisionData>`** | Body index | **`SurfaceCollisionSystem`** |
| **`CollisionDataMap`** | **`ListsArray<CollisionData>`** | Body index (outer); collision slot (inner) | **`CollisionDetectionSystem`** |

Both buffers are sized to **`MaxEntitiesCount`** at bootstrap. Live data uses indices **`0 … ActiveBodiesCount - 1`**.

### SurfaceCollisionMap

One **`SurfaceCollisionData`** per body index — contact flag, point, and normal against the scene [surface body]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %}). Every **dynamic** body is tested against the surface **each substep**, independent of the spatial map.

**`FrictionSystem`** reads **`IsColliding`** and **`Normal`** from this array when applying friction.

### CollisionDataMap

A [`ListsArray<CollisionData>`]({% link docs/guides/physics-singleton/lists-array/index.md %}) per body (see [Collision slots](#collision-slots) below). Each slot holds one **object-to-object** contact: the other body’s index, contact geometry, penetration depth, and push-out weight. Check **`HasValue`** before using a slot.

Pair collection respects LOD caps (**`PairPerEntity`**, **`CollisionPerEntity`**) from [physics settings]({% link docs/guides/settings/physics-settings-and-lod/index.md %}). Triggers still receive pair slots when overlaps occur — read results in [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) or inspect the map directly.

## Collision slots

Bootstrap allocates:

```
CollisionDataMap = ListsArray<CollisionData>(maxEntities, max.CollisionPerEntity, Persistent)
```

**`max.CollisionPerEntity`** is the maximum across LOD tiers. At runtime each body’s effective cap comes from its **`LodIndex`** and current time scale.

Iterate collisions for a body:

```csharp
var collisionMap = structures.Collisions.CollisionDataMap;
int collisionCount = collisionMap.GetCount(bodyIndex);

for (int slot = 0; slot < collisionCount; slot++)
{
    var collision = collisionMap.GetValue(bodyIndex, slot);

    if (!collision.HasValue)
    {
        continue;
    }

    var otherBody = structures.BodiesList[(int)collision.OtherIndex];
    // ...
}
```

See [Supporting body and collision structs]({% link docs/guides/physics-singleton/supporting-body-collision-structs/index.md %}) for **`CollisionData`** and **`SurfaceCollisionData`** field details.

## Update cycle (fixed step)

Buffers are **cleared and refilled each substep** — do not assume results persist across substeps or frames.

| Phase | System | Action |
|-------|--------|--------|
| After map update | **`CollisionDetectionSystem`** | Clears **`CollisionDataMap`** and internal pair lists; collects pairs from [`CollisionMapSingleton`]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}); writes **`CollisionData`** entries |
| After collision velocity | **`SurfaceCollisionSystem`** | Clears **`SurfaceCollisionMap`** for active bodies; tests dynamics vs surface; writes **`SurfaceCollisionData`** |

Custom systems in **`LittlePhysicsUserSystemGroup`** should schedule **after** internal collision and surface work (or chain on **`PhysicsJobHandle`**) before reading these buffers.

## Custom jobs

Package interfaces wrap the same data:

| Interface | Buffer | Access |
|-----------|--------|--------|
| **`ICollisionJob`** | **`CollisionDataMap`** + **`BodiesList`** | Per collision slot or per body pair |
| **`ISurfaceJob`** | **`SurfaceCollisionMap`** + **`BodiesList`** | Per body surface contact |

Both use **`ScheduleAndChain`** with **`PhysicsStructuresComponent`** and **`SimulationDataComponent`**. Schedule systems in **`LittlePhysicsUserSystemGroup`** so they run after internal collision and surface work.

### ICollisionJob — trigger attraction

The sample **Scene 4 — Trigger** uses **`ICollisionJob.IWriteBodies`** to pull dynamic bodies toward kinematic triggers when a pair slot fires:

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

**`IWriteBodies`** receives both bodies and the **`CollisionData`** slot. Use **`IReadBody`**, **`IReadBodies`**, or **`IEntities`** when you only need read access or entity IDs. See [ICollisionJob]({% link docs/guides/custom-jobs/icollision-job/index.md %}) for all variants.

### ISurfaceJob — tangent damping on contact

**`ISurfaceJob.IWriteBody`** runs once per active body index. Use it when surface contact should modify velocity or pose:

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
            if (!collision.IsColliding || !body.IsDynamic)
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

Non-colliding bodies are skipped before **`Execute`** runs — only indices with **`IsColliding == true`** invoke the callback. See [ISurfaceJob]({% link docs/guides/custom-jobs/isurface-job/index.md %}) for read-only and entity-based variants.

## Related

- [ListsArray]({% link docs/guides/physics-singleton/lists-array/index.md %}) — **`CollisionDataMap`** container
- [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — broad-phase input for object-to-object detection
- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — body records referenced by **`OtherIndex`**
- [Pairs debug window]({% link docs/guides/pairs-debug-window/index.md %}) — live view of pairs and collision slots
- [Settings]({% link docs/guides/settings/index.md %}) — trigger vs rigid behavior in pair collection
