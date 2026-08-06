---
title: Pairs debug window
layout: default
nav_order: 7
permalink: /docs/guides/pairs-debug-window/
description: Runtime debug table for entity pairs and collision data.
tags: [debug, editor, pairs, collision, lod]
---

# Pairs debug window

The **CollisionPairs** editor window shows a live table of physics bodies and their **pair slots** or **collision slots** while Play Mode is running. Use it to tune [LOD capacity limits]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) and to see when broad-phase pairs or narrow-phase contacts are dropped because lists are full.

The window reads buffers filled each substep by internal **`PairsDebugSystem`**. It is an editor-only tool — enable it with **`ShouldDebug`** on [`PhysicsSettingsAuthoring`]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}).

## Open the window

**Window → Little Physics → CollisionPairs**

The window repaints automatically during Play Mode. Settings you change in the toolbar are saved in the Unity Editor session and restored the next time you open the window or enter Play Mode.

## Enable debug capture

1. Select the GameObject with **`PhysicsSettingsAuthoring`** in your baked subscene.
2. Enable **`ShouldDebug`**.
3. Bake and enter **Play Mode**.

Bootstrap creates a debug entity with **`PairsDebugSettingsComponent`** and two dynamic buffers — **`PairsDebugItem`** (one row per body) and **`PairsIDsDebugItem`** (pair/collision indices). If debug is disabled or you are not in Play Mode, the window shows:

> No PairsDebugSettingsComponent found. Enable ShouldDebug on PhysicsSettingsAuthoring and enter Play Mode.

Leave **`ShouldDebug`** off in shipping builds. It allocates debug entities and runs **`PairsDebugSystem`** every substep.

## Toolbar settings

| Control | Default | Range | Description |
|---------|---------|-------|-------------|
| **Start Index** | `0` | `≥ 0` | First body index in [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}) to display |
| **Count** | `10` | `0–100` | Number of body rows to show, starting at **Start Index** |
| **Pairs Count** | `4` | `0–16` | Number of pair/collision columns (**P0**, **P1**, …) per row |
| **Debug Level** | **Pair Definition** | — | Which data source fills the pair columns (see below) |

Changing any control updates the singleton **`PairsDebugSettingsComponent`** immediately when a Play Mode world is active. On the next bootstrap, saved session values are applied to the new debug entity.

## Table columns

| Column | Meaning |
|--------|---------|
| **ID** | Body index in **`BodiesList`** (same index used by [`ListsArray`]({% link docs/guides/physics-singleton/lists-array/index.md %}) maps and custom jobs) |
| **Entity** | Main physics **`Entity`** as `index:version`, or `null` |
| **Trigger** | `Y` if the body is a trigger; `N` otherwise |
| **Type** | **`S`** static, **`K`** kinematic, **`D`** dynamic |
| **ShapeType** | [`ShapeType`]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) enum name (`Sphere`, `Capsule`, …) |
| **LOD** | Body **`LodIndex`** — selects which LOD tier caps apply |
| **P0 … P*n*** | Neighbor body indices for each slot, or **`-`** when the slot is empty |

Values in **P*** columns are **body indices**, not entity IDs. Look up the neighbor with **`BodiesList[neighborIndex]`** or cross-reference the **ID** column on another row.

## Debug levels

### Pair Definition

Shows entries from the internal **`Pairs`** list after broad-phase collection and before narrow-phase contact resolution. Each slot is a **candidate pair** — a neighbor index that may or may not produce a contact this substep.

Use this mode when tuning **`PairPerEntity`** per LOD tier. If bodies near the camera show **`-`** in high slots but you expect more neighbors, raise **`PairPerEntity`** or tighten LOD ranges.

### Collision Detection

Shows entries from [`CollisionsSingleton.CollisionDataMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — contacts that passed narrow-phase detection. Each slot’s value is **`CollisionData.OtherIndex`** for that body.

Use this mode when tuning **`CollisionPerEntity`**. Empty slots mean no contact was stored in that slot, either because there was no hit or because the per-body collision list was full.

## Pipeline placement

**`PairsDebugSystem`** runs at the end of **`LittlePhysicsInternalSystemGroup`**, after collision and surface work for the current substep. It schedules on **`PhysicsJobHandle`**, so the table reflects data for the substep that just finished.

```
CollisionDetectionSystem  →  fills internal Pairs + CollisionDataMap
SurfaceCollisionSystem    →  fills SurfaceCollisionMap
PairsDebugSystem          →  copies selected body range into debug buffers
Editor window             →  reads buffers each repaint
```

Surface collision results are **not** shown in this window — only object-to-object pairs or collision slots. Use [`ISurfaceJob`]({% link docs/guides/custom-jobs/isurface-job/index.md %}) or read **`SurfaceCollisionMap`** directly for ground/contact debugging.

## Typical workflow

1. Enable **`ShouldDebug`**, bake, enter Play Mode, and open **CollisionPairs**.
2. Set **Start Index** and **Count** to cover the bodies you care about (for example, indices `0–20` for the first crowd chunk).
3. Start in **Pair Definition** mode with **Pairs Count** matching your LOD **`PairPerEntity`** cap.
4. Pause or slow simulation with [`LittlePhysicsTimeComponent`]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) if rows update too quickly to read.
5. Switch to **Collision Detection** to confirm narrow-phase contacts match expectations.
6. Adjust LOD tiers on **`PhysicsSettingsAuthoring`**, rebake, and compare again.

## Related

- [Physics settings and LOD]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) — **`ShouldDebug`**, **`PairPerEntity`**, **`CollisionPerEntity`**
- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — **`CollisionDataMap`** layout and update cycle
- [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — broad-phase input for pair collection
- [ListsArray]({% link docs/guides/physics-singleton/lists-array/index.md %}) — fixed-capacity lists and **`TryAdd`** behavior
- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — fields shown in each row (shape, LOD, body type)
