# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.Learning.Process do
    alias NTA.CommunicationGraph.Learning.Process, as: Process

    use GenServer

    defstruct proc_known: MapSet.new, channels_known: MapSet.new,
              part: false, neighbors: MapSet.new

    def new do
        {:ok, pid} = GenServer.start(Process, nil)
        pid
    end

    def init(_), do: {:ok, %Process{}}

    def handle_cast(:start, state) do
        if not state.part do
            for id <- state.neighbors, do:
                send(id, {:position, self, state.neighbors})

            {:noreply, %Process{ state | part: true }}
        else
            {:noreply, state}
        end
    end

    def handle_cast(:stop, state), do: {:stop, :normal, state}

    def handle_cast({:set_neighbors, neighbors}, _) do
        {:noreply, %Process{
                            proc_known: MapSet.new([self]),
                            neighbors: neighbors,
	                        channels_known: MapSet.new(Enum.map(neighbors,
                                                                &{self, &1}))
                   }
        }
    end

    def handle_info({:position, id, neighbors}, state) do
        if not state.part, do: start(self)
        if not MapSet.member?(state.proc_known, id) do
            nproc = MapSet.put(state.proc_known, id)
            nchannels = MapSet.union(state.channels_known,
                                    MapSet.new(
                                        Enum.map(state.neighbors,
                                                 &{id, &1})
                                              ))

            for idy <- MapSet.difference(state.neighbors, MapSet.new([id])), do:
                send(idy, {:position, id, neighbors})

            if Enum.all?(Enum.map(state.channels_known,
                                                 fn {a, b} -> [a, b] end
                                                 ),
                        &MapSet.subset?(MapSet.new(&1), state.proc_known)
	                     ), do: # the process knows the communication graph

            {:noreply, %Process{ state | proc_known: nproc, channels_known: nchannels }}
        end
        {:noreply, state}
    end

    def start(pid), do: GenServer.cast(pid, :start)

    def stop(pid), do: GenServer.cast(pid, :stop)

    def set_neighbors(pid, neighbors), do: GenServer.cast(pid, {:set_neighbors, MapSet.new(neighbors)})

end
