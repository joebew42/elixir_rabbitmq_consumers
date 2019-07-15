defmodule ElixirRabbitMQConsumers.Payload do
  def decode!(payload) do
    payload
    |> Jason.decode!()
    |> AtomicMap.convert()
  end

  def validate!(%{id: id} = payload) when is_number(id) do
    payload
  end
  def validate!(payload) do
    raise "#{inspect(payload)} is not a valid payload"
  end
end