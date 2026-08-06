---
title: Export workflow
layout: default
parent: Custom jobs
nav_order: 8
permalink: /docs/guides/custom-jobs/export-workflow/
description: LittlePhysicsExportGroup — after fixed-step physics.
---

# Export workflow

Export runs once per frame in **`SimulationSystemGroup`**, **after** **`FixedStepSimulationSystemGroup`** completes all **time scale × substeps** inner loops. It copies native simulation results back to ECS components and transforms.

## What internal export does

**`ExportPhysicsDataSystem`** runs inside **`LittlePhysicsInternalExportGroup`**. For each entity with a valid **`PhysicsBodyUpdateComponent.Index`**, it reads **`BodiesList[index]`** and writes:

- **`LocalTransform`** — position and rotation (including accumulated **`RotationOffset`**)
- **`PhysicsVelocityComponent`** — linear and angular velocity when present

See [BodiesList — Export]({% link docs/guides/physics-singleton/bodies-list/index.md %}#export-simulation).

## Hook points

```
Simulation (after FixedStep)
  └─ LittlePhysicsExportGroup
       ├─ Your pre-export systems      [UpdateBefore internal export]
       ├─ LittlePhysicsInternalExportGroup
       │    └─ ExportPhysicsDataSystem
       └─ Your post-export systems      [UpdateAfter internal export]
```

### Before internal export — read native structures

Use this when you need final native state **before** components are updated — for example logging, analytics, or a one-off read of **`BodiesList`** at the end of simulation.

Chain on **`PhysicsJobHandle`** if you schedule jobs over native buffers:

```csharp
[UpdateInGroup(typeof(LittlePhysicsExportGroup))]
[UpdateBefore(typeof(LittlePhysicsInternalExportGroup))]
[BurstCompile]
public partial struct PreExportStatsSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state) =>
        state.RequireForUpdate<PhysicsReadyTag>();

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
        ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;

        new CountFastBodiesJob().ScheduleAndChain(ref state, in structures, ref simulation);
    }

    [BurstCompile]
    private struct CountFastBodiesJob : IBodiesJob.IRead
    {
        public void Execute(in PhysicsBodyData body)
        {
            // Read-only inspection of native state before write-back
        }
    }
}
```

### After internal export — modify ECS components

Use this when **`LocalTransform`** and velocity components reflect simulated positions and you want gameplay reactions — destroying entities, spawning VFX, syncing to custom components, or networking.

The **Scene 3 — Pachinko** sample removes balls that fall below a Y threshold **after** export updates transforms:

```csharp
[BurstCompile]
[UpdateInGroup(typeof(LittlePhysicsExportGroup), OrderLast = true)]
public partial struct DisappearAtYSystem : ISystem
{
    public void OnCreate(ref SystemState state)
    {
        state.RequireForUpdate<DisappearAtYComponent>();
        state.RequireForUpdate<EndSimulationEntityCommandBufferSystem.Singleton>();
    }

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var commandBuffer = SystemAPI
            .GetSingleton<EndSimulationEntityCommandBufferSystem.Singleton>()
            .CreateCommandBuffer(state.WorldUnmanaged);

        state.Dependency = new DisappearAtYJob
        {
            CommandBuffer = commandBuffer,
        }.Schedule(state.Dependency);
    }

    [BurstCompile]
    private partial struct DisappearAtYJob : IJobEntity
    {
        public EntityCommandBuffer CommandBuffer;

        public void Execute(
            Entity entity,
            in LocalTransform localTransform,
            in DisappearAtYComponent disappearAtY)
        {
            if (localTransform.Position.y > disappearAtY.Y)
            {
                return;
            }

            CommandBuffer.DestroyEntity(entity);
        }
    }
}
```

Post-export systems typically operate on ECS components and do **not** need **`PhysicsJobHandle`** unless they also touch native buffers.

## Native vs components

| Timing | Read/write | Data is current |
|--------|------------|-----------------|
| Pre-export | Native (`BodiesList`, maps) | Yes — final native state for the frame |
| Pre-export | ECS components | Stale — last frame's export values |
| Post-export | ECS components | Yes — just written by **`ExportPhysicsDataSystem`** |
| Post-export | Native buffers | Current, but components are usually what rendering and gameplay consume |

## Related

- [Custom job groups]({% link docs/guides/custom-jobs/custom-job-groups/index.md %})
- [BodiesList — Export]({% link docs/guides/physics-singleton/bodies-list/index.md %}#export-simulation)
- [Pipeline — Simulation export]({% link docs/pipeline/index.md %}#simulation--export)
