---
title: Home
layout: default
nav_order: 1
permalink: /
description: Little Physics — Unity ECS physics for large-scale simulations.
---

# Little Physics

**Little Physics** is a Unity ECS physics package built for large-scale simulations — crowds, physical particles, liquids, and other scenarios where throughput matters more than perfect determinism.

Dynamic bodies are **spheres only**, but the package trades shape variety for speed: configurable simulation limits, up to **four LOD levels**, **Burst** compilation, and **multithreading** let you run on the order of **1,000,000** units at once. Looser settings reduce determinism; tighter settings and closer camera ranges improve it.

{% include youtube.html id="SvjItMu0dro" %}

## Requirements

- **Unity 6000.0+** (Unity 6) — not compatible with Unity 2022
- **Entities** `com.unity.entities` 1.4.8
- **Namespace:** `LittlePhysics`

## Supported platforms

- **Tested:** Android, Web, Desktop
- **Not tested:** iOS and consoles

## Supported render pipelines

- **URP**, **HDRP**, and **Built-in**

Samples ship for **URP** and require **Entities Graphics**.

## Features

- **Deep simulation tuning** — separate fixed and variable settings for different simulation profiles
- **LOD** — up to four levels with per-level limits
- **Time control** — pause, slow down, or speed up (`0`, `1`, `2`, or `4` time scale)
- **Body types** — dynamic, static, kinematic, and triggers
- **Gravity** — directional and radial
- **Friction** and **surface collisions** — every dynamic body is tested against surfaces each frame
- **Substeps** — split a fixed update into 1–4 substeps for better penetration handling and stability
- **Custom jobs** — hook into the pipeline via public job interfaces and system groups
- **Samples** — five scenes via Package Manager (**All Samples**; URP + Entities Graphics)

## Shape support

| Body type | Shapes |
|-----------|--------|
| Dynamic | Sphere only |
| Kinematic & static | Sphere, capsule |
| Surface | Sphere, inverse sphere, infinite plane (identity rotation), box (identity rotation) |

Object-to-object collisions run inside the **Spatial Map** bounds you configure. Bodies outside the map still receive gravity and surface collision, but not pairwise object collisions.

## Known limitations

- Determinism decreases with loose LOD and simulation settings; the system is designed for use cases where that trade-off is acceptable
- **MaxEntitiesCount** caps how many entities participate; excess entities are ignored
- **Dynamic bodies: spheres only** — simplifies collision math and memory use
- **Static and kinematic bodies: spheres and capsules only**
- **Surface shapes:** sphere, inverse sphere, infinite plane (identity rotation), box (identity rotation)
- **Time scale** supports `0`, `1`, `2`, and `4` only
- Pairwise collisions are limited to the spatial map volume
- iOS and consoles have not been tested

## Documentation

| Section | What you'll find |
|---------|------------------|
| [Getting Started]({% link docs/getting-started/index.md %}) | Install the package, add authorings to a subscene, and run your first simulation |
| [How it works]({% link docs/how-it-works/index.md %}) | ECS baking, simulation flow, LOD, and spatial map concepts |
| [Pipeline]({% link docs/pipeline/index.md %}) | System group hierarchy, update order, and custom hook points |
| [Settings]({% link docs/guides/settings/index.md %}) | Physics settings, LOD, spatial map, gravity, and body types |
| [Physics singleton]({% link docs/guides/physics-singleton/index.md %}) | Shared components and native data structures |
| [Custom jobs]({% link docs/guides/custom-jobs/index.md %}) | `IBodiesJob`, `ICollisionJob`, `ISurfaceJob`, import/export workflow |
| [Builders]({% link docs/guides/builders/index.md %}) | Runtime body creation with `DynamicBodyBuilder`, `KinematicBodyBuilder`, `StaticBodyBuilder` |
| [LLM skills]({% link docs/llm-skills/index.md %}) | Skill file for AI assistants writing Little Physics code |

New to the package? Start with [Getting Started]({% link docs/getting-started/index.md %}).
