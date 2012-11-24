-- input.lua

local event = require "event"

local M = {}

local training = false
local current = 1
local inputs = {
   "a",
   "b",
   "left",
   "right",
   "up",
   "down",
}

event.subscribe("begin training", 0, function ()
  training = true
  current = 1
end)

local map = {
   keys = {},
   joysticks = {},
}

trainNext = function ()
  current = current + 1
  if current > #inputs then
     training = false
     event.notify("end training", 0)
  end
end

M.keyPressed = function (key)
  if training then
     if not map.keys[key] then
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
        map.joysticks[joystick] = {}
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

-- local joystickPushed = function (joystick, axis)
  
-- end

-- local oldAxis = {}

-- M.update = function (dt)
--   for i=0,love.joystick.getNumJoysticks() then
--     for j=1,love.joystick.getNumAxes(i) do
--       if love.joystick.getAxis(i, j) > 0.2 then
--          joystickPushed(i, j)
--       elseif love.joystick.getAxis(i, j) < -0.2 then
--          joystickPushed(i, -j)
--       end
--     end
--   end
-- end

return M