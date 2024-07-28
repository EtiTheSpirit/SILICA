# SILICA
An experimental recreation of Rain World's LevelColor.shader for use in Unity editor and in-game.

It was designed for my mod, "Dreams of Infinite Glass", as I had dynamic/animated level graphics that could leverage GPU-bound effects for performance. This is where the name "SILICA" comes from.

## Features
* It is documented and uses macros to try to improve readability at a glance.
  * It is optimized for rendering, and implements static branches if certain keywords are defined (by modded code) to implement them.
  * It controls specific branch types for additional performance.
* **This can be used to visualize level files within the Unity editor when you are writing your own shaders via a separate `LevelColorDebug` shader.**
