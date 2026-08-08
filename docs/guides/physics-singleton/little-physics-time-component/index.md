---
title: LittlePhysicsTimeComponent
layout: default
parent: Physics singleton
nav_order: 5
permalink: /docs/guides/physics-singleton/little-physics-time-component/
description: LittlePhysicsTimeComponent — time scale, delta time, and elapsed time.
tags: [singleton, time, pause, substeps]
---

# LittlePhysicsTimeComponent

A singleton component that tracks **physics time scale**, **substep delta time**, and **accumulated simulation time**. Bootstrap creates it with **`TimeScale = 1`**; [`LittlePhysicsSystemGroup`]({% link docs/pipeline/index.md %}#fixed-update--inner-loop) refreshes **`DeltaTime`** and **`ElapsedTime`** on every inner fixed-step pass.

Use it to pause, slow, or fast-forward the simulation, and to read the scaled timestep inside custom physics systems.

## Component fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `TimeScale` | `int` | `1` | How many full physics loops run per Unity fixed update (**0**, **1**, **2**, or **4**) |
| `DeltaTime` | `float` | — | Scaled delta for one **substep**; set by the system group each inner iteration |
| `ElapsedTime` | `double` | `0` | Accumulated physics time since bootstrap |

## TimeScale

Valid values are **`0`**, **`1`**, **`2`**, and **`4`** only:

| Value | Effect |
|-------|--------|
| `0` | Pause — the inner physics loop does not run |
| `1` | Normal speed |
| `2` | Two full physics passes per fixed update |
| `4` | Four full physics passes per fixed update |

Change **`TimeScale`** at runtime with **`SystemAPI.GetSingletonRW<LittlePhysicsTimeComponent>()`**. The sample **`TimeScalePresenter`** cycles **1 → 2 → 4** and toggles pause by storing the last value and setting **`TimeScale`** to **`0`**.

{: .warning }
> There is no validation in code — assign only **0**, **1**, **2**, or **4**. Other values produce undefined loop counts.

## DeltaTime and ElapsedTime

These fields are **written by `LittlePhysicsSystemGroup`**, not by gameplay code:

```csharp
float substepDeltaTime = worldTime.DeltaTime / substepsCount;

for (int i = 0; i < timeScale; i++)
{
    for (int substep = 0; substep < substepsCount; substep++)
    {
        timeElapsed += substepDeltaTime;
        // singleton updated with ElapsedTime, DeltaTime = substepDeltaTime, TimeScale
        // ... run full physics pass ...
    }
}
```

- **`DeltaTime`** is **`Unity fixed delta / SubstepsCount`**, not multiplied by time scale. Time scale repeats the whole pass instead.
- **`ElapsedTime`** advances by **`DeltaTime`** on each substep while the simulation is running.

Read **`DeltaTime`** inside systems that run in the fixed-step inner loop — especially **`LittlePhysicsUserSystemGroup`** and internal systems such as gravity, friction, and velocity integration. Package samples use it for spawn timing and trigger forces.

{: .note }
> Outside an active inner iteration (for example while paused), **`DeltaTime`** is **`0`**. Do not use **`UnityEngine.Time.deltaTime`** for physics integration when a substep-accurate value is required — use this component or chain through the pipeline groups.

### Total work per fixed update

Combined cost scales with both time scale and substeps:

```
passes per fixed update = TimeScale × SubstepsCount
```

Example: **`TimeScale = 2`** and **`SubstepsCount = 2`** → **4** complete physics passes per Unity fixed tick. See [`PhysicsVariableSettingsComponent`]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}) for substep settings.

## Runtime example

```csharp
ref var time = ref SystemAPI.GetSingletonRW<LittlePhysicsTimeComponent>().ValueRW;
time.TimeScale = 0; // pause

// later
time.TimeScale = 2; // 2× speed
```

For MonoBehaviour UI that runs outside ECS systems, query the singleton from the default world (as **`TimeScalePresenter`** does) rather than caching **`DeltaTime`** across frames.

## What reads TimeScale

Internal systems pass **`TimeScale`** into LOD lookups so capacity limits (`DynamicsInCells`, `CellPerEntity`, `PairPerEntity`, and related fields) resolve to the correct tier for the current simulation speed. See [Physics settings and LOD]({% link docs/guides/settings/physics-settings-and-lod/index.md %}).

## Related

- [PhysicsVariableSettingsComponent]({% link docs/guides/physics-singleton/physics-variable-settings-component/index.md %}) — `SubstepsCount` (1–4) divides `DeltaTime`
- [Pipeline — Fixed update]({% link docs/pipeline/index.md %}#fixed-update--inner-loop) — inner loop driven by this component
- [How it works — Fixed step]({% link docs/how-it-works/index.md %}#fixed-step)
