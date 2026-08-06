---
title: Import workflow
layout: default
parent: Custom jobs
nav_order: 7
permalink: /docs/guides/custom-jobs/import-workflow/
description: LittlePhysicsImportGroup — before and after internal import.
---

# Import workflow

Import is the handoff from baked ECS components to native simulation memory. It runs once per frame in **`LateSimulationSystemGroup`**, **before** the fixed-step physics loop.

## What internal import does

**`LittlePhysicsInternalImportGroup`** runs two systems:

| System | Role |
|--------|------|
| **`PhysicsStepSystem`** | Updates **`PhysicsStepComponent`** with main-camera position, forward, and projection for LOD tier selection |
| **`ImportPhysicsDataSystem`** | Counts qualifying entities, clears **`BodiesList`**, copies component data into native buffers, fills **`EntitiesMap`**, sets **`ActiveBodiesCount`** |

Qualifying entities need **`LocalToWorld`**, **`PhysicsBodyComponent`**, and **`PhysicsBodyUpdateComponent`**. The count is clamped to **`MaxEntitiesCount`** — excess bodies are disabled and skipped.

See [BodiesList — Import]({% link docs/guides/physics-singleton/bodies-list/index.md %}#import-latesimulation) for the full copy table.

## Hook points

Place systems in **`LittlePhysicsImportGroup`** and order them relative to **`LittlePhysicsInternalImportGroup`**:

```
LateSimulation
  └─ LittlePhysicsImportGroup
       ├─ Your pre-import systems     [UpdateBefore internal import]
       ├─ LittlePhysicsInternalImportGroup
       │    ├─ PhysicsStepSystem
       │    └─ ImportPhysicsDataSystem
       └─ Your post-import systems     [UpdateAfter internal import]
```

### Before internal import — modify ECS components

Use this when transforms, layers, velocity, or flags on components should change **before** they are copied into **`BodiesList`**.

The **Scene 5 — Linecast** sample reads pointer input and writes a singleton component during import:

```csharp
[UpdateInGroup(typeof(LittlePhysicsImportGroup), OrderFirst = true)]
public partial struct LineCastInputSystem : ISystem
{
    public void OnCreate(ref SystemState state) =>
        state.RequireForUpdate<LineCastComponent>();

    public void OnUpdate(ref SystemState state)
    {
        var config = SystemAPI.GetSingleton<LineCastComponent>();
        config.IsClickedThisFrame = InputUtility.IsPointerPressed();

        var camera = Camera.main;
        if (camera != null && InputUtility.TryReadPointerPosition(out var pointerPosition))
        {
            var ray = camera.ScreenPointToRay(pointerPosition);
            config.RayOrigin = ray.origin;
            config.RayDirection = ray.direction;
        }

        SystemAPI.SetSingleton(config);
    }
}
```

This system does not touch native buffers, so **`PhysicsJobHandle`** chaining is optional.

### After internal import — modify native structures

Use this when you need to patch **`BodiesList`**, **`EntitiesMap`**, or other native data **after** the internal copy completes.

Chain on **`PhysicsJobHandle`** when scheduling jobs that read or write native memory:

```csharp
[UpdateInGroup(typeof(LittlePhysicsImportGroup))]
[UpdateAfter(typeof(LittlePhysicsInternalImportGroup))]
[BurstCompile]
public partial struct PostImportPatchSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state) =>
        state.RequireForUpdate<PhysicsReadyTag>();

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

        new ClampSpawnHeightJob { MinY = 0f }
            .ScheduleAndChain(ref state, in structures, ref simulation);
    }

    [BurstCompile]
    private struct ClampSpawnHeightJob : IBodiesJob.IWrite
    {
        public float MinY;

        public void Execute(ref PhysicsBodyData body)
        {
            if (body.PositionData.Position.y < MinY)
            {
                var pos = body.PositionData;
                pos.Position.y = MinY;
                body.PositionData = pos;
            }
        }
    }
}
```

Alternatively, schedule a raw **`IJobParallelFor`** and update **`PhysicsJobHandle`** manually — see [Custom job interfaces]({% link docs/guides/custom-jobs/using-custom-job-interfaces/index.md %}#physicsjobhandle-chaining).

## ActiveBodiesCount timing

**`SimulationDataComponent.ActiveBodiesCount`** is set during **`ImportPhysicsDataSystem`**. Post-import systems see the final count for the current frame. Mid-step systems in the upcoming fixed update use the same value.

## Related

- [Custom job groups]({% link docs/guides/custom-jobs/custom-job-groups/index.md %})
- [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %})
- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %})
- [Pipeline — Late update import]({% link docs/pipeline/index.md %}#late-update--import)
