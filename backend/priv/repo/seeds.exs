require Logger

# Users

{:ok, anna} = Ggyo.Account.create_user(%{username: "anna", password: "abc123"})
{:ok, _vasyl} = Ggyo.Account.create_user(%{username: "vasyl", password: "abc123"})
{:ok, _igor} = Ggyo.Account.create_user(%{username: "igor", password: "abc123"})
{:ok, _grusha} = Ggyo.Account.create_user(%{username: "grusha", password: "abc123"})

Logger.info("Created users")

# Room

Ggyo.Yarnballs.create_room()

Logger.info("Created fake room")
