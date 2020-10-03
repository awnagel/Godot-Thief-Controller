# Godot-Thief-Controller
A first-person character controller with an FSM, inspired by the Thief games and Quadrilateral Cowboy.

Made in and for the Godot engine.

## Features

- Clambering up ledges and into vents.
- Detects how lit the player is.
- Get the texture of the surface walked on and signal to nearby listeners in a radius.
- Head bobbing
- Crouching
- Sneaking
- Leaning
- Frobbing (Interacting)
- Dragging  and throwing rigidbodies with the mouse.

## Guide

To detect the player visually, have the AI access the player light_level variable. To detect the player by sound, add a *listen* function to the AI script. To make an object frobbable, add an *on_frob* function to the object script. To make an object draggable, simply have it be a Rigidbody with a collider.

- Move with WASD.

- Crouch by holding C.

- Lean by holding E and pressing A and D.

- Sneak by holding Shift.

- Clamber and jump by pressing space.

- Frob and drag by clicking the Left Mouse Button.

- Throw when dragging by clicking the Right Mouse Button.

## Sources

Uses the light detection method from [The Dark Mod](https://www.thedarkmod.com/main/), as documented [here](https://forums.thedarkmod.com/index.php?/topic/18882-how-does-the-light-awareness-system-las-work/).

Clambering code inspired and adapted from [Quadrilateral Cowboy](https://blendogames.com/qc/) by [Blendo Games](https://blendogames.com/). [(Source)](https://github.com/blendogames/quadrilateralcowboy)

​	