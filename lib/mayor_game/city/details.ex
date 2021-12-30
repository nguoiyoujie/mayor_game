defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Buildable, Town}

  @derive {Inspect, except: [:town]}

  schema "details" do
    field :city_treasury, :integer

    # add buildables to schema dynamically
    for buildable <- Buildable.buildables_list() do
      has_many buildable, {to_string(buildable), Buildable}
    end

    # ok so basically this is a macro
    # this "belongs to is called "city" but it belongs to the "town" schema
    # so there has to be a "whatever_id" has_many in the migration
    # automatically adds "_id" when looking for a foreign key, unless you set it
    belongs_to :town, Town

    timestamps()
  end

  @doc false
  def changeset(details, attrs) do
    detail_fields = [:city_treasury, :town_id]

    details
    # this basically defines the has_manys users can change
    |> cast(attrs, detail_fields)
    |> validate_required(detail_fields)
  end
end
