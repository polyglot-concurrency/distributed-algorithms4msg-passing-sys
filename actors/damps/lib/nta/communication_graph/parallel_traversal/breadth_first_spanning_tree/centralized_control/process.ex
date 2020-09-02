# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.BreadthFirstSpanningTree.CentralizedControl.Process do
  @moduledoc false

  alias NTA.CommunicationGraph.ParallelTraversal.BreadthFirstSpanningTree.CentralizedControl.Process,
    as: Process

  use GenServer

  defstruct neighbors: MapSet.new(),
            parent: nil,
            children: MapSet.new(),
            distance: -1,
            to_send: MapSet.new(),
            waiting_from: MapSet.new(),
            function: nil

  def new do
    {:ok, pid} = GenServer.start(Process, nil)
    pid
  end

  def init(_), do: {:ok, %Process{}}

  def handle_cast(:stop, _), do: {:stop, :normal, :ok}

  def handle_cast({:set_neighbors, neighbors}, state),
    do: {:noreply, %Process{state | neighbors: MapSet.new(neighbors)}}

  def handle_cast({:set_function, f}, state), do: {:noreply, %Process{state | function: f}}

  # The distinguished process p_a is the only process which receives the external message START()
  def handle_cast(:start, state) do
    nparent = self()
    nchildren = MapSet.new()
    ndistance = 0
    nto_send = state.neighbors

    for k <- nto_send, do: send(k, {:go, %{d: 0, sender: self()}})

    {:noreply,
     %Process{
       state
       | parent: nparent,
         children: nchildren,
         distance: ndistance,
         to_send: nto_send
     }}
  end

  def handle_info({:go, data}, state) do
    {:noreply,
     cond do
       !state.parent ->
         nparent = data[:sender]
         nchildren = MapSet.new()
         ndistance = data[:d] + 1

         nto_send =
           MapSet.difference(
             state.neighbors,
             MapSet.new([data[:sender]])
           )

         if MapSet.size(nto_send) == 0 do
           send(data[:sender], {:back, :stop, %{sender: self()}})
         else
           send(data[:sender], {:back, :continue, %{sender: self()}})
         end

         %Process{
           state
           | parent: nparent,
             children: nchildren,
             distance: ndistance,
             to_send: nto_send
         }

       state.parent == data[:sender] ->
         for k <- state.to_send, do: send(k, {:go, %{d: state.distance, sender: self()}})

         nwaiting_from = state.to_send

         %Process{state | waiting_from: nwaiting_from}

       true ->
         send(data[:sender], {:back, :no, %{sender: self()}})
         state
     end}
  end

  def handle_info({:back, resp, data}, state) do
    nwaiting_from =
      MapSet.difference(
        state.waiting_from,
        MapSet.new([data[:sender]])
      )

    nchildren =
      if MapSet.member?(MapSet.new([:continue, :stop]), resp) do
        MapSet.union(
          state.children,
          MapSet.new([data[:sender]])
        )
      else
        state.children
      end

    nto_send =
      if MapSet.member?(MapSet.new([:no, :stop]), resp) do
        MapSet.difference(
          state.to_send,
          MapSet.new([data[:sender]])
        )
      else
        state.to_send
      end

    {:noreply,
     cond do
       MapSet.size(nto_send) == 0 ->
         if state.parent == self() do
           state.function.()
         else
           send(state.parent, {:back, :stop, %{sender: self()}})
         end

         %Process{state | children: nchildren, waiting_from: nwaiting_from, to_send: nto_send}

       MapSet.size(nwaiting_from) == 0 ->
         nnwaiting_from =
           if state.parent == self() do
             for k <- nto_send, do: send(k, {:go, %{d: state.distance, sender: self()}})
             nto_send
           else
             send(state.parent, {:back, :continue, %{sender: self()}})
             nwaiting_from
           end

         %Process{state | children: nchildren, waiting_from: nnwaiting_from, to_send: nto_send}

       true ->
         %Process{state | children: nchildren, waiting_from: nwaiting_from, to_send: nto_send}
     end}
  end

  def start(pid), do: GenServer.cast(pid, :start)

  def stop(pid), do: GenServer.cast(pid, :stop)

  def set_neighbors(pid, neighbors),
    do: GenServer.cast(pid, {:set_neighbors, MapSet.new(neighbors)})

  def set_function(pid, f), do: GenServer.cast(pid, {:set_function, f})

  def handle_call(:get_parent, _from, state), do: {:reply, state.parent, state}

  def handle_call(:get_children, _from, state), do: {:reply, state.children, state}

  def handle_call(:get_distance, _from, state), do: {:reply, state.distance, state}

  def get_parent(pid), do: GenServer.call(pid, :get_parent)

  def get_children(pid), do: GenServer.call(pid, :get_children)

  def get_distance(pid), do: GenServer.call(pid, :get_distance)
end
