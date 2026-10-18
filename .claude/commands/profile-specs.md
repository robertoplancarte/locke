---
description: Profile RSpec files to find where the time goes (factories, SQL, setup)
argument-hint: <spec file or directory>
---

Profile the specs at `$ARGUMENTS` and report where the time goes. If no path
was given, ask for one — profiling the whole suite drowns the signal in noise.

Usage examples:

```
/profile-specs spec/models/user_spec.rb
/profile-specs spec/services/
```

Run the steps in order and interpret each result before moving to the next.

1. **Find the slowest examples**: `bundle exec rspec --profile 10 $ARGUMENTS`.
   If the top entries share one feature (e.g. all touch password hashing),
   suspect expensive global setup, not factories.
2. **Count factory runs**: `FPROF=1 bundle exec rspec $ARGUMENTS`.
   `total` ≫ `top-level` for a factory means a cascade — associations or
   traits creating records the specs never asked for.
3. **Measure SQL share**: `EVENT_PROF='sql.active_record' bundle exec rspec $ARGUMENTS`.
   If SQL is a small fraction of total time, don't chase N+1s — look at
   factories and hooks instead.
4. **Split hook time from example time**: `RD_PROF=1 bundle exec rspec $ARGUMENTS`.
   Heavy `before`-hook time with light example bodies points at setup that
   should be shared (`let_it_be` / `before_all`).

The full flag-by-flag cheat-sheet (including `TPS_PROF`, `TEST_MEM_PROF`,
`TEST_STACK_PROF`) lives in the `martian-spec` skill's
`references/profiling.md`.

Finish with a short report: the top time sinks, whether the bottleneck is
factories, SQL, hooks, or example bodies, and the single highest-leverage fix.
