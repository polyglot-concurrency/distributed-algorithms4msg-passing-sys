# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.Basic.Main do
  @moduledoc false

  alias NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.Basic.Process,
    as: MainProcess

  defmodule Manager do
    @moduledoc false

    use GenServer

    defstruct labels: %{}

    def new do
      {:ok, pid} = GenServer.start(Manager, nil)
      pid
    end

    def init(_) do
      a = MainProcess.new()
      b = MainProcess.new()
      c = MainProcess.new()
      i = MainProcess.new()
      j = MainProcess.new()
      k = MainProcess.new()
      f = MainProcess.new()
      g = MainProcess.new()

      MainProcess.set_neighbors(a, [b, i, j])
      MainProcess.set_neighbors(b, [a, c, j])
      MainProcess.set_neighbors(c, [b, f])
      MainProcess.set_neighbors(i, [a, j, f, k])
      MainProcess.set_neighbors(j, [a, b, i, f])
      MainProcess.set_neighbors(k, [i, f, g])
      MainProcess.set_neighbors(f, [i, j, c, k, g])
      MainProcess.set_neighbors(g, [k, f])

      labels = %{a => :a, b => :b, c => :c, i => :i, j => :j, k => :k, f => :f, g => :g}

      this = self
      MainProcess.set_function(a, fn -> send(this, :print) end)

      {:ok, %Manager{labels: labels}}
    end

    def handle_cast({:start, name}, state) do
      {a, _} = Enum.find(Map.to_list(state.labels), fn {_, l} -> l == name end)
      MainProcess.start(a)
      {:noreply, state}
    end

    def handle_info(:stop, state) do
      for {k, _} <- state.labels, do: MainProcess.stop(k)
      {:stop, :normal, :ok}
    end

    def handle_info(:print, state) do
      names = &Map.get(state.labels, &1, :no)

      for {k, v} <- state.labels do
        IO.puts("Node: #{v}")
        IO.puts("Parent: #{names.(MainProcess.get_parent(k))}")
        children = for ch <- MainProcess.get_children(k), do: names.(ch)
        if Enum.count(children) != 0, do: IO.puts("Children: #{inspect(children)}")
        IO.puts("")
      end

      send(self, :stop)

      {:noreply, state}
    end

    def start(pid, name), do: GenServer.cast(pid, {:start, name})

    def stop(pid), do: send(pid, :stop)
  end

  def run do
    a = Manager.new()
    Manager.start(a, :a)
  end
end
