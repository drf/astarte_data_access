#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataAccess.InterfacesTest do
  use ExUnit.Case
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Interface

  @simplestreamtest_interface_id <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221,
                                   24, 201, 175>>

  @simplestreamtest_interface_descriptor %InterfaceDescriptor{
    aggregation: :individual,
    automaton:
      {%{
         {0, ""} => 1,
         {0, "foo"} => 3,
         {1, "value"} => 2,
         {3, ""} => 4,
         {4, "blobValue"} => 6,
         {4, "longValue"} => 7,
         {4, "stringValue"} => 5,
         {4, "timestampValue"} => 8
       },
       %{
         2 => <<117, 1, 14, 27, 25, 158, 238, 252, 221, 53, 210, 84, 176, 226, 9, 36>>,
         5 => <<57, 7, 212, 29, 91, 202, 50, 157, 158, 81, 76, 234, 42, 84, 169, 154>>,
         6 => <<122, 164, 76, 17, 34, 115, 71, 217, 230, 36, 74, 224, 41, 222, 222, 170>>,
         7 => <<239, 249, 87, 207, 3, 223, 222, 237, 151, 132, 168, 112, 142, 61, 140, 185>>,
         8 => <<52, 108, 128, 228, 202, 153, 98, 116, 129, 246, 123, 28, 27, 229, 149, 33>>
       }},
    interface_id: @simplestreamtest_interface_id,
    major_version: 1,
    minor_version: 0,
    name: "com.test.SimpleStreamTest",
    ownership: :device,
    storage: "individual_datastreams",
    storage_type: :multi_interface_individual_datastream_dbtable,
    type: :datastream
  }

  setup do
    DatabaseTestHelper.seed_data()
  end

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  test "check if interfaces exists" do
    {:ok, db_client} = Database.connect("autotestrealm")

    assert Interface.check_if_interface_exists(db_client, "com.test.SimpleStreamTest", 0) ==
             {:error, :interface_not_found}

    assert Interface.check_if_interface_exists(db_client, "com.test.SimpleStreamTest", 1) == :ok

    assert Interface.check_if_interface_exists(db_client, "com.test.SimpleStreamTest", 2) ==
             {:error, :interface_not_found}

    assert Interface.check_if_interface_exists(db_client, "com.Missing", 1) ==
             {:error, :interface_not_found}

    assert Interface.check_if_interface_exists(db_client, "com.example.TestObject", 0) ==
             {:error, :interface_not_found}

    assert Interface.check_if_interface_exists(db_client, "com.example.TestObject", 1) == :ok
  end

  test "fetch_interface_descriptor returns an InterfaceDescriptor struct" do
    {:ok, db_client} = Database.connect("autotestrealm")

    assert Interface.fetch_interface_descriptor(db_client, "com.test.SimpleStreamTest", 1) ==
             {:ok, @simplestreamtest_interface_descriptor}
  end

  test "retrieve_interface_row returns a row with expected values" do
    {:ok, db_client} = Database.connect("autotestrealm")

    {:ok, row} = Interface.retrieve_interface_row(db_client, "com.test.SimpleStreamTest", 1)

    assert is_list(row) == true

    assert Keyword.fetch(row, :name) == {:ok, "com.test.SimpleStreamTest"}
    assert Keyword.fetch(row, :interface_id) == {:ok, @simplestreamtest_interface_id}
    assert Keyword.fetch(row, :major_version) == {:ok, 1}
    assert Keyword.fetch(row, :minor_version) == {:ok, 0}
  end
end
