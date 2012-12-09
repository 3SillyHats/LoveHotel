return {
  id = "condom",
  name = "Condom Mach.",
  cost = 100,
  width = 1,
  condomSupplies = true,
  stock = 3,
  restockCost = 20,

  sprites = {
    {
      name = "machine",
      animations = {
        stocked3 = {
          first = 0,
          last = 0,
          speed = 1,
        },
         stocked2 = {
          first = 1,
          last = 1,
          speed = 1,
        },     
        stocked1 = {
          first = 2,
          last = 2,
          speed = 1,
        },
        stocked0 = {
          first = 3,
          last = 3,
          speed = 1,
        },
      },
      playing = "stocked3",
    },
  },
}
