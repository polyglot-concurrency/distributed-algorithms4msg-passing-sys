# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.RootedSpanningTree.Main do
  @moduledoc false

  alias NTA.CommunicationGraph.ParallelTraversal.RootedSpanningTree.Process, as: MainProcess

  def run do
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

    this = self

    MainProcess.set_convergecast_function(
      a,
      fn val_set ->
        for _v <- val_set do
          # IO.inspect(v)
        end

        send(this, :ok)
      end
    )

    MainProcess.start(a)

    receive do
      _ ->
        labels = %{a => :a, b => :b, c => :c, i => :i, j => :j, k => :k, f => :f, g => :g}
        names = &Map.get(labels, &1, :no)

        for {k, v} <- labels do
          IO.puts("Node: #{v}")
          IO.puts("Parent: #{names.(MainProcess.get_parent(k))}")
          children = for ch <- MainProcess.get_children(k), do: names.(ch)
          if Enum.count(children) != 0, do: IO.puts("Children: #{inspect(children)}")
          IO.puts("")
        end
    end
  end
end
