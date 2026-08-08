---
title: Spatial map
layout: default
parent: Settings
nav_order: 2
permalink: /docs/guides/settings/spatial-map/
description: Spatial map concept, SpacialMapAuthoring setup, and runtime grid data.
tags: [spatial-map, broad-phase, authoring, cells]
---

# Spatial map

The **spatial map** is a user-defined volume divided into cubic **cells**. It is the only region where **object-to-object** collision is simulated — broad-phase bucketing, pair collection, and narrow-phase contact all depend on bodies being inside this grid.

Bodies **outside** the map still receive **gravity** and **surface** collision every substep. They do **not** participate in pairwise object collisions.

Configure the map with **`SpacialMapAuthoring`** in a subscene. Bootstrap copies the baked grid into [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}) and sizes [`CollisionMapSingleton`]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) from the cell count and LOD capacity limits.

## SpacialMapAuthoring

Add **`SpacialMapAuthoring`** to a GameObject in your subscene. Bootstrap requires exactly one baked instance — without it, **`LittlePhysicsBootstrapSystem`** does not allocate collision maps.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `CellWidth` | `float` | `1` | World size of one grid cell along each axis |
| `GridSize` | `int3` | `(16, 16, 16)` | Number of cells along X, Y, and Z |
| `RandomSeed` | `uint` | `12345` | Seed for per-body random cell subsampling when an AABB spans more cells than LOD allows |
| `ShouldDrawInEditor` | `bool` | `false` | Draw the grid wireframe in the Scene view |

The Inspector also shows **Total Cells Count** (`GridSize.x × GridSize.y × GridSize.z`) — bootstrap allocates one list slot per cell in both **`DynamicMap`** and **`StaticMap`**.

### Map bounds and placement

At bake time the grid **minimum corner** is computed from the GameObject transform:

```
halfSize = CellWidth × GridSize × 0.5
Grid.Position = transform.position − halfSize
```

The authoring transform sits at the **center** of the volume. World extent along each axis is **`CellWidth × GridSize`**.

Toggle **`ShouldDrawInEditor`** to visualize cell boundaries while positioning the map over your play area. Match **`CellWidth`** and **`GridSize`** to the densest region where bodies need object-to-object contact.

{: .note }
> The public API spellings **`SpacialMap`**, **`SpacialMapAuthoring`**, and **`SpacialMapSettingsComponent`** match the package source.

## How bodies use the map

Each fixed substep, **`CollisionMapUpdateSystem`** inserts bodies whose AABB overlaps the grid:

| Body kind | Map | When inserted |
|-----------|-----|---------------|
| Dynamic / kinematic | **`DynamicMap`** | On update ticks (`TimeElapsed == 0`) when the AABB is inside the grid |
| Static | **`StaticMap`** | Once after import (`TimeElapsed == -1` and `IsStatic`), then the entry persists |

Dynamic and kinematic bodies can occupy **multiple cells** based on position, scale, and **`CellWidth`**. The number of cells per body is capped by the active LOD limit **`CellPerEntity`**. When an AABB spans more cells than the limit, the system **randomly subsamples** cells using that body’s slot in [`Randoms`]({% link docs/guides/physics-singleton/randoms/index.md %}) — seeded from **`RandomSeed`** at bootstrap.

**`CollisionDetectionSystem`** then walks shared cells to collect unique pairs and run intersection tests. Pair and collision budgets come from the body’s **`LodIndex`** and current [time scale]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}).

See [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) for map update order and custom read access.

## Runtime data

After bootstrap, read the grid from **`PhysicsFixedSettingsComponent`** — it is fixed for the session alongside the settings blob:

```csharp
var fixedSettings = SystemAPI.GetSingleton<PhysicsFixedSettingsComponent>();
SpacialMap map = fixedSettings.SpacialMap;

float3 cellSize = map.Grid.CellSize;
float3 minCorner = map.Grid.Position;
int3 gridSize = map.GridSize;
int totalCells = map.GetCellsCount();
```

| Type | Role |
|------|------|
| **`SpacialMap`** | Grid definition plus cell dimensions on **`PhysicsFixedSettingsComponent`** |
| **`Grid3D`** | Minimum corner **`Position`** and **`CellSize`** |
| **`SpacialMapSettingsComponent`** | ECS component holding the baked map before bootstrap copies it to **`PhysicsFixedSettingsComponent`** |

Use **`Grid3DExtensions`** helpers (`GetCell`, `GetCells`, `GridCellToIndex`) when converting world positions to flattened cell indices for custom broad-phase queries. [`ILineCastJob`]({% link docs/guides/custom-jobs/ilinecast-job/index.md %}) reads **`DynamicMap`** and **`StaticMap`** through the same grid.

## Tuning tips

- **Smaller cells** — finer broad-phase resolution, more cells to traverse, higher memory (`totalCells × per-cell capacity`).
- **Larger cells** — fewer cells and less memory, but more bodies per cell; raise **`DynamicsInCells`** and related LOD limits or pairs may be dropped silently.
- **Extend the grid** — increase **`GridSize`** or reposition the authoring object so important gameplay stays inside bounds.
- **Bodies falling through each other near the edge** — they may be outside the map AABB; only gravity and surfaces apply there.

Capacity fields (**`DynamicsInCells`**, **`StaticInCells`**, **`CellPerEntity`**) are set per LOD tier on [`PhysicsSettingsAuthoring`]({% link docs/guides/settings/physics-settings-and-lod/index.md %}). Bootstrap sizes native buffers from the **maximum** values across all tiers.

## Setup checklist

1. Add **`SpacialMapAuthoring`** to a GameObject in the subscene (alongside **`PhysicsSettingsAuthoring`**).
2. Set **`CellWidth`** and **`GridSize`** to cover the simulation volume.
3. Enable **`ShouldDrawInEditor`** and position the object so the wireframe encloses dynamic bodies.
4. Bake the subscene and enter Play mode — bootstrap logs allocation size when maps are created.

## Related

- [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — **`DynamicMap`** and **`StaticMap`** contents and update cycle
- [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}) — **`CellPerEntity`**, **`DynamicsInCells`**, **`StaticInCells`**
- [How it works — Spatial map]({% link docs/how-it-works/index.md %}#spatial-map) — placement in the fixed-step pipeline
- [PhysicsFixedSettingsComponent]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}) — runtime **`SpacialMap`** field
- [Getting Started]({% link docs/getting-started/index.md %}) — minimal scene setup
