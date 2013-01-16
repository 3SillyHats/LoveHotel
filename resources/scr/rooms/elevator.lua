return {
  id = "elevator",
  name = "Elevator",
  cost = 0,
  width = 1,
  dirtyable = false,
  breakable = true,
  integrity = 32,

  sprites = {
    {
      name = "background",
      animations = {
        idle = {
          first = 0,
          last = 0,
          speed = 1,
        },
      },
      playing = "idle",
    },
    {
      name = "foreground",
      animations = {
        closed = {
          first = 5,
          last = 5,
          speed = 1,
        },
        closing = {
          first = 0,
          last = 5,
          speed = 0.2,
          goto = "closed",
        },
        opening = {
          first = 5,
          last = 0,
          speed = 0.05,
          goto = "closing",
        },
        broken = {
          first = 6,
          last = 7,
          speed = 0.5,
        },

      },
      playing = "closing",
    },
  },
}
