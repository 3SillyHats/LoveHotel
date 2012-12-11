return {
  id = "vending",
  name = "Vending Mach.",
  cost = 200,
  width = 1,
  foodSupplies = true,
  stock = 8,
  restockCost = 50,

  sprites = {
    {
      name = "machine",
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
        broken = {
          first = 9,
          last = 10,
          speed = 1,
        },
      },
      playing = "stocked8",
    },
  },
}
