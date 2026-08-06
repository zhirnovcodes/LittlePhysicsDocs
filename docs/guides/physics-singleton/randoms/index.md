---
title: Randoms
layout: default
parent: PhysicsStructuresComponent
nav_order: 2
permalink: /docs/guides/physics-singleton/randoms/
description: Randoms — per-body random state array for custom systems.
tags: [singleton, native, random]
---

# Randoms

A **`NativeArray<Unity.Mathematics.Random>`** on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}). Each slot is a **persistent per-body random stream** — one **`Random`** state per body index, parallel to [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}).

Internal systems use **`Randoms[index]`** for spatial-map work. You can read and write the same slots from custom systems when you need deterministic, per-body randomness without allocating your own RNG arrays.

## Allocation and initialization

Bootstrap allocates **`Randoms`** with length **`MaxEntitiesCount`**, matching **`BodiesList`**.

Each entry is seeded from **`SpacialMapAuthoring.RandomSeed`** (baked into internal **`PhysicsMapRandomComponent`**, default **`12345`**):

```csharp
Randoms[i] = new Random(seed + (uint)i + 1u);
```

The per-index offset gives every body slot an independent stream even when **`ActiveBodiesCount`** is lower than the pool size.

## Active body indices

Parallel jobs schedule over **`ActiveBodiesCount`**. Only indices **`0 … ActiveBodiesCount - 1`** participate in a given frame, but **`Randoms`** retains state for each index across frames.

Always **write the updated `Random` back** to **`Randoms[index]`** after drawing values so the stream stays consistent for internal systems and later custom jobs.

## Custom job example

Schedule inside **`LittlePhysicsUserSystemGroup`**, combine with **`PhysicsJobHandle`**, and use the body index to access both **`Randoms`** and **`BodiesList`**. For package interfaces that chain **`PhysicsJobHandle`** automatically, see [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}).

```csharp
using LittlePhysics;
using Unity.Burst;
using Unity.Collections;
using Unity.Entities;
using Unity.Jobs;
using Unity.Mathematics;

[BurstCompile]
[UpdateInGroup(typeof(LittlePhysicsUserSystemGroup))]
public partial struct BodyRandomJitterSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state) =>
        state.RequireForUpdate<PhysicsReadyTag>();

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;
        var deltaTime = SystemAPI.GetSingleton<LittlePhysicsTimeComponent>().DeltaTime;

        var combined = JobHandle.CombineDependencies(
            state.Dependency, simulation.PhysicsJobHandle);

        var handle = new BodyRandomJitterJob
        {
            BodiesList = structures.BodiesList,
            Randoms = structures.Randoms,
            Strength = 0.5f * deltaTime,
        }.Schedule(simulation.ActiveBodiesCount, 32, combined);

        simulation.PhysicsJobHandle = handle;
        state.Dependency = handle;
    }

    [BurstCompile]
    private struct BodyRandomJitterJob : IJobParallelFor
    {
        [NativeDisableParallelForRestriction]
        public NativeArray<PhysicsBodyData> BodiesList;

        [NativeDisableParallelForRestriction]
        public NativeArray<Random> Randoms;

        public float Strength;

        public void Execute(int index)
        {
            var random = Randoms[index];
            var body = BodiesList[index];

            if (!body.IsDynamic)
            {
                Randoms[index] = random;
                return;
            }

            float3 jitter = random.NextFloat3Direction() * Strength;
            var velocity = body.VelocityData;
            velocity.Linear += jitter;
            body.VelocityData = velocity;

            BodiesList[index] = body;
            Randoms[index] = random;
        }
    }
}
```

Pair **`Randoms[index]`** with **`BodiesList[index]`** (or [`IBodiesJob.IWriteIndex`]({% link docs/guides/custom-jobs/ibodies-job/index.md %})) when you need both random draws and body mutation in one pass.

## Related

- [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %}) — parallel indexing with **`Randoms`**
- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) — `ActiveBodiesCount` and job handle
- [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}) — **`ScheduleAndChain`** and **`PhysicsJobHandle`** chaining
- [Spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}) — source of the bootstrap seed
