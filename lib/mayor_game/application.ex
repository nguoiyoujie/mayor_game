defmodule MayorGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      MayorGame.Repo,
      # Start the Telemetry supervisor
      MayorGameWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: MayorGame.PubSub},
      # Start the Endpoint (http/https)
      MayorGameWeb.Endpoint,

      # start cityCalculator process with initial value 1
      # oh this is how you can start multiple children
      # Start a worker by calling: MayorGame.CityCalculator.start_link(arg)

      Supervisor.child_spec({MayorGame.CityMigrator, 1}, id: :city_migrator),
      Supervisor.child_spec({MayorGame.CityCalculator, 1}, id: :city_calculator),

      # clean up old records a la https://github.com/ZennerIoT/pow_postgres_store
      {Pow.Postgres.Store.AutoDeleteExpired, [interval: :timer.hours(1)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MayorGame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MayorGameWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
