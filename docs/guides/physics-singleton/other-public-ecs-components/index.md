---
title: Other public ECS components
layout: default
parent: Physics singleton
nav_order: 14
permalink: /docs/guides/physics-singleton/other-public-ecs-components/
description: Per-entity ECS components baked from authorings — body, velocity, surface, map, gravity, and LOD data.
tags: [ecs, component, authoring, body, surface]
---

# Other public ECS components

Little Physics splits data across two layers:

1. **ECS components** on baked entities — what you author in the Editor or spawn at runtime with [builders]({% link docs/guides/builders/index.md %}).
2. **Native structures** on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}) — what the fixed-step loop reads and writes each substep.

This page covers the **public per-entity (and scene) ECS components** that connect those layers. Singleton settings (`PhysicsFixedSettingsComponent`, `LittlePhysicsTimeComponent`, and related types) are documented on their own pages under [Physics singleton]({% link docs/guides/physics-singleton/index.md %}).

## Component map

| Component | Baked from | On which bodies |
|-----------|------------|-----------------|
| [`PhysicsBodyComponent`](#physicsbodycomponent) | Dynamic / kinematic / static authorings, builders | Dynamic, kinematic, static |
| [`PhysicsBodyUpdateComponent`](#physicsbodyupdatecomponent) | Same | Dynamic, kinematic, static |
| [`PhysicsVelocityComponent`](#physicsvelocitycomponent) | `DynamicBodyAuthoring`, `DynamicBodyBuilder` | Dynamic only |
| [`CollisionSurfaceComponent`](#collisionsurfacecomponent) | `SurfaceBodyAuthoring` | Scene surface (singleton) |
| [`SpacialMapSettingsComponent`](#spacialmapsettingscomponent) | `SpacialMapAuthoring` | Scene (singleton) |
| [`SphericalGravitySourceComponent`](#gravity-source-components) | `GravitySourceAuthoring` | Per source entity |
| [`DirectionalGravitySourceComponent`](#gravity-source-components) | `GravitySourceAuthoring` | Per source entity |

[`PhysicsLodData`](#physicsloddata-and-physicslodelement) and [`CameraData`](#cameradata) are public types used during LOD selection but are not standard body components — see their sections below.

## Import and export flow

```
Authoring / builder  →  ECS components on entities
                              ↓
LateSimulation import  →  PhysicsBodyData in BodiesList
                              ↓
FixedStep simulation  →  native buffers updated in place
                              ↓
Simulation export  →  LocalTransform + PhysicsVelocityComponent (dynamics)
                     PhysicsBodyUpdateComponent.TimeElapsed
```

Custom systems can modify ECS components **before** [`LittlePhysicsInternalImportGroup`]({% link docs/guides/custom-jobs/import-workflow/index.md %}) or read native data **after** import. Schedule import/export work with **`SimulationDataComponent.PhysicsJobHandle`**.

## PhysicsBodyComponent

The main **collider and material** record for dynamic, kinematic, and static bodies. Import calls **`ToBodyData(LocalToWorld, lodIndex)`** to build a [`PhysicsBodyData`]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) entry.

| Field | Type | Default (typical) | Description |
|-------|------|-------------------|-------------|
| **`BodyType`** | **`BodyType`** | From authoring | **`Dynamic`**, **`Kinematic`**, or **`Static`** |
| **`IsTrigger`** | **`bool`** | **`false`** | **`true`** for kinematic or static triggers only |
| **`ColliderType`** | **`ColliderType`** | Shape from authoring | Baked shape kind — cast to **`ShapeType`** at import |
| **`LocalPosition`** | **`float3`** | Authoring offset | Collider center offset in local space |
| **`Scale`** | **`float`** | **`1`** | Uniform collider scale |
| **`Mass`** | **`float`** | **`1`** (dynamic) | Mass — dynamics only |
| **`Bounciness`** | **`float`** | Authoring value | Restitution |
| **`Friction`** | **`float`** | **`0.5`** | Contact friction |
| **`Hardness`** | **`float`** | Authoring value | Push-out stiffness |
| **`Main`** | **`Entity`** | Self or parent | Root entity for map lookup. Kinematic triggers may use a **parent** from **`KinematicBodyAuthoring.Main`**. |
| **`Layer`** | **`int`** | GameObject layer | Physics layer bit — same as Unity layer index |
| **`ShouldRotateOnCollision`** | **`bool`** | **`true`** (dynamic) | When **`false`**, import sets **`VelocityData.IsRotationBlocked`**. |

{: .note }
> **`PhysicsBodyComponent`** is **not** written back during export for pose or velocity. Export updates **`LocalTransform`** and **`PhysicsVelocityComponent`** from native **`PhysicsBodyData`**. Treat this component as **input** to import unless you intentionally change it before the next import pass.

### Which authorings add it

| Authoring | **`BodyType`** | Shapes |
|-----------|----------------|--------|
| [`DynamicBodyAuthoring`]({% link docs/guides/types-of-bodies/dynamic/index.md %}) | **`Dynamic`** | Sphere only |
| [`KinematicBodyAuthoring`]({% link docs/guides/types-of-bodies/kinematic/index.md %}) | **`Kinematic`** | Sphere, capsule |
| [`StaticBodyAuthoring`]({% link docs/guides/types-of-bodies/static/index.md %}) | **`Static`** | Sphere, capsule |

Runtime equivalents: [`DynamicBodyBuilder`]({% link docs/guides/builders/dynamic-body-builder/index.md %}), [`KinematicBodyBuilder`]({% link docs/guides/builders/kinematic-body-builder/index.md %}), [`StaticBodyBuilder`]({% link docs/guides/builders/static-body-builder/index.md %}).

## PhysicsBodyUpdateComponent

Per-entity **import bookkeeping**: body index assignment, update cadence, LOD tier, and whether the body fit within **`MaxEntitiesCount`**. Required alongside **`PhysicsBodyComponent`** for import — entities missing it are not counted in **`ActiveBodiesCount`**.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| **`Interval`** | **`float`** | **`0`** (dynamic/kinematic rigid), trigger interval, or **`0`** (static) | Seconds between map/trigger update ticks. **`0`** = every substep. |
| **`TimeElapsed`** | **`float`** | **`0`**, **`-1`** (static) | Countdown to next tick. Export writes the simulated value back. |
| **`Index`** | **`int`** | **`-1`** until import | Body index in **`BodiesList`** / collision buffers |
| **`LodIndex`** | **`int`** | **`0`** | LOD tier. Overwritten during import when camera LOD runs. |
| **`IsEnabled`** | **`bool`** | Set at import | **`false`** when the entity exceeds **`MaxEntitiesCount`** and is skipped |

### Update cadence by body type

| Body type | Baked **`Interval`** | Baked **`TimeElapsed`** | Behavior |
|-----------|---------------------|-------------------------|----------|
| Dynamic | **`0`** | **`0`** | Map and collision every substep |
| Kinematic rigid | **`0`** | **`0`** | Map update every substep |
| Kinematic trigger | **`UpdateInterval`** | **`0`** | Trigger checks on interval |
| Static rigid | **`0`** | **`-1`** | Registered in static map **once** |
| Static trigger | **`0`** | **`-1`** | Same one-shot static registration |

See [PhysicsBodyData — Update cadence]({% link docs/guides/physics-singleton/physics-body-data/index.md %}#update-cadence) for how **`TimeElapsed`** and **`Interval`** copy into native memory.

## PhysicsVelocityComponent

Linear and angular velocity for **dynamic** bodies. Optional at bake time — if absent, import leaves velocity at zero unless set elsewhere before import.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| **`Linear`** | **`float3`** | **`StartLinear`** from `PhysicsVelocityAuthoring`, or zero | World linear velocity |
| **`Angular`** | **`float3`** | **`StartAngular`** from `PhysicsVelocityAuthoring`, or zero | World angular velocity |

**Export** (for enabled dynamics only) writes simulated velocity from **`BodiesList[tag.Index].VelocityData`** back to this component and updates **`LocalTransform`** position and rotation.

{: .warning }
> Attaching **`PhysicsVelocityAuthoring`** to kinematic, static, or surface bodies logs a warning and has **no effect**. Velocity is dynamic-only.

## CollisionSurfaceComponent

Describes the **scene surface** collider — an infinite or large shape tested against every dynamic body each substep. Exactly **one** instance must exist; **`SurfaceCollisionSystem`** and **`FrictionSystem`** require it.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| **`SurfaceType`** | **`ShapeType`** | From `SurfaceBodyAuthoring` | **`SimplePlane`**, **`SimpleBox`**, **`ReverseSphere`**, or sphere |
| **`ShapeData`** | **`float3`** | Box extents or zero | Extra shape payload — box half-extents for **`SimpleBox`** |
| **`Bounciness`** | **`float`** | **`0.5`** | Surface restitution |
| **`Hardness`** | **`float`** | **`1`** | Push-out stiffness |
| **`Friction`** | **`float`** | **`0.5`** | Surface friction |
| **`AngularDrag`** | **`float`** | **`0`** | Angular damping on contact |
| **`Layer`** | **`int`** | GameObject layer | Surface physics layer |

Each frame, surface systems call **`ToBodyData(LocalToWorld)`** to build a temporary **`PhysicsBodyData`** for intersection tests — the surface is **not** stored in **`BodiesList`**.

See [Types of bodies — Surface]({% link docs/guides/types-of-bodies/surface/index.md %}).

## SpacialMapSettingsComponent

Scene singleton baked from **`SpacialMapAuthoring`**. Bootstrap requires it before allocating native map memory, then copies **`SpacialMap`** onto [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}).

| Field | Type | Description |
|-------|------|-------------|
| **`SpacialMap`** | **`SpacialMap`** | Grid origin, cell size, and **`GridSize`** in cells |

Object-to-object collision runs **only** inside this volume. Dynamics outside the map still receive gravity and surface collision.

See [Spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}) (authoring and grid layout).

## Gravity source components

Baked from **`GravitySourceAuthoring`**. Multiple sources can exist; the gravity system accumulates their contribution on dynamic bodies.

### SphericalGravitySourceComponent

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| **`Center`** | **`float3`** | Authoring position | Gravity center |
| **`SurfaceGravity`** | **`float`** | **`9.81`** | Gravity strength at **`Radius`** |
| **`Radius`** | **`float`** | **`localScale.x / 2`** | Sphere radius defining the gravity field |

### DirectionalGravitySourceComponent

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| **`Direction`** | **`float3`** | **`-transform.up`** | Constant gravity direction |
| **`Strength`** | **`float`** | **`9.81`** | Acceleration magnitude |

See [Gravity]({% link docs/guides/physics-singleton/gravity/index.md %}).

## PhysicsLodData and PhysicsLodElement

**`PhysicsLodData`** is a **`IBufferElementData`** tier entry baked from **`PhysicsSettingsAuthoring`** into **`PhysicsSettingsBlobAsset.LodData`** (via [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %})). It is not added to individual body entities.

Each tier defines:

| Field | Type | Description |
|-------|------|-------------|
| **`Range`** | **`float`** | Distance from camera for this tier |
| **`VisionAngle`** | **`float`** | Vision cone angle (360° recommended) |
| **`DynamicsInCells`**, **`StaticInCells`**, **`CellPerEntity`**, **`PairPerEntity`**, **`CollisionPerEntity`** | **`int3`** | Capacity limits at time scales **×1**, **×2**, and **×4** |

**`PhysicsLodElement`** is the resolved **`int`** subset for one active time scale, returned by **`PhysicsLodData.GetElement(int timeScale)`** and **`GetMaxElement()`** (used at bootstrap for buffer sizing).

Import assigns **`LodIndex`** on each body when **`PhysicsStepComponent`** (camera LOD pass) is present — see [`CameraData`](#cameradata).

## CameraData

Public struct passed into the import LOD job when a camera step is registered. Holds the camera pose and projection data used to test each body against LOD vision cones.

| Field | Type | Description |
|-------|------|-------------|
| **`CameraPosition`** | **`float3`** | World camera position |
| **`CameraForward`** | **`float3`** | View direction |
| **`WorldToClipMatrix`** | **`float4x4`** | View-projection matrix |
| **`ViewportSizeInPixels`** | **`float2`** | Viewport dimensions |

When no camera step exists, import keeps **`PhysicsBodyUpdateComponent.LodIndex`** (default **`0`**) and skips cone tests.

## Related

- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — native record built from these components
- [Supporting body and collision structs]({% link docs/guides/physics-singleton/supporting-body-collision-structs/index.md %}) — nested structs inside **`PhysicsBodyData`** and collision buffers
- [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) — scheduling before or after internal import
- [Export workflow]({% link docs/guides/custom-jobs/export-workflow/index.md %}) — reading results after simulation
- [Types of bodies]({% link docs/guides/types-of-bodies/index.md %}) — authoring setup per body type
