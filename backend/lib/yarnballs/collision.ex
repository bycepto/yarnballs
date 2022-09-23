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
