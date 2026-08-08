---
title: CollisionMapSingleton
layout: default
parent: PhysicsStructuresComponent
nav_order: 4
permalink: /docs/guides/physics-singleton/collision-map-singleton/
description: CollisionMapSingleton — spatial broad-phase dynamic and static maps.
tags: [singleton, native, spatial-map, broad-phase]
---

# CollisionMapSingleton

A nested struct on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}) that holds the **spatial broad-phase maps** used for object-to-object pair collection. Bodies are bucketed into [spatial map]({% link docs/guides/settings/spatial-map/index.md %}) cells so **`CollisionDetectionSystem`** can find nearby candidates without testing every pair.

Object-to-object collision only runs for bodies whose AABB overlaps the spatial map bounds. Bodies outside the map still receive gravity and surface collision.

## Fields

| Field | Type | Contents |
|-------|------|----------|
| **`DynamicMap`** | **`ListsArray<uint>`** | Body **indices** for **dynamic** and **kinematic** bodies (rigid and trigger) |
| **`StaticMap`** | **`ListsArray<Entity>`** | **`Entity`** keys for **static** bodies (rigid and trigger) |

Each map is a [`ListsArray<T>`]({% link docs/guides/physics-singleton/lists-array/index.md %}). The **outer list index** is a flattened **3D cell coordinate** in the spatial grid. The **inner list** holds up to **`DynamicsInCells`** or **`StaticInCells`** entries for that cell (from the max LOD tier in [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %})).

Static entries store **`Entity`** because static bodies are registered once; dynamic entries store **`uint`** indices into [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}). Pair collection resolves static entities through [`EntitiesMap`]({% link docs/guides/physics-singleton/entities-map/index.md %}).

## Update cycle (fixed step)

**`CollisionMapUpdateSystem`** runs after friction each substep:

1. **`ClearJob`** — clears **`DynamicMap`** only. **`StaticMap`** is **not** cleared each tick; static entries persist after their one-time insert.
2. **`InitializeBroadPhaseJob`** — builds compact **`BroadPhaseFilterData`** per body (AABB, LOD, update flag).
3. **`AddBodiesJob`** — inserts bodies into the appropriate map when **`ShouldUpdate`** is true and the AABB lies inside map range.

### Which bodies get inserted

| Body kind | Map | When |
|-----------|-----|------|
| Dynamic / kinematic | **`DynamicMap`** | **`TimeElapsed == 0`** (update tick) and AABB inside map |
| Static | **`StaticMap`** | **`TimeElapsed == -1`** and **`IsStatic`** — fires **once** after import, then the entry remains |

Dynamic and kinematic bodies may occupy multiple cells. The number of cells per body is capped by the LOD limit **`CellPerEntity`** at the current [time scale]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}). When an AABB spans more cells than the limit, the system **randomly subsamples** cells using that body’s slot in [`Randoms`]({% link docs/guides/physics-singleton/randoms/index.md %}).

## List keys and capacity

Bootstrap sizes both maps from the baked spatial grid:

```
totalCells = GridSize.x × GridSize.y × GridSize.z
DynamicMap = ListsArray<uint>(totalCells, max.DynamicsInCells, Persistent)
StaticMap  = ListsArray<Entity>(totalCells, max.StaticInCells, Persistent)
```

**`max`** comes from the **maximum** LOD tier limits in the settings blob. Per-frame work uses the **active** LOD tier limits for each body when inserting and when collecting pairs.

If a cell list is full, **`TryAdd`** silently drops additional entries — tune **`DynamicsInCells`**, **`StaticInCells`**, and LOD settings if bodies miss expected neighbors.

## Custom access

**`ILineCastJob`** exposes read-only views of **`DynamicMap`** and **`StaticMap`** for linecast broad-phase queries. For general custom systems, read the maps from **`PhysicsStructuresComponent`** after **`CollisionMapUpdateSystem`** and chain on **`SimulationDataComponent.PhysicsJobHandle`**.

```csharp
var collisionMap = structures.CollisionMap;
var dynamicMap = collisionMap.DynamicMap;
var staticMap = collisionMap.StaticMap;

// Example: iterate entries in one cell
int cellIndex = /* flattened cell index */;
int count = dynamicMap.GetCount(cellIndex);
for (int i = 0; i < count; i++)
{
    uint bodyIndex = dynamicMap.GetValue(cellIndex, i);
    var body = structures.BodiesList[(int)bodyIndex];
}
```

## Related

- [ListsArray]({% link docs/guides/physics-singleton/lists-array/index.md %}) — fixed-capacity array-of-lists container
- [Spatial map]({% link docs/guides/settings/spatial-map/index.md %}) — grid bounds, cell size, and authoring
- [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}) — **`DynamicsInCells`**, **`StaticInCells`**, **`CellPerEntity`**
- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — narrow-phase results after pair collection
- [EntitiesMap]({% link docs/guides/physics-singleton/entities-map/index.md %}) — static entity → body index
