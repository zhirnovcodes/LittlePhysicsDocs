---
title: PhysicsStructuresComponent
layout: default
parent: Physics singleton
nav_order: 6
has_children: true
permalink: /docs/guides/physics-singleton/physics-structures-component/
description: PhysicsStructuresComponent — main native structures for the collision pipeline.
tags: [singleton, native, collision, bodies]
---

# PhysicsStructuresComponent

A singleton component on the **physics world entity** that owns the **native buffers** used throughout the import → fixed-step → export pipeline. Bootstrap allocates every array to **`MaxEntitiesCount`** and stores the handles here; systems and custom job interfaces read the same instance each frame.

Prefer data from this component over per-entity component lookups inside the hot physics loop.

## Fields

| Field | Type | Page |
|-------|------|------|
| `BodiesList` | `NativeArray<PhysicsBodyData>` | [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %}) |
| `Randoms` | `NativeArray<Random>` | [Randoms]({% link docs/guides/physics-singleton/randoms/index.md %}) |
| `EntitiesMap` | `NativeHashMap<Entity, uint>` | [EntitiesMap]({% link docs/guides/physics-singleton/entities-map/index.md %}) |
| `CollisionMap` | `CollisionMapSingleton` | [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) |
| `Collisions` | `CollisionsSingleton` | [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) |

All **`NativeArray`** lengths equal the allocated pool size (**`MaxEntitiesCount`**). Parallel work and valid data use indices **`0 … ActiveBodiesCount - 1`** from [`SimulationDataComponent`]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}).

## Lifecycle

```
Bootstrap     →  Allocate arrays; store handles on physics world entity
LateSimulation →  Import clears and refills BodiesList + EntitiesMap
FixedStep     →  Internal systems + user jobs read/write native buffers
Simulation    →  Export copies BodiesList back to ECS components
Shutdown      →  Bootstrap disposes native memory
```

{: .warning }
> Do not dispose or reassign these **`NativeArray`** fields from custom code. They are **`Allocator.Persistent`** and owned by bootstrap for the session.

## Accessing the singleton

After [`PhysicsReadyTag`]({% link docs/guides/physics-singleton/physics-ready-tag/index.md %}) is present:

```csharp
var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
```

Custom jobs that touch shared buffers must combine with **`SimulationDataComponent.PhysicsJobHandle`** before scheduling. Package interfaces such as **`IBodiesJob`**, **`ICollisionJob`**, **`ISurfaceJob`**, and **`ILineCastJob`** accept **`PhysicsStructuresComponent`** and handle chaining through **`ScheduleAndChain`**.

See [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) for interface details and group placement.

## Related

- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) — `ActiveBodiesCount` and job handle
- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — record layout stored in **`BodiesList`**
- [How it works — Import]({% link docs/how-it-works/index.md %}#import)
