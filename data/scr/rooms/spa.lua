return {
  id = "spa",
  name = "Spa Room",
  cost = 20000,
  desirability = 25,
  width = 2,
  integrity = 5,
  upkeep = 500,

  sprites = {
    {
      name = "base",
      animations = {
        idle = {
          first = 0,
          last = 1,
          speed = 1,
        },
        broken = {
          first = 2,
          last = 3,
          speed = 0.5,
        }
      },
      playing = "idle",
    },
  },
}
