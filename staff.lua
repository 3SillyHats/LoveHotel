
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
      playing = "idle"
    }
  ))
  entity.addComponent(id, transform.new(
    id, {roomNum = -1.5, floorNum = 1}, {x = 16, y = 30}
  ))
  local com = entity.newComponent({
    roomNum = -1.5,
    floorNum = 1,
    update = function (self, dt)
      event.notify("entity.move", id, {
        roomNum = self.roomNum + 1*dt,
        floorNum = self.floorNum
      })
    end
  })
  event.subscribe("entity.move", id, function (pos)
    com.roomNum = pos.roomNum
    com.floorNum = pos.floorNum
  end)
  entity.addComponent(id, com)
  --[[entity.addComponent(id, ai.new(id, {
    subgoals = {
      ai.newMoveToGoal({x = 0, y = 0})
    }
  })--]]
  
  return id
end

return M
