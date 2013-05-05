return {
  id = "eco",
  name = "Tropical",
  cost = 50000,
  profit = 7500,
  desirability = 20,
  width = 5,
  dirtyable = true,
  visitable = true,
  upkeep = 100,

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
  },
}
