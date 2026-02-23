# Godot 4.5 AI Reference

This document serves as high-priority context for the AI when working on this project.

## GDScript 2.0 (Godot 4.5+) Features

### 1. Abstract Classes
You can now define classes that cannot be instantiated directly.
```gdscript
abstract class Enemy extends CharacterBody2D:
    func attack():
        pass
```

### 2. @export for Variants
More flexible exporting of custom variant types.
```gdscript
@export var metadata: Variant
```

### 3. Script Backtracing
Improved debugging with custom loggers and better backtrace information in the console.

### 4. Typed Arrays & Dictionaries
Always use static typing for performance and AI clarity.
```gdscript
var players: Array[Player] = []
var scores: Dictionary[String, int] = {}
```

## Project Standards

- **Node Access**: Use `%UniqueNodeName` for UI elements or stable scene components.
- **Signals**: Use the `connect` syntax: `button.pressed.connect(_on_button_pressed)`.
- **Async**: Use `await` for timers and signals: `await get_tree().create_timer(1.0).timeout`.

## Rendering (Forward+)
- This project uses the **Forward Plus** renderer.
- Support for **Stencil Buffers** and **Shader Baking** (faster startup).
