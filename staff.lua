
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")

local M = {}

M.new = function ()
  local id = entity.new(2)
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get("img/typing1.png"),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
        idle = {
          first = 0,
          last = 0,
          speed = 1,
        },
        typing = {
          first = 3,
          last = 0,
          speed = .1,
        },
      },
      playing = "idle",
    }
  ))
  local pos = {roomNum = -1.5, floorNum = 1}
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  local aiComponent = ai.new(id)
  entity.addComponent(id, aiComponent)
  aiComponent:addMoveToGoal(pos, {roomNum = 4, floorNum = 1}, STAFF_MOVE)
  
  return id
end

return M
