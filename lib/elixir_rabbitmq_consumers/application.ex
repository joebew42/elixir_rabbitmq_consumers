defmodule ElixirRabbitMQConsumers.Application do
  use Application

  def start(_type, _args) do
    children = [
      {ElixirRabbitMQConsumers.Listener, []},
      {ElixirRabbitMQConsumers.ConsumerSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: ElixirRabbitMQConsumers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
