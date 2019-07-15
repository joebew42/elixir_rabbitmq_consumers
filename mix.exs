defmodule ElixirRabbitMQConsumers.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_rabbitmq_consumers,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ElixirRabbitMQConsumers.Application, []}
    ]
  end

  defp deps do
    [
      {:atomic_map, "~> 0.9.3"},
      {:jason, "~> 1.1"},
      {:amqp, "~> 1.2"}
    ]
  end
end
