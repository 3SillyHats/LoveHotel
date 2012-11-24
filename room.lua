--The room "object" file

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")

--Create the module
local M = {}

--Position Component
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

--Room information component
local infoComponent = function (info)
  --Create a new component to store information in,
  --then store the info table into it.
  local component = entity.newComponent(info)

  --Return the room info table.
  return component
end

--Room constructor
M.new = function (state, roomType, pos)
  --Create an entity and get the id for the new room
  local roomId = entity.new(state)
  local room = resource.get("scr/rooms/" .. string.lower(roomType) .. ".lua")
  local img = resource.get("img/rooms/" .. room.image)

  --Add a sprite component for the room
  entity.addComponent(roomId, sprite.new(roomId,
    img, img:getWidth(), img:getHeight()))
  --Add position component
  entity.addComponent(roomId, posComponent(roomId, pos))
  --Add info component
  entity.addComponent(roomId, infoComponent(room))

  --Function returns the rooms id
  return roomId
end

--Return the module
return M
