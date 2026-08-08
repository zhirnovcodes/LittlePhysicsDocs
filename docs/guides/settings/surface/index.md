---
title: Surface
layout: default
parent: Settings
nav_order: 7
permalink: /docs/guides/settings/surface/
description: Surface body type — collides with all dynamic bodies every frame.
tags: [surface, body-type, plane, box]
---

# Surface

A **surface** is not a `PhysicsBodyComponent` body type — it is a separate **`CollisionSurfaceComponent`** baked from **`SurfaceBodyAuthoring`**. Surfaces represent large collision geometry: floors, walls, planet shells, and invisible bounds.

The internal **surface collision** pass runs **every substep** for **every imported non-static body** against the scene surface, **independent of LOD** and **independent of spatial map cells**. Dynamic bodies receive full contact response (impulses and push-out). **Kinematic** bodies — including triggers — receive **intersection data** without physical push-out.

## Shape options

| Authoring `Collider` | Simulation shape | Notes |
|----------------------|------------------|-------|
| **SimplePlane** | Infinite plane | Common for flat ground; orientation follows transform |
| **SimpleBox** | Axis-aligned box | **`ShapeData`** uses the authoring transform **`lossyScale`** |
| **Sphere** | Sphere | Sized from transform |
| **ReverseSphere** | Inverted sphere | Useful for enclosing volumes (planet interior, dome) |

Surfaces do not use `ColliderScale` / `ColliderLocalPosition` the same way as sphere bodies — geometry comes from the shape type and transform.

## Scene view

When the GameObject is selected, a **yellow wireframe** shows the active surface shape in the Scene view:

| `Collider` | Gizmo |
|------------|-------|
| **SimplePlane** | Grid on the horizontal plane at the transform height |
| **SimpleBox** | Box outline from transform position and **`lossyScale`** |
| **Sphere** / **ReverseSphere** | Sphere from transform position and **`lossyScale.x`** |

Switching **`Collider`** or moving/scaling the transform updates the preview immediately.

## Authoring fields

| Field | Default | Role |
|-------|---------|------|
| `Collider` | Sphere | Shape kind (see table above) |
| `Bounciness` | `0.5` | Restitution for dynamic contacts |
| `Friction` | `0.5` | Surface friction (also used when dynamics slide on the surface) |
| `Hardness` | `1` | Push-out weight |
| `AngularDrag` | `0` | Angular damping applied through surface friction path |

The GameObject **layer** participates in collision filtering via `PhysicsFixedSettingsComponent` layer masks.

{: .warning }
> **Do not** add **`PhysicsVelocityAuthoring`** to surface bodies. Velocity is not supported; Unity logs a warning if you attach it.

## One surface singleton in the built-in pass

The package’s **`SurfaceCollisionSystem`** reads a single **`CollisionSurfaceComponent`** via `GetSingletonEntity`. The shipped samples use **one** `SurfaceBodyAuthoring` per scene.

If you bake **multiple** surface entities, ECS singleton access is undefined — prefer **one** primary surface for automatic ground/world collision, and use **static** or **kinematic** colliders inside the spatial map for additional localized geometry.

## Dynamic vs kinematic on surfaces

| Body | Surface behavior |
|------|------------------|
| **Dynamic** | Full resolution — velocity changes, push-out, friction via [`SurfaceCollisionMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) |
| **Kinematic rigid** | Intersection recorded; no impulse (neither body is dynamic in the impulse path) |
| **Kinematic trigger** | Intersection recorded for gameplay queries |
| **Static** | Skipped by the surface collision job |

Surfaces therefore complement the spatial map: dynamics **always** hit the ground even when pairwise budgets are tight or the body is outside map cells (gravity and surface still apply).

## Custom surface logic

React to surface contacts in `LittlePhysicsUserSystemGroup` with [`ISurfaceJob`]({% link docs/guides/custom-jobs/isurface-job/index.md %}), which iterates [`SurfaceCollisionMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) entries from the current substep.

## Setup

1. Add **`SurfaceBodyAuthoring`** to a GameObject in the subscene.
2. Choose a shape ( **`SimplePlane`** is the usual ground test ).
3. Position and rotate the transform so the surface faces the play area.
4. Bake and play — dynamics should collide even before you add object-to-object colliders.

See [Getting Started — add a surface]({% link docs/getting-started/index.md %}#5-add-a-surface).

## Related

- [Settings overview]({% link docs/guides/settings/index.md %})
- [Dynamic]({% link docs/guides/settings/dynamic/index.md %}) — primary consumers of surface response
- [How it works — fixed update]({% link docs/how-it-works/index.md %}#fixed-update--timescale-and-substeps) — surface step runs inside each substep loop
