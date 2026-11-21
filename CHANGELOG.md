# Changelog

## 0.10.0

### Breaking

- Removed the `comparable` dependency. `defcomparable` definitions are no longer honored. See the migration guide in `Wongi.Engine.Comparable`.
- Cross-type comparisons with the custom struct as the right operand now return the inverted answer. `defcomparable` did not invert it, so affected rules can match differently after migrating.
- `Decimal` values in comparison filters require Decimal 2.0 or later. Comparing a NaN raises `Decimal.Error`.

### Changed

- Structs with a `compare/2` function, including `Version` and `Decimal`, now compare semantically in filters instead of field by field.
- Conflicting cross-type `Wongi.Engine.Comparable` implementations now raise `ArgumentError`.

### Added

- `Wongi.Engine.Comparable`, a protocol for defining how structs compare in filters.
- `Wongi.Engine.Compare`, the comparison entry point used by filters and protocol implementations.
