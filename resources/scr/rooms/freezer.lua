return {
  id = "freezer",
  name = "Freezer",
  cost = 500,
  width = 2,
  cookingSupplies = true,
  stock = 8,

  sprites = {
    {
      name = "base",
      animations = {
        idle = {
          first = 0,
          last = 0,
          speed = 1,
        },
      },
      playing = "idle",
    },
  },
}
