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

defmodule Astarte.DataAccess.DatabaseTest do
  use ExUnit.Case
  alias Astarte.DataAccess.Database

  test "just connect to the database" do
    {status, _db_client} = Database.connect()

    assert status == :ok
  end

  test "connect to missing realm" do
    assert Database.connect("missing") == {:error, :database_connection_error}
  end
end
