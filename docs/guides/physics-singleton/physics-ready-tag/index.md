---
title: PhysicsReadyTag
layout: default
parent: Physics singleton
nav_order: 1
permalink: /docs/guides/physics-singleton/physics-ready-tag/
description: PhysicsReadyTag — signal that physics bootstrap is complete.
tags: [singleton, bootstrap, ecs]
---

# PhysicsReadyTag

An empty **`IComponentData`** tag added at the **very end** of [`LittlePhysicsBootstrapSystem`]({% link docs/pipeline/index.md %}#initialization--bootstrap). When this tag exists, native buffers, settings blobs, and the physics world entity are fully allocated and safe to read.

Use **`PhysicsReadyTag`** as the single readiness gate for custom systems. You do not need to require each physics singleton component individually.

## When bootstrap adds it

Bootstrap runs once during **Initialization** and performs work in a fixed order:

1. Build the settings blob from baked [`PhysicsSettingsAuthoring`]({% link docs/getting-started/index.md %}#2-add-global-physics-settings) data.
2. Allocate native structures (`BodiesList`, spatial maps, collision buffers, and related pools).
3. Create the physics world entity with [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}), [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}), [`PhysicsVariableSettingsComponent`]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}), and [`SimulationDataComponent`]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}).
4. Add **`PhysicsReadyTag`** on a separate entity and disable the bootstrap system.

Until step 4 completes, no physics import, fixed-step, or export systems run.

## Gating custom systems

In **`OnCreate`**, require the tag so your system never updates before physics is ready:

```csharp
[BurstCompile]
public partial struct MyPhysicsSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state)
    {
        state.RequireForUpdate<PhysicsReadyTag>();
    }
}
```

Every internal Little Physics system — import, gravity, collision, export, and the fixed-step group — uses the same pattern.

{: .note }
> Bootstrap also requires a baked **`PhysicsSettingsAuthoring`** entity in the world. Without it, settings and native memory are never created and **`PhysicsReadyTag`** is never added.

## Accessing singleton data

After the tag is present, read shared physics state with the usual Entities singleton APIs:

```csharp
var fixedSettings = SystemAPI.GetSingleton<PhysicsFixedSettingsComponent>();
ref var simulation = ref SystemAPI.GetSingletonRW<SimulationDataComponent>().ValueRW;
var structures = SystemAPI.GetSingleton<PhysicsStructuresComponent>();
```

The tag lives on its own entity; settings and structures live on the physics world entity. **`SystemAPI.GetSingleton<T>()`** resolves either way as long as exactly one instance exists.

## Related

- [How it works — Bootstrap]({% link docs/how-it-works/index.md %}#bootstrap)
- [Pipeline — Initialization]({% link docs/pipeline/index.md %}#initialization--bootstrap)
- [SimulationDataComponent]({% link docs/guides/physics-singleton/simulation-data-component/index.md %}) — per-tick body count and job handle
