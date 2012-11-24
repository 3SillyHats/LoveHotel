-- room file

local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")

local M = {}

local posComponent = function (id, pos)
  --Create a new component for position stuff
  local component = entity.newComponent()

  --Load the tower position into the component
  component.pos = pos

  --[[Subscribe to the scroll event so that the rooms screen
  position gets updated when the tower is scrolled.
  The callback method transforms from tower position to
  screen position, and notifies "sprite.move"--]]
  event.subscribe("scroll", 0,
    function (scrollPos)
      local screenPos = {
        x = (component.pos.roomNum - 1) * 32 + ROOM_INDENT,
        y = (scrollPos - component.pos.floorNum) * 32 + FLOOR_OFFSET,
      }

      event.notify("sprite.move", id, screenPos)

    end)

  return component
end

M.new = function (roomType, pos)
  --Create an entity and get the id for the new room
  local roomId = entity.new()
  local img = resource.get("img/rooms/utility.png")

  --Add a sprite component for the room
  entity.addComponent(roomId, sprite.new(roomId,
    img, img:getWidth(), img:getHeight()))
  --Add position component
  entity.addComponent(roomId, posComponent(roomId, pos))

  --Function returns the rooms id
  return roomId
end

return M