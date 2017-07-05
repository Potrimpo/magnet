defmodule Magnet do
  # compare as strings so that external input is never free to fill up erlang vm atom registry
  @valid_keys ["xt", "dn", "tr"]
  
  ## PUBLIC API

  @spec parse(String.t) :: tuple
  def parse(uri) do
    try do
      String.trim_leading(uri, "magnet:?")
      |> String.split("&")
      |> Enum.map(&split_to_tuple/1)
      |> Enum.reduce(%{}, &handle_multiples/2) 
      |> wrap(:ok)
    rescue
      e -> {:error, e.message}
    end
  end

  @spec get(String.t, atom) :: tuple
  def get(uri, param) when is_atom(param) do
    with {:ok, parsed_magnet} <- parse(uri),
         val <- Map.get(parsed_magnet, param),
         do: {:ok, val}
  end

  @spec get(String.t, String.t) :: tuple
  def get(uri, param) do
    try do
      with {:ok, parsed_magnet} <- parse(uri),
          { key, _ } <- magnet_param_to_atom({ param, nil}),
          val <- Map.get(parsed_magnet, key),
          do: {:ok, val}
    rescue
      e -> {:error, e.message}
    end
  end

  ## PRIVATE FUNCTIONS

  @spec split_to_tuple(String.t) :: tuple
  defp split_to_tuple(str) do
    String.split(str, "=")
    |> fn [k ,v] -> { String.trim(k), v } end.()
    |> magnet_param_to_atom
    |> pretty_print_name
  end

  @spec magnet_param_to_atom({ String.t | atom, any }) :: { atom, String.t }
  defp magnet_param_to_atom({key, val}) do
    if Enum.member?(@valid_keys, key) do
      { String.to_atom(key), val }
    else
       raise "invalid magnet parameter #{key}" 
    end
  end

  defp pretty_print_name({:dn, val}), do: { :dn, String.replace(val, "+", " ") }
  defp pretty_print_name(x), do: x

  @spec handle_multiples(tuple, map) :: map
  defp handle_multiples({ key, val }, acc) do
    if Map.has_key?(acc, key) do
      Map.update!(acc, key, fn
        old when is_list(old) -> [val | old]
        old -> [val, old]
      end)
    else
      Map.put(acc, key, val)
    end
  end

  defp wrap(data, :ok), do: {:ok, data}

end