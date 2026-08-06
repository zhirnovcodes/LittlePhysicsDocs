---
title: BodiesList
layout: default
parent: PhysicsStructuresComponent
nav_order: 1
permalink: /docs/guides/physics-singleton/bodies-list/
description: BodiesList — native array of PhysicsBodyData filled during import.
tags: [singleton, native, bodies, import]
---

# BodiesList

A **`NativeArray<PhysicsBodyData>`** on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}). It is the **simulation-side copy** of every active physics body — pose, velocity, shape, LOD tier, update cadence, and material data packed for Burst jobs.

Internal systems and custom job interfaces operate on **`BodiesList`** instead of querying ECS components during the fixed-step loop.

## Allocation and capacity

Bootstrap allocates **`BodiesList`** with length **`MaxEntitiesCount`** from [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}). The array size is fixed for the session.

Each frame, only the first **`ActiveBodiesCount`** entries (from [`SimulationDataComponent`]({% link docs/guides/physics-singleton/simulation-data-component/index.md %})) contain live data. Indices at or above that count are cleared and unused until the next import.

## Import (LateSimulation)

**`ImportPhysicsDataSystem`** runs in **`LittlePhysicsInternalImportGroup`**:

1. Set **`ActiveBodiesCount`** from entities with **`LocalToWorld`**, **`PhysicsBodyComponent`**, and **`PhysicsBodyUpdateComponent`**, clamped to **`MaxEntitiesCount`**.
2. **`ClearBodiesJob`** — zero the full array and clear **`EntitiesMap`**.
3. **`ImportPhysicsDataJob`** — for each qualifying entity, build a [`PhysicsBodyData`]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) record and write it at the entity’s query index.

Each imported body also registers in **`EntitiesMap`** under **`PhysicsBodyData.Main`**, and **`PhysicsBodyUpdateComponent.Index`** stores the native index for export.

Entities beyond **`MaxEntitiesCount`** get **`PhysicsBodyUpdateComponent.IsEnabled = false`** and are skipped.

### Data copied from ECS

Import merges baked **`PhysicsBodyComponent`** data with runtime state:

| Source | Copied into `PhysicsBodyData` |
|--------|-------------------------------|
| `PhysicsBodyComponent` + `LocalToWorld` | Pose, shape, layer, body type, trigger flag, rigidbody coefficients |
| `PhysicsBodyUpdateComponent` | `TimeElapsed`, `Interval`, LOD index (when camera LOD is active) |
| `PhysicsVelocityComponent` (if present) | Linear and angular velocity; rotation block respects **`ShouldRotateOnCollision`** |

## Export (Simulation)

**`ExportPhysicsDataSystem`** reads **`BodiesList[tag.Index]`** and writes results back to **`LocalTransform`**, **`PhysicsVelocityComponent`**, and related components using **`PhysicsBodyUpdateComponent.Index`** as the lookup key.

## Custom jobs — IBodiesJob

Use the package **`IBodiesJob`** interface and its nested variants to read or write **`BodiesList`** in parallel inside **`LittlePhysicsUserSystemGroup`**:

| Interface | Access |
|-----------|--------|
| **`IBodiesJob.IRead`** | Read-only per body |
| **`IBodiesJob.IWrite`** | Read-write per body |
| **`IBodiesJob.IReadIndex`** | Read-only; receives body index |
| **`IBodiesJob.IWriteIndex`** | Read-write; receives body index |

**`ScheduleAndChain`** combines with **`PhysicsJobHandle`** and schedules over **`ActiveBodiesCount`** automatically.

```csharp
[BurstCompile]
[UpdateInGroup(typeof(LittlePhysicsUserSystemGroup))]
public partial struct DampVelocitySystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state) =>
        state.RequireForUpdate<PhysicsReadyTag>();

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

        new DampVelocityJob { Factor = 0.99f }
            .ScheduleAndChain(ref state, in structures, ref simulation);
    }

    [BurstCompile]
    private struct DampVelocityJob : IBodiesJob.IWrite
    {
        public float Factor;

        public void Execute(ref PhysicsBodyData body)
        {
            if (!body.IsDynamic)
            {
                return;
            }

            var velocity = body.VelocityData;
            velocity.Linear *= Factor;
            body.VelocityData = velocity;
        }
    }
}
```

See [IBodiesJob]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) for all nested interfaces and scheduling details.

## Related

- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — struct layout for each slot
- [EntitiesMap]({% link docs/guides/physics-singleton/entities-map/index.md %}) — entity → index map built during import
- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) — live body count
- [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) — ordering custom work around import
