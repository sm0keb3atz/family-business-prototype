---
description: How to plan a new game feature in Godot 4.5
---

To plan a new feature, follow these steps:

1.  **Objective**: Define exactly what the feature is and why it's needed.
2.  **Scene Design**:
    - List the nodes required for the feature (e.g., `CharacterBody2D`, `CollisionShape2D`, `Sprite2D`).
    - Use `mcp_godot_search_scenes` to check for existing nodes that can be reused.
3.  **GDScript Logic**:
    - Outline the main variables and functions.
    - Identify if any **Godot 4.5** features like `abstract` classes should be used.
4.  **Signal Mapping**: Define which signals this feature will emit or connect to.
5.  **Task Update**: Add the implementation steps to `task.md`.
6.  **Implementation**: Proceed to the implementation phase once the plan is approved.
