defmodule Wongi.Engine do
  @moduledoc """
  This is a pure-Elixir forward chaining inference engine based on the classic
  Rete algorithm.

  It's derived from an earlier [Ruby library](ruby.md) and has a similar
  interface.

  ## Usage

  The following examples will assume a prelude of

  ```elixir
  import Wongi.Engine
  import Wongi.Engine.DSL
  ```

  which comprises the entire public interface of the library.

  First, an engine instance needs to be created:

  ```elixir
  engine = new()
  ```

  ## Knowledge management

  All knowledge in the system is represented as a set of triples in the form of
  `{subject, predicate, object}`. Any complex properties or relationships
  between entities can be broken down to this form, in which case the
  relationship members will take on the role of subjects and objects, and the
  type of the relationship will be the predicate.

  Any Elixir term except the atom `:_` can be used as any element of a triple,
  although predicates naturally tend to be atoms.

  References can be used to naturally represent anonymous graph nodes.

  Facts are added into the system with `assert/2` or `assert/4`:

  ```elixir
  engine = engine |> assert(:earth, :satellite, :moon)
  # or
  engine = engine |> assert({:earth, :satellite, :moon})
  # or
  engine = engine |> assert([:earth, :satellite, :moon])
  # or
  engine = engine |> assert(WME.new(:earth, :satellite, :moon))
  ```

  WME (working memory element) is the standard Rete term for "fact". You would
  rarely need to construct `Wongi.Engine.WME` instances by hand, but you might
  retrieve them from the engine and use in further function calls.

  Similarly, `retract/2` or `retract/4` remove facts from the system.

  ### Searching

  `select/2` and `select/4` can be used to return a set of facts matching a
  template. A template is a triple where some of the elements can be the special
  placeholder value `:_`.

  An enumerable of all facts matching the template is returned:

  ```elixir
  [fact] =
    engine
    |> select(:earth, :satellite, :_)
    |> Enum.to_list()

  IO.inspect(fact.object)
  # => :moon
  ```

  ## Rules

  Rules allow expressing more complex conditions than a single template.

  A rule is constructed like this:

  ```elixir
  rule = rule("optional name", forall: [
    matcher1,
    matcher2,
    ...
  ])

  IO.inspect(rule.ref)
  # => #Reference<...>
  ```

  The `ref` field is going to be used later to retrieve the results of rule
  execution.

  The rule can then be installed into the engine:

  ```elixir
  engine = engine |> compile(rule)
  ```

  Alternatively, this form can be used if you don't want an intermediate
  variable for the rule, although it is less pipeable:

  ```elixir
  {engine, ref} =
    engine
    |> compile_and_get_ref(rule(forall: [...]))
  ```

  The `forall` section of a rule consists of a list of matchers (more fully
  documented in `Wongi.Engine.DSL`) that express some sort of condition. The
  simplest matcher is `Wongi.Engine.DSL.has/3` which passes if a fact matching
  its template exists.

  A crucial part of matching is the variable bindings. A variable is specified
  using `Wongi.Engine.DSL.var/1`. The first time a variable is encountered, it
  is bound to the matched value. Subsequent matches will only succeed if the
  value is the same as the initially bound one.

  `:_` can be used as a placeholder variable that matches anything and is not
  bound to any value.

  ```elixir
  rule = rule(forall: [
    has(:_, :satellite, var(:satellite)),
    has(var(:satellite), :mass, var(:mass))
  ])

  engine =
    new()
    |> compile(rule)
    |> assert(:earth, :satellite, :moon)
    |> assert(:moon, :mass, 7.34767309e22)
  ```

  The results of rule execution can be retrieved using `tokens/2`, which returns
  an enumerable. A token represents a single possible execution of the matcher
  sequence. Our set of facts satisfies the rule exactly once, so we expect
  exactly one token. The bound variables can then be inspected on it:

  ```elixir
  [token] = engine |> tokens(rule.ref) |> Enum.to_list()

  IO.inspect(token[:satellite])
  # => :moon
  IO.inspect(token[:mass])
  # => 7.34767309e22
  ```

  ## Generation

  In addition to passively examining the results, it is also possible for a rule
  to perform some actions when it is fully satisfied. Generating additional
  facts is one such action.

  For example, we can add a rule that generates a fact about the gravitational
  pull on the satellite:

  ```elixir
  rule =
    rule(
      forall: [
        has(var(:planet), :satellite, var(:satellite)),
        has(var(:planet), :mass, var(:planet_mass)),
        has(var(:satellite), :mass, var(:sat_mass)),
        has(var(:satellite), :distance, var(:distance)),
        assign(:pull, &(6.674e-11 * &1[:sat_mass] * &1[:planet_mass] / :math.pow(&1[:distance], 2)))
      ],
      do: [
        gen(var(:satellite), :pull, var(:pull))
      ]
    )

  engine =
    new()
    |> compile(rule)
    |> assert(:earth, :satellite, :moon)
    |> assert(:earth, :mass, 5.972e24)
    |> assert(:moon, :mass, 7.34767309e22)
    |> assert(:moon, :distance, 384_400.0e3)

  [wme] = engine |> select(:moon, :pull, :_) |> Enum.to_list()
  IO.inspect(wme.object)
  # => 1.9819334566450407e20
  ```

  The generated facts keep track of the rule that generated them and get
  automatically retracted if the conditions are no longer satisfied.

  If a fact has been generated by a rule and also asserted manually, it also
  needs to be retracted by both means to be removed from the system.
  """

  alias Wongi.Engine.Entity
  alias Wongi.Engine.Rete

  @opaque t() :: Wongi.Engine.Rete.t()
  @opaque wme() :: Wongi.Engine.WME.t()
  @type fact() :: {any(), any(), any()} | wme()
  @type template() :: {any(), any(), any()} | wme()
  @opaque rule() :: Wongi.Engine.DSL.Rule.t()

  @doc """
  Creates a new engine instance.
  """
  @spec new() :: t()
  defdelegate new(), to: Rete

  @doc """
  Returns an engine with the given rule installed.

  See `Wongi.Engine.DSL` for details on the rule definition DSL.
  """
  @spec compile(t(), rule()) :: t()
  defdelegate compile(rete, rule), to: Rete

  @doc """
  Returns an engine with the given rule installed and the rule reference.

  The rule reference can be used to retrieve production tokens using `tokens/2`.

  See `Wongi.Engine.DSL` for details on the rule definition DSL.
  """
  @spec compile_and_get_ref(t(), rule()) :: {t(), reference()}
  defdelegate compile_and_get_ref(rete, rule), to: Rete

  @doc "Returns an engine with the given fact added to the working memory."
  @spec assert(t(), fact()) :: t()
  defdelegate assert(rete, fact), to: Rete

  @doc "Returns an engine with the given fact added to the working memory."
  @spec assert(t(), any(), any(), any()) :: t()
  defdelegate assert(rete, subject, predicate, object), to: Rete

  @doc "Returns an engine with the given fact removed from the working memory."
  @spec retract(t(), fact()) :: t()
  defdelegate retract(rete, fact), to: Rete

  @doc "Returns an engine with the given fact removed from the working memory."
  @spec retract(t(), any(), any(), any()) :: t()
  defdelegate retract(rete, subject, object, predicate), to: Rete

  @doc "Returns a set of all facts matching the given template."
  @spec select(t(), template()) :: MapSet.t(fact())
  defdelegate select(rete, template), to: Rete

  @doc "Returns a set of all facts matching the given template."
  @spec select(t(), any(), any(), any()) :: MapSet.t(fact())
  defdelegate select(rete, subject, predicate, object), to: Rete

  @doc "Returns a set of all tokens for the given production node reference."
  @spec tokens(t(), reference()) :: MapSet.t(Wongi.Engine.Token.t())
  defdelegate tokens(rete, node), to: Rete

  @doc "Returns all production node references."
  @spec productions(t()) :: MapSet.t(reference())
  defdelegate productions(rete), to: Rete

  def entity(rete, subject), do: Entity.new(rete, subject)
end
