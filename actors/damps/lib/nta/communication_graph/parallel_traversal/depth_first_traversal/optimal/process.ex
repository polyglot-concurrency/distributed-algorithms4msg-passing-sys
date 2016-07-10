# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.Optimal.Process do
    alias NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.Optimal.Process, as: Process

    use GenServer

    defstruct neighbors: MapSet.new, parent: nil, children: MapSet.new,
              function: nil

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

    def handle_cast(:start, state) do
        nparent = self
        k = Enum.random(state.neighbors)
        send(k, {:go, %{ sender: self, visited: MapSet.new([self]) }})
        nchildren = MapSet.new([k])

        {:noreply, %Process{ state | parent: nparent,
                                     children: nchildren }}
    end

    def handle_info({:go, data}, state) do
        nparent = data[:sender]

        nchildren = if MapSet.subset?(state.neighbors,
                                      data[:visited]) do
                        send(data[:sender], {:back, %{ sender: self,
                                                       visited: MapSet.union(data[:visited], MapSet.new([self])) }})
                        MapSet.new
                    else
                        k = Enum.random(MapSet.difference(state.neighbors, data[:visited]))
                        send(k, {:go, %{ sender: self,
                                         visited: MapSet.union(data[:visited], MapSet.new([self])) }})
                        MapSet.new([k])
                    end

        {:noreply, %Process{ state | parent: nparent,
                                     children: nchildren }}
    end

    def handle_info({:back, data}, state) do
        nchildren = if MapSet.subset?(state.neighbors,
                                      data[:visited]) do
                        if state.parent == self do
                            state.function.()
                        else
                            send(state.parent, {:back, %{ sender: self,
                                                          visited: data[:visited] }})
                        end

                        state.children
                    else
                        k = Enum.random(MapSet.difference(state.neighbors, data[:visited]))
                        send(k, {:go, %{ sender: self,
                                         visited: data[:visited] }})

                        MapSet.union(state.children, MapSet.new([k]))
                    end

        {:noreply, %Process{ state | children: nchildren }}
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
