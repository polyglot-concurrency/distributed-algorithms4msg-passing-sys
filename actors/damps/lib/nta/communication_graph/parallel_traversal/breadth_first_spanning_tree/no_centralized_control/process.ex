# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.BreadthFirstSpanningTree.NoCentralizedControl.Process do
    alias NTA.CommunicationGraph.ParallelTraversal.BreadthFirstSpanningTree.NoCentralizedControl.Process, as: Process

    use GenServer

    defstruct neighbors: MapSet.new, parent: nil, children: MapSet.new,
              expexted_msg: 0, level: 0, function: nil

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
        send(self, {:go, %{ level: -1, sender: self }})
        {:noreply, state}
    end

    defp go_common(data, state, new_level) do
        nparent = data[:sender]
        nchildren = MapSet.new
        nlevel = data[:level] + 1
        nexpexted_msg = MapSet.size(MapSet.difference(state.neighbors,
                                                      MapSet.new([data[:sender]])))

        if nexpexted_msg == 0 do
            send(data[:sender], {:back, :yes, %{level: new_level, sender: self}})
        else
            for id <- MapSet.difference(state.neighbors,
                                        MapSet.new([data[:sender]])), do:
                send(id, {:go, %{level: data[:level] + 1, sender: self}})
        end

        %Process{state | parent: nparent,
                         children: nchildren,
                         expexted_msg: nexpexted_msg,
                         level: nlevel}
    end

    def handle_info({:go, data}, state) do
        {:noreply, cond do
                        ! state.parent ->
                            go_common(data, state, data[:level] + 1)

                        state.level > data[:level] + 1 ->
                            go_common(data, state, state.level)

                        true ->
                            send(data[:sender], {:back, :no, %{level: data[:level] + 1, sender: self}})
                            state
                   end}
    end

    def handle_info({:back, resp, data}, state) do
        if data[:level] == state.level + 1 do
            nchildren = if resp == :yes do
                            MapSet.put(state.children, data[:sender])
                        else
                            state.children
                        end

            nexpexted_msg = state.expexted_msg - 1
            if nexpexted_msg == 0 do
                if state.parent != self do
                    send(state.parent, {:back, :yes, %{level: state.level, sender: self}})
                else
                    state.function.()
                end
            end
            {:noreply, %Process{ state | children: nchildren, expexted_msg: nexpexted_msg }}
        else
            {:noreply, state}
        end
    end

    def start(pid), do: GenServer.cast(pid, :start)

    def stop(pid), do: GenServer.cast(pid, :stop)

    def set_neighbors(pid, neighbors), do: GenServer.cast(pid, {:set_neighbors, MapSet.new(neighbors)})

    def set_function(pid, f), do: GenServer.cast(pid, {:set_function, f})

    def handle_call(:get_parent, _from, state), do:
        {:reply, state.parent, state}

    def handle_call(:get_children, _from, state), do:
        {:reply, state.children, state}

    def handle_call(:get_level, _from, state), do:
        {:reply, state.level, state}

    def get_parent(pid), do: GenServer.call(pid, :get_parent)

    def get_children(pid), do: GenServer.call(pid, :get_children)

    def get_level(pid), do: GenServer.call(pid, :get_level)

end
