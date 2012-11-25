-- menu.lua

local event = require("event")
local entity = require("entity")

local defaultAction = function ()
  print("action")
end

local hud = function (id, pos)
  local component = entity.newComponent()
  
  local selected = 1
  local buttons = {}

  component.draw = function (self)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill", 0, pos, 32*8, 32)
    for i = 1, #buttons do
      if i == selected then
        love.graphics.setColor(255,255,255)
      else
        love.graphics.setColor(89,89,89)
      end
      love.graphics.rectangle("fill", 18*i-16, pos+2, 16, 16)
    end
  end
  
  component.back = defaultAction
  
  event.subscribe("addButton", id, function (button)
    table.insert(buttons, button)
  end)
  
  event.subscribe("setBack", id, function (callback)
    component.back = callback
  end)
  
  event.subscribe("pressed", 0, function (key)
    if key == "left" then
      if selected > 1 then
        selected = selected - 1
      end
    elseif key == "right" then
      if selected < #buttons then
        selected = selected + 1
      end
    elseif key == "a" then
      if buttons[selected] then
        buttons[selected].action()
      end
    elseif key == "b" then
      component.back()
    end
  end)
  
  return component
end

local M = {}

M.new = function (state, pos)
  local id = entity.new(state)
    
  entity.addComponent(id, hud(id, pos))
  
  return id
end

M.newButton = function (callback)
  local button = {
    action = callback or defaultAction
  }
  return button
end

M.addButton = function (id, button)
  event.notify("addButton", id, button)
end

M.setBack = function(id, callback)
  event.notify("setBack", id, callback)
end

return M

