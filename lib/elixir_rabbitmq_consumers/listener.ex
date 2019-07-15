defmodule ElixirRabbitMQConsumers.Listener do
  use GenServer
  use AMQP

  require Logger

  alias ElixirRabbitMQConsumers.{ConsumerSupervisor, Payload}

  @host "amqp://localhost"
  @reconnect_interval 10_000
  @exchange "consumer_test_exchange"
  @queue "consumer_test_queue"
  @queue_error "#{@queue}_error"

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    send(self(), :connect)
    {:ok, nil}
  end

  def get_connection do
    case GenServer.call(__MODULE__, :get) do
      nil -> {:error, :not_connected}
      conn -> {:ok, conn}
    end
  end

  def handle_call(:get, _, conn) do
    {:reply, conn, conn}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, {_conn, chan} = state) do
    try do
      payload
      |> Payload.decode!()
      |> Payload.validate!()
      |> ConsumerSupervisor.consume({chan, tag, redelivered})
    rescue
      _error ->
        :ok = Basic.reject chan, tag, requeue: not redelivered
        Logger.error("Failed to consume #{payload}.")
    end

    {:noreply, state}
  end

  def handle_info(:connect, state) do
    case Connection.open(@host) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)

        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)

        # Limit unacknowledged messages to 10
        :ok = Basic.qos(chan, prefetch_count: 10)
        # Register the GenServer process as a consumer
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)

        {:noreply, {conn, chan}}

      {:error, _} ->
        Logger.error("Failed to connect #{@host}. Reconnecting later...")
        # Retry later
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_lost, reason}, nil}
  end

  defp setup_queue(chan) do
    {:ok, _} = Queue.declare(chan, @queue_error, durable: true)

    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} =
      Queue.declare(chan, @queue,
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, @queue_error}
        ]
      )

    :ok = Exchange.fanout(chan, @exchange, durable: true)
    :ok = Queue.bind(chan, @queue, @exchange)
  end
end
