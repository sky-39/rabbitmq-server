## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


defmodule EvalCommandTest do
  use ExUnit.Case, async: false
  import TestHelper
  import ExUnit.CaptureIO

  @command RabbitMQ.CLI.Ctl.Commands.EvalCommand

  setup_all do
    RabbitMQ.CLI.Distribution.start()
    :net_kernel.connect_node(get_rabbit_hostname)

    on_exit([], fn ->
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  setup _ do
    {:ok, opts: %{node: get_rabbit_hostname}}
  end

  test "validate: on an inappropriate number of arguments, validate should return an arg count error" do
    assert @command.validate([], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["too", "many"], %{}) == {:validation_failure, :too_many_args}
    assert @command.validate(["three", "too", "many"], %{}) == {:validation_failure, :too_many_args}
  end

  test "validate: report empty expression" do
    assert @command.validate([""], %{}) == {:validation_failure, "Expression could not be empty"}
  end

  test "validate: Syntax error in command" do
    assert @command.validate(["foo bar"], %{}) == {:validation_failure, "syntax error before: bar"}
  end

  test "run: request to a non-existent node returns nodedown", context do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target}


    assert @command.run(["ok."], opts) == {:badrpc, :nodedown}
  end

  test "run: executes erlang code", context do
    assert @command.run(["foo."], context[:opts]) == {:ok, :foo}
    assert @command.run(["length([1,2,3])."], context[:opts]) == {:ok, 3}
    assert @command.run(["lists:sum([1,2,3])."], context[:opts]) == {:ok, 6}
    {:ok, apps} = @command.run(["application:loaded_applications()."], context[:opts])
    assert is_list(apps)
  end

  test "run: executes on rabbit node", context do
    {:ok, apps} = @command.run(["application:loaded_applications()."], context[:opts])
    assert is_list(apps)
    assert List.keymember?(apps, :rabbit, 0)
  end

  test "run: returns stdout", context do
    assert capture_io(fn ->
      assert @command.run(["io:format(\"output\")."], context[:opts]) == {:ok, :ok}
    end) == "output"
  end
end