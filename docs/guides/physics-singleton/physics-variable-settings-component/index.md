---
title: PhysicsVariableSettingsComponent
layout: default
parent: Physics singleton
nav_order: 3
permalink: /docs/guides/physics-singleton/physics-variable-settings-component/
description: PhysicsVariableSettingsComponent — per-tick variable physics settings.
tags: [singleton, settings, substeps, friction]
---

# PhysicsVariableSettingsComponent

A singleton component with **simulation tuning values** copied from [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}) at bootstrap. Internal systems read it every fixed step for friction, push-out, and substeps.

Unlike [`PhysicsFixedSettingsComponent`]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}), these fields are plain struct data on the singleton — you can change them at runtime with **`SystemAPI.GetSingletonRW<PhysicsVariableSettingsComponent>()`** if you need live tuning (for example adjusting air drag or substep count from gameplay code).

## Component fields

| Field | Type | Default (authoring) | Description |
|-------|------|---------------------|-------------|
| `EnvironmentSettings` | `EnvironmentSettings` | see below | Global damping and push-out behaviour |
| `SubstepsCount` | `byte` | `1` | Physics substeps per inner fixed-step iteration (**1–4**) |

### EnvironmentSettings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `AirFriction` | `float` | `0.5` | Global linear air friction applied to dynamic bodies |
| `AirAngularDrag` | `float` | `0` | Global angular air drag |
| `PushOutPower` | `float` | `1` | Multiplier on penetration push-out strength |
| `PushOutType` | `PushOutType` | `Position` | Whether push-out writes **velocity** or **position** |

`PushOutType` enum values: **`Position`**, **`Velocity`**.

### SubstepsCount

`LittlePhysicsSystemGroup` reads **`SubstepsCount`** to decide how many inner loops run per time-scale iteration. Each substep uses a fraction of the fixed delta (`LittlePhysicsTimeComponent.DeltaTime`).

Example: time scale **2** and **`SubstepsCount` = 2** → **4** full physics passes per Unity fixed update.

## Runtime example

```csharp
ref var variable = ref SystemAPI.GetSingletonRW<PhysicsVariableSettingsComponent>().ValueRW;

variable.EnvironmentSettings.AirFriction = 0.2f;
variable.SubstepsCount = 2;
```

Changes take effect on the next read inside the fixed-step loop. They do not rebuild the fixed settings blob or reallocate native buffers.

{: .warning }
> Lower **`SubstepsCount`** or very loose environment values can increase penetration and instability. Raising substeps costs more CPU per fixed tick.

## Related

- [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}) — authoring source for environment and substep defaults
- [PhysicsFixedSettingsComponent]({% link docs/guides/physics-singleton/physics-fixed-settings-component/index.md %}) — LOD tiers, layer matrix, spatial map, `MaxEntitiesCount`
- [LittlePhysicsTimeComponent]({% link docs/guides/physics-singleton/little-physics-time-component/index.md %}) — time scale and scaled `DeltaTime`
- [Pipeline — Fixed update]({% link docs/pipeline/index.md %}#fixed-update--inner-loop)
