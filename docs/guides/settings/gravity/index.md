---
title: Gravity
layout: default
parent: Settings
nav_order: 3
permalink: /docs/guides/settings/gravity/
description: Directional and spherical gravity sources with GravitySourceAuthoring.
tags: [gravity, authoring, dynamic-bodies]
---

# Gravity

Little Physics applies gravity to **dynamic bodies only** during each fixed substep. Kinematic, static, and surface bodies are unaffected.

Add **`GravitySourceAuthoring`** to a GameObject in your subscene and choose **directional** or **spherical** mode. Baking produces an ECS component consumed by **`GravitySystem`** — the first system in the inner physics loop, before friction and spatial-map updates.

## GravitySourceAuthoring

| Field | Type | Default | Used when |
|-------|------|---------|-----------|
| `SourceType` | `GravitySourceType` | — | **Directional** or **Spherical** |
| `Strength` | `float` | `9.81` | **Directional** — acceleration magnitude along the gravity direction |
| `SurfaceGravity` | `float` | `9.81` | **Spherical** — gravity magnitude at the surface radius |

The custom Inspector shows **`Strength`** or **`SurfaceGravity`** depending on **`SourceType`**. Scene gizmos draw a **direction arrow** (directional) or a **sphere** (spherical) to preview the field.

### Directional gravity

**`GravitySourceType.Directional`** bakes **`DirectionalGravitySourceComponent`**:

| Baked field | Source |
|-------------|--------|
| `Direction` | **`−transform.up`** (normalized pull along the object’s “down”) |
| `Strength` | **`Strength`** |

Each substep, dynamic bodies receive:

```
velocity += Direction × Strength × DeltaTime
```

Rotate the GameObject to aim gravity. The Scene view arrow points in the pull direction.

### Spherical gravity

**`GravitySourceType.Spherical`** bakes **`SphericalGravitySourceComponent`**:

| Baked field | Source |
|-------------|--------|
| `Center` | **`transform.position`** at bake time |
| `Radius` | **`transform.localScale.x / 2`** |
| `SurfaceGravity` | **`SurfaceGravity`** |

Force points toward **`Center`** and falls off with distance squared — similar to planetary gravity:

```
gravityMagnitude = SurfaceGravity × (Radius² / distance²)
velocity += directionToCenter × gravityMagnitude × DeltaTime
```

The Scene gizmo draws a sphere using **world scale** on X. **`SurfaceGravity`** is the magnitude **at `Radius`**; it increases as bodies move closer to the center.

Use spherical mode for planets, attractors, or radial wells. Sample **Scene1_Planet** (package samples) demonstrates a spherical setup.

## Setup

1. Add **`GravitySourceAuthoring`** to a GameObject in the subscene.
2. Choose **`SourceType`**.
3. For directional: orient the transform so **`−up`** points the way objects should fall; set **`Strength`** (m/s² style acceleration).
4. For spherical: place the object at the attractor center; set **`localScale.x`** to the desired diameter; tune **`SurfaceGravity`**.
5. Bake the subscene.

Gravity is optional — omit the authoring component for zero-G tests. Most scenes include at least one source.

## Important constraints

| Topic | Detail |
|-------|--------|
| **Body types** | Only **dynamic** bodies receive gravity |
| **Baked values** | **`Center`**, **`Radius`**, and **`Direction`** are captured at **bake** time. Moving or scaling the GameObject at runtime does not update the ECS components until you rebake |
| **Singleton components** | Each gravity mode uses **`IComponentData`** singletons. Bake **at most one** directional and **at most one** spherical source — multiple baked entities of the same type can break singleton access |
| **Map boundary** | Gravity applies **inside and outside** the [spatial map]({% link docs/guides/settings/spatial-map/index.md %}) |
| **LOD** | Gravity is **not** reduced by LOD tier |

Custom systems in **`LittlePhysicsUserSystemGroup`** run **after** gravity and friction. To apply forces before integration, schedule in that group or modify **`BodiesList`** velocity during import/export workflows.

## Runtime components

These types are public for queries and tooling; they are normally authored through **`GravitySourceAuthoring`**:

| Component | Fields |
|-----------|--------|
| **`DirectionalGravitySourceComponent`** | `float3 Direction`, `float Strength` |
| **`SphericalGravitySourceComponent`** | `float3 Center`, `float SurfaceGravity`, `float Radius` |

```csharp
if (SystemAPI.HasSingleton<DirectionalGravitySourceComponent>())
{
    var source = SystemAPI.GetSingleton<DirectionalGravitySourceComponent>();
    // source.Direction, source.Strength
}
```

There is no built-in runtime API to retarget gravity after bake. For moving attractors, update **`BodiesList`** velocities in a custom job or rebake the subscene.

## Related

- [Settings — Dynamic]({% link docs/guides/settings/dynamic/index.md %}) — the only body type affected by gravity
- [LittlePhysicsTimeComponent]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) — **`DeltaTime`** used in gravity integration
- [Pipeline — Fixed update]({% link docs/pipeline/index.md %}#fixed-update--inner-loop) — gravity runs first in the inner loop
- [Getting Started]({% link docs/getting-started/index.md %}) — add gravity in a minimal scene
