defmodule MayorGame.City.TownStatistics do
  alias __MODULE__
  alias MayorGame.City.{ResourceStatistics, BuildableStatistics}
  alias MayorGame.Rules
  use Accessible

  defstruct [
    :id,
    :title,
    :region,
    :climate,
    :season,
    :user,
    :patron,
    :contributor,
    :priorities,
    :tax_rates,
    :jobs_by_level,
    :vacancies_by_level,
    :total_citizens,
    :citizen_count_by_level,
    :employed_citizen_count_by_level,
    :resource_stats,
    :buildable_stats
  ]

  @type t ::
          %TownStatistics{
            # City
            id: integer | nil,
            title: String.t(),
            region: String.t(),
            climate: String.t(),

            # World
            season: atom,

            # user stats
            user: %MayorGame.Auth.User{},
            patron: integer,
            contributor: boolean,

            # controls in City
            priorities: %{String.t() => integer},
            tax_rates: %{integer => number},

            # objects in City
            jobs_by_level: %{integer => integer},
            vacancies_by_level: %{integer => integer},
            total_citizens: integer,
            citizen_count_by_level: %{integer => integer},
            employed_citizen_count_by_level: %{integer => integer},

            # changes
            resource_stats: %{atom => ResourceStatistics.t()},
            buildable_stats: %{atom => BuildableStatistics.t()}
          }

  @spec fromTown(Town.t(), World.t()) :: TownStatistics.t()
  def fromTown(town, world) do
    %TownStatistics{
      id: town.id,
      title: town.title,
      region: town.region,
      climate: town.climate,
      season: Rules.season_from_day(world.day),
      user: town.user,
      patron: town.patron,
      contributor: town.contributor,
      priorities: town.priorities,
      tax_rates: town.tax_rates,
      jobs_by_level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
      vacancies_by_level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
      total_citizens: length(town.citizens_blob),
      citizen_count_by_level: Enum.frequencies_by(town.citizens_blob, & &1["education"]),
      employed_citizen_count_by_level: %{},
      resource_stats: %{
        :money => %ResourceStatistics{
          title: "money",
          stock: town.treasury,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :housing => %ResourceStatistics{
          title: "housing",
          stock: 0,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :steel => %ResourceStatistics{
          title: "steel",
          stock: town.steel,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :uranium => %ResourceStatistics{
          title: "uranium",
          stock: town.uranium,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :gold => %ResourceStatistics{
          title: "gold",
          stock: town.gold,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :sulfur => %ResourceStatistics{
          title: "sulfur",
          stock: town.sulfur,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :shields => %ResourceStatistics{
          title: "shields",
          stock: town.shields,
          storage: nil,
          production: 0,
          consumption: 0
        },
        :missiles => %ResourceStatistics{
          title: "missiles",
          stock: town.missiles,
          storage: nil,
          production: 0,
          consumption: 0
        }
      },
      buildable_stats: %{}
    }
  end

  @spec getResource(TownStatistics.t(), atom) :: ResourceStatistics.t()
  def getResource(town_stats, resource) do
    # fetch the resource stat from this struct. If it is not found, return an empty one
    Map.get(town_stats.resource_stats, resource, %MayorGame.City.ResourceStatistics{})
  end

  @spec getBuildable(TownStatistics.t(), atom) :: BuildableStatistics.t()
  def getBuildable(town_stats, buildable) do
    # fetch the buildable stat from this struct. If it is not found, return an empty one
    Map.get(town_stats.buildable_stats, buildable, %MayorGame.City.BuildableStatistics{})
  end
end