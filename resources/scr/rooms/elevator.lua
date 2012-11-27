return {
  id = "elevator",
  name = "Elevator",
  cost = 100,
  name = "elevator",
  width = 1,
  defaultBackgroundAnim = "default",
  defaultForegroundAnim = "closing",

  backgroundAnimations = {
      default = {
        first = 0,
        last = 0,
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
}
