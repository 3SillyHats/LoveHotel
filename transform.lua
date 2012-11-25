local M = {}

local entity = require("entity")
local event = require("event")

--Transform Component
M.new = function (id, pos, offset)
  --Create a new component for position stuff
  local component = entity.newComponent()

  local offset = offset or {x = 0, y = 0}

  local new = true

  --Load the tower position into the component
  component.pos = pos
  component.scroll = gScrollPos
  
  local updatePos = function ()
    local screenPos = {
      x = math.floor(component.pos.roomNum - 1) * 32 + offset.x + ROOM_INDENT,
      y = math.floor(component.scroll - component.pos.floorNum) * 32 + offset.y + FLOOR_OFFSET,
    }
    
    event.notify("sprite.move", id, screenPos)
  end

  component.update = function (dt)
    if new then
      updatePos()
      new = false
    end
  end
  
  --[[Subscribe to the scroll event so that the rooms screen
  position gets updated when the tower is scrolled.
  The callback method transforms from tower position to
  screen position, and notifies "sprite.move"--]]
  event.subscribe("scroll", 0,
    function (scrollPos)
      component.scroll = scrollPos
      updatePos()
    end)

  event.subscribe("entity.move", id,
    function (pos)
      component.pos = pos
      updatePos()
    end)

  return component
end

return M
