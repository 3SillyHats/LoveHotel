-- menu.lua

local event = require("event")
local entity = require("entity")
local resource = require("resource")

--Index locations for room types found within hud.png
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
  
  --Selected keeps track of the selected button
  local selected = 1
  local buttons = {}

  --The draw component for the hud menu
  component.draw = function (self)
    love.graphics.setColor(255,255,255)
    for i = 1, #buttons do
      if i == selected then
        love.graphics.drawq(buttons[i].image, buttons[i].quadS,
          16*(i-1), pos, 0, 1, 1, 0, 0)
      else
        love.graphics.drawq(buttons[i].image, buttons[i].quadU,
          16*(i-1), pos, 0, 1, 1, 0, 0)
      end
    end
  end
  
  component.enabled = true
  component.back = defaultAction
  
  event.subscribe("addButton", id, function (button)
    table.insert(buttons, button)
  end)
  
  event.subscribe("setBack", id, function (callback)
    component.back = callback
  end)
  
  event.subscribe("menu.enable", id, function ()
    component.enabled = true
  end)
  
  event.subscribe("menu.disable", id, function ()
    component.enabled = false
  end)
  
  event.subscribe("pressed", 0, function (key)
    if component.enabled then
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
    end
  end)
  
  return component
end

local M = {}

--Create a new hud menu
M.new = function (state, pos)
  local id = entity.new(state)
    
  entity.addComponent(id, hud(id, pos))
  
  return id
end

--Creates a new button of set type and desired callback function.
--The buttType is to define the sprite image
M.newButton = function (buttType, callback)
  --Pull the index location for the desired button type
  local index = buttLoc[buttType]
  --Load the hud image
  local img = resource.get("img/hud.png")

  local button = {
    action = callback or defaultAction,
    image = img,
    --The selected quad
    quadS = love.graphics.newQuad(
      16*(index - 1), 16, 16, 16,
      img:getWidth(), img:getHeight()
    ),
    --The unselected quad
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

M.enable = function(id)
  event.notify("menu.enable", id)
end

M.disable = function(id)
  event.notify("menu.disable", id)
end

return M

