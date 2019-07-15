defmodule ElixirRabbitMQConsumers.ConsumerSupervisor do
  use DynamicSupervisor

  alias ElixirRabbitMQConsumers.Consumer

  @number_of_consumers 100

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def consume(payload, {channel, tag, redelivered}) do
    consumer_id = consumer_id_for(payload.id)

    consumer_pid = case start_consumer(consumer_id) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid
    end

    :ok = Consumer.consume(consumer_pid, payload, {channel, tag, redelivered})
  end

  defp start_consumer(name) when is_atom(name) do
    DynamicSupervisor.start_child(__MODULE__, {Consumer, [name: name]})
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp consumer_id_for(id) do
    id
    |> rem(@number_of_consumers)
    |> Integer.to_string()
    |> String.to_atom()
  end
end