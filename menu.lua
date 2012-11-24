-- menu.lua

local event = require("event")
local entity = require("entity")

local hud = function (id)
  local component = entity.newComponent()
  
  local selected = 1
  local buttons = {0,1,2,3}
  
  component.draw = function (self)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill", 0, 32*6, 32*8, 32)
    for i = 1, #buttons do
      if i == selected then
        love.graphics.setColor(255,255,255)
      else
        love.graphics.setColor(89,89,89)
      end
      love.graphics.rectangle("fill", 18*i-16, 32*6+2, 16, 16)
    end
  end
  
  event.subscribe("pressed", 0, function (key)
    if key == "left" then
      if selected > 1 then
        selected = selected - 1
      end
    elseif key == "right" then
      if selected < #buttons then
        selected = selected + 1
      end
    end
  end) 
  
  return component
end

local M = {}

M.new = function (state)
  local id = entity.new(state)
    
  entity.addComponent(id, hud(id))
  
  return id
end

return M

