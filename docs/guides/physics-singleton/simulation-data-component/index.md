---
title: SimulationDataComponent
layout: default
parent: Physics singleton
nav_order: 4
permalink: /docs/guides/physics-singleton/simulation-data-component/
description: SimulationDataComponent — active body count and physics job handle.
tags: [singleton, jobs, import, bodies]
---

# SimulationDataComponent

A singleton component updated every frame that tracks **how many bodies participate in the current pipeline step** and **chains Unity Job System work** across import, the fixed-step loop, and export.

Any custom job that reads or writes native physics buffers must respect both fields.

## Component fields

| Field | Type | Description |
|-------|------|-------------|
| `ActiveBodiesCount` | `int` | Number of bodies imported for the current step (valid indices: `0` … `ActiveBodiesCount - 1`) |
| `PhysicsJobHandle` | `JobHandle` | Combined dependency for all scheduled physics jobs so far this frame |

## ActiveBodiesCount

Set each **LateSimulation** import by **`ImportPhysicsDataSystem`**:

```csharp
simulation.ActiveBodiesCount = math.min(CountQuery.CalculateEntityCount(), maxEntitiesCount);
```

`CountQuery` includes entities with **`LocalToWorld`**, **`PhysicsBodyComponent`**, and **`PhysicsBodyUpdateComponent`**. The count is clamped to **`PhysicsFixedSettingsComponent.BlobRef.Value.MaxEntitiesCount`** — bodies beyond the cap are not copied into native memory.

### What uses the count

Parallel jobs and native arrays are indexed by **`ActiveBodiesCount`**, not the allocated pool size:

| Structure | Relationship |
|-----------|--------------|
| [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}) | Indices `0 … ActiveBodiesCount - 1` hold live body data |
| [`Randoms`]({% link docs/guides/physics-singleton/randoms/index.md %}) | One RNG stream per active body index |
| [`SurfaceCollisionMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) | One surface contact slot per body index |
| [`CollisionDataMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) | Outer array length matches active bodies |

Internal systems (`GravitySystem`, `FrictionSystem`, `CollisionDetectionSystem`, and others) pass **`ActiveBodiesCount`** as the loop length when scheduling parallel jobs.

Custom **`IBodiesJob`**, **`ICollisionJob`**, **`ISurfaceJob`**, and **`ILineCastJob`** extensions also schedule over **`ActiveBodiesCount`**.

## PhysicsJobHandle

Every internal physics system and package job extension **combines** with **`PhysicsJobHandle`** before scheduling, then **writes the new handle back**:

```csharp
ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;
var combined = JobHandle.CombineDependencies(state.Dependency, simulation.PhysicsJobHandle);

var handle = myJob.Schedule(combined);
simulation.PhysicsJobHandle = handle;
state.Dependency = handle;
```

This serializes access to shared native arrays (`BodiesList`, maps, collision buffers) across:

- **Import** — `ImportPhysicsDataSystem` fills bodies and entity map
- **Fixed step** — gravity through surface collision, then user jobs, then velocity integration
- **Export** — writes native results back to ECS components

{: .warning }
> If you schedule a job that touches physics native memory **without** combining and updating **`PhysicsJobHandle`**, it may run concurrently with other physics jobs and corrupt buffers.

### When interfaces handle chaining for you

Inside **`LittlePhysicsUserSystemGroup`**, prefer the package job interfaces. Their **`ScheduleAndChain`** extension methods combine dependencies and update **`PhysicsJobHandle`** automatically:

```csharp
myBodiesJob.ScheduleAndChain(ref state, structures, ref simulation);
```

See [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}) for **`ScheduleAndChain`** usage, and [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) for group placement.

## Read-only access

Gameplay or UI code that only needs the live body count can read the singleton without chaining jobs:

```csharp
int count = SystemAPI.GetSingleton<SimulationDataComponent>().ActiveBodiesCount;
```

The sample **`PerformanceOutputPresenter`** uses this pattern to display active body statistics.

## Related

- [PhysicsReadyTag]({% link docs/guides/physics-singleton/physics-ready-tag/index.md %}) — gate systems until bootstrap finishes
- [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %}) — native body pool filled during import
- [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}) — **`ScheduleAndChain`** and **`PhysicsJobHandle`**
- [Pipeline — Chaining jobs with PhysicsJobHandle]({% link docs/pipeline/index.md %}#chaining-jobs-with-physicsjobhandle)
- [How it works — Import]({% link docs/how-it-works/index.md %}#import)
