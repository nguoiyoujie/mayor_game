# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.CityCalculator
  alias MayorGame.{Auth, City, Repo}
  alias MayorGame.City.Town
  # import MayorGame.CityHelpers
  alias MayorGame.City.Buildable

  import Ecto.Query, warn: false

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache
  # alias MayorGameWeb.Pow.Routes

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  def mount(%{"title" => title}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    world = Repo.get!(MayorGame.City.World, 1)

    explanations = %{
      transit:
        "Build transit to add area to your city. Area is required to build most other buildings.",
      energy:
        "Energy buildings produce energy when they're operational. Energy is required to operate most other buildings. You need citizens to operate most of the energy buildings.",
      housing:
        "Housing is required to retain citizens — otherwise, they'll die. Housing requires energy and area; if you run out of energy, you might run out of housing rather quickly!",
      education:
        "Education buildings will, once a year, move citizens up an education level. This allows them to work at buildings with higher job levels, and make more money (and you, too, through taxes!",
      civic: "Civic buildings add other benefits citizens like — jobs, fun, etc.",
      work: "Work buildings have lots of jobs to attract citizens to your city",
      entertainment: "Entertainment buildings have jobs, and add other intangibles to your city.",
      health:
        "Health buildings increase the health of your citizens, and make them less likely to die",
      combat: "Combat buildings let you attack other cities, or defend your city from attack."
    }

    buildables_map = %{
      buildables_flat: Buildable.buildables_flat(),
      buildables_kw_list: Buildable.buildables_kw_list(),
      buildables: Buildable.buildables(),
      buildables_list: Buildable.buildables_list(),
      buildables_ordered: Buildable.buildables_ordered(),
      buildables_ordered_flat: Buildable.buildables_ordered_flat(),
      sorted_buildables: Buildable.sorted_buildables(),
      empty_buildable_map: Buildable.empty_buildable_map()
    }

    # production_categories = [:energy, :area, :housing]

    {
      :ok,
      socket
      # put the title and day in assigns
      |> assign(:title, title)
      |> assign(:world, world)
      |> assign(:buildables_map, buildables_map)
      |> assign(:building_requirements, ["workers", "energy", "area", "money", "steel", "sulfur"])
      |> assign(:category_explanations, explanations)
      |> mount_city_by_title()
      |> update_city_by_title()
      |> assign_auth(session)
      |> update_current_user()
      # run helper function to get the stuff from the DB for those things
    }
  end

  # this handles different events
  def handle_event(
        "add_citizen",
        _value,
        # pull these variables out of the socket
        %{assigns: %{city2: city}} = socket
      ) do
    if socket.assigns.current_user.id == 1 do
      new_citizen = %{
        town_id: city.id,
        age: 0,
        education: 0,
        has_job: false,
        last_moved: socket.assigns.world.day,
        preferences: :rand.uniform(6)
      }

      from(t in Town,
        where: t.id == ^city.id,
        update: [
          push: [
            citizens_blob: ^new_citizen
          ]
        ]
      )
      |> Repo.update_all([])
    end

    {:noreply, socket |> update_city_by_title()}
  end

  # event
  def handle_event(
        "gib_money",
        _value,
        %{assigns: %{city2: city}} = socket
      ) do
    city_struct = struct(City.Town, city)

    if socket.assigns.current_user.id == 1 do
      case City.update_town(city_struct, %{treasury: city.treasury + 10_000}) do
        {:ok, _updated_town} ->
          IO.puts("money gabe")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "reset_city",
        %{"userid" => _user_id},
        %{assigns: %{city2: city}} = socket
      ) do
    if socket.assigns.current_user.id == city.user_id do
      # reset = Map.new(Buildable.buildables_list(), fn x -> {x, []} end)
      city_struct = struct(City.Town, city)

      reset_buildables =
        Map.new(Enum.map(Buildable.buildables_list(), fn building -> {building, 0} end))

      updated_attrs =
        reset_buildables |> Map.merge(%{treasury: 5000, pollution: 0, citizen_count: 0})

      case City.update_town(city_struct, updated_attrs) do
        {:ok, _updated_town} ->
          IO.puts("city_reset")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "purchase_building",
        %{"building" => building_to_buy},
        %{assigns: %{city2: city}} = socket
      ) do
    # check if user is mayor here?

    building_to_buy_atom = String.to_existing_atom(building_to_buy)

    # get exponential price — don't want to set price on front-end for cheating reasons
    initial_purchase_price = get_in(Buildable.buildables_flat(), [building_to_buy_atom, :price])
    buildable_count = length(city[building_to_buy_atom])

    purchase_price = MayorGame.CityHelpers.building_price(initial_purchase_price, buildable_count)

    city_struct = struct(City.Town, city)

    # check for upgrade requirements?

    case City.purchase_buildable(city_struct, building_to_buy_atom, purchase_price) do
      {_x, nil} ->
        nil
        IO.puts('purchase success')

      {:error, err} ->
        Logger.error(inspect(err))

      nil ->
        nil
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "demolish_building",
        %{"building" => building_to_demolish},
        %{assigns: %{city2: city}} = socket
      ) do
    # check if user is mayor here?
    buildable_to_demolish_atom = String.to_existing_atom(building_to_demolish)

    city_struct = struct(City.Town, city)

    buildable_count = length(city[buildable_to_demolish_atom])

    if buildable_count > 0 do
      case City.demolish_buildable(city_struct, buildable_to_demolish_atom) do
        {_x, nil} ->
          IO.puts("demolition success")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    else
      City.update_town(city_struct, %{buildable_to_demolish_atom => 0})
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "attack_building",
        %{"building" => building_to_attack},
        %{assigns: %{city2: city, current_user: current_user}} = socket
      ) do
    # check if user is mayor here?
    building_to_attack_atom = String.to_existing_atom(building_to_attack)

    attacking_town_struct = Repo.get!(Town, current_user.town.id)
    attacked_town_struct = struct(City.Town, city)

    updated_attacked_logs =
      Map.update(city.logs_attacks, attacking_town_struct.title, 1, &(&1 + 1))

    attacked_town_changeset =
      attacked_town_struct
      |> City.Town.changeset(%{
        logs_attacks: updated_attacked_logs
      })

    if city.shields <= 0 && attacking_town_struct.missiles > 0 do
      case City.demolish_buildable(attacked_town_struct, building_to_attack_atom) do
        {_x, nil} ->
          from(t in Town, where: [id: ^current_user.town.id])
          |> Repo.update_all(inc: [missiles: -1])

          attack_building =
            Ecto.Multi.new()
            |> Ecto.Multi.update(
              {:update_attacked_town, attacked_town_struct.id},
              attacked_town_changeset
            )
            |> Repo.transaction(timeout: 10_000)

          case attack_building do
            {:ok, _updated_details} ->
              IO.puts("attack success")

            {:error, err} ->
              Logger.error(inspect(err))
          end

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title() |> update_current_user()}
  end

  def handle_event(
        "attack_shields",
        _value,
        %{assigns: %{city2: city, current_user: current_user}} = socket
      ) do
    # check if user is mayor here?

    attacking_town_struct = Repo.get!(Town, current_user.town.id)
    shielded_town_struct = struct(City.Town, city)

    updated_attacked_logs =
      Map.update(city.logs_attacks, attacking_town_struct.title, 1, &(&1 + 1))

    shields_update_changeset =
      shielded_town_struct
      |> City.Town.changeset(%{
        logs_attacks: updated_attacked_logs
      })

    from(t in Town, where: [id: ^city.id])
    |> Repo.update_all(inc: [shields: -1])

    from(t in Town, where: [id: ^current_user.town.id])
    |> Repo.update_all(inc: [missiles: -1])

    if city.shields > 0 && attacking_town_struct.missiles > 0 do
      attack_shields =
        Ecto.Multi.new()
        |> Ecto.Multi.update({:update_attacked_town, city.id}, shields_update_changeset)
        |> Repo.transaction(timeout: 10_000)

      case attack_shields do
        {:ok, _updated_details} ->
          IO.puts("attack success")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title() |> update_current_user()}
  end

  def handle_event(
        "update_tax_rates",
        %{"job_level" => job_level, "value" => updated_value},
        %{assigns: %{city2: city}} = socket
      ) do
    # check if user is mayor here?
    updated_value_float = Float.parse(updated_value)

    if updated_value_float != :error do
      updated_value_constrained =
        elem(updated_value_float, 0) |> max(0.0) |> min(1.0) |> Float.round(2)

      # check if it's below 0 or above 1 or not a number

      updated_tax_rates =
        city.tax_rates |> Map.put(job_level, updated_value_constrained) |> Map.drop(["6"])

      case City.update_town_by_id(city.id, %{tax_rates: updated_tax_rates}) do
        {:ok, _updated_details} ->
          IO.puts("tax rates updated")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  # this is what gets messages from CityCalculator
  def handle_info(%{event: "ping", payload: world}, socket) do
    {:noreply, socket |> assign(:world, world) |> update_city_by_title()}
  end

  # this is what gets messages from CityCalculator
  def handle_info(%{event: "pong", payload: world}, socket) do
    {:noreply, socket |> update_city_by_title()}
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # just update the whole city
    {:noreply, socket |> update_city_by_title()}
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_city_by_title(%{assigns: %{title: title, world: world}} = socket) do
    # cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)

    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    season =
      cond do
        rem(world.day, 365) < 91 -> :winter
        rem(world.day, 365) < 182 -> :spring
        rem(world.day, 365) < 273 -> :summer
        true -> :fall
      end

    # this shouuuuld be fresh…
    city =
      City.get_town_by_title!(title)
      |> MayorGame.CityHelpers.preload_city_check()

    city_with_stats2 =
      MayorGame.CityHelpers.calculate_city_stats(
        city,
        world,
        pollution_ceiling,
        season,
        socket.assigns.buildables_map
      )

    # ok, here the price is updated per each CombinedBuildable

    # have to have this separate from the actual city because the city might not have some buildables, but they're still purchasable
    # this status is for the whole category
    buildables_with_status =
      calculate_buildables_statuses(
        city_with_stats2,
        socket.assigns.buildables_map.buildables_kw_list
      )

    mapped_details_2 =
      Enum.reduce(
        city_with_stats2.result_buildables,
        socket.assigns.buildables_map.empty_buildable_map,
        fn buildable, acc ->
          Map.update!(acc, buildable.title, fn current_list ->
            [buildable | current_list]
          end)
        end
      )

    # need to get a map with the key

    operating_count =
      Enum.map(mapped_details_2, fn {category, list} ->
        {category, Enum.frequencies_by(list, fn x -> x.reason end)}
      end)
      |> Enum.into(%{})

    operating_tax =
      Enum.map(mapped_details_2, fn {category, _} ->
        {category,
         (
           buildable = socket.assigns.buildables_map.buildables_flat[category]

           if operating_count[category][[]] != nil && Map.has_key?(buildable, :requires) &&
                buildable.requires != nil,
              do:
                if(Map.has_key?(buildable.requires, :workers),
                  do:
                    MayorGame.CityHelpers.calculate_earnings(
                      operating_count[category][[]] * buildable.requires.workers.count,
                      buildable.requires.workers.level,
                      city.tax_rates[to_string(buildable.requires.workers.level)]
                    ),
                  else: 0
                ),
              else: 0
         )}
      end)
      |> Enum.into(%{})

    tax_by_level =
      Enum.map(
        Enum.group_by(
          operating_tax,
          fn {category, _} ->
            buildable = socket.assigns.buildables_map.buildables_flat[category]

            if operating_count[category][[]] != nil && Map.has_key?(buildable, :requires) &&
                 buildable.requires != nil,
               do:
                 if(Map.has_key?(buildable.requires, :workers),
                   do: buildable.requires.workers.level,
                   else: 0
                 ),
               else: 0
          end,
          fn {_, value} -> value end
        ),
        fn {level, array} -> {level, Enum.sum(array)} end
      )
      |> Enum.into(%{})

    citizen_edu_count =
      Enum.frequencies_by(city_with_stats2.all_citizens, fn x -> x.education end)

    city2_without_citizens =
      Map.drop(city_with_stats2, [
        :citizens,
        :citizens_looking,
        :citizens_to_reproduce,
        :citizens_polluted,
        :citizens_looking,
        :education
      ])

    socket
    |> assign(:season, season)
    |> assign(:buildables, buildables_with_status)
    # |> assign(:user_id, city_user.id)
    # |> assign(:username, city_user.nickname)
    |> assign(:city2, city2_without_citizens)
    |> assign(:operating_count, operating_count)
    |> assign(:operating_tax, operating_tax)
    |> assign(:tax_by_level, tax_by_level)
    |> assign(:citizens_by_edu, citizen_edu_count)
    |> assign(:total_citizens, length(city_with_stats2.all_citizens))
  end

  # function to mount city
  defp mount_city_by_title(%{assigns: %{title: title}} = socket) do
    # this shouuuuld be fresh…
    city = City.get_town_by_title!(title)

    # grab whole user struct
    city_user = Auth.get_user!(city.user_id)

    socket
    |> assign(:user_id, city_user.id)
    |> assign(:username, city_user.nickname)
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(%{assigns: %{current_user: current_user}} = socket) do
    if !is_nil(current_user) do
      current_user_updated = current_user |> Repo.preload([:town])

      if is_nil(current_user_updated.town) do
        socket
        |> assign(:current_user, current_user_updated)
      else
        updated_town = City.get_town!(current_user_updated.town.id)

        socket
        |> assign(:current_user, Map.put(current_user_updated, :town, updated_town))
      end
    else
      socket
    end
  end

  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(socket) do
    socket
  end

  # this takes the generic buildables map and builds the status (enabled, etc) for each buildable
  defp calculate_buildables_statuses(city, buildables_kw_list) do
    Enum.map(buildables_kw_list, fn {category, buildables} ->
      {category,
       buildables
       |> Enum.map(fn {buildable_key, buildable_stats} ->
         {buildable_key,
          Map.from_struct(
            calculate_buildable_status(
              buildable_stats,
              city,
              length(Map.get(city, buildable_key))
            )
          )}
       end)}
    end)
  end

  # this takes a buildable, and builds purchasable status from database
  # TODO: Clean this shit upppp
  defp calculate_buildable_status(buildable, city_with_stats, buildable_count) do
    updated_price = MayorGame.CityHelpers.building_price(buildable.price, buildable_count)

    if city_with_stats.treasury > updated_price do
      if is_nil(buildable.requires) do
        %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}
      else
        purchase_requirements = [:energy, :area]

        unfulfilled_requirements =
          Enum.reduce(purchase_requirements, [], fn requirement, acc ->
            if Map.has_key?(buildable.requires, requirement) &&
                 city_with_stats[requirement] < buildable.requires[requirement] do
              acc ++ [requirement]
            else
              acc
            end
          end)

        if length(unfulfilled_requirements) > 0 do
          %{
            buildable
            | purchasable: false,
              purchasable_reason:
                "not enough " <> Enum.join(unfulfilled_requirements, " or ") <> " to build",
              price: updated_price
          }
        else
          %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}
        end

        # cond do
        #   # enough energy AND enough area

        #   Map.has_key?(buildable.requires, :energy) and
        #     city_with_stats.energy >= buildable.requires.energy &&
        #       (Map.has_key?(buildable.requires, :area) and
        #          city_with_stats.area >= buildable.requires.area) ->
        #     %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        #   # not enough energy, enough area
        #   Map.has_key?(buildable.requires, :energy) and
        #     city_with_stats.energy < buildable.requires.energy &&
        #       (Map.has_key?(buildable.requires, :area) and
        #          city_with_stats.area >= buildable.requires.area) ->
        #     %{
        #       buildable
        #       | purchasable: false,
        #         purchasable_reason: "not enough energy to build",
        #         price: updated_price
        #     }

        #   # enough energy, not enough area
        #   Map.has_key?(buildable.requires, :energy) and
        #     city_with_stats.energy >= buildable.requires.energy &&
        #       (Map.has_key?(buildable.requires, :area) and
        #          city_with_stats.area < buildable.requires.area) ->
        #     %{
        #       buildable
        #       | purchasable: false,
        #         purchasable_reason: "not enough area to build",
        #         price: updated_price
        #     }

        #   # not enough energy AND not enough area
        #   Map.has_key?(buildable.requires, :energy) and
        #     city_with_stats.energy < buildable.requires.energy &&
        #       (Map.has_key?(buildable.requires, :area) and
        #          city_with_stats.area < buildable.requires.area) ->
        #     %{
        #       buildable
        #       | purchasable: false,
        #         purchasable_reason: "not enough area or energy to build",
        #         price: updated_price
        #     }

        #   # no energy needed, enough area
        #   Map.has_key?(buildable.requires, :energy) &&
        #       (Map.has_key?(buildable.requires, :area) and
        #          city_with_stats.area >= buildable.requires.area) ->
        #     %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        #   # no energy needed, not enough area
        #   Map.has_key?(buildable.requires, :energy) &&
        #       (Map.has_key?(buildable.requires, :area) and
        #          city_with_stats.area < buildable.requires.area) ->
        #     %{
        #       buildable
        #       | purchasable: false,
        #         purchasable_reason: "not enough area to build",
        #         price: updated_price
        #     }

        #   # no area needed, enough energy
        #   !Map.has_key?(buildable.requires, :area) &&
        #       (Map.has_key?(buildable.requires, :energy) and
        #          city_with_stats.energy >= buildable.requires.energy) ->
        #     %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        #   # no area needed, not enough energy
        #   !Map.has_key?(buildable.requires, :area) &&
        #       (Map.has_key?(buildable.requires, :energy) and
        #          city_with_stats.energy < buildable.requires.energy) ->
        #     %{
        #       buildable
        #       | purchasable: false,
        #         purchasable_reason: "not enough energy to build",
        #         price: updated_price
        #     }

        #   # no area needed, no energy needed
        #   !Map.has_key?(buildable.requires, :energy) and
        #       !Map.has_key?(buildable.requires, :energy) ->
        #     %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        #   # catch-all
        #   true ->
        #     %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}
        # end
      end
    else
      %{
        buildable
        | purchasable: false,
          purchasable_reason: "not enough money",
          price: updated_price
      }
    end
  end

  # POW
  # AUTH
  # POW AUTH STUFF DOWN HERE BAYBEE

  defp assign_auth(socket, session) do
    # add an assign :current_user to the socket
    socket =
      assign_new(socket, :current_user, fn ->
        get_user(socket, session) |> Repo.preload([:town])
      end)

    if socket.assigns.current_user do
      # if there's a user logged in
      socket
      |> assign(
        :is_user_mayor,
        to_string(socket.assigns.user_id) == to_string(socket.assigns.current_user.id)
      )
    else
      # if there's no user logged in
      socket
      |> assign(:is_user_mayor, false)
    end
  end

  # POW HELPER FUNCTIONS
  defp get_user(socket, session, config \\ [otp_app: :mayor_game])

  defp get_user(socket, %{"mayor_game_auth" => signed_token}, config) do
    conn = struct!(Plug.Conn, secret_key_base: socket.endpoint.config(:secret_key_base))
    salt = Atom.to_string(Pow.Plug.Session)

    with {:ok, token} <- Pow.Plug.verify_token(conn, salt, signed_token, config),
         # Use Pow.Store.Backend.EtsCache if you haven't configured Mnesia yet.
         {user, _metadata} <-
           CredentialsCache.get([backend: Pow.Postgres.Store], token) do
      user
    else
      _any -> nil
    end
  end

  defp get_user(_, _, _), do: nil
end
