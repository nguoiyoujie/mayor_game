defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset

  schema "details" do
    field :houses, :integer
    field :roads, :integer
    field :schools, :integer

    field :parks, :integer
    field :libraries, :integer
    field :universities, :integer
    field :airports, :integer
    field :office_buildings, :integer
    field :city_treasury, :integer
    # ok so basically
    # this "belongs to is called "city" but it belongs to the "info" schema
    # so there has to be a "whatever_id" field in the migration
    # automatically adds "_id" when looking for a foreign key, unless you set it
    belongs_to :info, MayorGame.City.Info

    timestamps()
  end

  @doc false
  def changeset(details, attrs) do
    detail_fields = [
      :houses,
      :roads,
      :schools,
      :parks,
      :libraries,
      :universities,
      :airports,
      :office_buildings,
      :city_treasury,
      :info_id
    ]

    details
    # this basically defines the fields users can change
    |> cast(attrs, detail_fields)
    # and this is required fields
    |> validate_required(detail_fields)
  end
end