return {
  id = "flower",
  name = "Lily R.",
  cost = 500,
  profit = 100,
  name = "flower",
  width = 2,
  defaultBackgroundAnim = "clean",
  defaultForegroundAnim = "opening",

  backgroundAnimations = {
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
