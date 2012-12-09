return {
  id = "utility",
  name = "Utility Room",
  cost = 150,
  profit = 20,
  desirability = 2,
  width = 1,
  dirtyable = false,
  cleaningSupplies = true,
  stock = 5,
  defaultBackgroundAnim = "stocked3",
  defaultForegroundAnim = "opening",

  backgroundAnimations = {
      dirty = {
        first = 0,
        last = 0,
        speed = 1,
      },
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

  foregroundAnimations = {
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

}
