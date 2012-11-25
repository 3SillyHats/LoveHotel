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

local outline = function (id, t)
  local component = entity.newComponent({
    x = 0,
    y = 0,
    width = t.width,
    height = t.height,
  })
  
  component.draw = function (self)
    love.graphics.setColor(0,114,0)
    love.graphics.line(self.x, self.y, self.x+self.width-1, self.y)
    love.graphics.line(self.x+self.width-1, self.y, self.x+self.width-1, self.y+self.height)
    love.graphics.line(self.x+self.width-1, self.y+self.height-1, self.x, self.y+self.height-1)
    love.graphics.line(self.x, self.y+self.height-1, self.x, self.y)
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

  --Function returns the rooms id
  return id
end

--Return the module
return M
