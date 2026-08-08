---
title: How it works
layout: default
nav_order: 3
permalink: /docs/how-it-works/
description: One-frame simulation flow, LOD, and spatial map concepts.
tags: [architecture, pipeline, lod, spatial-map]
---

# How it works

This page explains the high-level simulation flow — how bodies enter the pipeline, what happens during a fixed update, and how **LOD** and the **spatial map** shape collision work.

For system group names, execution order, and custom hook points, see [Pipeline]({% link docs/pipeline/index.md %}).

## Overview video

This is a video series where I walk through how I designed the Little Physics system — architecture choices, data flow, and the reasoning behind major features.

{% include youtube.html id="E2M__WlXrI0" %}

## One frame at a glance

Each Unity frame, Little Physics runs through these steps in order:

1. **Bootstrap** (once, on Initialization) — `LittlePhysicsBootstrapSystem` creates native buffers, settings blobs, and singleton components, then adds `PhysicsReadyTag`.
2. **Import** (Late update) — `LittlePhysicsImportGroup` counts bodies, assigns body indices, and copies component data into native structures such as `BodiesList`.
3. **Fixed step** (Entities fixed update) — `LittlePhysicsSystemGroup` runs a nested **TimeScale** × **Substeps** loop. Each iteration:
   1. **Gravity and friction** — apply gravity and air/surface friction to dynamic bodies.
   2. **Spatial map update** — place dynamic and kinematic bodies into grid cells.
   3. **Pair collection** — build the set of body pairs to test (capped by LOD).
   4. **Collision detection** — intersection tests and collision data for dynamics.
   5. **Velocity and push-out** — resolve contacts and separation forces between bodies.
   6. **Surface collision** — test every dynamic body against all surfaces.
   7. **User jobs** (optional) — custom logic in `LittlePhysicsUserSystemGroup`.
   8. **Velocity → position** — integrate velocity into position data.
4. **Export** (Simulation, after fixed step) — `LittlePhysicsExportGroup` writes calculated position, rotation, and velocity back to ECS components and transforms.

Custom systems can hook **import** (`LittlePhysicsImportGroup`), **mid-step** (`LittlePhysicsUserSystemGroup`), or **export** (`LittlePhysicsExportGroup`). See [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) and [Pipeline]({% link docs/pipeline/index.md %}).

## Bootstrap

`LittlePhysicsBootstrapSystem` runs once during **Initialization**. It:

- Allocates the native structures held on `PhysicsStructuresComponent` (body list, entity map, collision maps, random streams).
- Builds fixed and variable settings from `PhysicsSettingsAuthoring` into blob assets on the physics singleton.
- Creates supporting singletons such as `LittlePhysicsTimeComponent` and `SimulationDataComponent`.

At the very end it adds **`PhysicsReadyTag`**. Other systems — including your own — should **`RequireForUpdate<PhysicsReadyTag>()`** in `OnCreate` so they never run before physics is initialized.

Without a baked **`PhysicsSettingsAuthoring`** in the world, bootstrap does not set up the simulation.

## Import

On **LateSimulation**, `LittlePhysicsImportGroup` runs. User systems in this group execute **before** `LittlePhysicsInternalImportGroup`.

Import:

1. Counts dynamic, kinematic, and static bodies (respecting **`MaxEntitiesCount`** — excess entities are ignored).
2. Assigns each participating entity a **body index** for the current pipeline loop.
3. Copies transform, collider, layer, trigger flags, and related data from components into **`NativeArray<PhysicsBodyData> BodiesList`** and **`EntitiesMap`**.

Import is the handoff from ECS components to the unmanaged memory pool used in the fixed-step jobs. If you need to modify component data before it enters native buffers, schedule work **before** internal import; if you need data already in native structures, run **after** internal import and chain on `SimulationDataComponent.PhysicsJobHandle`.

## Fixed update — TimeScale and Substeps

`LittlePhysicsSystemGroup` runs inside **`FixedStepSimulationSystemGroup`**. Each Unity fixed update, it nests two loops:

- **Time scale** — read from [`LittlePhysicsTimeComponent`]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) (`TimeScale`: `0` pause, `1`, `2`, or `4`). A scale of `2` runs the inner pipeline twice per fixed tick; `0` skips simulation.
- **Substeps** — from `PhysicsSettingsAuthoring` (**1–4**). Each substep uses a fraction of the fixed delta time for finer penetration handling and stability.

Example: time scale **2** and **2** substeps → **4** full inner loops per fixed update.

During each inner loop, **`LittlePhysicsInternalSystemGroup`** runs the core physics steps in order:

1. **Gravity and friction** — apply directional or radial gravity and air/surface friction to dynamic bodies.
2. **Spatial map fill** — place dynamic and kinematic bodies into grid cells (see [Spatial map](#spatial-map) below).
3. **Pair collection** — build a unique set of body pairs to test, capped per entity by LOD limits.
4. **Collision detection** — intersection tests for dynamic and kinematic rigid bodies; collision slots filled for dynamics.
5. **Velocity and push-out** — resolve contacts and compute separation forces between bodies.
6. **Surface collision** — every dynamic body is tested against **all** surface bodies **every** substep, regardless of LOD or map cell.

Then **`LittlePhysicsUserSystemGroup`** runs your custom logic (forces, gameplay, debug) **after** collisions are known but **before** positions are integrated.

Finally **`LittlePhysicsLateSystemGroup`** applies velocity to position data inside the native buffers.

## Export

After the fixed-step group finishes, **`LittlePhysicsExportGroup`** runs in **`SimulationSystemGroup`**. Internal export runs first; user export systems run after.

Export copies calculated **position**, **rotation**, and **velocity** from native structures back to ECS components and transforms so GameObjects and rendering systems see the new state.

## LOD (level of detail)

LOD lets the simulation **tighten or relax limits** based on each body’s distance to the camera. Configure tiers on **`PhysicsSettingsAuthoring`**:

- Add or remove LOD levels in the Inspector; the **last** level is always the default fallback for bodies outside all defined ranges.
- Adjust each level’s **distance range** and optional **vision angle** (360° is recommended for simpler indexing).
- Per LOD level, set limits such as **`DynamicsInCells`**, **`StaticInCells`**, **`CellPerEntity`**, **`PairPerEntity`**, and **`CollisionPerEntity`** at time scales **×1**, **×2**, and **×4**.

At runtime a LOD job assigns each body an **`LodIndex`** in `PhysicsBodyData`. Closer bodies typically get higher pair and collision budgets; distant bodies skip expensive pairwise work. That trade-off improves throughput for crowds and particles but **reduces determinism** when settings are loose. Tighter limits and closer camera ranges improve consistency.

LOD affects **object-to-object** work inside the spatial map. It does **not** skip **surface** collision — surfaces are always tested against all dynamic bodies each substep.

For field definitions and singleton access, see [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}).

## Spatial map

The **spatial map** is a user-defined volume divided into cubic **cells**. It is the only region where **object-to-object** collisions are simulated. Configure it with **`SpacialMapAuthoring`**:

| Field | Role |
|-------|------|
| `CellWidth` | Size of one cell in world units |
| `GridSize` | Number of cells along each axis |
| `ShouldDrawInEditor` | Visualize the grid in the Scene view |

The map is centered on the authoring transform. Each frame, dynamic and kinematic rigid bodies are inserted into cells based on position and size (subject to **`CellPerEntity`** per LOD). Static rigid bodies are inserted once when created; triggers follow their update intervals.

**Outside the map**, bodies still receive **gravity** and **surface** collision, but **not** pairwise object collisions.

For authoring setup, see [Getting Started]({% link docs/getting-started/index.md %}). For runtime structures (`DynamicMap`, `StaticMap`), see [Spatial map]({% link docs/guides/settings/spatial-map/index.md %}).

## Time control

Pause, slow down, or speed up the simulation at runtime by changing **`TimeScale`** on [`LittlePhysicsTimeComponent`]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) — without altering Unity’s fixed timestep. The same singleton also exposes **`DeltaTime`** (scaled substep delta, useful in `LittlePhysicsUserSystemGroup`) and **`ElapsedTime`** (accumulated physics time). See [LittlePhysicsTimeComponent]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) for field details and usage.

## What to read next

| Topic | Page |
|-------|------|
| Install and first scene | [Getting Started]({% link docs/getting-started/index.md %}) |
| System groups, diagram, hook order | [Pipeline]({% link docs/pipeline/index.md %}) |
| Settings, body types, LOD, spatial map, gravity | [Settings]({% link docs/guides/settings/index.md %}) |
| `BodiesList`, collision maps, singletons | [Physics singleton]({% link docs/guides/physics-singleton/index.md %}) |
| `IBodiesJob`, import/export workflow | [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) |
