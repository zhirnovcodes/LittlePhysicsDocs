---
title: ILineCastJob
layout: default
parent: Custom jobs
nav_order: 5
permalink: /docs/guides/custom-jobs/ilinecast-job/
description: Line cast custom job interface — single helper thread.
tags: [custom-jobs, ilinecast-job, linecast]
---

# ILineCastJob

Single-threaded linecast callbacks against bodies registered in the [spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %})). Unlike the other package job interfaces, **`ILineCastJob`** schedules as **`ScheduleMode.Single`** — one worker thread per invocation.

Schedule inside **`LittlePhysicsUserSystemGroup`** so broad-phase maps and **`BodiesList`** reflect the current substep.

## Nested interfaces

| Interface | `Execute` signature | Access |
|-----------|---------------------|--------|
| **`ILineCastJob`** (base) | `Execute(in LineCastResult result)` | Hit result only |
| **`ILineCastJob.IReadBody`** | `Execute(in PhysicsBodyData body, in LineCastResult result)` | Hit body read-only |
| **`ILineCastJob.IWriteBody`** | `Execute(ref PhysicsBodyData body, in LineCastResult result)` | Hit body read-write |

Extension classes: **`ILineCastJobExtensions`**, **`ILineCastReadBodyExtensions`**, **`ILineCastWriteBodyExtensions`**.

## Cast parameters

Scheduling requires more arguments than the body/collision interfaces:

| Parameter | Type | Role |
|-----------|------|------|
| **`structures`** | **`PhysicsStructuresComponent`** | **`BodiesList`**, **`EntitiesMap`**, **`CollisionMap`** |
| **`variableSettings`** | **`PhysicsVariableSettingsComponent`** | **`SpacialMap`** bounds and grid |
| **`simulation`** | **`SimulationDataComponent`** | Job handle chaining |
| **`line`** | **`Line`** | Origin (**`Position`**) and segment vector (**`Direction`** — not necessarily normalized) |
| **`filter`** | **`CastFilter`** | Body-type flags and layer mask |

### Line

```csharp
public struct Line
{
    public float3 Position;   // segment start
    public float3 Direction;  // segment end offset (Position + Direction = end)
}
```

### CastFilter

```csharp
public struct CastFilter
{
    public BodyTypes Types;  // Dynamic, Static, Trigger, Kinematic flags
    public LayerMask Layer;

    public static CastFilter Default => ...;  // dynamic bodies, all layers
    public static CastFilter All => ...;      // all body types, all layers
}
```

### LineCastResult

| Field | Description |
|-------|-------------|
| **`Target`** | Hit entity |
| **`BodyIndex`** | Index in **`BodiesList`** |
| **`Contact`** | World-space hit point |

## Schedule overloads

Two scheduling modes exist for each nested interface:

| Overload | Behavior |
|----------|----------|
| **`Schedule(..., line, filter, deps)`** | **`LineCastFirst`** — stops at the first hit; one **`Execute`** call |
| **`Schedule(..., line, filter, ref results, deps)`** | **`LineCast`** — collects all hits into **`NativeList<LineCastResult>`**; **`Execute`** per hit |

**`ScheduleAndChain`** mirrors both overloads and updates **`PhysicsJobHandle`**.

## Example — impulse on click

From **Scene 5 — Linecast**. Casts along a camera ray and applies an impulse to the first hit dynamic body:

```csharp
[UpdateInGroup(typeof(LittlePhysicsUserSystemGroup))]
public partial struct LineCastSystem : ISystem
{
    public void OnCreate(ref SystemState state)
    {
        state.RequireForUpdate<PhysicsReadyTag>();
        state.RequireForUpdate<LineCastComponent>();
    }

    public void OnUpdate(ref SystemState state)
    {
        var config = SystemAPI.GetSingleton<LineCastComponent>();

        if (!config.IsClickedThisFrame)
        {
            return;
        }

        float3 castDirection = math.normalizesafe(config.RayDirection);
        var line = new Line
        {
            Position = config.RayOrigin,
            Direction = castDirection * config.LineLength,
        };

        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        var variableSettings = SystemAPI.GetSingleton<PhysicsVariableSettingsComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

        new LineCastJob
        {
            CastDirection = castDirection,
            Force = config.Force,
        }.ScheduleAndChain(
            ref state, in structures, in variableSettings, ref simulation, line, config.Filter);
    }

    [BurstCompile]
    private struct LineCastJob : ILineCastJob.IWriteBody
    {
        public float3 CastDirection;
        public float Force;

        public void Execute(ref PhysicsBodyData body, in LineCastResult result)
        {
            var velocity = body.VelocityData;
            velocity.Linear += CastDirection * Force;
            body.VelocityData = velocity;
        }
    }
}
```

Input for the ray is gathered in **`LineCastInputSystem`**, which runs in **`LittlePhysicsImportGroup`** — see [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}).

## Example — all hits

Collect every intersection along the segment:

```csharp
var results = new NativeList<LineCastResult>(Allocator.TempJob);

new LogAllHitsJob()
    .ScheduleAndChain(
        ref state, in structures, ref variableSettings, ref simulation,
        line, CastFilter.All, ref results);

// Dispose results after the system's Dependency completes
state.Dependency = results.Dispose(state.Dependency);
```

## Broad-phase source

Linecasts traverse [`CollisionMapSingleton`]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — **`DynamicMap`** and **`StaticMap`** — using the same grid as object-to-object broad phase. Bodies outside the spatial map are not considered.

For manual queries without the job interface, call **`PhysicsStructuresComponent.LineCast`** / **`LineCastFirst`** extension methods directly (same underlying implementation).

## When to use

| Use **`ILineCastJob`** | Consider instead |
|------------------------|------------------|
| Click-to-push, weapon rays, AI line-of-sight | **`ICollisionJob`** for contacts already detected this substep |
| First-hit or all-hit segment queries | **`IBodiesJob`** for per-body logic unrelated to casts |

## Related

- [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — maps used by linecast broad phase
- [Spatial map]({% link docs/guides/physics-singleton/spatial-map/index.md %}) — grid bounds and cell helpers
- [Import workflow]({% link docs/guides/custom-jobs/import-workflow/index.md %}) — **`LineCastInputSystem`** pattern
