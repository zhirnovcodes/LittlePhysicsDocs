---
title: ListsArray
layout: default
parent: Physics singleton
nav_order: 12
permalink: /docs/guides/physics-singleton/lists-array/
description: ListsArray — fixed-capacity array of lists for spatial maps and collision slots.
tags: [singleton, native, container]
---

# ListsArray

**`ListsArray<T>`** is a public native container in the **`LittlePhysics`** namespace: a **fixed-capacity array of lists** laid out as one flat 2D buffer. Bootstrap allocates instances with **`Allocator.Persistent`**; systems clear and refill them each tick.

Little Physics uses **`ListsArray`** wherever many independent lists must stay Burst-friendly and cache-coherent — spatial broad-phase cells, per-body collision slots, and internal pair buffers.

## Layout

```
ListsArray<T>(listCount, listCapacity, allocator)
```

| Concept | Meaning |
|---------|---------|
| **`listCount`** | Number of outer lists (**`TotalListCount`**) |
| **`listCapacity`** | Max entries per list (**`CapacityPerList`**) |
| **Outer index** | Which list — e.g. flattened spatial cell or body index |
| **Inner index** | Slot within that list — **`0 … GetCount(outer) - 1`** |

Storage is a single flat block: **`Data[outer * listCapacity + inner]`**. Each list tracks its live count separately. **`TryAdd`** appends until the list is full, then returns **`false`** without error.

## Core API

| Method | Description |
|--------|-------------|
| **`TryAdd(listIndex, value)`** | Append if the list has free capacity |
| **`GetCount(listIndex)`** | Current entry count for one list |
| **`GetValue(listIndex, valueIndex)`** | Read one entry |
| **`SetValue(listIndex, valueIndex, value)`** | Write one entry |
| **`CanAdd(listIndex)`** | Whether the list still has room |
| **`Clear()`** | Reset all list counts to zero |
| **`ClearAt(listIndex)`** | Reset one list |
| **`Traverse(listIndex, ref iterator, out value)`** | Walk entries with an **`Iterator`** helper |

Parallel job variants:

| View | Use |
|------|-----|
| **`AsParallelWriter()`** | Lock-free append from parallel jobs |
| **`AsParallelHashWriter()`** | Append only if value not already in the list (**`TryAddUnique`**) |
| **`AsParallelReader()`** | Read-only flat buffer access |

{: .warning }
> Do not dispose **`ListsArray`** instances held on [`PhysicsStructuresComponent`]({% link docs/guides/physics-singleton/physics-structures-component/index.md %}). Bootstrap owns their lifetime.

## Where Little Physics uses ListsArray

| Instance | Outer index | Inner contents | Page |
|----------|-------------|----------------|------|
| **`CollisionMap.DynamicMap`** | Spatial cell | Dynamic/kinematic body indices | [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) |
| **`CollisionMap.StaticMap`** | Spatial cell | Static body entities | [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) |
| **`Collisions.CollisionDataMap`** | Body index | Object-to-object **`CollisionData`** slots | [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) |

Internal **`PhysicsInternalStructuresComponent.Pairs`** is also a **`ListsArray<uint>`** (body index → pair indices). It is not on the public singleton but follows the same layout.

## Example — iterate one list

```csharp
ListsArray<uint> dynamicMap = structures.CollisionMap.DynamicMap;
int cellIndex = /* flattened cell index */;

int count = dynamicMap.GetCount(cellIndex);
for (int i = 0; i < count; i++)
{
    uint bodyIndex = dynamicMap.GetValue(cellIndex, i);
    var body = structures.BodiesList[(int)bodyIndex];
}
```

Or with the built-in iterator:

```csharp
var iterator = new ListsArray<uint>.Iterator();
while (dynamicMap.Traverse(cellIndex, ref iterator, out uint bodyIndex))
{
    var body = structures.BodiesList[(int)bodyIndex];
}
```

## Related

- [CollisionMapSingleton]({% link docs/guides/physics-singleton/collision-map-singleton/index.md %}) — **`DynamicMap`** and **`StaticMap`**
- [CollisionsSingleton]({% link docs/guides/physics-singleton/collisions-singleton/index.md %}) — **`CollisionDataMap`**
- [Physics settings and LOD]({% link docs/guides/physics-singleton/physics-settings-and-lod/index.md %}) — per-LOD caps that size list capacities
