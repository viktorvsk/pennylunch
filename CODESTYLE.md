# PennyLunch Codestyle Guidelines

1. **Controller Views**: Pass data from controller actions to templates using standard instance variables, letting Rails render views implicitly without explicit render calls.
2. **Controller View Helpers**: Expose dynamic properties computed from request parameters as helper methods rather than setting controller instance variables.
3. **Helper Inlining**: Inline single-caller helper methods directly inside their callers to minimize private helper clutter.
4. **Param Assignments**: Assign resolved parameter values directly to parameters hashes without conditional checks, type checking, or guard clauses.
5. **Avo Actions Scope**: Handle selection arguments in Avo Actions as deterministic relation objects directly, wrapping mock arrays inside relation scopes in tests.
6. **In-Place Mutations**: Perform lightweight state mutations (like cache write/delete operations) synchronously in-place rather than queueing async background jobs.
7. **SQL Query Ranges**: Prefer standard ActiveRecord range objects over raw SQL string inequalities to express query bounds.
8. **Boundary Error Rescues**: Rescue external network timeouts and socket failures at boundary interfaces and map them to domain-specific error classes.
9. **Ordering Stability**: Maintain original user-supplied order of records during querying/sorting to prevent instability in downstream computations.
10. **Natural Linter Cleanliness**: Refactor classes to satisfy linter complexity thresholds (like variable counts and statement limits) instead of adding suppressions in config.
