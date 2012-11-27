-- menu.lua

local event = require("event")
local entity = require("entity")
local resource = require("resource")

--Index locations for room types found within hud.png
buttLoc = {
  build = 1,
  destroy = 2,
  hire = 3,
  utility = 4,
  flower = 5,
  heart = 6,
  tropical = 7,
  elevator = 8,
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
      event.notify("menu.info", 0, {
        image = buttons[selected].info.image,
        name = buttons[selected].info.name,
        desc = buttons[selected].info.desc
      })
    end
  end
  
  component.setBack = function (self, callback)
    component.back = callback
  end
  
  component.enable =  function (self)
    component.enabled = true
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
          event.notify("menu.info", 0, {
            image = buttons[selected].info.image,
            name = buttons[selected].info.name,
            desc = buttons[selected].info.desc
          })
          love.audio.rewind(snd)
          love.audio.play(snd)
        end
      elseif key == "right" then
        if selected < #buttons then
          selected = selected + 1
          event.notify("menu.info", 0, {
            image = buttons[selected].info.image,
            name = buttons[selected].info.name,
            desc = buttons[selected].info.desc
          })
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
M.newButton = function (buttType, callback, info)
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
    info = info
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

