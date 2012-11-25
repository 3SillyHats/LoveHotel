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
local infoComponent = function (id, info, pos)
  --Create a new component to store information in,
  --then store the info table into it.
  local component = entity.newComponent(info)
  
  local check = function (t)
    if math.ceil(t.floorNum) == pos.floorNum and
        t.roomNum >= pos.roomNum - 0.5 and
        t.roomNum <= pos.roomNum - 0.5 + info.width then
      t.callback(id, info.type)
    end
  end
  
  event.subscribe("room.check", 0, check)
  
  local function delete ()
    event.unsubscribe("room.check", 0, check)
    event.unsubscribe("room.check", id, delete)
  end
  
  event.subscribe("room.check", id, delete)

  --Return the room info table.
  return component
end

--Room constructor
M.new = function (state, roomType, pos)
  --Create an entity and get the id for the new room
  local roomId = entity.new(state)
  local room = resource.get("scr/rooms/" .. string.lower(roomType) .. ".lua")
  room.type = roomType
  local img = resource.get("img/rooms/" .. room.image)
  local imgWidth = img:getWidth()
  local imgHeight = 32

  --Add a sprite component for the back layer of the room
  entity.addComponent(roomId, sprite.new(roomId, {
    image = img,
    width = imgWidth,
    height = imgHeight,
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
    playing = "clean",
  }))
  --Add a sprite component for the front layer of the room
  entity.addComponent(roomId, sprite.new(roomId, {
    image = img,
    width = imgWidth,
    height = imgHeight,
    animations = {
      opened = {
        first = 2,
        last = 2,
        speed = 1,
      },
      closed = {
        first = room.aniFrames+1,
        last = room.aniFrames+1,
        speed = 1,
      },
      closing = {
        first = 2,
        last = room.aniFrames+1,
        speed = 0.2,
        goto = "closed",
      },
      opening = {
        first = room.aniFrames+1,
        last = 2,
        speed = 0.2,
        goto = "opened",
      },
    },
    playing = "opening",
  }))

  --Add position component
  entity.addComponent(roomId, transform.new(roomId, pos))
  --Add info component
  entity.addComponent(roomId, infoComponent(roomId, room, pos))

  --Function returns the rooms id
  return roomId
end

M.getPos = function (id)
  local pos
  event.notify("entity.pos", id, function (e)
    pos = e
  end)
  return pos
end

--Return the module
return M
