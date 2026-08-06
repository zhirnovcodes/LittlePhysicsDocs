# Little Physics — documentation hierarchy

Source: `doc.txt`, `public.txt`, package code (`com.ivancodes.littlephysics`).

Use this as the site nav outline. Slugs in parentheses are suggested future page paths under `docs/`.

---

## 1 Home

`index.md`

- Product overview — Unity ECS physics for large-scale simulations (~1M units)
- Key features (LOD, time scale, body types, gravity, friction, surfaces, substeps)
- Known limitations (determinism, MaxEntitiesCount, shapes, spatial map bounds, time scale values)
- Links to Getting Started, How it works, API Reference

---

## 2 Getting Started

`docs/getting-started/index.md`

- Requirements — Unity 6 (6000.0+), Entities 1.4.8, optional Entities.Graphics for samples
- Install — Package Manager → `com.ivancodes.littlephysics`
- Quick start (subscene workflow)
  - Add `PhysicsSettingsAuthoring`
  - Add `SpacialMapAuthoring` (size, cell size, position; enable editor gizmo)
  - Add `GravitySourceAuthoring` (optional)
  - Add `SurfaceBodyAuthoring` (optional)
  - Add body authorings — `DynamicBodyAuthoring`, `KinematicBodyAuthoring`, or `StaticBodyAuthoring`
  - Play
- Samples — Package Manager → Little Physics → All Samples (5 scenes; requires Entities.Graphics)
- Next steps — Types of bodies, Pipeline, Custom jobs

---

## 3 How it works

`docs/how-it-works/index.md`

- ECS + baking overview (authorings → components → native structures)
- One-frame narrative (bootstrap → import → fixed-step loop → export)
- Bootstrap — `LittlePhysicsBootstrapSystem` creates structures, settings, `PhysicsReadyTag`
- Import — body count, entity → native `BodiesList`, unique body index per pipeline loop
- Fixed update — nested loops: **TimeScale** (0, 1, 2, 4) × **Substeps** (1–4)
- Per substep (high level) — gravity/friction → spatial map → pairs → collision detection → velocity/push-out → surface collision → user jobs → velocity → position
- Export — native data back to physics / transform / velocity components
- LOD concept — distance-to-camera tiers change simulation limits (see Physics Settings)
- Spatial map concept — object-to-object collisions only inside map bounds; outside still gets gravity + surface
- Link to **4 Pipeline** for execution order detail

---

## 4 Pipeline

`docs/pipeline/index.md`

- Pipeline diagram (from `pipeline.pdf`)
- System group hierarchy

```
Initialization
  └─ LittlePhysicsBootstrapSystem

LateSimulation
  └─ LittlePhysicsImportGroup                    [public — user systems OrderFirst]
       └─ LittlePhysicsInternalImportGroup      [internal]

FixedStepSimulationSystemGroup
  └─ LittlePhysicsSystemGroup                    [internal — TimeScale × Substeps loop]
       ├─ LittlePhysicsInternalSystemGroup       [internal]
       │    ├─ gravity
       │    ├─ friction
       │    ├─ spatial map fill
       │    ├─ pair collection
       │    ├─ collision detection
       │    ├─ velocity / push-out
       │    └─ surface collision
       ├─ LittlePhysicsUserSystemGroup           [public]
       └─ LittlePhysicsLateSystemGroup           [internal — velocity → position]

SimulationSystemGroup (after FixedStep)
  └─ LittlePhysicsExportGroup                    [public — user systems OrderLast]
       └─ LittlePhysicsInternalExportGroup       [internal]
```

- Public vs internal groups
- When to hook custom systems — import (LateUpdate), mid-step (FixedStep), export (Simulation)
- `SimulationDataComponent.PhysicsJobHandle` — chaining custom jobs
- `PhysicsReadyTag` — require in custom system `OnCreate`

---

## 5 Types of bodies

`docs/guides/types-of-bodies/index.md`

### 5.1 Dynamic

`docs/guides/types-of-bodies/dynamic/index.md`

- Body affected by gravity, friction, surface, and object-to-object collisions (doc.txt)
- **Shapes:** sphere only
- Authoring: `DynamicBodyAuthoring`
- Optional initial velocity: `PhysicsVelocityAuthoring` (dynamic only; see doc.txt *Physics Velocity authoring*)

### 5.2 Kinematic

`docs/guides/types-of-bodies/kinematic/index.md`

- **Rigid** — affects dynamic bodies; not affected by gravity, collision forces, or physics velocities; updated in spatial map each simulation step (`KinematicBodyAuthoring`, `IsTrigger = false`)
- **Trigger** — no physical response; intersection checks on trigger update interval; checks dynamic, kinematic, static, and triggers (`KinematicBodyAuthoring`, `IsTrigger = true`)
- **Shapes:** sphere, capsule

### 5.3 Static

`docs/guides/types-of-bodies/static/index.md`

- **Rigid** — affects dynamic bodies; not affected by forces or velocities; added to spatial map once after creation (`StaticBodyAuthoring`, `IsTrigger = false`)
- **Trigger** — no physical response; intersection checks only; added to map once; checks dynamic and kinematic objects (`StaticBodyAuthoring`, `IsTrigger = true`)
- **Shapes:** sphere, capsule

### 5.4 Surface

`docs/guides/types-of-bodies/surface/index.md`

- Collisions with **all dynamic bodies every frame**; intersection checks with kinematic triggers (doc.txt)
- **Shapes:** sphere, capsule, simple plane, box, reverse sphere, etc.
- Authoring: `SurfaceBodyAuthoring`
- Note: velocity on surface authoring is ignored

---

## 6 Physics singleton (public components and structures)

`docs/guides/physics-singleton/index.md`

Overview — singleton entity created by bootstrap; custom systems read/write via `SystemAPI.GetSingleton`.

### 6.1 PhysicsReadyTag

`docs/guides/physics-singleton/physics-ready-tag/index.md`

- Created at end of bootstrap; signal that physics is ready
- Use `[RequireForUpdate(typeof(PhysicsReadyTag))]` in custom systems

### 6.2 PhysicsFixedSettingsComponent

`docs/guides/physics-singleton/physics-fixed-settings-component/index.md`

- Blob asset with fixed settings from `PhysicsSettingsAuthoring`
- Related: `PhysicsSettingsBlobAsset`, `EnvironmentSettings`, `CollisionCheckSettings`

### 6.3 PhysicsVariableSettingsComponent

`docs/guides/physics-singleton/physics-variable-settings-component/index.md`

- Variable per-tick settings from `PhysicsSettingsAuthoring` (e.g. substeps count)

### 6.4 SimulationDataComponent

`docs/guides/physics-singleton/simulation-data-component/index.md`

- `ActiveBodiesCount` — bodies in current simulation step
- `PhysicsJobHandle` — chain import / export / custom jobs

### 6.5 LittlePhysicsTimeComponent

`docs/guides/physics-singleton/little-physics-time-component/index.md`

- `TimeScale` — 0 (pause), 1, 2, 4 only
- `DeltaTime` — read-only; scaled delta for use in `LittlePhysicsUserSystemGroup`
- `ElapsedTime` — read-only; accumulated simulation time

### 6.6 PhysicsStructuresComponent

`docs/guides/physics-singleton/physics-structures-component/index.md`

Main native structures for collision pipeline.

#### 6.6.1 BodiesList

`docs/guides/physics-singleton/bodies-list/index.md`

- `NativeArray<PhysicsBodyData>` — filled by import; count = `ActiveBodiesCount`
- See **6.8 PhysicsBodyData**

#### 6.6.2 Randoms

`docs/guides/physics-singleton/randoms/index.md`

- `NativeArray<Random>` — per-body random state; count = `ActiveBodiesCount`

#### 6.6.3 EntitiesMap

`docs/guides/physics-singleton/entities-map/index.md`

- `NativeHashMap<Entity, uint>` — entity → body index in `BodiesList`

#### 6.6.4 CollisionMapSingleton

`docs/guides/physics-singleton/collision-map-singleton/index.md`

Spatial broad-phase maps (cell key → body indices / entities).

- **DynamicMap** — `ListsArray<uint>` — dynamic + kinematic (rigid and trigger) body indices
- **StaticMap** — `ListsArray<Entity>` — static body entities

Cell index: 1D → 4D (3 spatial cell coords + index within cell; up to `MaxEntitiesInCell` per cell).

#### 6.6.5 CollisionsSingleton

`docs/guides/physics-singleton/collisions-singleton/index.md`

Per-body collision results.

- **SurfaceCollisionMap** — `NativeArray<SurfaceCollisionData>` keyed by body index
- **CollisionDataMap** — `ListsArray<CollisionData>` — per-body list of object-to-object collisions (up to `MaxCollisionsPerEntity`)

### 6.7 PhysicsBodyData

`docs/guides/physics-singleton/physics-body-data/index.md`

Simulation-side body record in `BodiesList`.

- `Main`, `Layer`, `LodIndex`
- `IsTrigger`, `BodyType`, `ShapeType`
- `TimeElapsed`, `Interval` — update cadence / trigger interval
- `PositionData`, `VelocityData`, `RigidbodyData`
- Helpers: `IsStatic`, `IsKinematic`, `IsDynamic`

### 6.8 Supporting body / collision structs

`docs/guides/physics-singleton/supporting-body-collision-structs/index.md`

- **RigidbodyData** — `Mass`, `Bounciness`, `Friction`, `Hardness`, `AngularDrag`
- **VelocityData** — `Linear`, `Angular`, `IsRotationBlocked`
- **PositionData** — scale, position, up (capsules), rotation
- **CollisionData** — `HasValue`, `OtherIndex`, contact geometry, `PenetrationDepth`, `PushOutWeight`
- **SurfaceCollisionData** — `IsColliding`, `ContactPoint`, `Normal`

### 6.9 Other public ECS components (singleton-related)

`docs/guides/physics-singleton/other-public-ecs-components/index.md`

- `PhysicsBodyComponent`, `PhysicsBodyUpdateComponent` — per-entity baked data
- `PhysicsVelocityComponent` — dynamic velocity component
- `SpacialMapSettingsComponent` — baked map bounds / cell settings
- `PhysicsMapRandomComponent`
- `CollisionSurfaceComponent`
- `SphericalGravitySourceComponent`, `DirectionalGravitySourceComponent`
- `PhysicsLodData`, `PhysicsLodElement`
- `CameraData`

### 6.10 Spatial map

`docs/guides/physics-singleton/spatial-map/index.md`

- Concept — cubic cells; object-to-object collision region
- Authoring: `SpacialMapAuthoring` → `SpacialMapSettingsComponent`
- Types: `SpacialMap`, `Grid3D`, `AABB`
- LOD table properties (see **6.11**): `DynamicsInCells`, `StaticInCells`, `CellPerEntity`, `PairPerEntity`, `CollisionPerEntity`

### 6.11 Physics settings and LOD

`docs/guides/physics-singleton/physics-settings-and-lod/index.md`

Authoring: `PhysicsSettingsAuthoring`

- LOD levels (up to 4) — distance / vision angle from camera; last level = default fallback
- Per-LOD limits at time scales ×1, ×2, ×4:
  - **DynamicsInCells** — max dynamic/kinematic bodies per cell
  - **StaticInCells** — max static bodies per cell (0 if no statics)
  - **CellPerEntity** — max cells one body occupies (dynamic/kinematic)
  - **PairPerEntity** — max unique pairs per entity
  - **CollisionPerEntity** — max collision checks per entity
- Substeps — 1–4 per fixed update

### 6.12 Gravity

`docs/guides/physics-singleton/gravity/index.md`

Authoring: `GravitySourceAuthoring`

- **Directional** — along object's Down axis
- **Radial** — pull toward scaled spherical region

---

## 7 Pairs debug window

`docs/guides/pairs-debug-window/index.md`

- Menu: Window → Little Physics → debug window (`PairsDebugSystem` / `CollisionPairsDebugWindow`)
- Runtime table of entities, pairs, and collision data
- Columns — entity ID, shape, LOD, pair indices, collision flags (see `PairsDebugSystem`)
- Use for tuning LOD limits and diagnosing pair/collision caps

---

## 8 Custom jobs

`docs/guides/custom-jobs/index.md`

### 8.1 Custom job groups

`docs/guides/custom-jobs/custom-job-groups/index.md`

| Group | Update phase | User order | Purpose |
|-------|--------------|------------|---------|
| `LittlePhysicsImportGroup` | LateSimulation | Before `LittlePhysicsInternalImportGroup` | Alter components before import |
| `LittlePhysicsImportGroup` | LateSimulation | After `LittlePhysicsInternalImportGroup` | Read/alter `BodiesList` etc. after import |
| `LittlePhysicsUserSystemGroup` | FixedStep (inner loop) | After internal collision, before velocity→position | Mid-step physics logic |
| `LittlePhysicsExportGroup` | Simulation (after FixedStep) | Before `LittlePhysicsInternalExportGroup` | Read structures before write-back |
| `LittlePhysicsExportGroup` | Simulation (after FixedStep) | After `LittlePhysicsInternalExportGroup` | Alter components after export |

- Schedule with `SimulationDataComponent.PhysicsJobHandle`
- Prefer `PhysicsStructuresComponent` data over component lookups inside the pipeline loop

### 8.2 Custom job interfaces

All parallel except `ILineCastJob`. Execute inside `LittlePhysicsUserSystemGroup` unless noted.

#### 8.2.1 IBodiesJob

`docs/guides/custom-jobs/ibodies-job/index.md`

Per physics body; parallel.

- `IBodiesJob.IRead`
- `IBodiesJob.IWrite`
- `IBodiesJob.IReadIndex`
- `IBodiesJob.IWriteIndex`
- Extensions: `IBodiesJobExtensions`, `IBodiesReadExtensions`, `IBodiesWriteExtensions`, `IBodiesReadIndexExtensions`, `IBodiesWriteIndexExtensions`

#### 8.2.2 ICollisionJob

`docs/guides/custom-jobs/icollision-job/index.md`

Per object-to-object collision slot; parallel.

- `ICollisionJob.IReadBody`
- `ICollisionJob.IWriteBody`
- `ICollisionJob.IReadBodies`
- `ICollisionJob.IWriteBodies`
- `ICollisionJob.IEntities`
- Extensions: `ICollisionJobExtensions`, `ICollisionReadBodyExtensions`, `ICollisionWriteBodyExtensions`, `ICollisionReadBodiesExtensions`, `ICollisionWriteBodiesExtensions`, `ICollisionEntitiesExtensions`

#### 8.2.3 ISurfaceJob

`docs/guides/custom-jobs/isurface-job/index.md`

Per body surface collision; parallel.

- `ISurfaceJob.IReadBody`
- `ISurfaceJob.IWriteBody`
- `ISurfaceJob.IEntity`
- Extensions: `ISurfaceJobExtensions`, `ISurfaceReadBodyExtensions`, `ISurfaceWriteBodyExtensions`, `ISurfaceEntityExtensions`

#### 8.2.4 ILineCastJob

`docs/guides/custom-jobs/ilinecast-job/index.md`

Line cast; **single helper thread**.

- `ILineCastJob.IReadBody`
- `ILineCastJob.IWriteBody`
- Extensions: `ILineCastJobExtensions`, `ILineCastReadBodyExtensions`, `ILineCastWriteBodyExtensions`
- Related types: `LineCastResult`, `CastFilter`, `LinecastIterator`, `TraverseLineIterator`, `AABBTraverseIterator`

### 8.3 Custom job interfaces

`docs/guides/custom-jobs/using-custom-job-interfaces/index.md`

- Code examples per interface (schedule + system attribute)
- Alternative: raw `IJob` / `IJobParallelFor` — see guidelines in doc.txt

### 8.4 Import workflow

`docs/guides/custom-jobs/import-workflow/index.md`

- `LittlePhysicsImportGroup` — before internal import: modify components; after: modify native structures
- Related jobs: `ImportPhysicsDataJob`, `ClearBodiesJob`

### 8.5 Export workflow

`docs/guides/custom-jobs/export-workflow/index.md`

- `LittlePhysicsExportGroup` — runs after all fixed-step physics
- Order relative to `LittlePhysicsInternalExportGroup` depending on components vs structures

### 8.6 Inside the pipeline

`docs/guides/custom-jobs/inside-the-pipeline/index.md`

- Use `LittlePhysicsUserSystemGroup` for mid-step logic
- Read/write via `PhysicsStructuresComponent`, not entity component lookups when possible

---

## 9 Builders

`docs/guides/builders/index.md`

Runtime/spawn helpers for creating bodies without scene authorings.

### 9.1 DynamicBodyBuilder

`docs/guides/builders/dynamic-body-builder/index.md`

- Build dynamic sphere bodies

### 9.2 KinematicBodyBuilder

`docs/guides/builders/kinematic-body-builder/index.md`

- Build kinematic bodies (sphere, capsule)

### 9.3 StaticBodyBuilder

`docs/guides/builders/static-body-builder/index.md`

- Build static bodies (sphere, capsule)

---

## 10 API Reference

`docs/api-reference/index.md` — generated from `public.txt` (every public type gets a page or grouped section).

### 10.1 Systems and system groups

| Type | Doc note |
|------|----------|
| `LittlePhysicsBootstrapSystem` | Internal — document in Pipeline only |
| `PairsDebugSystem` | Internal — document in Pairs debug window |
| `LittlePhysicsUserSystemGroup` | Public — Custom jobs §8.1 |
| `LittlePhysicsImportGroup` | Public — Custom jobs §8.1, §8.4 |
| `LittlePhysicsExportGroup` | Public — Custom jobs §8.1, §8.5 |

### 10.2 Authoring

- `DynamicBodyAuthoring`
- `KinematicBodyAuthoring` (+ nested `ColliderType`)
- `StaticBodyAuthoring` (+ nested `ColliderType`)
- `SurfaceBodyAuthoring` (+ nested `ColliderType`)
- `GravitySourceAuthoring`
- `PhysicsSettingsAuthoring`
- `PhysicsVelocityAuthoring`
- `SpacialMapAuthoring`

### 10.3 Components and ECS data

- `PhysicsBodyComponent`
- `PhysicsBodyUpdateComponent`
- `PhysicsVelocityComponent`
- `PhysicsReadyTag`
- `PhysicsFixedSettingsComponent`
- `PhysicsVariableSettingsComponent`
- `PhysicsSettingsBlobAsset`
- `EnvironmentSettings`
- `CollisionCheckSettings`
- `SpacialMapSettingsComponent`
- `PhysicsMapRandomComponent`
- `CollisionSurfaceComponent`
- `SphericalGravitySourceComponent`
- `DirectionalGravitySourceComponent`
- `PhysicsLodData`
- `PhysicsLodElement`
- `LittlePhysicsTimeComponent`
- `SimulationDataComponent`
- `PhysicsStructuresComponent`
- `CollisionMapSingleton`
- `CollisionsSingleton`
- `CameraData`

### 10.4 Body data and collision results

- `PhysicsBodyData`
- `RigidbodyData`
- `VelocityData`
- `PositionData`
- `CollisionData`
- `SurfaceCollisionData`
- `BodyCollisionResult`
- `IntersectionData`
- `LineCastResult`
- `CastFilter` (+ nested `BodyTypes`)
- `LinecastIterator`
- `TraverseLineIterator`
- `AABBTraverseIterator`

### 10.5 Builders

- `DynamicBodyBuilder`
- `KinematicBodyBuilder`
- `StaticBodyBuilder`

### 10.6 Shapes and geometry

- `Sphere`
- `Capsule`
- `SimpleBox`
- `SimplePlane`
- `InverseSphere`
- `SphericalCone`
- `Line`
- `AABB`
- `Grid3D`
- `SpacialMap`
- `Rectangle`
- `ListsArray<T>` (+ nested `Iterator`)

### 10.7 Job interfaces

- `IBodiesJob` (+ `IRead`, `IWrite`, `IReadIndex`, `IWriteIndex`)
- `ICollisionJob` (+ `IReadBody`, `IWriteBody`, `IReadBodies`, `IWriteBodies`, `IEntities`)
- `ISurfaceJob` (+ `IReadBody`, `IWriteBody`, `IEntity`)
- `ILineCastJob` (+ `IReadBody`, `IWriteBody`)

### 10.8 Enums

- `BodyType`
- `ColliderType`
- `ShapeType`
- `GravitySourceType`
- `PushOutType`

### 10.9 Utility classes

- `CollisionMethods` (+ nested shape helpers)
- `PhysicsCastExtensions`
- `SpacialMapExtensions`
- `MapExtensions`
- `Grid3DExtensions`
- `PhysicsSettingsExtensions`
- `PhysicsDebug`
- `LittlePhysicsPerformance`
- `PhysicsLodDataList`
- Job schedule helpers: `IBodies*Extensions`, `ICollision*Extensions`, `ISurface*Extensions`, `ILineCast*Extensions`
- Jobs: `ClearBodiesJob`, `ImportPhysicsDataJob`

### 10.10 Editor (public)

- `DynamicBodyEditor`
- `KinematicBodyEditor`
- `StaticBodyEditor`
- `SurfaceBodyEditor`
- `GravitySourceEditor`
- `SpacialMapEditor`
- `PhysicsSettingsAuthoringEditor`
- `PhysicsLodDataDrawer`
- `PhysicsLodDataListDrawer`
- `PhysicsLodDataDrawHelper`
- `LodDrawConfig`
- `EditorShapeDrawer`

---

## Nav order summary

| Order | Section | Primary source |
|------:|---------|----------------|
| 1 | Home | doc.txt (intro, features, limitations) |
| 2 | Getting Started | doc.txt (quick start, samples) |
| 3 | How it works | doc.txt §How it works |
| 4 | Pipeline | doc.txt + pipeline.pdf |
| 5 | Types of bodies | doc.txt §Types of bodies |
| 6 | Physics singleton | doc.txt §Physics Singleton, LOD, gravity, spatial map |
| 7 | Pairs debug window | doc.txt §PairsDebugWindow |
| 8 | Custom jobs | doc.txt §Custom job groups, §Custom jobs interfaces, import/export |
| 9 | Builders | doc.txt §builders, public.txt |
| 10 | API Reference | public.txt (full type list) |

---

## Naming notes (code overrides doc.txt)

| doc.txt / public.txt | Code (use in docs) |
|----------------------|-------------------|
| `LittlePhysicsUserImportGroup` | `LittlePhysicsImportGroup` |
| `LittlePhysicsUserExportGroup` | `LittlePhysicsExportGroup` |
| `SimulationDataComponent.BodiesCount` | `ActiveBodiesCount` |
| `PairsDebugWindow` | `CollisionPairsDebugWindow` (internal editor class) |
