# Godot 4.7.2 parser fix

The project previously used local-variable type inference (`var x := expression`) in code paths where the expression contained calls through dynamically typed references such as `player` or `game`. Godot 4.7.2 cannot always infer a static type from those Variant-returning expressions and reports `Cannot infer the type ... because the value doesn't have a set type`.

Fix: all local `var ... := ...` declarations in gameplay scripts were changed to ordinary Variant assignment (`var ... = ...`). Constants continue to use `:=` because their literal types are unambiguous.
