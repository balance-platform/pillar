defmodule Pillar.TypeConvert.Base do
  @callback convert(any) :: any
  @callback convert(any, any) :: any
end
