---
title: Inside the pipeline
layout: default
parent: Custom jobs
nav_order: 9
permalink: /docs/guides/custom-jobs/inside-the-pipeline/
description: Mid-step logic in LittlePhysicsUserSystemGroup.
---

# Inside the pipeline

Mid-step custom logic runs in **`LittlePhysicsUserSystemGroup`** — after internal collision and surface systems finish, and before **`PhysicsVelocitySystem`** integrates velocity into position data.

## Where it sits

Each fixed update, **`LittlePhysicsSystemGroup`** runs the inner pipeline **time scale × substeps** times. Every iteration executes three child groups in order:

| Order | Group | What completes before your code runs |
|------:|-------|--------------------------------------|
| 1 | **`LittlePhysicsInternalSystemGroup`** | Gravity, friction, spatial map, object-to-object detection and velocity resolution, surface collision |
| 2 | **`LittlePhysicsUserSystemGroup`** | **Your systems** |
| 3 | **`LittlePhysicsLateSystemGroup`** | Velocity → position integration in native buffers |

Your systems see **current-substep** collision results in [`CollisionsSingleton`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) and live body state in [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}). Changes to velocity or pose you write here affect the integration step that follows immediately.

## Read native structures, not ECS components

During the fixed-step loop, internal systems operate on unmanaged buffers attached to [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}):

| Need | Read from |
|------|-----------|
| Body pose, velocity, shape, flags | **`BodiesList[index]`** |
| Object-to-object contacts | **`Collisions.CollisionDataMap`** |
| Surface contacts | **`Collisions.SurfaceCollisionMap`** |
| Broad-phase cell membership | **`CollisionMap.DynamicMap`** / **`StaticMap`** |
| Entity → body index | **`EntitiesMap`** |
| Per-body RNG | **`Randoms`** |

ECS components such as **`PhysicsBodyComponent`** and **`LocalTransform`** are updated on **import** and **export**, not between substeps. Querying them mid-loop reads stale data.

Export copies native results back to components once per frame, after all inner loops complete.

## Time and iteration count

Each inner iteration sets [`LittlePhysicsTimeComponent`]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}):

- **`DeltaTime`** — `fixedDeltaTime / substepsCount` (not multiplied by time scale; the outer loop runs **`TimeScale`** iterations instead).
- **`TimeScale`** — current scale value (`0`, `1`, `2`, or `4`).
- **`ElapsedTime`** — accumulated physics time.

Multiply forces and impulses by **`DeltaTime`** when integrating manually. Example: the **Scene 4 — Trigger** sample scales attraction power by **`DeltaTime`** before applying velocity in an **`ICollisionJob`**.

When time scale is **`0`**, the inner loop does not run and **`LittlePhysicsUserSystemGroup`** systems are not invoked.

## Scheduling

Annotate systems with:

```csharp
[UpdateInGroup(typeof(LittlePhysicsUserSystemGroup))]
public partial struct MyMidStepSystem : ISystem { ... }
```

Prefer package job interfaces and **`ScheduleAndChain`**:

```csharp
[BurstCompile]
public void OnUpdate(ref SystemState state)
{
    var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
    ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

    new MyBodiesJob { Strength = 1f }
        .ScheduleAndChain(ref state, in structures, ref simulation);
}
```

**`ScheduleAndChain`** combines **`state.Dependency`** and **`simulation.PhysicsJobHandle`**, schedules over **`ActiveBodiesCount`**, and writes the result back to **`PhysicsJobHandle`**.

For extra native arrays alongside body data — for example [`Randoms`]({% link docs/guides/physics-singleton/randoms/index.md %}) — pass them as fields on an [`IBodiesJob.IWriteIndex`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) job and use **`ScheduleAndChain`**. For more complex multi-buffer access, use raw **`IJobParallelFor`** — see [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}).

## Choosing an interface

| Task | Interface |
|------|-----------|
| Per-body force, damping, or pose tweak | [`IBodiesJob`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) |
| React to object-to-object pairs or triggers | [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) |
| Custom friction or slide along ground | [`ISurfaceJob`]({% link docs/guides/custom-jobs/isurface-job/index.md %}) |
| Ray/segment cast against bodies in the map | [`ILineCastJob`]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) |

## Limitations

- **Dynamic bodies are spheres only** — mid-step shape assumptions match that constraint.
- **Object-to-object collisions** only occur inside the [spatial map]({% link docs/guides/settings/spatial-map/index.md %}) bounds; outside the map, dynamics still get gravity and surface collision.
- **Collision slot caps** come from LOD settings — not every theoretical overlap gets a slot when limits are hit.
- **Determinism** decreases with loose LOD; tighter camera ranges improve repeatability.

## Related

- [Pipeline — Fixed update inner loop]({% link docs/pipeline/index.md %}#fixed-update--inner-loop)
- [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %})
- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — buffers filled before your systems run
