#
# Copyright (C) 2018 Ispirata Srl
#
# This file is part of Astarte.
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#

defmodule Astarte.DataAccess.Data do
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias CQEx.Query
  alias CQEx.Result

  @individual_properties_table "individual_properties"

  @spec fetch_property(
          :cqerl.client(),
          Device.device_id(),
          %InterfaceDescriptor{},
          %Mapping{},
          String.t()
        ) :: {:ok, any} | {:error, atom}
  def fetch_property(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        %Mapping{} = mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    value_column = CQLUtils.type_to_db_column_name(mapping.value_type)

    fetch_property_value_statement = """
    SELECT #{value_column}
    FROM "#{interface_descriptor.storage}"
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    fetch_property_query =
      Query.new()
      |> Query.statement(fetch_property_value_statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:interface_id, interface_descriptor.interface_id)
      |> Query.put(:endpoint_id, mapping.endpoint_id)
      |> Query.put(:path, path)
      |> Query.consistency(:quorum)

    with {:ok, result} <- Query.call(db_client, fetch_property_query),
         [{_column, value}] when not is_nil(value) <- Result.head(result) do
      {:ok, value}
    else
      :empty_dataset ->
        {:error, :property_not_set}

      [{column, nil}] when is_atom(column) ->
        Logger.warn("Unexpected null value on #{path}, mapping: #{inspect(mapping)}.")
        {:error, :undefined_property}

      %{acc: _, msg: error_message} ->
        Logger.warn("fetch_property: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Database error while retrieving property: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  @spec path_exists?(
          :cqerl.client(),
          Device.device_id(),
          %InterfaceDescriptor{},
          %Mapping{},
          String.t()
        ) :: {:ok, boolean} | {:error, atom}
  def path_exists?(db_client, device_id, interface_descriptor, %Mapping{} = mapping, path)
      when is_binary(device_id) and is_binary(path) do
    # TODO: do not hardcode individual_properties here
    fetch_property_value_statement = """
    SELECT COUNT(*)
    FROM #{@individual_properties_table}
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    fetch_property_query =
      Query.new()
      |> Query.statement(fetch_property_value_statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:interface_id, interface_descriptor.interface_id)
      |> Query.put(:endpoint_id, mapping.endpoint_id)
      |> Query.put(:path, path)
      |> Query.consistency(:quorum)

    with {:ok, result} <- Query.call(db_client, fetch_property_query),
         [count: value] when not is_nil(value) <- Result.head(result) do
      case value do
        0 ->
          {:ok, false}

        1 ->
          {:ok, true}
      end
    else
      :empty_dataset ->
        {:error, :property_not_set}

      [count: nil] ->
        Logger.warn("Unexpected null value on #{path}, mapping: #{inspect(mapping)}.")
        {:error, :undefined_property}

      %{acc: _, msg: error_message} ->
        Logger.warn("path_exists?: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Database error while retrieving property: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  @spec fetch_last_path_update(
          :cqerl.client(),
          Device.device_id(),
          %InterfaceDescriptor{},
          %Mapping{},
          String.t()
        ) ::
          {:ok, %{value_timestamp: DateTime.t(), reception_timestamp: DateTime.t()}}
          | {:error, atom}
  def fetch_last_path_update(
        db_client,
        device_id,
        interface_descriptor,
        %Mapping{} = mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    # TODO: do not hardcode individual_properties here
    fetch_property_value_statement = """
    SELECT datetime_value, reception_timestamp, reception_timestamp_submillis
    FROM #{@individual_properties_table}
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    fetch_property_query =
      Query.new()
      |> Query.statement(fetch_property_value_statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:interface_id, interface_descriptor.interface_id)
      |> Query.put(:endpoint_id, mapping.endpoint_id)
      |> Query.put(:path, path)
      |> Query.consistency(:quorum)

    with {:ok, result} <- Query.call(db_client, fetch_property_query),
         [
           datetime_value: datetime_value,
           reception_timestamp: reception_timestamp,
           reception_timestamp_submillis: reception_timestamp_submillis
         ]
         when is_integer(reception_timestamp) and is_integer(datetime_value) <-
           Result.head(result),
         {:ok, value_t} <- DateTime.from_unix(datetime_value, :milliseconds),
         {:ok, reception_t} <-
           DateTime.from_unix(
             reception_timestamp * 1000 + div(reception_timestamp_submillis || 0, 10),
             :microseconds
           ) do
      {:ok,
       %{
         value_timestamp: value_t,
         reception_timestamp: reception_t
       }}
    else
      :empty_dataset ->
        {:error, :path_not_set}

      [datetime_value: _, reception_timestamp: _, reception_timestamp_submillis: _] ->
        Logger.warn("Unexpected null timestamp on #{path}, mapping: #{inspect(mapping)}.")
        {:error, :invalid_result}

      %{acc: _, msg: error_message} ->
        Logger.warn("fetch_last_path_update: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Database error while retrieving property: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end
end
