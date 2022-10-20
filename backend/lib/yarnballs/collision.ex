defprotocol Yarnballs.Collidable do
  @moduledoc """
  A protocol defining an 2D entity that can collide with another collidable 2D
  entity. Assumes the entities have circular collision zones.
  """

  @doc """
  The location of an entity's top-left corner.
  """
  @spec top_left(t) :: {float, float}
  def top_left(entity)

  @doc """
  The distance from an entity's center to its perimeter.
  """
  @spec radius(t) :: float
  def radius(entity)
end

defmodule Yarnballs.Collider do
  @moduledoc """
  Manages collisions between collidable entities.
  """

  alias Yarnballs.Collidable

  def spatial_hash(entities, hash, key) do
    for entity <- entities, reduce: %{} do
      acc -> spatial_hash_for_entity(entity, hash, acc)
    end
    |> Enum.map(fn {space, entities} -> {space, %{key => entities}} end)
    |> Enum.into(%{})
  end

  defp spatial_hash_for_entity(entity, hash, spaces) do
    entity
    |> envelope()
    |> SpatialHash.hash_range(hash)
    |> cartesian_2d()
    |> Enum.reduce(
      spaces,
      fn space, acc ->
        Map.update(acc, space, [entity], fn existing -> [entity | existing] end)
      end
    )
  end

  defp cartesian_2d([xs, ys]) do
    for x <- xs, y <- ys, do: {x, y}
  end

  defp envelope(entity) do
    {x, y} = Collidable.top_left(entity)
    size = 2 * Collidable.radius(entity)

    %Envelope{
      min_x: x,
      min_y: y,
      max_x: x + size,
      max_y: y + size
    }
  end

  def collided?(entity1, entity2) do
    {x1, y1} = center(entity1)
    {x2, y2} = center(entity2)
    threshold = Collidable.radius(entity1) + Collidable.radius(entity2)

    distance(x1, y1, x2, y2) <= threshold
  end

  defp center(entity) do
    {x, y} = Collidable.top_left(entity)
    r = Collidable.radius(entity)

    {x + r, y + r}
  end

  defp distance(x1, y1, x2, y2) do
    :math.sqrt(round(x2 - x1) ** 2 + round(y2 - y1) ** 2)
  end
end

defmodule Yarnballs.CollisionSpace do
  @moduledoc """
  A space containing collidable entities.
  """

  alias Yarnballs.Collider
  alias Yarnballs.Enemies
  alias Yarnballs.Missiles
  alias Yarnballs.PlayerShip
  alias Yarnballs.PlayerShips

  @type t :: %{
          optional(:missiles) => Missiles.t(),
          optional(:enemies) => Enemies.t(),
          optional(:ships) => PlayerShips.t()
        }

  @spec update(__MODULE__.t()) :: __MODULE__.t()
  def update(space) do
    {enemy_ids, missiles} = Enum.unzip(enemy_missile_collisions(space))

    ships =
      ship_enemy_collisions(space)
      |> Enum.reduce(
        space.ships,
        fn {p, e}, ships -> PlayerShips.collide_with(ships, p.id, e) end
      )

    scores = Enum.frequencies_by(missiles, & &1.shooter_id)

    %{
      space
      | enemies: Enemies.remove(space.enemies, enemy_ids),
        missiles: Missiles.remove(space.missiles, Enum.map(missiles, & &1.id)),
        ships: PlayerShips.increase_scores(ships, scores)
    }
  end

  # TODO: come up with better names for entity x entity collision functions
  def emc(space) do
    for e <- Map.get(space, :enemies, []),
        m <- Map.get(space, :missiles, []),
        Collider.collided?(e, m),
        !m.dead do
      {e, m}
    end
  end

  # TODO: come up with better names for entity x entity collision functions
  def esc(space) do
    for e <- Map.get(space, :enemies, []),
        s <- Map.get(space, :ships, []),
        Collider.collided?(e, s),
        !PlayerShip.dead?(s) do
      {e, s}
    end
  end

  @spec enemy_missile_collisions(__MODULE__.t()) :: List.t({binary, Missile.t()})
  defp enemy_missile_collisions(space) do
    for e <- space.enemies.entities,
        missile <- space.missiles.entities,
        Collider.collided?(e, missile),
        !missile.dead do
      {e.id, missile}
    end
  end

  @spec ship_enemy_collisions(__MODULE__.t()) :: List.t({PlayerShip.t(), Enemy.t()})
  defp ship_enemy_collisions(space) do
    for e <- space.enemies.entities,
        p <- PlayerShips.entities(space.ships),
        Collider.collided?(e, p),
        !PlayerShip.dead?(p) do
      {p, e}
    end
  end
end
