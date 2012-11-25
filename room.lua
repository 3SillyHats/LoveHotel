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
  local width = img:getWidth()
  local height = 32

  --Add a sprite component for the back layer of the room
  entity.addComponent(roomId, sprite.new(roomId, {
    image = img,
    width = width,
    height = height,
    animations = {
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
    playing = clean,
  }))
  --Add a sprite component for the front layer of the room
  entity.addComponent(roomId, sprite.new(roomId, {
    image = img,
    width = width,
    height = height,
    animations = {
      opened = {
        first = 3,
        last = 3,
        speed = 1,
      },
      closed = {
        first = room.aniFrames+2,
        last = room.aniFrames+2,
        speed = 1,
      },
      closing = {
        first = 3,
        last = room.aniFrames+2,
        speed = 1,
        goto = closed,
      },
      opening = {
        first = room.aniFrames+2,
        last = 3,
        speed = 1,
        goto = opened,
      },
    },
    playing = opened,
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
