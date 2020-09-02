# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.RootedSpanningTree.Process do
  @moduledoc false

  alias NTA.CommunicationGraph.ParallelTraversal.RootedSpanningTree.Process, as: Process

  use GenServer

  defstruct neighbors: MapSet.new(),
            parent: nil,
            children: MapSet.new(),
            expexted_msg: 0,
            value: nil,
            val_sets: [],
            function: nil

  def new do
    {:ok, pid} = GenServer.start(Process, nil)
    pid
  end

  def init(_), do: {:ok, %Process{}}

  def handle_cast(:stop, _), do: {:stop, :normal, :ok}

  def handle_cast({:set_convergecast_function, f}, state),
    do: {:noreply, %Process{state | function: f}}

  # The distinguished process p_a is the only process which receives the external message START()
  def handle_cast(:start, state) do
    for id <- state.neighbors, do: send(id, {:go, %{sender: self}})

    {:noreply, %Process{state | parent: self, expexted_msg: MapSet.size(state.neighbors)}}
  end

  def handle_cast({:set_neighbors, neighbors}, state),
    do: {:noreply, %Process{state | neighbors: MapSet.new(neighbors)}}

  def handle_info({:go, data}, state) do
    if !state.parent do
      nparent = data[:sender]
      nchildren = MapSet.new()
      nexpexted_msg = MapSet.size(state.neighbors) - 1

      if nexpexted_msg == 0 do
        send(data[:sender], {:back, %{sender: self, val_set: [{self, state.value}]}})
      else
        for id <-
              MapSet.difference(
                state.neighbors,
                MapSet.new([data[:sender]])
              ),
            do: send(id, {:go, %{sender: self}})
      end

      {:noreply,
       %Process{
         state
         | parent: nparent,
           children: nchildren,
           expexted_msg: nexpexted_msg
       }}
    else
      send(data[:sender], {:back, nil})
      {:noreply, state}
    end
  end

  def handle_info({:back, data}, state) do
    nexpexted_msg = state.expexted_msg - 1

    nstate =
      if data do
        %Process{
          state
          | expexted_msg: nexpexted_msg,
            val_sets: data[:val_set] ++ state.val_sets,
            children: MapSet.put(state.children, data[:sender])
        }
      else
        %Process{state | expexted_msg: nexpexted_msg}
      end

    if nstate.expexted_msg == 0 do
      nval_set = nstate.val_sets ++ [{self, state.value}]
      pr = state.parent

      if pr != self do
        send(pr, {:back, %{sender: self, val_set: nval_set}})
        # Partial result
      else
        state.function.(nval_set)
        # Final result
      end
    end

    {:noreply, nstate}
  end

  def start(pid), do: GenServer.cast(pid, :start)

  def stop(pid), do: GenServer.cast(pid, :stop)

  def go(pid, data), do: GenServer.cast(pid, {:go, data})

  def back(pid, val_set), do: GenServer.cast(pid, {:go, val_set})

  def set_neighbors(pid, neighbors),
    do: GenServer.cast(pid, {:set_neighbors, MapSet.new(neighbors)})

  def set_convergecast_function(pid, f), do: GenServer.cast(pid, {:set_convergecast_function, f})

  def handle_call(:get_parent, _from, state), do: {:reply, state.parent, state}

  def handle_call(:get_children, _from, state), do: {:reply, state.children, state}

  def get_parent(pid), do: GenServer.call(pid, :get_parent)

  def get_children(pid), do: GenServer.call(pid, :get_children)
end
