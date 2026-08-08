---
title: Static
layout: default
parent: Settings
nav_order: 6
permalink: /docs/guides/settings/static/
description: Static rigid and trigger body types — sphere and capsule shapes.
tags: [static, trigger, body-type]
---

# Static

**Static** bodies represent fixed geometry: level collision, invisible blockers, and stationary trigger volumes. They never integrate velocity or respond to forces.

Add **`StaticBodyAuthoring`** in a subscene. Like kinematic bodies, statics support **rigid** and **trigger** modes via **`IsTrigger`**.

## Rigid vs trigger

| | **Rigid** (`IsTrigger = false`) | **Trigger** (`IsTrigger = true`) |
|---|-----------------------------------|-------------------------------------|
| Physical effect | Pushes **dynamic** bodies | None — overlap only |
| Spatial map | Added to the **static map once** after creation (`TimeElapsed = -1`) | Same one-time placement |
| Who initiates overlap tests | Dynamic and **kinematic** bodies during pair collection | Dynamic and **kinematic** bodies when they query the static map |
| Intersection targets | Dynamics (and kinematics in broad phase) | **Dynamic and kinematic** objects only — static bodies do not run pair collection, so static–static trigger pairs are not detected |
| Typical use | Walls, floors (when not using a surface), pillars | Stationary pickup zones, room bounds |

{: .note }
> Static triggers do **not** detect other static or trigger-only volumes on their own. A **kinematic trigger** that updates on an interval **can** overlap a static trigger when the kinematic body runs pair collection against the static map.

## Shape options

| Shape | Authoring enum |
|-------|----------------|
| **Sphere** | `ColliderType.Sphere` |
| **Capsule** | `ColliderType.Capsule` |

Use **`ColliderScale`** and **`ColliderLocalPosition`** like other body types.

## Scene view

When the GameObject is selected, the Scene view draws a wireframe sphere or capsule using the same rules as [kinematic bodies]({% link docs/guides/settings/kinematic/index.md %}#scene-view): **yellow** for rigid colliders, **blue** for triggers. Size and offset reflect **`ColliderScale`**, **`ColliderLocalPosition`**, and transform scale.

## What does not affect static bodies

- No gravity, friction integration, or velocity.
- **`PhysicsVelocityAuthoring`** logs a **warning** and is **ignored** on static authorings.
- Static entities are **not** tested against **surfaces** in the built-in surface collision pass (that job skips `body.IsStatic`).

For ground and large bounds, prefer [`SurfaceBodyAuthoring`]({% link docs/guides/settings/surface/index.md %}) when you need every dynamic body checked every substep without spatial-map cell limits.

## Authoring fields

| Field | Default | Role |
|-------|---------|------|
| `Collider` | Sphere | Sphere or capsule |
| `ColliderScale` | `1` | Collider size |
| `ColliderLocalPosition` | `(0,0,0)` | Local offset |
| `Bounciness` | `0` | Material when pushing dynamics |
| `Friction` | `0.5` | Material when pushing dynamics |
| `Hardness` | `1` | Push-out weight vs dynamics |
| `IsTrigger` | `false` | Rigid vs trigger mode |

## Map update behavior

On bake, static bodies receive `PhysicsBodyUpdateComponent` with **`TimeElapsed = -1`**. The collision map system treats that as **“insert once”**: the body’s AABB is written to **`StaticMap`** the first time it qualifies for update, then skipped on later substeps unless a kinematic/dynamic neighbor pulls it into pair tests from their side.

Dynamic and kinematic bodies **move** through the map each substep (or on trigger interval); statics **stay** in the cells where they were first placed.

## When to use static vs surface

| Use **static rigid** when… | Use **surface** when… |
|----------------------------|------------------------|
| Localized colliders inside the spatial map (posts, rocks, door frames) | A single large ground plane or world bound |
| You need capsule or sphere **push-out** against dynamics in specific cells | You need **guaranteed** dynamic-vs-ground tests every substep outside LOD pair budgets |

## Runtime creation

Use [`StaticBodyBuilder`]({% link docs/guides/builders/static-body-builder/index.md %}) with `.AsRigidBody(...)` or `.AsTrigger()` for runtime spawning.

## Related

- [Settings overview]({% link docs/guides/settings/index.md %})
- [Kinematic]({% link docs/guides/settings/kinematic/index.md %}) — moving colliders and moving triggers
- [Spatial map]({% link docs/guides/settings/spatial-map/index.md %}) — `StaticMap` cell layout
