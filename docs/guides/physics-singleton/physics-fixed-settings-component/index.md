---
title: PhysicsFixedSettingsComponent
layout: default
parent: Physics singleton
nav_order: 2
permalink: /docs/guides/physics-singleton/physics-fixed-settings-component/
description: PhysicsFixedSettingsComponent — blob asset with fixed physics settings.
tags: [singleton, settings, lod, blob]
---

# PhysicsFixedSettingsComponent

A singleton component that holds **fixed physics settings** baked at startup. Values come from [Physics settings and LOD]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) and the Unity **layer collision matrix**; they are treated as **fixed for the session** after bootstrap.

Internal systems read this component for caps, LOD tiers, pair-check toggles, layer filtering, and spatial-map bounds. Custom code can read it too — for example to respect **`MaxEntitiesCount`** or query whether two layers collide.

## Component fields

| Field | Type | Description |
|-------|------|-------------|
| `BlobRef` | `BlobAssetReference<PhysicsSettingsBlobAsset>` | Persistent reference to the packed settings blob |
| `SpacialMap` | `SpacialMap` | Grid definition and cell dimensions for the spatial map |

Access blob data with **`fixedSettings.BlobRef.Value`** (or `ref fixedSettings.BlobRef.Value` when you need a ref).

### SpacialMap

Set from **`SpacialMapAuthoring`** at bootstrap. Holds the **`Grid3D`** definition and **`GridSize`** in cells. Collision and map systems use it to convert world positions to cell indices.

See [Spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}).

## PhysicsSettingsBlobAsset

The blob is created once in **`LittlePhysicsBootstrapSystem`** and stored in **`BlobRef`**.

| Field | Type | Source | Role |
|-------|------|--------|------|
| `MaxEntitiesCount` | `int` | `PhysicsSettingsAuthoring.MaxEntitiesCount` | Upper bound on bodies imported each frame; excess entities are ignored |
| `LayersMaps` | `BlobArray<int>` | Unity `Physics.GetIgnoreLayerCollision` | Per-layer bitmask of which other layers can collide (32 entries) |
| `LodData` | `BlobArray<PhysicsLodData>` | LOD list on `PhysicsSettingsAuthoring` | Distance/vision tiers and per–time-scale capacity limits |
| `CheckSettings` | `CollisionCheckSettings` | `PhysicsSettingsAuthoring.CollisionCheckSettings` | Enables dynamic-vs-static and dynamic-vs-dynamic pair collection |
| `ShouldDebug` | `bool` | `PhysicsSettingsAuthoring.ShouldDebug` | When true, bootstrap creates debug capture entities |

### CollisionCheckSettings

| Field | Default | Description |
|-------|---------|-------------|
| `CheckDynamicVsStatic` | `true` | Include dynamic–static pairs in broad phase |
| `CheckDynamicVsDynamic` | `true` | Include dynamic–dynamic pairs in broad phase |

### PhysicsLodData

Each LOD tier in **`LodData`** defines a **`Range`**, optional **`VisionAngle`**, and **`int3`** capacity fields (`DynamicsInCells`, `StaticInCells`, `CellPerEntity`, `PairPerEntity`, `CollisionPerEntity`) resolved at time scales **×1**, **×2**, and **×4**. Import and collision systems pick the active tier per body to cap spatial-map and pairwise work.

See [Physics settings and LOD]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) and [How it works — LOD]({% link docs/how-it-works/index.md %}#lod-level-of-detail).

## Layer collision helper

Use the extension on **`PhysicsFixedSettingsComponent`** to test the baked layer matrix:

```csharp
var fixedSettings = SystemAPI.GetSingleton<PhysicsFixedSettingsComponent>();

if (fixedSettings.IsColliding(bodyLayer, otherLayer))
{
    // layers are allowed to interact
}
```

This reads **`LayersMaps[layer1]`** and checks the bit for **`layer2`**.

{: .note }
> Air friction, push-out tuning, and substeps live on [`PhysicsVariableSettingsComponent`]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}), not here. **`SpacialMap`** and the settings blob are fixed for the session after bootstrap.

## Related

- [Physics settings and LOD]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) — authoring setup for blob fields and LOD tiers
- [PhysicsVariableSettingsComponent]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}) — per-tick environment and substep settings
- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) — `ActiveBodiesCount` capped by `MaxEntitiesCount`
- [Spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}) — how cells and maps use `SpacialMap`
