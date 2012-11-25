
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
  isMale = math.random(0,1) < .5  --randomize male or female
  
  local prefix = "resources/img/people_parts"
  local nudes = love.filesystem.enumerate(nudeimg)
  nudeimg = nudeimg .. nudes[math.random(1,#nudes)]
  nudeimg = string.sub(nudeimg,10)
  
  local staffimg = "resources/img/people_parts"
  
  --add skin
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(nudeimg),
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
  
  local pos = {roomNum = -1, floorNum = 1}
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  entity.addComponent(id,entity.newComponent{
    timer = 0,
    update = function (self,dt)
      self.timer = self.timer - dt
      if self.timer <= 0 then
        money = money - STAFF_WAGE
        self.timer = self.timer + PAY_PERIOD
      end
    end,
  })
  local aiComponent = ai.new(id)
  aiComponent:addCleanGoal()
  entity.addComponent(id, aiComponent)
  
  return id
end

return M
