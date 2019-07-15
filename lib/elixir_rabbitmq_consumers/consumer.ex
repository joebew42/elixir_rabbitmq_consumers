defmodule ElixirRabbitMQConsumers.Consumer do
  use GenServer, restart: :transient
  use AMQP

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def consume(name, payload, {channel, tag, redelivered}) do
    :ok = GenServer.call(name, {:consume, payload, {channel, tag, redelivered}})
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call({:consume, payload, {channel, tag, redelivered}}, _from, []) do
    Logger.info("Received #{inspect(payload)}.")

    number = payload.id
    if number <= 10 do
      :ok = Basic.ack channel, tag
      Logger.info("Consumed a #{number}.")
    else
      :ok = Basic.reject channel, tag, requeue: false
      Logger.warn("#{number} is too big and was rejected.")
    end

    {:reply, :ok, []}
  rescue
    # Requeue unless it's a redelivered message.
    # This means we will retry consuming a message once in case of exception
    # before we give up and have it moved to the error queue
    #
    # You might also want to catch :exit signal in production code.
    # Make sure you call ack, nack or reject otherwise comsumer will stop
    # receiving messages.
    _exception ->
      :ok = Basic.reject channel, tag, requeue: not redelivered
      Logger.error("#{inspect(payload)} is a bad payload.")

      {:reply, :ok, []}
  end
end