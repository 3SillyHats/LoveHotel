-- menu.lua

local event = require("event")
local entity = require("entity")
local resource = require("resource")

local buttLoc = {
  build = 1,
  destroy = 2,
  hire = 3,
  janitor = 4,
  flower = 5,
  heart = 6,
}

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
    love.graphics.setColor(255,255,255)
    for i = 1, #buttons do
      if i == selected then
        love.graphics.drawq(buttons[i].image, buttons[i].quadS,
          18*i-16, pos+2, 0, 1, 1, 0, 0)
      else
        love.graphics.drawq(buttons[i].image, buttons[i].quadU,
          18*i-16, pos+2, 0, 1, 1, 0, 0)
      end
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

--Creates a new button of set type and desired callback function.
--The buttType is to define the sprite image
M.newButton = function (buttType, callback)
  local index = buttLoc[buttType]
  local img = resource.get("img/hud.png")

  local button = {
    action = callback or defaultAction,
    image = img,
    quadS = love.graphics.newQuad(
      16*(index - 1), 16, 16, 16,
      img:getWidth(), img:getHeight()
    ),
    quadU = love.graphics.newQuad(
      16*(index - 1), 0, 16, 16,
      img:getWidth(), img:getHeight()
    ),
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

