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
  if love.filesystem.exists(FILE_SETTINGS) then
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
  love.audio.rewind(snd)
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
  if training then
    if not map.joysticks[joystick] then
      map.joysticks[joystick] = {
        buttons = {},
        axes = {},
        hats = {},
      }
    end
    if not map.joysticks[joystick].buttons[button] then
      map.joysticks[joystick].buttons[button] = inputs[current]
      trainNext()
    end
    return
  end
  
  if map.joysticks[joystick] and map.joysticks[joystick].buttons[button] then
    event.notify("pressed", 0, map.joysticks[joystick].buttons[button])
  end
end

M.joystickReleased = function (joystick, button)
  if training then
    return
  end
  
  if map.joysticks[joystick] and map.joysticks[joystick].buttons[button] then
    event.notify("released", 0, map.joysticks[joystick].buttons[button])
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
  for i=1,love.joystick.getJoystickCount() do
    if not oldAxis[i] then
      oldAxis[i] = {}
    end
    if not oldHat[i] then
      oldHat[i] = {}
    end
    for j=1,love.joystick.getNumHats(i) do
      if not oldHat[i][j] then
        oldHat[i][j] = 'c'
      end
      local hat = love.joystick.getHat(i,j)
      if training then
        if hat ~= oldHat[i][j] and (hat == 'u' or hat == 'd' or hat == 'l' or hat == 'r') then
          if not map.joysticks[i] then
            map.joysticks[i] = {
              buttons = {},
              axes = {},
              hats = {},
            }
          end
          if not map.joysticks[i].hats[hat] then
            map.joysticks[i].hats[hat] = inputs[current]
            trainNext()
          end
        end
      else
        if hat ~= oldHat[i][j] then
          if map.joysticks[i] then
            if (hat == 'u' or hat == 'd' or hat == 'l' or hat == 'r') and map.joysticks[i].hats[hat] then
              event.notify("pressed", 0, map.joysticks[i].hats[hat])
            end
            if (oldHat[i][j] == 'u' or oldHat[i][j] == 'd' or oldHat[i][j] == 'l' or oldHat[i][j] == 'r')
                and map.joysticks[i].hats[oldHat[i][j]] then
              event.notify("released", 0, map.joysticks[i].hats[oldHat[i][j]])
            end
          end
        end
      end
      
      oldHat[i][j] = hat
    end
     for j=1,love.joystick.getNumAxes(i) do
      if not oldAxis[i][j] then
        oldAxis[i][j] = 0
      end
      local axis = love.joystick.getAxis(i, j)
      if axis > 0.2 and oldAxis[i][j] <= 0.2 then
        joystickPushed(i, j)
      elseif axis <= 0.2 and oldAxis[i][j] > 0.2 then
        joystickReleased(i, j)
      end
      if axis < -0.2 and oldAxis[i][j] >= -0.2  then
        joystickPushed(i, -1-j)
      elseif axis >= -0.2 and oldAxis[i][j] < -0.2 then
        joystickReleased(i, -1-j)
      end
      oldAxis[i][j] = axis
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
