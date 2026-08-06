---
title: Custom job interfaces
layout: default
parent: Custom jobs
nav_order: 6
permalink: /docs/guides/custom-jobs/using-custom-job-interfaces/
description: Writing custom IJob and IJobParallelFor systems against physics native buffers.
---

# Custom job interfaces

Little Physics recommends its own job interfaces — [`IBodiesJob`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}), [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}), [`ISurfaceJob`]({% link docs/guides/custom-jobs/isurface-job/index.md %}), and [`ILineCastJob`]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) — for the common iteration patterns inside **`LittlePhysicsUserSystemGroup`**. Those interfaces handle buffer wiring, loop bounds, and **`PhysicsJobHandle`** chaining through **`ScheduleAndChain`**.

When you need something they do not cover — multiple native arrays in one pass, custom iteration logic, or a one-off **`IJobEntity`** query — write a standard Unity job (**`IJob`**, **`IJobParallelFor`**, **`IJobEntity`**) and chain it yourself.

## When to use raw Unity jobs

| Situation | Prefer |
|-----------|--------|
| Per-body read/write over **`BodiesList`** | [`IBodiesJob`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) |
| Per collision slot or pair | [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) |
| Per surface contact | [`ISurfaceJob`]({% link docs/guides/custom-jobs/isurface-job/index.md %}) |
| Linecast along the spatial map | [`ILineCastJob`]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) |
| **`BodiesList`** + one extra native array (e.g. **`Randoms`**) | [`IBodiesJob.IWriteIndex`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) — see [Randoms]({% link docs/guides/physics-singleton/randoms/index.md %}) |
| Multiple native buffers with custom iteration | **`IJobParallelFor`** — this page |
| Custom outer loop over collision slots with extra state | **`IJobParallelFor`** or **`IJob`** |
| Post-export ECS queries (`LocalTransform`, destroy entity) | **`IJobEntity`** — see [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %}) |

## PhysicsJobHandle chaining

Any job that reads or writes physics native memory must **combine** with **`SimulationDataComponent.PhysicsJobHandle`** before scheduling, then **assign the result back** to both **`PhysicsJobHandle`** and **`state.Dependency`**.

```csharp
ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

var combined = JobHandle.CombineDependencies(
    state.Dependency, simulation.PhysicsJobHandle);

var handle = myJob.Schedule(/* args */, combined);

simulation.PhysicsJobHandle = handle;
state.Dependency = handle;
```

This serializes access to shared buffers across import, the fixed-step inner loop, and export. Internal physics systems and package **`ScheduleAndChain`** extensions follow the same rule.

{: .warning }
> Scheduling over **`BodiesList`**, collision maps, or **`Randoms`** without combining **`PhysicsJobHandle`** can race with internal jobs and corrupt native data.

See [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) and [Pipeline — Chaining jobs]({% link docs/pipeline/index.md %}#chaining-jobs-with-physicsjobhandle).

## IJobParallelFor — per-body work

The most common raw pattern mirrors [`IBodiesJob`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}): parallel over body indices **`0 … ActiveBodiesCount - 1`**, batch size **32** (same default the package uses).

For **`BodiesList`** plus an extra array such as **`Randoms`**, prefer [`IBodiesJob.IWriteIndex`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) with **`ScheduleAndChain`** — see [Randoms]({% link docs/guides/physics-singleton/randoms/index.md %}). Use raw **`IJobParallelFor`** when you need full control over scheduling or several writable buffers:

```csharp
ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;
var combined = JobHandle.CombineDependencies(state.Dependency, simulation.PhysicsJobHandle);

var handle = new DampVelocityParallelJob
{
    BodiesList = structures.BodiesList,
    Factor = 0.99f,
}.Schedule(simulation.ActiveBodiesCount, 32, combined);

simulation.PhysicsJobHandle = handle;
state.Dependency = handle;
```

```csharp
[BurstCompile]
private struct DampVelocityParallelJob : IJobParallelFor
{
    [NativeDisableParallelForRestriction]
    public NativeArray<PhysicsBodyData> BodiesList;

    public float Factor;

    public void Execute(int index)
    {
        var body = BodiesList[index];

        if (body.Main == Entity.Null || !body.IsDynamic)
        {
            return;
        }

        var velocity = body.VelocityData;
        velocity.Linear *= Factor;
        body.VelocityData = velocity;
        BodiesList[index] = body;
    }
}
```

### Guidelines for parallel body jobs

| Rule | Why |
|------|-----|
| Loop length = **`simulation.ActiveBodiesCount`** | Only imported bodies are live this frame |
| Skip **`body.Main == Entity.Null`** | Cleared pool slots are not active bodies |
| Mark writable arrays **`[NativeDisableParallelForRestriction]`** | Each thread writes its own index, but Unity's safety system needs the attribute |
| Use **`[ReadOnly]`** on arrays you only read | Enables stricter safety when sharing read-only views |
| Multiply forces by **`LittlePhysicsTimeComponent.DeltaTime`** | Substep-scaled delta inside **`LittlePhysicsUserSystemGroup`** |

The allocated pool size is **`MaxEntitiesCount`**; never schedule parallel jobs beyond **`ActiveBodiesCount`** unless you intentionally process empty slots.

## IJobParallelFor — collision slots

Package [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) already iterates **`CollisionDataMap`** slots per body. Use a raw job when you need a different parallelization — for example one thread per body that performs extra work across all slots with local state:

```csharp
[BurstCompile]
private struct CustomCollisionResponseJob : IJobParallelFor
{
    [NativeDisableParallelForRestriction]
    public NativeArray<PhysicsBodyData> BodiesList;

    [ReadOnly]
    public ListsArray<CollisionData> CollisionDataMap;

    public void Execute(int bodyIndex)
    {
        var body = BodiesList[bodyIndex];

        if (body.Main == Entity.Null)
        {
            return;
        }

        int count = CollisionDataMap.GetCount(bodyIndex);

        for (int slot = 0; slot < count; slot++)
        {
            var collision = CollisionDataMap.GetValue(bodyIndex, slot);

            if (!collision.HasValue)
            {
                continue;
            }

            // Read collision.OtherIndex, ContactPoint, Normal, etc.
        }

        BodiesList[bodyIndex] = body;
    }
}
```

Schedule with the same **`PhysicsJobHandle`** chaining and **`ActiveBodiesCount`** loop length. See [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) for buffer layout.

## IJob — single-threaded native work

Use **`IJob`** when work must run on one thread — custom aggregation, debugging, or sequential passes over native data that are awkward to split.

```csharp
[BurstCompile]
private struct SummarizeEnergyJob : IJob
{
    [ReadOnly] public NativeArray<PhysicsBodyData> BodiesList;
    public int ActiveBodiesCount;
    public NativeReference<float> TotalEnergy;

    public void Execute()
    {
        float sum = 0f;

        for (int i = 0; i < ActiveBodiesCount; i++)
        {
            var body = BodiesList[i];

            if (body.Main == Entity.Null || !body.IsDynamic)
            {
                continue;
            }

            sum += math.lengthsq(body.VelocityData.Linear);
        }

        TotalEnergy.Value = sum;
    }
}
```

```csharp
var combined = JobHandle.CombineDependencies(state.Dependency, simulation.PhysicsJobHandle);
var handle = new SummarizeEnergyJob { /* fields */ }.Schedule(combined);
simulation.PhysicsJobHandle = handle;
state.Dependency = handle;
```

For linecasts, prefer [`ILineCastJob`]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) (already single-threaded). If you call **`PhysicsStructuresComponent.LineCast`** / **`LineCastFirst`** directly, still chain **`PhysicsJobHandle`**.

## IJobEntity — ECS components

**`IJobEntity`** fits **import** and **export** hooks where you read or write ECS components rather than native simulation buffers:

- **Before import** — modify **`LocalTransform`**, **`PhysicsVelocityComponent`**, or custom components; **`PhysicsJobHandle`** optional.
- **After export** — read **`LocalTransform`** after **`ExportPhysicsDataSystem`**; **`PhysicsJobHandle`** optional unless you also touch native memory in the same system.

The **Scene 3 — Pachinko** sample uses **`IJobEntity`** in **`LittlePhysicsExportGroup`** to destroy entities below a Y threshold — see [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %}).

Do **not** rely on ECS component queries for mid-step physics inside **`LittlePhysicsUserSystemGroup`** — component data is stale until export. Read [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}) instead.

## Which group to use

| Group | Raw job touches | Chain **`PhysicsJobHandle`**? |
|-------|-----------------|-------------------------------|
| **`LittlePhysicsImportGroup`** (after internal import) | Native buffers | Yes |
| **`LittlePhysicsImportGroup`** (before internal import) | ECS components only | No |
| **`LittlePhysicsUserSystemGroup`** | Native buffers | Yes |
| **`LittlePhysicsExportGroup`** (before internal export) | Native buffers | Yes |
| **`LittlePhysicsExportGroup`** (after internal export) | ECS components only | No |

See [Custom job groups]({% link docs/guides/custom-jobs/custom-job-groups/index.md %}) for **`UpdateBefore`** / **`UpdateAfter`** attributes.

## Package interfaces vs raw jobs

If your logic maps to an existing package interface, use it — less boilerplate and the same chaining behavior:

```csharp
// Package interface — chaining handled for you
new DampVelocityJob { Factor = 0.99f }
    .ScheduleAndChain(ref state, in structures, ref simulation);

// Equivalent raw job — you chain PhysicsJobHandle yourself
var combined = JobHandle.CombineDependencies(state.Dependency, simulation.PhysicsJobHandle);
var handle = new DampVelocityParallelJob { BodiesList = structures.BodiesList, Factor = 0.99f }
    .Schedule(simulation.ActiveBodiesCount, 32, combined);
simulation.PhysicsJobHandle = handle;
state.Dependency = handle;
```

Reach for raw Unity jobs when the package callback shape is too narrow — extra native arrays, custom filtering, or non-standard iteration.

## Related

- [IBodiesJob]({% link docs/guides/custom-jobs/ibodies-job/index.md %}), [ICollisionJob]({% link docs/guides/custom-jobs/icollision-job/index.md %}), [ISurfaceJob]({% link docs/guides/custom-jobs/isurface-job/index.md %}), [ILineCastJob]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) — preferred package interfaces
- [Inside the pipeline]({% link docs/guides/custom-jobs/inside-the-pipeline/index.md %}) — when mid-step systems run
- [Randoms]({% link docs/guides/physics-singleton/randoms/index.md %}) — **`IBodiesJob.IWriteIndex`** example with **`Randoms`**
- [PhysicsStructuresComponent]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}) — native buffers to pass into your jobs
