---
title: Getting Started
layout: default
nav_order: 2
permalink: /docs/getting-started/
description: Install Little Physics, set up a subscene with authorings, and run your first simulation.
tags: [getting-started, install, subscene, authoring]
---

# Getting Started

Little Physics is an **ECS** package: you add **authoring** components to GameObjects in a **subscene**, Unity **bakes** them into entities at build time, and the simulation runs in the Entities fixed-step pipeline. This page walks through install and a minimal scene setup.

## Requirements

Before you install, confirm your project meets these dependencies:

| Requirement | Version / notes |
|-------------|-----------------|
| Unity | **6000.0+** (Unity 6). Not compatible with Unity 2022. |
| Entities | `com.unity.entities` **1.4.8** (installed automatically with the package) |
| Input System | `com.unity.inputsystem` 1.19.0 (package dependency) |
| Namespace | `LittlePhysics` |

**Samples** (optional) require **Entities.Graphics**. Unity shows a popup to install it after you import samples from the Package Manager.

## Install

1. Open your Unity 6 project.
2. Download **Little Physics** from the [Asset Store]({{ site.aux_links["Asset Store"] | first }}).
3. Go to **Window → Package Manager** → **My Assets**, find **Little Physics**, and click **Import** / **Download**.
4. Wait for Unity to resolve dependencies (`com.unity.entities`, `com.unity.inputsystem`).

After import, authoring components appear under **Add Component** when you search for `Little Physics` or the type names below.

## Quick start

These steps create a minimal simulation: global settings, a spatial map, gravity, a surface, and at least one physics body.

### 1. Create a scene and subscene

1. Create or open a Unity scene.
2. Add a **Sub Scene** (Entities) and open it for editing.
3. Work inside the subscene for all following steps.

### 2. Add global physics settings

Create an empty GameObject and add **`PhysicsSettingsAuthoring`**.

This component defines simulation-wide limits: maximum body count, air friction, push-out behavior, substeps (1–4 per fixed update), collision check flags, and LOD tiers. Defaults are suitable for a small test (`MaxEntitiesCount` = 10,000, `SubstepsCount` = 1).

You need **one** `PhysicsSettingsAuthoring` in the baked world. Without it, bootstrap does not run.

### 3. Define the spatial map

Create another GameObject and add **`SpacialMapAuthoring`**.

The spatial map is the volume where **object-to-object** collisions are simulated. Configure:

| Field | Role |
|-------|------|
| `CellWidth` | Width of each grid cell (default `1`) |
| `GridSize` | Map dimensions in cells (default `16×16×16`) |
| `ShouldDrawInEditor` | Toggle on to visualize the grid in the Scene view |

Position the GameObject so the map covers your play area. The map is centered on the transform: world bounds extend from the object position minus half the total size.

Bodies **outside** the map still receive gravity and **surface** collision, but not pairwise object collisions.

### 4. Add gravity (optional)

If you want gravity, add **`GravitySourceAuthoring`** to a GameObject and choose a mode:

| `SourceType` | Behavior |
|--------------|----------|
| **Directional** | Pulls along the object’s **down** direction (`transform.up` inverted). Use **`Strength`**. |
| **Spherical** | Pulls toward a sphere centered on the object. **`SurfaceGravity`** at the surface radius; sphere **radius** comes from **`transform.localScale.x / 2`**. |

You can omit gravity for a zero-G test, but most scenes need at least one source.

### 5. Add a surface

Add **`SurfaceBodyAuthoring`** and pick a collider. Dynamic bodies are tested against surfaces every frame — you need at least one for a typical ground-or-walls setup:

- **SimplePlane** — flat ground (common for first tests)
- **SimpleBox** — box volume (uses transform scale)
- **Sphere** / **ReverseSphere** — spherical bounds

Every dynamic body is tested against surfaces **each frame**, regardless of LOD or spatial map cells.

{: .warning }
> **Do not** add `PhysicsVelocityAuthoring` to surface bodies. Velocity is ignored on surfaces; Unity logs a warning if you do.

### 6. Add physics bodies

Add one or more objects with body authorings. All dynamic bodies are **spheres**; kinematic and static bodies support **sphere** and **capsule**.

| Authoring | Use for |
|-----------|---------|
| **`DynamicBodyAuthoring`** | Bodies affected by gravity, friction, collisions, and surfaces |
| **`KinematicBodyAuthoring`** | Moves under your control; pushes dynamic bodies; not driven by forces |
| **`StaticBodyAuthoring`** | Fixed colliders that push dynamics; baked into the map once |

Set **`ColliderScale`** (and capsule height where applicable) to match your visuals. Use the GameObject **layer** for collision filtering where needed.

#### Initial velocity (dynamic only)

To give a dynamic body a starting velocity, add **`PhysicsVelocityAuthoring`** on the **same** GameObject as `DynamicBodyAuthoring`. Set **`StartLinear`** and **`StartAngular`**. This component is only meaningful on dynamic bodies.

### 7. Bake and play

1. Save the subscene.
2. Enter **Play** mode.
3. The bootstrap system creates native buffers and settings; import systems gather bodies; the fixed-step loop runs gravity, map fill, collisions, surfaces, then export writes positions back to transforms.

If nothing moves, check that:

- Authorings are inside a **baked subscene**
- **`SpacialMapAuthoring`** covers your bodies (for object-to-object contact)
- A **`SurfaceBodyAuthoring`** or other colliders exist where you expect contact
- **`MaxEntitiesCount`** in `PhysicsSettingsAuthoring` is not exceeded (excess entities are ignored)

## Import samples

The package ships **five demo scenes** covering different features:

1. **Window → Package Manager** → **Little Physics** → **Samples** → **Import** next to **All Samples**.
2. If prompted, install **Entities.Graphics**.
3. Open scenes under the imported samples folder. They show planet gravity, planes, pachinko, triggers, and linecast jobs.

Samples are the fastest way to see LOD, spawning, triggers, and custom jobs in a complete project.

## What to read next

| Topic | Page |
|-------|------|
| Body types, triggers, and shapes | [Types of bodies]({% link docs/guides/types-of-bodies/index.md %}) |
| Bootstrap, import, fixed step, export | [How it works]({% link docs/how-it-works/index.md %}) |
| System groups and custom hook points | [Pipeline]({% link docs/pipeline/index.md %}) |
| Shared native data and singleton components | [Physics singleton]({% link docs/guides/physics-singleton/index.md %}) |
| Custom logic in the simulation step | [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) |
| Runtime body creation | [Builders]({% link docs/guides/builders/index.md %}) |

For a high-level product overview and limitation list, see the [home page]({% link index.md %}).
