---
title: Kinematic
layout: default
parent: Types of bodies
nav_order: 2
permalink: /docs/guides/types-of-bodies/kinematic/
description: Kinematic rigid and trigger body types — sphere and capsule shapes.
tags: [kinematic, trigger, body-type]
---

# Kinematic

**Kinematic** bodies move under your control (transforms, scripts, or animation). They are **not** driven by gravity, friction impulses, or simulation velocity integration — but they **can** affect the world in two different ways depending on **`IsTrigger`**.

Add **`KinematicBodyAuthoring`** in a subscene and choose **rigid** or **trigger** mode in the Inspector.

## Rigid vs trigger

| | **Rigid** (`IsTrigger = false`) | **Trigger** (`IsTrigger = true`) |
|---|-----------------------------------|-------------------------------------|
| Physical effect | Pushes **dynamic** bodies out of the way | None — overlap only |
| Spatial map | Inserted into the **dynamic map every substep** | Inserted on **`UpdateInterval`** (default `1` second) |
| Intersection targets | Dynamics and other bodies in pair collection | Dynamic, kinematic, static, and other triggers |
| Typical use | Moving platforms, animated obstacles | Overlap zones, proximity gameplay |

For triggers, set **`UpdateInterval`** to control how often the body refreshes its map cells and runs intersection tests. An interval of **`0`** fires every substep (same cadence as rigid, but still without physical response).

## Shape options

Kinematic bodies support:

| Shape | Authoring enum | Notes |
|-------|----------------|-------|
| **Sphere** | `ColliderType.Sphere` | Uniform scale via `ColliderScale` |
| **Capsule** | `ColliderType.Capsule` | Uses transform scale for capsule geometry |

Offset the collider with **`ColliderLocalPosition`**.

## Scene view

When the GameObject is selected, the Scene view draws a wireframe matching the chosen shape:

| Mode | Color | Shape |
|------|-------|-------|
| Rigid (`IsTrigger = false`) | Yellow | Sphere or capsule from **`Collider`**, **`ColliderScale`**, **`ColliderLocalPosition`**, and transform scale |
| Trigger (`IsTrigger = true`) | Blue | Same geometry as rigid — color indicates trigger mode |

The preview follows the authoring transform (not **`Main`**) and updates as you edit Inspector fields.

## What does not affect kinematic bodies

- Gravity and global air friction do not move kinematics.
- Collision **impulses** do not change kinematic velocity — there is no `PhysicsVelocityComponent` on baked kinematic entities.
- **`PhysicsVelocityAuthoring`** on the same GameObject logs a **warning** and is **ignored**.

Move kinematics by updating the entity transform (or the **`Main`** transform — see below) from your systems or gameplay code.

## Main transform

**`Main`** optionally references another GameObject whose transform drives the collider pose. When **`Main`** is null, the authoring object's own transform is used.

Use **`Main`** when the physics entity sits on a child object but should follow a parent rig or animated root.

## Authoring fields

| Field | Default | Role |
|-------|---------|------|
| `Collider` | Sphere | Sphere or capsule |
| `ColliderScale` | `1` | Collider size |
| `ColliderLocalPosition` | `(0,0,0)` | Local offset |
| `Bounciness` | `0.5` | Material when pushing dynamics |
| `Friction` | `0.5` | Material when pushing dynamics |
| `Hardness` | `0.5` | Push-out weight vs dynamics |
| `IsTrigger` | `false` | Rigid vs trigger mode |
| `UpdateInterval` | `1` | Trigger refresh period (seconds); ignored when rigid |

## Surface contact

The internal **surface collision** step tests **non-static** bodies against the scene surface. Kinematic bodies — including triggers — receive **intersection data** in [`SurfaceCollisionMap`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) when overlapping a surface, but **triggers are not pushed** out (no impulse path in `ResolvePair` when either body is a trigger or neither is dynamic).

## Reading trigger overlaps

When a kinematic trigger overlaps another body, collision slots contain contact geometry (`ContactPoint`, `Normal`, `PenetrationDepth`) without velocity changes. Handle these in:

- [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) — per-pair callbacks in `LittlePhysicsUserSystemGroup`
- Sample **Scene4_Trigger** (import via Package Manager samples) for a trigger-attraction example

## Runtime creation

Use [`KinematicBodyBuilder`]({% link docs/guides/builders/kinematic-body-builder/index.md %}) with `.AsRigidBody(...)` or `.AsTrigger(updateInterval)` for runtime spawning.

## Related

- [Types of bodies overview]({% link docs/guides/types-of-bodies/index.md %})
- [Static]({% link docs/guides/types-of-bodies/static/index.md %}) — fixed counterparts to kinematic colliders
- [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) — react to trigger intersections
