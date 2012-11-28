local M = {}

local entity = require("entity")
local event = require("event")

--Transform Component
M.new = function (id, pos, offset, width)
  --Create a new component for position stuff
  local component = entity.newComponent()

  local offset = offset or {x = 0, y = 0}
  
  local new = true

  --Load the tower position into the component
  component.pos = pos
  component.scroll = gScrollPos
  
  local updatePos = function ()
    local screenPos = {
      x = math.floor((component.pos.roomNum - 1) * 32) + offset.x + ROOM_INDENT,
      y = math.floor((component.scroll - component.pos.floorNum) * 32) + offset.y + FLOOR_OFFSET,
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

  local scroll = function (scrollPos)
    component.scroll = scrollPos
    updatePos()
  end

  local move = function (pos)
    component.pos = pos
    updatePos()
  end

  local getPos = function (callback)
    if width then
      callback({
        floorNum = component.pos.floorNum,
        roomNum = component.pos.roomNum + width/2 - 0.5,
      })
    else
      callback({
        floorNum = component.pos.floorNum,
        roomNum = component.pos.roomNum,
      })
    end
  end
  
  local function delete ()
    event.unsubscribe("scroll", 0, scroll)
    event.unsubscribe("entity.move", id, move)
    event.unsubscribe("entity.pos", id, getPos)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("scroll", 0, scroll)
  event.subscribe("entity.move", id, move)
  event.subscribe("entity.pos", id, getPos)
  event.subscribe("delete", id, delete)

  return component
end

return M
