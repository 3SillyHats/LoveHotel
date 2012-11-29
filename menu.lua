-- menu.lua

local event = require("event")
local entity = require("entity")
local resource = require("resource")

--Index locations for room types found within hud.png
buttLoc = {
  infrastructure = 0,
  suites = 1,
  entertainment = 2,
  hotel = 3,
  manage = 4,

  stairs = 8,
  elevator = 9,
  floorUp = 10,
  floorDown = 11,
  destroy = 12,
 
  flower = 16,
  heart = 17,
  tropical = 18,
  
  condom = 24,
  spa = 25,
  dining = 26,

  utility = 32,
  reception = 33,
  staffRoom = 34,
  kitchen = 35,
   
  hire = 40,
  stock = 41,
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
  
  component.addButton = function (self, button)
    table.insert(buttons, button)
    if #buttons == 1 then
      event.notify("menu.info", 0, buttons[selected].type)
    end
  end
  
  component.setBack = function (self, callback)
    component.back = callback
  end
  
  component.enable =  function (self)
    component.enabled = true
    event.notify("menu.info", 0, buttons[selected].type)
  end
  
  component.disable = function (self)
    component.enabled = false
  end
  
  local pressed = function (key)
    local snd = resource.get("snd/select.wav")
    if component.enabled then
      if key == "left" then
        if selected > 1 then
          selected = selected - 1
          event.notify("menu.info", 0, buttons[selected].type)
          love.audio.rewind(snd)
          love.audio.play(snd)
        end
      elseif key == "right" then
        if selected < #buttons then
          selected = selected + 1
          event.notify("menu.info", 0, buttons[selected].type)
          love.audio.rewind(snd)
          love.audio.play(snd)
        end
      elseif key == "a" then
        if buttons[selected] then
          buttons[selected].action()
          love.audio.rewind(snd)
          love.audio.play(snd)
        end
      elseif key == "b" then
        component.back()
        love.audio.rewind(snd)
        love.audio.play(snd)
      end
    end
  end
  
  local function delete ()
    event.unsubscribe("pressed", 0, pressed)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("pressed", 0, pressed)
  event.subscribe("delete", id, delete)
  
  return component
end

local M = {}

local huds = {}

--Create a new hud menu
M.new = function (state, pos)
  local id = entity.new(state)
  entity.setOrder(id, 100)
  
  huds[id] = hud(id, pos)
  
  entity.addComponent(id, huds[id])
  
  return id
end

--Creates a new button of set type and desired callback function.
--The buttType is to define the sprite image
M.newButton = function (buttType, callback)
  --Pull the index location for the desired button type
  local index = buttLoc[buttType]
  local row = math.floor(index / 16)
  local col = index % 16
  --Load the hud image
  local img = resource.get("img/hud.png")

  local button = {
    action = callback or defaultAction,
    image = img,
    --The unselected quad
    quadU = love.graphics.newQuad(
      16*col, 32*row, 16, 16,
      img:getWidth(), img:getHeight()
    ),
    --The selected quad
    quadS = love.graphics.newQuad(
      16*col, (32*row)+16, 16, 16,
      img:getWidth(), img:getHeight()
    ),
    type = buttType
  }

  return button
end

M.addButton = function (id, button)
  huds[id]:addButton(button)
end

M.setBack = function(id, callback)
  huds[id]:setBack(callback)
end

M.enable = function(id)
  huds[id]:enable()
end

M.disable = function(id)
  huds[id]:disable()
end

return M

