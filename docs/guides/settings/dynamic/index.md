---
title: Dynamic
layout: default
parent: Settings
nav_order: 4
permalink: /docs/guides/settings/dynamic/
description: Dynamic body type — sphere only, affected by gravity, friction, surface, and collisions.
tags: [dynamic, body-type, sphere]
---

# Dynamic

A **dynamic** body is fully simulated: gravity, air and surface friction, push-out against other bodies, and contact with **surfaces** all apply each substep.

Use dynamic bodies for particles, debris, crowds, liquids, and any object that should move under forces rather than direct transform control.

## Shape constraint

Dynamic bodies are **spheres only**. The baker sets `ColliderType.Sphere` on `PhysicsBodyComponent`; there is no capsule or box option on `DynamicBodyAuthoring`.

Scale the sphere with **`ColliderScale`** and offset it with **`ColliderLocalPosition`** in local space.

## Scene view

When the GameObject is selected, a **yellow wireframe sphere** is drawn in the Scene view at the collider center (transform position plus **`ColliderLocalPosition`**) with radius **`ColliderScale`** × transform **`lossyScale.x`**. Adjust scale and offset in the Inspector and the gizmo updates immediately.

## What affects a dynamic body

| Effect | Applied |
|--------|---------|
| Directional or radial **gravity** (`GravitySourceAuthoring`) | Yes |
| **Air friction** (global settings) | Yes |
| **Surface friction** when on a surface | Yes |
| **Object-to-object** collision and push-out | Yes, inside the [spatial map]({% link docs/how-it-works/index.md %}#spatial-map) |
| **Surface** collision | Yes — **every substep**, independent of LOD or map cell |

{: .note }
> Pairwise collisions require the body to lie inside the volume defined by **`SpacialMapAuthoring`**. Outside the map, dynamics still fall and slide on surfaces, but do not collide with other objects.

## Authoring

Add **`DynamicBodyAuthoring`** to a GameObject in a subscene.

| Field | Default | Role |
|-------|---------|------|
| `ColliderScale` | `1` | Sphere radius scale |
| `ColliderLocalPosition` | `(0,0,0)` | Collider offset in local space |
| `Mass` | `1` | Used in impulse and push-out weighting |
| `Bounciness` | `0` | Restitution on contact |
| `Friction` | `0.5` | Material friction |
| `Hardness` | `1` | Push-out weight vs other bodies |
| `ShouldRotateOnCollision` | `true` | Whether angular velocity changes on impact |

The GameObject **layer** is copied to the baked entity for collision filtering.

### Initial velocity

To set a starting linear or angular velocity, add **`PhysicsVelocityAuthoring`** on the **same** GameObject. The dynamic baker reads `StartLinear` and `StartAngular` at bake time.

{: .warning }
> **`PhysicsVelocityAuthoring` is only valid on dynamic bodies.** Other body types log a warning and ignore velocity.

## Runtime data

After import, dynamic bodies appear in [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}) with `BodyType.Dynamic`. Collision results for the current substep are written to [`CollisionDataMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}); surface contact is in [`SurfaceCollisionMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}).

Custom mid-step logic can read or modify dynamic bodies through [`IBodiesJob`]({% link docs/guides/custom-jobs/ibodies-job/index.md %}) in `LittlePhysicsUserSystemGroup`.

## Runtime creation

Spawn dynamics at runtime with [`DynamicBodyBuilder`]({% link docs/guides/builders/dynamic-body-builder/index.md %}) instead of an authoring component.

## Related

- [Settings overview]({% link docs/guides/settings/index.md %})
- [Getting Started — add physics bodies]({% link docs/getting-started/index.md %}#6-add-physics-bodies)
- [Kinematic]({% link docs/guides/settings/kinematic/index.md %}) — bodies you move manually that push dynamics
