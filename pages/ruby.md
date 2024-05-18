# Differences from the Ruby library

- variables are constructed explicitly rather than using the capitalized symbol
  convention
- neg matchers can declare variables, although the variables are only used for
  unification if they're used more than once within the same template, and do
  not escape the scope of the matcher
- `assert` is called `filter`
- `assuming` clauses are not implemented yet
- queries are not implemented but may be in the future
- `maybe`/`optional` matcher is not implemented since it's unclear at the moment
  whether it actually serves a purpose
- overlays are not implemented and are not going to be, since the immutable
  nature of the language makes almost the entire feature redundant
- self-invalidation detection is not implemented and likely isn't going to be,
  since it is computationally quite expensive while still detecting only a small
  set of possible contradictions, which is likely impossible to solve in a
  general case anyway since it seems to boil down to the halting problem; so be
  aware that your rules may create infinite loops when you generate facts that
  invalidate their own creation