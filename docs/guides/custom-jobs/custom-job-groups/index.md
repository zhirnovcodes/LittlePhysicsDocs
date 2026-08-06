---
title: Custom job groups
layout: default
parent: Custom jobs
nav_order: 1
permalink: /docs/guides/custom-jobs/custom-job-groups/
description: LittlePhysicsImportGroup, LittlePhysicsUserSystemGroup, and LittlePhysicsExportGroup.
---

# Custom job groups

Little Physics defines three **public** `ComponentSystemGroup` types as extension points. Internal groups and systems may change between package versions; only these three are intended for user code.

## Overview

| Group | Unity phase | Runs | Typical use |
|-------|-------------|------|-------------|
| **`LittlePhysicsImportGroup`** | LateSimulation | Once per frame, before fixed step | Copy or override ECS data; patch native buffers after import |
| **`LittlePhysicsUserSystemGroup`** | FixedStep (inner loop) | **TimeScale × Substeps** per fixed update | Forces, collision response, gameplay, debug |
| **`LittlePhysicsExportGroup`** | Simulation (after FixedStep) | Once per frame, after all inner loops | Read native state; post-process exported components |

All three require physics to be bootstrapped. Gate your systems with **`RequireForUpdate<PhysicsReadyTag>()`** unless you only touch ECS components that exist before bootstrap.

## LittlePhysicsImportGroup

Defined in **`LateSimulationSystemGroup`**. Contains **`LittlePhysicsInternalImportGroup`**, which runs **`PhysicsStepSystem`** (camera/LOD step) and **`ImportPhysicsDataSystem`** (ECS → native copy).

Order your systems **relative to the internal group** — placement inside **`LittlePhysicsImportGroup`** alone does not guarantee before/after ordering:

```csharp
// Modify ECS components before they are copied into BodiesList
[UpdateInGroup(typeof(LittlePhysicsImportGroup))]
[UpdateBefore(typeof(LittlePhysicsInternalImportGroup))]
public partial struct MyPreImportSystem : ISystem { ... }

// Read or alter native structures after import fills them
[UpdateInGroup(typeof(LittlePhysicsImportGroup))]
[UpdateAfter(typeof(LittlePhysicsInternalImportGroup))]
public partial struct MyPostImportSystem : ISystem { ... }
```

See [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) for examples and job chaining.

## LittlePhysicsUserSystemGroup

Defined inside **`LittlePhysicsSystemGroup`**, which loops **time scale × substeps** each fixed update.

```
LittlePhysicsInternalSystemGroup   (gravity → friction → map → collisions → surface)
        ↓
LittlePhysicsUserSystemGroup       ← your systems and package job interfaces
        ↓
LittlePhysicsLateSystemGroup       (PhysicsVelocitySystem — integrates velocity → position)
```

This is the recommended place for mid-step physics logic:

- Collision and surface buffers are filled.
- Positions have **not** yet been integrated from velocity.
- **`LittlePhysicsTimeComponent.DeltaTime`** reflects the current substep.

Package job interfaces (**`IBodiesJob`**, **`ICollisionJob`**, **`ISurfaceJob`**, **`ILineCastJob`**) are designed for this group. See [Inside the pipeline]({% link docs/guides/custom-jobs/inside-the-pipeline/index.md %}).

## LittlePhysicsExportGroup

Defined in **`SimulationSystemGroup`**, **`UpdateAfter(typeof(FixedStepSimulationSystemGroup))`**. Contains **`LittlePhysicsInternalExportGroup`**, which runs **`ExportPhysicsDataSystem`** (native → ECS write-back).

```csharp
// Read BodiesList before components are updated
[UpdateInGroup(typeof(LittlePhysicsExportGroup))]
[UpdateBefore(typeof(LittlePhysicsInternalExportGroup))]
public partial struct MyPreExportSystem : ISystem { ... }

// Modify LocalTransform, custom components, or destroy entities after export
[UpdateInGroup(typeof(LittlePhysicsExportGroup))]
[UpdateAfter(typeof(LittlePhysicsInternalExportGroup))]
public partial struct MyPostExportSystem : ISystem { ... }
```

See [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %}).

## PhysicsJobHandle

Any custom job that reads or writes native physics buffers during import, the fixed-step loop, or export must **combine** with **`SimulationDataComponent.PhysicsJobHandle`** and **write the handle back** when scheduling completes.

Inside **`LittlePhysicsUserSystemGroup`**, prefer **`ScheduleAndChain`** on the package job interfaces — it handles chaining automatically. For import/export systems or raw Unity jobs, chain manually:

```csharp
ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;
var combined = JobHandle.CombineDependencies(state.Dependency, simulation.PhysicsJobHandle);

var handle = myJob.Schedule(combined);
simulation.PhysicsJobHandle = handle;
state.Dependency = handle;
```

See [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) and [Pipeline — Chaining jobs]({% link docs/pipeline/index.md %}#chaining-jobs-with-physicsjobhandle).

## Related

- [Pipeline — System group hierarchy]({% link docs/pipeline/index.md %}#system-group-hierarchy)
- [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %})
- [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %})
- [Inside the pipeline]({% link docs/guides/custom-jobs/inside-the-pipeline/index.md %})
