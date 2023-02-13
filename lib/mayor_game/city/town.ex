defmodule MayorGame.City.Town do
  @moduledoc """
      A %Town{} is the highest-level representation of a "town" in-game
      It contains:
      __meta__: Ecto.Schema.Metadata.t(),
      id: integer | nil,
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil,
      title: String.t(),
      region: String.t(),
      climate: String.t(),
      logs: list(String.t()),
      tax_rates: map,
      user: %MayorGame.Auth.User{},
      citizens: list(Citizens.t()),
      pollution: integer,
      treasury: integer
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Buildable}
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  # don't print these on inspect
  @derive {Inspect, except: [:logs, :citizens]}

  @typedoc """
      Type for %Town{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t ::
          %__MODULE__{
            __meta__: Ecto.Schema.Metadata.t(),
            id: integer | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil,
            title: String.t(),
            region: String.t(),
            climate: String.t(),
            logs: list(String.t()),
            tax_rates: map,
            user: %MayorGame.Auth.User{},
            citizens: list(Citizens.t()),
            pollution: integer,
            treasury: integer,
            citizen_count: integer,
            citizens_blob: list(map),
            patron: integer,
            # logs ——————————————————————————————
            logs_emigration_housing: map,
            logs_emigration_taxes: map,
            logs_emigration_jobs: map,
            logs_immigration: map,
            logs_attacks: map,
            logs_edu: map,
            logs_deaths_pollution: integer,
            logs_deaths_age: integer,
            logs_deaths_housing: integer,
            logs_deaths_attacks: integer,
            logs_births: integer,

            # Resources————————————————————————————
            steel: integer,
            missiles: integer,
            shields: integer,
            sulfur: integer,
            gold: integer,
            uranium: integer,

            # Buildings ————————————————————————————
            huts: integer,
            single_family_homes: integer,
            multi_family_homes: integer,
            homeless_shelters: integer,
            apartments: integer,
            high_rises: integer,
            roads: integer,
            highways: integer,
            airports: integer,
            bus_lines: integer,
            subway_lines: integer,
            bike_lanes: integer,
            bikeshare_stations: integer,
            coal_plants: integer,
            wind_turbines: integer,
            solar_plants: integer,
            nuclear_plants: integer,
            dams: integer,
            carbon_capture_plants: integer,
            parks: integer,
            libraries: integer,
            schools: integer,
            middle_schools: integer,
            high_schools: integer,
            universities: integer,
            research_labs: integer,
            retail_shops: integer,
            factories: integer,
            mines: integer,
            office_buildings: integer,
            theatres: integer,
            arenas: integer,
            hospitals: integer,
            doctor_offices: integer,
            air_bases: integer,
            defense_bases: integer
          }

  schema "cities" do
    field(:title, :string)
    field(:region, :string)
    field(:climate, :string)
    field(:pollution, :integer)
    field(:treasury, :integer)
    field(:citizen_count, :integer)
    field(:steel, :integer)
    field(:missiles, :integer)
    field(:shields, :integer)
    field(:sulfur, :integer)
    field(:gold, :integer)
    field(:uranium, :integer)

    field(:patron, :integer)
    field :citizens_blob, {:array, :map}, null: false, default: []

    # this corresponds to an elixir list
    field(:logs, {:array, :string})
    field(:tax_rates, :map)
    belongs_to(:user, MayorGame.Auth.User)

    # logs ——————————————————————————————
    field :logs_emigration_housing, :map, default: %{}
    field :logs_emigration_taxes, :map, default: %{}
    field :logs_emigration_jobs, :map, default: %{}
    field :logs_immigration, :map, default: %{}
    field :logs_attacks, :map, default: %{}
    field :logs_edu, :map, default: %{}
    field :logs_deaths_pollution, :integer, default: 0
    field :logs_deaths_age, :integer, default: 0
    field :logs_deaths_housing, :integer, default: 0
    field :logs_deaths_attacks, :integer, default: 0
    field :logs_births, :integer, default: 0

    # outline relationship between city and citizens
    # this has to be passed as a list []
    has_many(:citizens, Citizens)

    # buildable schema
    for buildable <- MayorGame.City.Buildable.buildables_list() do
      field(buildable, :integer)
    end

    timestamps()
  end

  def regions do
    [
      "ocean",
      "mountain",
      "desert",
      "forest",
      "lake"
    ]
  end

  def climates do
    [
      "arctic",
      "tundra",
      "temperate",
      "subtropical",
      "tropical"
    ]
  end

  @doc false
  def changeset(%MayorGame.City.Town{} = town, attrs) do
    town
    # add a validation here to limit the types of regions
    |> cast(
      attrs,
      [
        :title,
        :pollution,
        :citizen_count,
        :treasury,
        :region,
        :climate,
        :user_id,
        :logs,
        :tax_rates,
        :steel,
        :missiles,
        :shields,
        :sulfur,
        :gold,
        :uranium,
        :patron,
        :citizens_blob,
        :logs_emigration_housing,
        :logs_emigration_taxes,
        :logs_emigration_jobs,
        :logs_immigration,
        :logs_attacks,
        :logs_edu,
        :logs_deaths_pollution,
        :logs_deaths_age,
        :logs_deaths_housing,
        :logs_deaths_attacks,
        :logs_births
      ] ++ Buildable.buildables_list()
    )
    |> validate_required([:title, :region, :climate, :user_id])
    |> validate_length(:title, min: 1, max: 20)
    |> validate_inclusion(:region, regions())
    |> validate_inclusion(:climate, climates())
    |> unique_constraint(:title)
  end
end
