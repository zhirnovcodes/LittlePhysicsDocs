---
title: IBodiesJob
layout: default
parent: Custom jobs
nav_order: 2
permalink: /docs/guides/custom-jobs/ibodies-job/
description: Per-body parallel custom job interface.
tags: [custom-jobs, ibodies-job, bodies]
---

# IBodiesJob

Parallel job callbacks over [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}). Each invocation receives one active body. Schedule inside **`LittlePhysicsUserSystemGroup`** (or post-import in **`LittlePhysicsImportGroup`** when patching native data after import).

## Nested interfaces

| Interface | `Execute` signature | Access |
|-----------|---------------------|--------|
| **`IBodiesJob.IRead`** | `Execute(in PhysicsBodyData body)` | Read-only body |
| **`IBodiesJob.IWrite`** | `Execute(ref PhysicsBodyData body)` | Read-write body |
| **`IBodiesJob.IReadIndex`** | `Execute(in int index, in PhysicsBodyData body)` | Read-only; includes body index |
| **`IBodiesJob.IWriteIndex`** | `Execute(in int index, ref PhysicsBodyData body)` | Read-write; includes body index |

Choose **`IRead`** / **`IWrite`** when you only need body fields. Choose **`IReadIndex`** / **`IWriteIndex`** when the index is required — for example pairing with [`Randoms[index]`]({% link docs/guides/physics-singleton/randoms/index.md %}) or writing to parallel native arrays.

Extension classes: **`IBodiesReadExtensions`**, **`IBodiesWriteExtensions`**, **`IBodiesReadIndexExtensions`**, **`IBodiesWriteIndexExtensions`**.

## Scheduling

```csharp
new MyJob { Factor = 0.99f }
    .ScheduleAndChain(ref state, in structures, ref simulation);
```

- Loops **`0 … ActiveBodiesCount - 1`** with batch size **32**.
- Skips slots where **`body.Main == Entity.Null`**.
- Write variants persist changes back to **`BodiesList[index]`**.

## Example — velocity damping

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

## Example — per-index random jitter

Use **`IWriteIndex`** when you need the body index to access parallel arrays:

```csharp
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
            Randoms[index] = random;
            return;
        }

        float3 jitter = random.NextFloat3Direction() * Strength;
        var velocity = body.VelocityData;
        velocity.Linear += jitter;
        body.VelocityData = velocity;

        Randoms[index] = random;
    }
}
```

Pass **`Randoms`** as a job field and call **`ScheduleAndChain`** as usual — the extension wires **`BodiesList`** and **`PhysicsJobHandle`**; your extra fields ride on the job struct. See [Randoms]({% link docs/guides/physics-singleton/randoms/index.md %}) for the full system.

## When to use

| Use **`IBodiesJob`** | Consider instead |
|----------------------|------------------|
| Global forces, damping, or pose tweaks on all bodies | **`ICollisionJob`** when logic depends on pair contact |
| Per-body gameplay state driven by body fields | **`ISurfaceJob`** when logic depends on ground contact |
| Reading body statistics without collision context | **`ILineCastJob`** for segment queries |

## Related

- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — struct layout for each body slot
- [Inside the pipeline]({% link docs/guides/custom-jobs/inside-the-pipeline/index.md %}) — when mid-step systems run
- [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}) — raw **`IJobParallelFor`** when you need buffers beyond **`BodiesList`**
