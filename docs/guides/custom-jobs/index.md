---
title: Custom jobs
layout: default
nav_order: 8
has_children: true
permalink: /docs/guides/custom-jobs/
description: Custom job groups, interfaces, and import/export workflows.
---

# Custom jobs

Little Physics exposes three **public system groups** where you can plug in ECS systems, plus four **job interfaces** that schedule Burst-friendly work over native physics buffers. Together they let you read and modify simulation state at import, mid-step, and export without fighting the internal pipeline.

## When to use what

| Goal | Hook | Recommended API |
|------|------|-----------------|
| Override ECS data before it enters native memory | [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) — before internal import | ECS components |
| Patch `BodiesList` or maps after import | [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) — after internal import | Native structures + `PhysicsJobHandle` |
| Apply forces, custom collision response, gameplay | [Inside the pipeline]({% link docs/guides/custom-jobs/inside-the-pipeline/index.md %}) — `LittlePhysicsUserSystemGroup` | Package job interfaces |
| Read native results before write-back | [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %}) — before internal export | Native structures |
| Sync to rendering, networking, or destroy entities | [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %}) — after internal export | ECS components |

Prefer the package job interfaces inside the fixed-step loop. They iterate the correct buffers, respect **`ActiveBodiesCount`**, and chain **`PhysicsJobHandle`** through **`ScheduleAndChain`**. For raw **`IJob`** / **`IJobParallelFor`** work, combine dependencies manually — see [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}).

## Job interfaces

All four interfaces run in **`LittlePhysicsUserSystemGroup`** unless noted. Three are **parallel** over active bodies or collision slots; **`ILineCastJob`** uses a **single helper thread**.

| Interface | Iterates | Parallel |
|-----------|----------|----------|
| [IBodiesJob]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) | Every active body in `BodiesList` | Yes |
| [ICollisionJob]({% link docs/guides/custom-jobs/icollision-job/index.md %}) | Object-to-object collision slots in `CollisionDataMap` | Yes |
| [ISurfaceJob]({% link docs/guides/custom-jobs/isurface-job/index.md %}) | Surface contacts in `SurfaceCollisionMap` | Yes |
| [ILineCastJob]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) | Linecast hits against the spatial map | No (single thread) |

## Prerequisites

Custom systems should:

1. Gate on [`PhysicsReadyTag`]({% link docs/guides/physics-singleton/physics-ready-tag/index.md %}) after bootstrap completes.
2. Read simulation buffers from [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}).
3. Chain jobs through [`SimulationDataComponent.PhysicsJobHandle`]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) whenever you touch native memory outside the package interfaces.

Use [`LittlePhysicsTimeComponent.DeltaTime`]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) inside **`LittlePhysicsUserSystemGroup`** for the scaled substep delta (respects time scale and substeps).

## Samples

The package **All Samples** import includes working custom-job examples:

| Sample scene | System | Interface / group |
|--------------|--------|-------------------|
| Scene 4 — Trigger | `TriggerAttractionSystem` | `ICollisionJob.IWriteBodies` |
| Scene 5 — Linecast | `LineCastSystem` | `ILineCastJob.IWriteBody` |
| Scene 5 — Linecast | `LineCastInputSystem` | `LittlePhysicsImportGroup` (pre-import input) |
| Scene 3 — Pachinko | `DisappearAtYSystem` | `LittlePhysicsExportGroup` (post-export cleanup) |

## Related

- [Pipeline]({% link docs/pipeline/index.md %}) — full system group hierarchy and execution order
- [Physics singleton]({% link docs/guides/physics-singleton/index.md %}) — native buffers your jobs read and write
- [Custom job groups]({% link docs/guides/custom-jobs/custom-job-groups/index.md %}) — import, mid-step, and export hook points
