# Little Physics — video script

**Docs:** https://zhirnovcodes.github.io/LittlePhysicsDocs/

---

## Intro

I present to you **Little Physics** — an ECS physics package for Unity, built for large-scale simulations. It lets you choose between **higher determinism** or **higher, stable performance**, depending on what your project needs.

The system offers a deep level of settings so you can get the best results on different processors or at different entity counts. 

You can **pause**, **slow down**, or **speed up** the simulation at any time.

**Level of detail** is supported as well: simulation becomes **more accurate** the closer bodies are to the camera, and lighter farther away. Together, that makes Little Physics a strong fit for crowd simulation, space objects, particles, liquids — where exact, frame-perfect behaviour matters less, especially at distance from the camera.

---

## Bodies and physics

The package supports **dynamic**, **static**, and **kinematic** rigid bodies, plus **triggers**.

Dynamic objects are **spheres only** — a deliberate design choice that keeps collision math simple and fast.

There is **directional** and **radial** gravity, **friction**, and **rotation on collisions**.

You can **track collisions** with custom jobs, and run **linecasts** through the public job interfaces.

For a deeper look at how the package was built, see my **YouTube series**.

---

## Quick start

To get running quickly:

1. Install the package from **Package Manager**.
2. Add **`PhysicsSettingsAuthoring`** to your subscene.
3. Add **`SpacialMapAuthoring`**. Adjust its size, cell size, and position so the grid covers your simulation area. Enable **Should Draw In Editor** to see the grid in the Scene view.
4. Add **`GravitySourceAuthoring`** if you need gravity, and choose the gravity type.
5. Add **`SurfaceBodyAuthoring`** if you need surfaces, and choose the surface type.
6. Add physical objects with **`DynamicBodyAuthoring`**, **`KinematicBodyAuthoring`**, or **`StaticBodyAuthoring`**.
7. Run the simulation.

For the full walkthrough — subscene baking, velocity, samples, and more — follow the complete documentation linked on the Asset Store page or in the description of this video.

You can also download a **skills file for LLMs** from the docs.

---

## Samples

Install the **samples** that ship with the package from Package Manager. They require **Entities.Graphics**; the Editor shows a popup asking you to install it once, after sample import.

---

## Outro

And that is the package in a nutshell. Have fun coding!
