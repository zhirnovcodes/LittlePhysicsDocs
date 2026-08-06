---
title: EntitiesMap
layout: default
parent: PhysicsStructuresComponent
nav_order: 3
permalink: /docs/guides/physics-singleton/entities-map/
description: EntitiesMap — entity to body index hash map.
tags: [singleton, native, import, lookup]
---

# EntitiesMap

A **`NativeHashMap<Entity, uint>`** on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}). It maps a body’s **main entity** to its index in [`BodiesList`]({% link docs/guides/physics-singleton/bodies-list/index.md %}).

Use **`EntitiesMap`** when you have an **`Entity`** and need the corresponding native body index — for example when resolving static-map entries or looking up a slot in collision buffers.

## Key and value

| | |
|---|---|
| **Key** | **`PhysicsBodyData.Main`** — the root entity for the body (from [`PhysicsBodyComponent`]({% link docs/guides/physics-singleton/other-public-ecs-components/index.md %})). For kinematic or static triggers this may be a **parent** entity, not the collider entity itself. |
| **Value** | **`uint`** body index — the same index stored in **`PhysicsBodyUpdateComponent.Index`** and used to index **`BodiesList`**, **`Randoms`**, **`Collisions`**, and related buffers. |

Only entities imported this frame appear in the map. Indices are **`0 … ActiveBodiesCount - 1`**.

## Lifecycle

Bootstrap allocates **`EntitiesMap`** with capacity **`MaxEntitiesCount`**.

Each frame in **LateSimulation**, **`ImportPhysicsDataSystem`**:

1. **`ClearBodiesJob`** — clears the hash map together with **`BodiesList`**.
2. **`ImportPhysicsDataJob`** — for each active body, writes **`BodiesList[entityInQueryIndex]`** and calls **`EntitiesMap.TryAdd(bodyData.Main, (uint)entityInQueryIndex)`**.

The map is **rebuilt from scratch every import**. Do not cache indices across frames without also reading **`PhysicsBodyUpdateComponent.Index`** or re-querying the map after import.

Custom jobs that receive an **`Entity`** and need simulation data should **`TryGetValue`** on **`EntitiesMap`**, then index **`BodiesList`** or collision buffers with the returned index.

```csharp
if (structures.EntitiesMap.TryGetValue(bodyEntity, out uint bodyIndex))
{
    var body = structures.BodiesList[(int)bodyIndex];
    // ...
}
```

{: .note }
> If **`TryGetValue`** fails, the entity was not imported this frame (disabled, over **`MaxEntitiesCount`**, or missing required components).

## Related

- [BodiesList]({% link docs/guides/physics-singleton/bodies-list/index.md %}) — array indexed by map values
- [PhysicsBodyData]({% link docs/guides/physics-singleton/physics-body-data/index.md %}) — **`Main`** field is the map key
- [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — **`StaticMap`** stores entities; detection resolves them via **`EntitiesMap`**
