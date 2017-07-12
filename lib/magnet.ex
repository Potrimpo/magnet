defmodule Magnet do
  @moduledoc """
  Provides functionality for dealing with magnet links.
  """

  # compare as strings so that external input is never free to fill up erlang vm atom registry
  @valid_keys ["xt", "dn", "tr"]

  @type parsed_magnet :: %{
    dn: String.t,
    xt: String.t,
    tr: String.t | [String.t]
  }
  
  ## PUBLIC API

  @doc """
  Turns a magnet URI into a map

  Returns a tuple of either {:ok, parsed_magnet} | {:error, message}

  ### Examples

    iex> Magnet.parse("magnet:?
      xt=urn:btih:b99f93d2df9472910941c4a315718fb0d1eff191
      &dn=The+Mummy+2017+HD-TS+x264-CPG
      &tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969
      &tr=udp%3A%2F%2Fzer0day.ch%3A1337"

      {:ok,
        %{
          dn: "The Mummy 2017 HD-TS x264-CPG",
          tr: [
            "udp%3A%2F%2Fzer0day.ch%3A1337",
            "udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969"
            ],
          xt: "urn:btih:b99f93d2df9472910941c4a315718fb0d1eff191"
        }
      }
  """
  @spec parse([String.t]) :: [{:ok, parsed_magnet} | {:error, String.t}]
  def parse(uris) when is_list(uris) do
    Task.async_stream(uris, &parse/1)
    |> Enum.to_list
  end

  @spec parse(String.t) :: {:ok, parsed_magnet} | {:error, String.t}
  def parse(uri) do
    String.trim_leading(uri, "magnet:?")
    |> String.split("&")
    |> Enum.map(&split_to_tuple/1)
    |> Enum.reduce(%{}, &handle_multiples/2) 
  end

  @doc """
  Returns only the specified parameter of a given magnet URI

  Returns a tuple of either {:ok, value} | {:error, message}

  ### Examples

    iex> Magnet.get("magnet:?
      xt=urn:btih:b99f93d2df9472910941c4a315718fb0d1eff191
      &dn=The+Mummy+2017+HD-TS+x264-CPG
      &tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969
      &tr=udp%3A%2F%2Fzer0day.ch%3A1337", :tr

      {:ok, [ "udp%3A%2F%2Fzer0day.ch%3A1337", "udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969" ] }
  """
  @spec get([String.t], atom | String.t) :: [{:ok, String.t | [String.t]} | {:error, String.t}]
  def get(uris, param) when is_list(uris) do
    Task.async_stream(uris, Magnet, :get, [param])
    |> Enum.to_list
  end

  @spec get(String.t, atom) :: {:ok, String.t | [String.t]} | {:error, String.t}
  def get(uri, param) when is_atom(param) do
    with parsed_magnet <- parse(uri),
         val <- Map.get(parsed_magnet, param),
         do: val
  end

  @spec get(String.t, String.t) :: {:ok, String.t | [String.t]} | {:error, String.t}
  def get(uri, param) do
    with parsed_magnet <- parse(uri),
         { key, _ } <- magnet_param_to_atom({ param, nil}),
         val <- Map.get(parsed_magnet, key),
         do: val
  end

  ## PRIVATE FUNCTIONS

  @spec split_to_tuple(String.t) :: {atom, String.t}
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

  @spec handle_multiples({atom, String.t}, parsed_magnet | map) :: parsed_magnet | map
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