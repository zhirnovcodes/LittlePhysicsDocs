---
title: Settings
layout: default
nav_order: 5
has_children: true
permalink: /docs/guides/settings/
description: Physics settings, LOD, spatial map, gravity, and body types.
tags: [guides, settings, lod, spatial-map, gravity, body-types]
---

# Settings

This section covers the authoring you configure once per scene — simulation limits and LOD, the spatial map volume, gravity sources — plus the **body types** you place in that setup.

All of these use **authoring** components on GameObjects inside a **subscene**, then bake into ECS entities. See [Getting Started]({% link docs/getting-started/index.md %}) for the setup workflow.

## Pages in this section

| Page | Covers |
|------|--------|
| [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}) | `PhysicsSettingsAuthoring`, capacity limits, LOD tiers, push-out |
| [Spatial map]({% link docs/guides/settings/spatial-map/index.md %}) | `SpacialMapAuthoring`, grid bounds, object-to-object collision region |
| [Gravity]({% link docs/guides/settings/gravity/index.md %}) | Directional and spherical `GravitySourceAuthoring` |
| [Dynamic]({% link docs/guides/settings/dynamic/index.md %}) | Simulated spheres — gravity, friction, collisions, surfaces |
| [Kinematic]({% link docs/guides/settings/kinematic/index.md %}) | Rigid movers and triggers on an update interval |
| [Static]({% link docs/guides/settings/static/index.md %}) | Fixed colliders and triggers baked into the map once |
| [Surface]({% link docs/guides/settings/surface/index.md %}) | Ground, walls, and bounds that all dynamics hit every frame |

## Body types at a glance

| Type | Authoring | Shapes | Affected by gravity & friction | Object-to-object collisions | Surface collision |
|------|-----------|--------|--------------------------------|----------------------------|-------------------|
| **Dynamic** | `DynamicBodyAuthoring` | Sphere only | Yes | Yes (inside spatial map) | Yes (every substep) |
| **Kinematic rigid** | `KinematicBodyAuthoring` (`IsTrigger = false`) | Sphere, capsule | No | Pushes dynamics; updated in map each substep | Intersection only (no impulse) |
| **Kinematic trigger** | `KinematicBodyAuthoring` (`IsTrigger = true`) | Sphere, capsule | No | Intersection checks on `UpdateInterval` | Intersection only |
| **Static rigid** | `StaticBodyAuthoring` (`IsTrigger = false`) | Sphere, capsule | No | Pushes dynamics; added to map once | No |
| **Static trigger** | `StaticBodyAuthoring` (`IsTrigger = true`) | Sphere, capsule | No | Intersection checks when dynamics/kinematics pair against it | No |
| **Surface** | `SurfaceBodyAuthoring` | Sphere, plane, box, reverse sphere | No | No | Collides **all** non-static bodies each substep |

{: .note }
> **Dynamic bodies are spheres only.** Kinematic and static bodies support **sphere** and **capsule**. Surfaces use specialized shapes (plane, box, reverse sphere, etc.). See [known limitations on the home page]({% link index.md %}#known-limitations).

## Scene view

Every body authoring draws its **collider shape as a wireframe** in the Unity **Scene view** when the GameObject is selected. The preview updates live as you change **`ColliderScale`**, **`ColliderLocalPosition`**, **`Collider`**, transform scale, and other Inspector fields — so you can align colliders with meshes without entering Play mode.

| Body kind | Wireframe color |
|-----------|-----------------|
| Rigid (dynamic, kinematic rigid, static rigid, surface) | Yellow |
| Trigger (kinematic or static) | Blue |

Surfaces draw the active shape (plane grid, box cage, or sphere) from the transform. Individual pages below describe shape-specific gizmo behavior.

## Rigid vs trigger

Every kinematic and static body is either **rigid** or **trigger**, controlled by **`IsTrigger`** on the authoring component.

| | **Rigid** | **Trigger** |
|---|-----------|-------------|
| Physical response | Applies push-out and velocity changes to **dynamic** bodies | None — overlap is recorded as intersection data only |
| Forces | Rigid kinematic/static bodies are not driven by gravity or collision impulses | Same |
| Typical use | Moving platforms, doors, fixed walls | Pickup zones, proximity checks, gameplay events |

Triggers still participate in **pair collection** and **`CollisionData`** slots when overlaps occur. Read results in custom systems via [`ICollisionJob`]({% link docs/guides/custom-jobs/icollision-job/index.md %}) or inspect [`CollisionsSingleton`]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}).

## Spatial map vs surface

Two separate collision paths exist:

- **Object-to-object** — dynamic and kinematic bodies inside the volume defined by [`SpacialMapAuthoring`]({% link docs/getting-started/index.md %}#3-define-the-spatial-map) are inserted into grid cells and tested against neighbors. **Outside the map**, bodies still get gravity and surface contact, but **not** pairwise object collisions.
- **Surface** — every **dynamic** body is tested against the scene surface **every substep**, regardless of LOD or map cell. **Kinematic** bodies (including triggers) also get surface **intersection** tests; triggers receive contact data without physical push-out.

For map internals, see [Spatial map]({% link docs/guides/settings/spatial-map/index.md %}) and [How it works]({% link docs/how-it-works/index.md %}#spatial-map).

## Body count limit

Import respects **`MaxEntitiesCount`** on `PhysicsSettingsAuthoring`. Bodies beyond the cap are **ignored** for the simulation. Plan capacity when spawning large crowds.

## What to read next

| Topic | Page |
|-------|------|
| First scene setup | [Getting Started]({% link docs/getting-started/index.md %}) |
| Import, fixed step, LOD | [How it works]({% link docs/how-it-works/index.md %}) |
| Runtime spawning | [Builders]({% link docs/guides/builders/index.md %}) |
| React to collisions and triggers | [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) |
