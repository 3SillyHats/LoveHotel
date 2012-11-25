-- builder.lua
-- GUI element for placing a new room

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")

--Create the module
local M = {}

local placer = function (id, width, cost)
  local component = entity.newComponent({
    room = 4,
    floor = gScrollPos,
    width = width,
    cost = cost,
  })
  
  event.subscribe("pressed", 0, function (key)
    if key == "left" then
      if component.room > 1 then
        component.room = component.room - 1
        event.notify("entity.move", id, {roomNum = component.room, floorNum = component.floor})
      end
    elseif key == "right" then
      if component.room < 7 then
        component.room = component.room + 1
        event.notify("entity.move", id, {roomNum = component.room, floorNum = component.floor})
      end
    end
  end)

  event.subscribe("scroll", 0, function (scrollPos)
    component.floor = scrollPos
    event.notify("entity.move", id, {roomNum = component.room, floorNum = component.floor})
  end)
  return component
end

local outline = function (id, t)
  local component = entity.newComponent({
    x = 0,
    y = 0,
    width = t.width,
    height = t.height,
  })
  
  component.draw = function (self)
    love.graphics.setColor(0,114,0)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  end
  
  event.subscribe("sprite.move", id, function (pos)
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

  --Add a sprite component for the room
  entity.addComponent(id, sprite.new(id, {
   image = img,
   width = img:getWidth(),
   height = img:getHeight()
  }))
  --Add an outline component for the room
  entity.addComponent(id, outline(id, {
    width = img:getWidth(),
    height = img:getHeight()
  }))
  --Add position component
  entity.addComponent(id, transform.new(id, pos))
  --Add placer component
  entity.addComponent(id, placer(id, room.width, room.cost))

  --Function returns the rooms id
  return id
end

--Return the module
return M
