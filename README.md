# Wongi.Engine

[![Build Status](https://github.com/ulfurinn/wongi-engine-elixir/actions/workflows/test.yml/badge.svg)](https://github.com/ulfurinn/wongi-engine-elixir/actions/workflows/test.yml)
[![hex.pm](https://img.shields.io/hexpm/v/wongi_engine)](https://hex.pm/packages/wongi_engine)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R0YVX79)

This is a pure-Elixir forward-chaining rule engine based on the classic [Rete algorithm](http://en.wikipedia.org/wiki/Rete_algorithm).

It's a port of the [Ruby library](https://github.com/ulfurinn/wongi-engine) of the same name. It aims to keep the public API close enough for rules to be easily portable, where their respective languages align.

## Acknowledgements

The Rete implementation in this library largely follows the outline presented in [\[Doorenbos, 1995\]](http://reports-archive.adm.cs.cmu.edu/anon/1995/CMU-CS-95-113.pdf), although by now it is three rewrites away from the original pseudocode.
