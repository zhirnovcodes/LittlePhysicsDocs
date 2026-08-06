---
title: Physics settings and LOD
layout: default
parent: Physics singleton
nav_order: 16
permalink: /docs/guides/physics-singleton/physics-settings-and-lod/
description: PhysicsSettingsAuthoring, LOD tiers, and per-LOD simulation capacity limits.
tags: [settings, lod, authoring, capacity, determinism]
---

# Physics settings and LOD

**`PhysicsSettingsAuthoring`** defines global simulation limits and **LOD (level of detail)** tiers. Bootstrap packs values into a persistent blob on [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}) and copies runtime-tunable fields to [`PhysicsVariableSettingsComponent`]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}).

LOD lets the simulation **spend more collision budget on nearby bodies** and relax work for distant ones. That trade-off enables large crowds and particle fields, but **loose limits reduce determinism**. Tighter tiers and closer camera ranges improve consistency.

## PhysicsSettingsAuthoring

Add **`PhysicsSettingsAuthoring`** once per baked world. Bootstrap waits for this component before allocating native structures.

### Global fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `MaxEntitiesCount` | `int` | `10000` | Maximum bodies imported each frame; excess entities are ignored |
| `AirFriction` | `float` | `0.5` | Global linear air friction on dynamic bodies |
| `AirAngularDrag` | `float` | `0` | Global angular air drag |
| `PushOutPower` | `float` | `1` | Multiplier on penetration push-out strength |
| `PushOutType` | `PushOutType` | `Position` | Apply push-out as **position** or **velocity** correction |
| `SubstepsCount` | `byte` | `1` | Inner physics loops per time-scale iteration (**1–4**) |
| `CollisionCheckSettings` | struct | both `true` | Toggles for dynamic–static and dynamic–dynamic pair collection |
| `ShouldDebug` | `bool` | `false` | Creates entities for the [Pairs debug window]({% link docs/guides/pairs-debug-window/index.md %}) |

### CollisionCheckSettings

| Field | Default | Description |
|-------|---------|-------------|
| `CheckDynamicVsStatic` | `true` | Include dynamic–static pairs in broad phase |
| `CheckDynamicVsDynamic` | `true` | Include dynamic–dynamic pairs in broad phase |

The Unity **layer collision matrix** is also baked into the settings blob at bootstrap. Use **`PhysicsFixedSettingsComponent.IsColliding(layer1, layer2)`** to query it at runtime.

## LOD tiers

Use the **LOD** list on **`PhysicsSettingsAuthoring`** to add up to **four** distance tiers. The Inspector draws each tier in the Scene view (matching colors in the property window).

| Control | Behavior |
|---------|----------|
| **Add / Remove** | Insert or delete tiers; at least one tier is always present |
| **Last tier** | Always the **default fallback** for bodies outside all nearer ranges |
| **`Range`** | Distance from the camera for this tier; must increase between tiers |
| **`VisionAngle`** | Vision cone half-angle (degrees) used with **`Range`** to test visibility |

{: .note }
> Set **`VisionAngle`** to **360°** when possible — it simplifies LOD indexing to a distance sphere and avoids cone edge cases.

When **more than one** LOD tier exists, bootstrap creates **`PhysicsStepComponent`**. Each late-update import pass, **`PhysicsStepSystem`** writes **`Camera.main`** position and forward into that singleton, and **`ImportPhysicsDataSystem`** assigns each body a **`LodIndex`** stored in [`PhysicsBodyData`]({% link docs/guides/physics-singleton/physics-body-data/index.md %}).

LOD assignment tests the body’s bounding sphere against each tier’s spherical cone, **from nearest to farthest**. The **first matching tier** wins; if none match, the body uses the **last** tier index.

With only **one** tier in the list, camera LOD is disabled and bodies keep the authored **`LodIndex`** (default `0`).

## Per-tier capacity limits

Each LOD tier stores five limits as **`int3`** vectors. The three components are the values used at time scales **×1**, **×2**, and **×4** ([`LittlePhysicsTimeComponent.TimeScale`]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %})).

| Field | What it limits |
|-------|----------------|
| **`DynamicsInCells`** | Max dynamic and kinematic body **indices** stored in one spatial-map cell per substep |
| **`StaticInCells`** | Max static body **entities** stored in one cell. Set to **0** if the scene has no static bodies |
| **`CellPerEntity`** | Max cells a dynamic or kinematic body may occupy when its AABB spans multiple cells. Excess cells are **randomly subsampled** |
| **`PairPerEntity`** | Max unique collision **pairs** collected per body during broad phase |
| **`CollisionPerEntity`** | Max narrow-phase **collisions** stored per body — the heaviest step; keep lower on distant LOD tiers |

At runtime, **`PhysicsLodData.GetElement(timeScale)`** resolves the active **`PhysicsLodElement`** for the current substep. Internal systems call **`GetLodData(timeScale, lodIndex)`** on the settings blob when inserting into the [spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}), collecting pairs, and writing [`CollisionData`]({% link docs/guides/physics-singleton/supporting-body-collision-structs/index.md %}).

Bootstrap allocates native buffers using **`GetMaxLodData()`** — the **maximum** value of each field across **all tiers and all time-scale slots**. Per-frame work still respects the **active** tier for each body.

### Default tier values

New tiers start from **`PhysicsLodData.CreateDefault()`**:

| Field | ×1 | ×2 | ×4 |
|-------|----|----|-----|
| `DynamicsInCells` | 32 | 16 | 8 |
| `StaticInCells` | 8 | 8 | 8 |
| `CellPerEntity` | 32 | 16 | 8 |
| `PairPerEntity` | 32 | 16 | 8 |
| `CollisionPerEntity` | 16 | 8 | 4 |

When **`TimeScale`** is **2**, the middle column applies; at **4** (and **3**, which maps to the same slot), the third column applies.

## What LOD affects

LOD caps **object-to-object** work inside the [spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}):

- Cells a body occupies (**`CellPerEntity`**)
- Neighbors seen per cell (**`DynamicsInCells`**, **`StaticInCells`**)
- Pairs and contacts per body (**`PairPerEntity`**, **`CollisionPerEntity`**)

LOD does **not** reduce:

- **Gravity** or friction on dynamic bodies
- **Surface collision** — every dynamic body is tested against all surfaces **every** substep
- Import/export of body transforms and velocities

If lists or maps are full, **`TryAdd`** silently drops entries. Use the [Pairs debug window]({% link docs/guides/pairs-debug-window/index.md %}) or enable **`ShouldDebug`** when tuning limits.

## Runtime access

Fixed settings live in the blob referenced by **`PhysicsFixedSettingsComponent.BlobRef`**:

```csharp
ref var blob = ref SystemAPI.GetSingleton<PhysicsFixedSettingsComponent>().BlobRef.Value;

int maxBodies = blob.MaxEntitiesCount;
int lodTierCount = blob.LodData.Length;

// Capacity for body at lodIndex during time scale 2
PhysicsLodElement limits = blob.GetLodData(2, bodyLodIndex);
```

Variable settings (air friction, substeps) are on **`PhysicsVariableSettingsComponent`** and can be changed at runtime without rebuilding the blob.

## Tuning workflow

1. Start with defaults and a single LOD tier while validating basic collisions.
2. Add tiers with **decreasing** capacity columns for distant **`Range`** values.
3. Enable **`ShouldDrawInEditor`** on **`SpacialMapAuthoring`** and confirm bodies stay inside the map volume.
4. Raise **`MaxEntitiesCount`** only as needed — it sizes **`BodiesList`**, collision arrays, and related native memory.
5. At **×2** or **×4** time scale, expect stricter effective limits from the ×2 and ×4 columns; increase those columns if distant bodies lose contacts when speeding up simulation.

## Related

- [PhysicsFixedSettingsComponent]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}) — blob layout and layer matrix
- [PhysicsVariableSettingsComponent]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}) — air friction, push-out, substeps
- [LittlePhysicsTimeComponent]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) — time scale selects the ×1 / ×2 / ×4 column
- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — **`LodIndex`** field on each body
- [How it works — LOD]({% link docs/how-it-works/index.md %}#lod-level-of-detail) — pipeline overview
