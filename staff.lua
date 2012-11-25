
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")

local M = {}

M.new = function ()
  local id = entity.new(2)
  entity.setOrder(id, 50)
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get("img/people_parts/naked_white_man.png"),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
        idle = {
          first = 0,
          last = 0,
          speed = 1,
        },
        walking = {
          first = 1,
          last = 2,
          speed = .2,
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
  aiComponent:addMoveToGoal(pos, {roomNum = 3, floorNum = 1}, STAFF_MOVE)
  
  return id
end

return M
