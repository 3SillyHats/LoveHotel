--The room "object" file

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")

--Create the module
local M = {}

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
  entity.addComponent(roomId, sprite.new(roomId, {
    image = img,
    width = img:getWidth(),
    height = img:getHeight()
  }))
  --Add position component
  entity.addComponent(roomId, transform.new(roomId, pos))
  --Add info component
  entity.addComponent(roomId, infoComponent(room))

  --Function returns the rooms id
  return roomId
end

--Return the module
return M
