return {
  id = "moustache",
  name = "Chocolate",
  cost = 8000,
  profit = 1200,
  desirability = 15,
  width = 2,
  dirtyable = true,
  visitable = true,
  upkeep = 25,

  sprites = {
    {
      name = "interior",
      animations = {
        clean = {
          first = 0,
          last = 0,
          speed = 1,
        },
        dirty = {
          first = 1,
          last = 1,
          speed = 1,
        },
      },
      playing = "clean",
    },
    {
      name = "door",
      animations = {
        opened = {
          first = 0,
          last = 0,
          speed = 1,
        },
        closed = {
          first = 3,
          last = 3,
          speed = 1,
        },
        closing = {
          first = 0,
          last = 3,
          speed = 0.2,
          goto = "closed",
        },
        opening = {
          first = 3,
          last = 0,
          speed = 0.2,
          goto = "opened",
        },
      },
      playing = "opening",
    },
    {
      name = "windows",
      animations = {
        opened = {
          first = 0,
          last = 0,
          speed = 1,
        },
        closed = {
          first = 4,
          last = 4,
          speed = 1,
        },
        closing = {
          first = 0,
          last = 4,
          speed = 0.2,
          goto = "closed",
        },
        opening = {
          first = 4,
          last = 0,
          speed = 0.2,
          goto = "opened",
        },
      },
      playing = "opening",
    },
  },
}
