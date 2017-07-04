defmodule Magnet do
  @valid_keys ["xt", "dn", "tr"]
  
  @spec parse(String.t) :: Map
  def parse(uri) do
    String.trim_leading(uri, "magnet:?")
    |> String.split("&")
    |> Enum.map(&split_to_tuple/1)
    |> Enum.reduce(%{}, &handle_multiples/2) 
  end

  @spec split_to_tuple(String.t) :: Tuple
  defp split_to_tuple(str) do
    String.split(str, "=")
    |> fn [k ,v] -> { String.trim(k), v } end.()
    |> magnet_param_to_atom
    |> case do
      { :dn, v } -> { :dn, String.replace(v, "+", " ") } # pretty print display name
      pair -> pair
    end
  end

  @spec magnet_param_to_atom({ String.t, String.t }) :: { atom, String.t }
  defp magnet_param_to_atom({key, val}) do
    case Enum.member?(@valid_keys, key) do
      true -> { String.to_atom(key), val }
      _ -> raise "invalid magnet parameter #{inspect key}"
    end
  end

  @spec handle_multiples(Tuple, Map) :: Map
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

end