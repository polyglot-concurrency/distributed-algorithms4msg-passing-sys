# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.Basic.Process do
    alias NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.Basic.Process, as: Process

    use GenServer

    defstruct neighbors: MapSet.new, parent: nil, children: MapSet.new,
              visited: MapSet.new, function: nil

    def new do
        {:ok, pid} = GenServer.start(Process, nil)
        pid
    end

    def init(_), do: {:ok, %Process{}}

    def handle_cast(:stop, _), do: {:stop, :normal, :ok}

    def handle_cast({:set_neighbors, neighbors}, state), do:
        {:noreply, %Process{ state | neighbors: MapSet.new(neighbors) }}

    def handle_cast({:set_function, f}, state), do:
        {:noreply, %Process{ state | function: f }}

    def handle_cast(:start, state) do # The distinguished process p_a is the only process which receives the external message START()
        nparent = self
        nchildren = MapSet.new
        nvisited = MapSet.new

        k = Enum.random(state.neighbors)
        send(k, {:go, %{ sender: self }})

        {:noreply, %Process{ state | parent: nparent,
                                     children: nchildren,
                                     visited: nvisited }}
    end

    def handle_info({:go, data}, state) do
        if ! state.parent do
            nparent = data[:sender]
            nchildren = MapSet.new
            nvisited = MapSet.new([data[:sender]])

            if nvisited === state.neighbors do
                send(data[:sender], {:back, :yes, %{ sender: self }})
            else
                k = Enum.random(MapSet.difference(state.neighbors, nvisited))
                send(k, {:go, %{ sender: self }})
            end
            {:noreply, %Process{ state | parent: nparent,
                                         children: nchildren,
                                         visited: nvisited }}
        else
            send(data[:sender], {:back, :no, %{ sender: self }})
            {:noreply, state}
        end
    end

    def handle_info({:back, resp, data}, state) do
        nchildren = if resp == :yes do
                        MapSet.union(state.children,
                                     MapSet.new([data[:sender]]))
                    else
                        state.children
                    end

        nvisited = MapSet.union(state.visited,
                                MapSet.new([data[:sender]]))

        if nvisited === state.neighbors do
            if state.parent == self do
                state.function.()
            else
                send(state.parent, {:back, :yes, %{ sender: self }})
            end
        else
            k = Enum.random(MapSet.difference(state.neighbors, nvisited))
            send(k, {:go, %{ sender: self }})
        end

        {:noreply, %Process{ state | children: nchildren,
                                     visited: nvisited }}
    end

    def start(pid), do: GenServer.cast(pid, :start)

    def stop(pid), do: GenServer.cast(pid, :stop)

    def set_neighbors(pid, neighbors), do: GenServer.cast(pid, {:set_neighbors, MapSet.new(neighbors)})

    def set_function(pid, f), do: GenServer.cast(pid, {:set_function, f})

    def handle_call(:get_parent, _from, state), do:
        {:reply, state.parent, state}

    def handle_call(:get_children, _from, state), do:
        {:reply, state.children, state}

    def get_parent(pid), do: GenServer.call(pid, :get_parent)

    def get_children(pid), do: GenServer.call(pid, :get_children)

end
