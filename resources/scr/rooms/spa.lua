return {
  id = "spa",
  name = "Spa Room",
  cost = 30000,
  width = 2,
  breakable = true,
  integrity = 8,
  reputation = 1,

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
