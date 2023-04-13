defmodule Pillar.Ecto.QueryBuilder do
  alias Ecto.Query
  alias Ecto.Query.BooleanExpr
  alias Ecto.Query.JoinExpr
  alias Ecto.Query.QueryExpr
  alias Pillar.Ecto.QueryParam

  # alias ClickhouseEcto.Connection
  alias Pillar.Ecto.Helpers

  # TODO: We need to convert our values
  # to the a parameterized query.
  #
  #
  # {id:UInt8} and string_column = {phrase:String}"
  #
  # Probably add info to the columns in ecto
  # or give good defaults

  binary_ops = [
    ==: " = ",
    !=: " != ",
    <=: " <= ",
    >=: " >= ",
    <: " < ",
    >: " > ",
    and: " AND ",
    or: " OR ",
    ilike: " ILIKE ",
    like: " LIKE ",
    in: " IN ",
    is_nil: " WHERE "
  ]

  @binary_ops Keyword.keys(binary_ops)

  Enum.map(binary_ops, fn {op, str} ->
    def handle_call(unquote(op), 2), do: {:binary_op, unquote(str)}
  end)

  def handle_call(fun, _arity), do: {:fun, Atom.to_string(fun)}

  def select(%Query{select: %{fields: fields}} = query, select_distinct, sources, all_params) do
    {ex, all_params} = select_fields(fields, sources, query, all_params)
    {["SELECT", select_distinct, ?\s | ex], all_params}
  end

  def select_fields([], _sources, _query, all_params), do: {"'TRUE'", all_params}

  def select_fields(fields, sources, query, all_params) do
    Helpers.intersperse_reduce(fields, ", ", all_params, fn
      {key, value}, all_params ->
        {ex, all_params} = expr(value, sources, query, all_params)
        {[ex, " AS " | Helpers.quote_name(key)], all_params}

      value, all_params ->
        expr(value, sources, query, all_params)
    end)
  end

  def distinct(nil, _, _), do: {[], []}
  def distinct(%QueryExpr{expr: []}, _, _), do: {[], []}
  def distinct(%QueryExpr{expr: true}, _, _), do: {" DISTINCT", []}
  def distinct(%QueryExpr{expr: false}, _, _), do: {[], []}

  def distinct(%QueryExpr{expr: _exprs}, _sources, query) do
    Helpers.error!(
      query,
      "DISTINCT ON is not supported! Use `distinct: true`, for ex. `from rec in MyModel, distinct: true, select: rec.my_field`"
    )
  end

  def from(%{from: %{source: source}} = query, sources, all_params) do
    {{from, name}, all_params} = Helpers.get_source(query, sources, 0, source, all_params)
    {[" FROM ", from, " AS " | name], all_params}
  end

  def update_fields(query, _sources) do
    Helpers.error!(query, "UPDATE is not supported")
  end

  def join(%Query{joins: []}, _sources, all_params), do: {[], all_params}

  def join(%Query{joins: joins} = query, sources, all_params) do
    [
      ?\s
      | Helpers.intersperse_reduce(joins, ?\s, all_params, fn
          %JoinExpr{qual: qual, ix: ix, source: source, on: %QueryExpr{expr: on_expr}},
          all_params ->
            {{join, _name}, all_params} =
              Helpers.get_source(query, sources, ix, source, all_params)

            {["ANY", join_qual(qual), join, " USING ", on_join_expr(on_expr)], all_params}
        end)
    ]
  end

  def on_join_expr({_, _, [head | tail]}) do
    retorno = [on_join_expr(head) | on_join_expr(tail)]
    retorno |> Enum.uniq() |> Enum.join(",")
  end

  def on_join_expr([head | tail]) do
    [on_join_expr(head) | tail]
  end

  def on_join_expr({{:., [], [{:&, [], _}, column]}, [], []}) when is_atom(column) do
    column |> Atom.to_string()
  end

  def on_join_expr({:==, _, [{{_, _, [_, column]}, _, _}, _]}) when is_atom(column) do
    column |> Atom.to_string()
  end

  def join_qual(:inner), do: " INNER JOIN "
  def join_qual(:left), do: " LEFT OUTER JOIN "

  def where(%Query{wheres: wheres} = query, sources, all_params) do
    boolean(" WHERE ", wheres, sources, query, all_params)
  end

  def having(%Query{havings: havings} = query, sources, all_params) do
    boolean(" HAVING ", havings, sources, query, all_params)
  end

  def group_by(%Query{group_bys: []}, _sources, all_params), do: {[], all_params}

  def group_by(%Query{group_bys: group_bys} = query, sources, all_params) do
    {expr, all_params} =
      Helpers.intersperse_reduce(group_bys, ", ", all_params, fn
        %QueryExpr{expr: expr}, all_params ->
          Helpers.intersperse_reduce(expr, ", ", all_params, &expr(&1, sources, query, &2))
      end)

    xs = [
      " GROUP BY "
      | expr
    ]

    {xs, all_params}
  end

  def order_by(%Query{order_bys: []}, _distinct, _sources, all_params), do: {[], all_params}

  def order_by(%Query{order_bys: order_bys} = query, distinct, sources, all_params) do
    order_bys = Enum.flat_map(order_bys, & &1.expr)

    xs = [
      " ORDER BY "
      | Helpers.intersperse_map(
          distinct ++ order_bys,
          ", ",
          &order_by_expr(&1, sources, query, all_params)
        )
    ]

    {xs, all_params}
  end

  def order_by_expr({dir, expr}, sources, query, all_params) do
    str = expr(expr, sources, query, all_params)

    case dir do
      :asc -> str
      :desc -> [str | " DESC"]
    end
  end

  def limit(%Query{offset: nil, limit: nil}, _sources, all_params), do: {[], all_params}

  def limit(%Query{offset: nil, limit: %QueryExpr{expr: expr}} = query, sources, all_params) do
    {exp, all_params} = expr(expr, sources, query, all_params)
    {[" LIMIT ", exp], all_params}
  end

  def limit(
        %Query{offset: %QueryExpr{expr: expr_offset}, limit: %QueryExpr{expr: expr_limit}} =
          query,
        sources,
        all_params
      ) do
    {expr_offset, all_params} = expr(expr_offset, sources, query, all_params)
    {expr_limit, all_params} = expr(expr_limit, sources, query, all_params)

    {[
       " LIMIT ",
       expr_offset,
       ", ",
       expr_limit
     ], all_params}
  end

  def boolean(_name, [], _sources, _query, all_params), do: {[], all_params}

  def boolean(
        name,
        [%{expr: expr, op: op} | query_exprs],
        sources,
        query,
        all_params
      ) do
    {exp, all_params} = paren_expr(expr, sources, query, all_params)

    acc = {
      {op, exp},
      all_params
    }

    {{_, where_filters}, all_params} =
      Enum.reduce(query_exprs, acc, fn
        %BooleanExpr{expr: expr, op: op}, {{op, acc}, all_params} ->
          {exp, all_params} = paren_expr(expr, sources, query, all_params)

          acc = {op, [acc, operator_to_boolean(op), exp]}

          {acc, all_params}

        %BooleanExpr{expr: expr, op: op}, {{_, acc}, all_params} ->
          {exp, all_params} = paren_expr(expr, sources, query, all_params)

          acc = {op, [?(, acc, ?), operator_to_boolean(op), exp]}

          {acc, all_params}
      end)

    {[name | where_filters], all_params}
  end

  def operator_to_boolean(:and), do: " AND "
  def operator_to_boolean(:or), do: " OR "

  def paren_expr(false, _sources, _query, all_params), do: {"false", all_params}
  def paren_expr(true, _sources, _query, all_params), do: {"true", all_params}

  def paren_expr(expr, sources, query, all_params) do
    {ex, all_params} = expr(expr, sources, query, all_params)
    {[?(, ex, ?)], all_params}
  end

  def expr({_type, [literal]}, sources, query, all_params) do
    expr(literal, sources, query, all_params)
  end

  def expr({:^, [], [_ix]}, _sources, _query, all_params) do
    [param | rest] = all_params
    {to_string(param), rest}
  end

  def expr({{:., _, [{:&, _, [idx]}, field]}, _, []}, sources, _query, all_params)
      when is_atom(field) do
    res = Helpers.quote_qualified_name(field, sources, idx)
    {res, all_params}
  end

  def expr({:&, _, [idx, fields, _counter]}, sources, query, _all_params) do
    {_, name, schema} = elem(sources, idx)

    if is_nil(schema) and is_nil(fields) do
      Helpers.error!(
        query,
        "ClickHouse requires a schema module when using selector " <>
          "#{inspect(name)} but none was given. " <>
          "Please specify a schema or specify exactly which fields from " <>
          "#{inspect(name)} you desire"
      )
    end

    Helpers.intersperse_map(fields, ", ", &[name, ?. | Helpers.quote_name(&1)])
  end

  def expr({:in, _, [_left, []]}, _sources, _query, all_params) do
    {"0", all_params}
  end

  def expr({:in, _, [left, right]}, sources, query, all_params) when is_list(right) do
    {args, all_params} =
      Helpers.intersperse_reduce(right, ?,, all_params, &expr(&1, sources, query, all_params))

    {exp, all_params} = expr(left, sources, query, all_params)
    {[exp, " IN (", args, ?)], all_params}
  end

  def expr({:in, _, [_, {:^, _, [_, 0]}]}, _sources, _query, all_params) do
    {"0", all_params}
  end

  def expr({:in, _, [left, {:^, _, [_, length]}]}, sources, query, all_params) do
    # TODO
    args = Enum.intersperse(List.duplicate(??, length), ?,)
    [expr(left, sources, query, all_params), " IN (", args, ?)]
  end

  def expr({:in, _, [left, right]}, sources, query, all_params) do
    {left, all_params} = expr(left, sources, query, all_params)
    {right, all_params} = expr(right, sources, query, all_params)

    # TODO: Any is not being supported
    {[
       left,
       " = ANY(",
       right,
       ?)
     ], all_params}
  end

  def expr({:is_nil, _, [arg]}, sources, query, all_params) do
    {exp, all_params} = expr(arg, sources, query, all_params)
    {[exp | " IS NULL"], all_params}
  end

  def expr({:not, _, [expr]}, sources, query, all_params) do
    case expr do
      {fun, _, _} when fun in @binary_ops ->
        {ex, all_params} = expr(expr, sources, query, all_params)
        {["NOT (", ex, ?)], all_params}

      _ ->
        {ex, all_params} = expr(expr, sources, query, all_params)
        {["~(", ex, ?)], all_params}
    end
  end

  def expr(%Ecto.SubQuery{query: query, params: _params}, _sources, _query, all_params) do
    {Pillar.Ecto.Query.all(query), all_params}
  end

  def expr({:fragment, _, [kw]}, _sources, query, _all_params)
      when is_list(kw) or tuple_size(kw) == 3 do
    Helpers.error!(query, "ClickHouse adapter does not support keyword or interpolated fragments")
  end

  def expr({:fragment, _, parts}, sources, query, all_params) do
    {expr, all_params} =
      Enum.reduce(parts, {[], all_params}, fn
        {:raw, part}, {acc, all_params} ->
          {[part | acc], all_params}

        {:expr, expr}, {acc, all_params} ->
          {expr, all_params} = expr(expr, sources, query, all_params)
          {[expr | acc], all_params}
      end)

    {Enum.reverse(expr), all_params}
  end

  def expr({fun, _, args}, sources, query, all_params) when is_atom(fun) and is_list(args) do
    {modifier, args} =
      case args do
        [rest, :distinct] -> {"DISTINCT ", [rest]}
        _ -> {[], args}
      end

    case handle_call(fun, length(args)) do
      {:binary_op, op} ->
        [left, right] = args

        {left, all_params} = op_to_binary(left, sources, query, all_params)
        {right, all_params} = op_to_binary(right, sources, query, all_params)

        xs = [
          left,
          op | right
        ]

        {xs, all_params}

      {:fun, fun} ->
        {exp, all_params} =
          Helpers.intersperse_reduce(args, ", ", all_params, &expr(&1, sources, query, &2))

        {[
           fun,
           ?(,
           modifier,
           exp,
           ?)
         ], all_params}
    end
  end

  def expr({:count, _, []}, _sources, _query, all_params), do: {"count(*)", all_params}

  def expr(list, sources, query, all_params) when is_list(list) do
    {exp, all_params} =
      Helpers.intersperse_reduce(list, ?,, all_params, &expr(&1, sources, query, &2))

    {["ARRAY[", exp, ?]], all_params}
  end

  def expr(%Decimal{} = decimal, _sources, _query, all_params) do
    {Decimal.to_string(decimal, :normal), all_params}
  end

  def expr(%Ecto.Query.Tagged{value: binary, type: :binary}, _sources, _query, all_params)
      when is_binary(binary) do
    {["0x", Base.encode16(binary, case: :lower)], all_params}
  end

  # def expr(%Ecto.Query.Tagged{value: other, type: {_, field}}, sources, query) do
  #   # We don't support joins for now.
  #   {_, name, schema} = elem(sources, 0)
  #   IO.inspect(["elem(sources, 0)", elem(sources, 0)])
  #   IO.inspect(["other", other])
  #   type = schema.__schema__(:type, field)
  #   [?", expr(other, sources, query), " AS ", Helpers.ecto_to_db(type), ")"]
  # end

  def expr(%Ecto.Query.Tagged{value: other}, sources, query, all_params) do
    # ["CAST(", expr(other, sources, query), " AS ", Helpers.ecto_to_db(type), ")"]
    expr(other, sources, query, all_params)
  end

  def expr(nil, _sources, _query, all_params), do: {"NULL", all_params}
  def expr(true, _sources, _query, all_params), do: {"1", all_params}
  def expr(false, _sources, _query, all_params), do: {"0", all_params}

  def expr(s, _s, _q, all_params) when is_binary(s) do
    {[?\', String.replace(s, "'", "''"), ?\'], all_params}
  end

  def expr(i, _s, _q, all_params) when is_integer(i), do: {Integer.to_string(i), all_params}
  def expr(f, _s, _q, all_params) when is_float(f), do: {Float.to_string(f), all_params}

  def interval(count, _interval, sources, query, all_params) do
    [expr(count, sources, query, all_params)]
  end

  def op_to_binary({op, _, [_, _]} = expr, sources, query, all_params) when op in @binary_ops do
    paren_expr(expr, sources, query, all_params)
  end

  def op_to_binary(expr, sources, query, all_params) do
    expr(expr, sources, query, all_params)
  end

  def returning(_returning), do: raise("RETURNING is not supported!")

  def create_names(%{sources: sources}) do
    create_names(sources, 0, tuple_size(sources)) |> List.to_tuple()
  end

  def create_names(sources, pos, limit) when pos < limit do
    [create_name(sources, pos) | create_names(sources, pos + 1, limit)]
  end

  def create_names(_sources, pos, pos) do
    [[]]
  end

  def create_name(sources, pos, as_prefix \\ []) do
    case elem(sources, pos) do
      {:fragment, _, _} ->
        {nil, as_prefix ++ [?f | Integer.to_string(pos)], nil}

      {table, schema, prefix} ->
        name = as_prefix ++ [create_alias(table) | Integer.to_string(pos)]
        {quote_table(prefix, table), name, schema}

      %Ecto.SubQuery{} ->
        {nil, as_prefix ++ [?s | Integer.to_string(pos)], nil}
    end
  end

  defp quote_table(nil, name), do: quote_table(name)
  defp quote_table(prefix, name), do: [quote_table(prefix), ?., quote_table(name)]

  defp quote_table(name) when is_atom(name),
    do: quote_table(Atom.to_string(name))

  defp quote_table(name) do
    if String.contains?(name, "\"") do
      raise "bad table name #{inspect(name)}"
    end

    [?", name, ?"]
  end

  defp create_alias(<<first, _rest::binary>>) when first in ?a..?z when first in ?A..?Z do
    first
  end

  defp create_alias(_) do
    ?t
  end

  alias Ecto.Query.BooleanExpr

  def param_extractor(%BooleanExpr{expr: expr}, sources, all_params) do
    case expr do
      {:and, _, xs} ->
        Enum.reduce(xs, all_params, fn expr, all_params ->
          param_extractor(expr, sources, all_params)
        end)

      expr ->
        param_extractor(expr, sources, all_params)
    end
  end

  def param_extractor({op, [], [param, _]}, sources, all_params) when op in @binary_ops do
    maybe_to_param_name(param, sources, all_params)
  end

  def param_extractor(_, _, all_params), do: all_params

  def maybe_to_param_name({{:., _, [{:&, _, [idx]}, field]}, _, []}, sources, all_params)
      when is_atom(field) do
    {_, _name, schema} = elem(sources, idx)

    type = schema.__schema__(:type, field)

    param = %QueryParam{
      type: type,
      field: field,
      name: "#{Atom.to_string(field)}_#{length(all_params)}",
      value: nil,
      clickhouse_type: Helpers.ecto_to_db(type)
    }

    [param | all_params]
  end

  def maybe_to_param_name(_, _, all_params), do: all_params
end
