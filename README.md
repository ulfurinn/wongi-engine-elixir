# Wongi.Engine

[![Build Status](https://github.com/ulfurinn/wongi-engine-elixir/actions/workflows/test.yml/badge.svg)](https://github.com/ulfurinn/wongi-engine-elixir/actions/workflows/test.yml)

This is a pure-Elixir forward-chaining rule engine based on the classic [Rete algorithm](http://en.wikipedia.org/wiki/Rete_algorithm).

It's a port of the [Ruby library](https://github.com/ulfurinn/wongi-engine) of the same name. It aims to keep the public API close enough for rules to be easily portable, where their respective languages align.

This is ongoing work and it's far from feature parity with the Ruby library.

## Acknowledgements

The Rete implementation in this library largely follows the outline presented in [\[Doorenbos, 1995\]](http://reports-archive.adm.cs.cmu.edu/anon/1995/CMU-CS-95-113.pdf), although by now it is three rewrites away from the original pseudocode.