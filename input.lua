-- input.lua

local luatexts = require("luatexts")

local event = require("event")
local resource = require("resource")

local M = {}

local training = false
local current = 1
local inputs = {
  "up",
  "down",
  "left",
  "right",
  "select",
  "start",
  "b",
  "a",
}

local map = {
  keys = {},
  joysticks = {},
}

event.subscribe("training.begin", 0, function ()
  training = true
  current = 1
  map = {
    keys = {},
    joysticks = {},
  }
  event.notify("state.enter", 0, 1)
  event.notify("training.current", 0, inputs[current])
end)

event.subscribe("training.load", 0, function ()
  if love.filesystem.getInfo(FILE_SETTINGS) ~= nil then
    local success, result = luatexts.load(love.filesystem.read(
      FILE_SETTINGS
    ))
    if success then
      gShowHelp = false
      training = false
      current = nil
      map = result
      event.notify("training.end", 0)
    end
  end
end)

local trainNext = function ()
  current = current + 1
  local snd = resource.get("snd/select.wav")
  snd:seek(0)
  love.audio.play(snd)
  if current > #inputs then
    training = false
    event.notify("training.end", 0)
    M.save()
  else
    event.notify("training.current", 0, inputs[current])
  end
end

M.save = function ()
  local s = luatexts.save(map)
  love.filesystem.write(
    FILE_SETTINGS,
    s
  )
end

M.keyPressed = function (key)
  if training then
    if key ~= nil and not map.keys[key] then
      map.keys[key] = inputs[current]
      trainNext()
    end
    return
  end

  if map.keys[key] then
    event.notify("pressed", 0, map.keys[key])
  end
end

M.keyReleased = function (key)
  if training then
    return
  end

  if map.keys[key] then
    event.notify("released", 0, map.keys[key])
  end
end

M.joystickPressed = function (joystick, button)
  id = joystick:getID()
  if training then
    if not map.joysticks[id] then
      map.joysticks[id] = {
        buttons = {},
        axes = {},
        hats = {},
      }
    end
    if not map.joysticks[id].buttons[button] then
      map.joysticks[id].buttons[button] = inputs[current]
      trainNext()
    end
    return
  end
  
  if map.joysticks[id] and map.joysticks[id].buttons[button] then
    event.notify("pressed", 0, map.joysticks[id].buttons[button])
  end
end

M.joystickReleased = function (joystick, button)
  id = joystick:getID()
  if training then
    return
  end
  
  if map.joysticks[id] and map.joysticks[id].buttons[button] then
    event.notify("released", 0, map.joysticks[id].buttons[button])
  end
end

local joystickPushed = function (joystick, axis)
  if training then
    if not map.joysticks[joystick] then
      map.joysticks[joystick] = {
        buttons = {},
        axes = {},
        hats = {},
      }
    end
    if not map.joysticks[joystick].axes[axis] then
      map.joysticks[joystick].axes[axis] = inputs[current]
      trainNext()
    end
    return
  end
  
  if map.joysticks[joystick] and map.joysticks[joystick].axes[axis] then
    event.notify("pressed", 0, map.joysticks[joystick].axes[axis])
  end
end

local joystickReleased = function (joystick, axis)
  if training then
    return
  end
  
  if map.joysticks[joystick] and map.joysticks[joystick].axes[axis] then
    event.notify("released", 0, map.joysticks[joystick].axes[axis])
  end
end

local oldAxis = {}
local oldHat = {}

M.update = function (dt)
  for i, joystick in  ipairs(love.joystick.getJoysticks()) do
    id = joystick:getID()
    if not oldAxis[id] then
      oldAxis[id] = {}
    end
    if not oldHat[id] then
      oldHat[id] = {}
    end
    for j=1,joystick:getHatCount() do
      if not oldHat[id][j] then
        oldHat[id][j] = 'c'
      end
      local hat = joystick:getHat(j)
      if training then
        if hat ~= oldHat[id][j] and (hat == 'u' or hat == 'd' or hat == 'l' or hat == 'r') then
          if not map.joysticks[id] then
            map.joysticks[id] = {
              buttons = {},
              axes = {},
              hats = {},
            }
          end
          if not map.joysticks[id].hats[hat] then
            map.joysticks[id].hats[hat] = inputs[current]
            trainNext()
          end
        end
      else
        if hat ~= oldHat[id][j] then
          if map.joysticks[id] then
            if (hat == 'u' or hat == 'd' or hat == 'l' or hat == 'r') and map.joysticks[id].hats[hat] then
              event.notify("pressed", 0, map.joysticks[id].hats[hat])
            end
            if (oldHat[id][j] == 'u' or oldHat[id][j] == 'd' or oldHat[id][j] == 'l' or oldHat[id][j] == 'r')
                and map.joysticks[id].hats[oldHat[id][j]] then
              event.notify("released", 0, map.joysticks[id].hats[oldHat[id][j]])
            end
          end
        end
      end
      
      oldHat[id][j] = hat
    end
     for j=1,joystick:getAxisCount() do
      if not oldAxis[id][j] then
        oldAxis[id][j] = 0
      end
      local axis = joystick:getAxis(j)
      if axis > 0.2 and oldAxis[id][j] <= 0.2 then
        joystickPushed(id, j)
      elseif axis <= 0.2 and oldAxis[id][j] > 0.2 then
        joystickReleased(id, j)
      end
      if axis < -0.2 and oldAxis[id][j] >= -0.2  then
        joystickPushed(id, -1-j)
      elseif axis >= -0.2 and oldAxis[id][j] < -0.2 then
        joystickReleased(id, -1-j)
      end
      oldAxis[id][j] = axis
    end
  end
end

M.isMapped = function (key)
  if map.keys[key] then
    return true
  else
    return false
  end
end

return M
