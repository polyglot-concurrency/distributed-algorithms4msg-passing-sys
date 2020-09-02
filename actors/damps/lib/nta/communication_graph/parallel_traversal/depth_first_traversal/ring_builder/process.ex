# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.RingBuilder.Process do
  @moduledoc false

  alias NTA.CommunicationGraph.ParallelTraversal.DepthFirstTraversal.RingBuilder.Process,
    as: Process

  use GenServer

  defstruct neighbors: MapSet.new(),
            parent: nil,
            succ: nil,
            routing: Map.new(),
            first: nil,
            function: nil,
            init: nil

  def new do
    {:ok, pid} = GenServer.start(Process, nil)
    pid
  end

  def init(_), do: {:ok, %Process{}}

  def handle_cast(:stop, _), do: {:stop, :normal, :ok}

  def handle_cast({:set_neighbors, neighbors}, state),
    do: {:noreply, %Process{state | neighbors: MapSet.new(neighbors)}}

  def handle_cast({:set_function, f}, state), do: {:noreply, %Process{state | function: f}}

  def handle_cast(:start, state) do
    nparent = self()
    k = Enum.random(state.neighbors)
    send(k, {:go, %{sender: self(), visited: MapSet.new([self()]), last: self()}})
    nfirst = k

    {:noreply, %Process{state | parent: nparent, first: nfirst}}
  end

  def handle_cast(:walk, state) do
    send(self(), {:token, %{sender: self()}})
    {:noreply, %Process{state | init: self()}}
  end

  def handle_info({:go, data}, state) do
    nparent = data[:sender]
    nsucc = data[:last]

    nrouting =
      if MapSet.subset?(
           state.neighbors,
           data[:visited]
         ) do
        send(
          data[:sender],
          {:back,
           %{
             sender: self(),
             visited: MapSet.union(data[:visited], MapSet.new([self()])),
             last: self()
           }}
        )

        Map.put(state.routing, data[:sender], data[:sender])
      else
        k = Enum.random(MapSet.difference(state.neighbors, data[:visited]))

        send(
          k,
          {:go,
           %{
             sender: self(),
             visited: MapSet.union(data[:visited], MapSet.new([self()])),
             last: self()
           }}
        )

        Map.put(state.routing, k, data[:sender])
      end

    {:noreply, %Process{state | parent: nparent, succ: nsucc, routing: nrouting}}
  end

  def handle_info({:token, data}, state) do
    IO.puts("pid: #{inspect(self())}")
    IO.puts("Routing: #{inspect(state.routing)}")

    ndest =
      if data[:dest] == self() do
        # use the token!
        IO.puts("Token doing: #{inspect(self())}")
        state.succ
      else
        data[:dest]
      end

    k = state.routing[data[:sender]]

    if state.init != k do
      send(k, {:token, %{sender: self(), dest: ndest}})
    end

    {:noreply, state}
  end

  def handle_info(:finished, state) do
    state.function.()
    {:noreply, state}
  end

  def handle_info({:back, data}, state) do
    {nsucc, nrouting} =
      if MapSet.subset?(
           state.neighbors,
           data[:visited]
         ) do
        if state.parent == self() do
          send(self(), :finished)
          {data[:last], Map.put(state.routing, state.first, data[:sender])}
        else
          send(
            state.parent,
            {:back, %{sender: self(), visited: data[:visited], last: data[:last]}}
          )

          {state.succ, Map.put(state.routing, state.parent, data[:sender])}
        end
      else
        k = Enum.random(MapSet.difference(state.neighbors, data[:visited]))
        send(k, {:go, %{sender: self(), visited: data[:visited], last: data[:last]}})

        {state.succ, Map.put(state.routing, k, data[:sender])}
      end

    {:noreply, %Process{state | succ: nsucc, routing: nrouting}}
  end

  def start(pid), do: GenServer.cast(pid, :start)

  def stop(pid), do: GenServer.cast(pid, :stop)

  def set_neighbors(pid, neighbors),
    do: GenServer.cast(pid, {:set_neighbors, MapSet.new(neighbors)})

  def set_function(pid, f), do: GenServer.cast(pid, {:set_function, f})

  def start_token_walk(pid), do: GenServer.cast(pid, :walk)

  def handle_call(:get_parent, _from, state), do: {:reply, state.parent, state}

  def handle_call(:get_succ, _from, state), do: {:reply, state.succ, state}

  def get_parent(pid), do: GenServer.call(pid, :get_parent)

  def get_succ(pid), do: GenServer.call(pid, :get_succ)
end
