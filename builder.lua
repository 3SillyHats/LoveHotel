-- builder.lua
-- GUI element for placing a new room

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")
local room = require("room")

--Create the module
local M = {}

local placer = function (id, type, width, cost)
  local component = entity.newComponent({
    room = 4,
    floor = gScrollPos,
    width = width,
    cost = cost,
  })
  
  local clear = true
    
  local updatePosition = function()
    clear = true
    event.notify("entity.move", id, {roomNum = component.room, floorNum = component.floor})
    
    for i = 1,component.width do
      event.notify("room.check", 0, {
        roomNum = component.room + i - 1,
        floorNum = component.floor,
        callback = function (otherId)
          clear = false,
          event.notify("room.conflict", id, otherId)
        end,
      })
    end
  end
  
  event.subscribe("pressed", 0, function (key)
    if key == "left" then
      if component.room > 1 then
        component.room = component.room - 1
        updatePosition()
      end
    elseif key == "right" then
      if component.room < 7 then
        component.room = component.room + 1
        updatePosition()
      end
    elseif key == "a" then
      if clear then
        local room = room.new(2, type, {roomNum = component.room, floorNum = component.floor})
      end
    end
  end)

  event.subscribe("scroll", 0, function (scrollPos)
    component.floor = scrollPos
    updatePosition()
  end)
  
  updatePosition()
  
  return component
end

local outline = function (id, t)
  local component = entity.newComponent({
    x = 0,
    y = 0,
    width = t.width,
    height = t.height,
  })
  
  local clear = true
  
  component.draw = function (self)
    if clear then
      love.graphics.setColor(0,184,0)
    else
      love.graphics.setColor(172,16,0)
    end
    love.graphics.setLine(1, "rough")
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  end
  
  event.subscribe("room.conflict", id, function (otherId)
    clear = false
  end)

  event.subscribe("sprite.move", id, function (pos)
    clear = true
    --print(clear)
    component.x = pos.x
    component.y = pos.y
  end)
  
  return component
end

--Constructor
M.new = function (state, roomType, pos)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  local room = resource.get("scr/rooms/" .. string.lower(roomType) .. ".lua")
  local img = resource.get("img/rooms/" .. room.image)

  --Add a sprite component for back layer the room
  entity.addComponent(id, sprite.new(id, {
    image = img,
    width = img:getWidth(),
    height = 32,
    --Use the clean room back layer
    animation = {
      clean = {
        first = 1,
        last = 1,
        speed = 1,
      },
    },
    playing = clean,
  }))
  --Add a sprite for the front layer of the room
  entity.addComponent(id, sprite.new(id, {
    image = img,
    width = img:getWidth(),
    height = 32,
    --Used the closed door front layer
    animation = {
      closed = {
        first = room.aniFrames+2,
        last = room.aniFrames+2,
        speed = 1,
      },
    },
    playing = closed,
  }))
  --Add an outline component for the room
  entity.addComponent(id, outline(id, {
    width = img:getWidth(),
    height = 32,
  }))
  --Add position component
  entity.addComponent(id, transform.new(id, pos))
  --Add placer component
  entity.addComponent(id, placer(id, roomType, room.width, room.cost))

  --Function returns the rooms id
  return id
end

--Return the module
return M
