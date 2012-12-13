return {
  id = "elevator",
  name = "Elevator",
  cost = 100,
  width = 1,
  dirtyable = false,
  breakable = true,
  
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
        opened = {
          first = 0,
          last = 0,
          speed = 1,
        },
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
          speed = 0.2,
          goto = "opened",
        },
      },
      playing = "opening",
    },
  },
}
