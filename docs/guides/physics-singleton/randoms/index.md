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

Schedule inside **`LittlePhysicsUserSystemGroup`** with [`IBodiesJob.IWriteIndex`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) so you receive the body index for **`Randoms[index]`** while **`ScheduleAndChain`** handles **`BodiesList`** and **`PhysicsJobHandle`**. Pass **`Randoms`** as an extra field on the job struct.

```csharp
using LittlePhysics;
using Unity.Burst;
using Unity.Collections;
using Unity.Entities;
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

        new BodyRandomJitterJob
        {
            Randoms = structures.Randoms,
            Strength = 0.5f * deltaTime,
        }.ScheduleAndChain(ref state, in structures, ref simulation);
    }

    [BurstCompile]
    private struct BodyRandomJitterJob : IBodiesJob.IWriteIndex
    {
        [NativeDisableParallelForRestriction]
        public NativeArray<Random> Randoms;

        public float Strength;

        public void Execute(in int index, ref PhysicsBodyData body)
        {
            var random = Randoms[index];

            if (!body.IsDynamic)
            {
                return;
            }

            float3 jitter = random.NextFloat3Direction() * Strength;
            var velocity = body.VelocityData;
            velocity.Linear += jitter;
            body.VelocityData = velocity;

            Randoms[index] = random;
        }
    }
}
```

Pair **`Randoms[index]`** with the body index from **`IWriteIndex`** when you need both random draws and body mutation in one pass. For raw **`IJobParallelFor`** when touching many buffers at once, see [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}).

## Related

- [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %}) — parallel indexing with **`Randoms`**
- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) — `ActiveBodiesCount` and job handle
- [IBodiesJob]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) — **`IWriteIndex`** and **`ScheduleAndChain`**
- [Spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}) — source of the bootstrap seed
