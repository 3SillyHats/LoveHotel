return {
  id = "utility",
  name = "Supply Closet",
  cost = 500,
  profit = 50,
  desirability = -10,
  width = 1,
  dirtyable = false,
  visitable = true,
  cleaningSupplies = true,
  stock = 8,
  restockCost = 500,
  upkeep = 5,
  
  sprites = {
    {
      name = "background",
      animations = {
        stocked8 = {
          first = 0,
          last = 0,
          speed = 1,
        },
         stocked7 = {
          first = 1,
          last = 1,
          speed = 1,
        },     
        stocked6 = {
          first = 2,
          last = 2,
          speed = 1,
        },
        stocked5 = {
          first = 3,
          last = 3,
          speed = 1,
        },
        stocked4 = {
          first = 4,
          last = 4,
          speed = 1,
        },
         stocked3 = {
          first = 5,
          last = 5,
          speed = 1,
        },     
        stocked2 = {
          first = 6,
          last = 6,
          speed = 1,
        },
        stocked1 = {
          first = 7,
          last = 7,
          speed = 1,
        },
        stocked0 = {
          first = 8,
          last = 8,
          speed = 1,
        },
      },
      playing = "stocked8",
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
