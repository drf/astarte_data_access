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

defmodule Astarte.DataAccess.Interface do
  require Logger
  alias Astarte.Core.InterfaceDescriptor
  alias CQEx.Query
  alias CQEx.Result

  @spec retrieve_interface_row(:cqerl.client(), String.t(), integer) ::
          {:ok, keyword} | {:error, atom}
  def retrieve_interface_row(client, interface, major_version) do
    interface_statement = """
    SELECT name, major_version, minor_version, interface_id, type, ownership, aggregation,
      storage, storage_type, automaton_transitions, automaton_accepting_states
    FROM interfaces
    WHERE name=:name AND major_version=:major_version
    """

    interface_query =
      Query.new()
      |> Query.statement(interface_statement)
      |> Query.put(:name, interface)
      |> Query.put(:major_version, major_version)

    with {:ok, result} <- Query.call(client, interface_query),
         interface_row when is_list(interface_row) <- Result.head(result) do
      {:ok, interface_row}
    else
      :empty_dataset ->
        {:error, :interface_not_found}

      %{acc: _, msg: error_message} ->
        Logger.warn("retrieve_interface_row: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("retrieve_interface_row: failed with reason #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  @spec fetch_interface_descriptor(:cqerl.client(), String.t(), non_neg_integer) ::
          {:ok, %InterfaceDescriptor{}} | {:error, atom}
  def fetch_interface_descriptor(client, interface_name, major_version) do
    with {:ok, interface_row} <- retrieve_interface_row(client, interface_name, major_version) do
      InterfaceDescriptor.from_db_result(interface_row)
    end
  end

  @spec check_if_interface_exists(:cqerl.client(), String.t(), non_neg_integer) ::
          :ok | {:error, atom}
  def check_if_interface_exists(client, interface_name, major_version) do
    check_statement = """
    SELECT COUNT(*)
    FROM interfaces
    WHERE name=:name AND major_version=:major_version
    """

    interface_query =
      Query.new()
      |> Query.statement(check_statement)
      |> Query.put(:name, interface_name)
      |> Query.put(:major_version, major_version)

    with {:ok, result} <- Query.call(client, interface_query),
         [count: 1] <- Result.head(result) do
      :ok
    else
      [count: 0] ->
        {:error, :interface_not_found}

      %{acc: _, msg: error_message} ->
        Logger.warn("check_if_interface_exists: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("check_if_interface_exists: failed, reason: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end
end
