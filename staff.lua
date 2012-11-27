
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local room = require("room")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")

local M = {}

M.new = function ()
  local id = entity.new(2)
  entity.setOrder(id, 50)
  isMale = math.random(0,1) < .5  --randomize male or female
  
  local prefix = "resources/img/people_parts"
  local nudeimg = nil
  local hairimg = nil
  local staffimg = nil
  if isMale==1 then
    nudeimg = prefix .. "/man/nude/"
    hairimg = prefix .. "/man/hair/"
    staffimg = prefix .. "/man/staff/"
  else
    nudeimg = prefix .. "/woman/nude/"
    hairimg = prefix .. "/man/hair/"
    staffimg = prefix .. "/woman/staff/"
  end
  local nudes = love.filesystem.enumerate(nudeimg)
  local hairs = love.filesystem.enumerate(hairimg)
  local staffs = love.filesystem.enumerate(staffimg)
  nudeimg = nudeimg .. nudes[math.random(1,#nudes)]
  nudeimg = string.sub(nudeimg,10)
  hairimg = hairimg .. hairs[math.random(1,#hairs)]
  hairimg = string.sub(hairimg,10)
  staffimg = staffimg .. staffs[math.random(1, #staffs)]
  staffimg = string.sub(staffimg,10)
  local haircolour = math.random(0,3)
  
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

  --add hair
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(hairimg),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
        neat = {
          first = haircolour,
          last = haircolour,
          speed = 1,
        },
        messy = {
          first = haircolour + 4,
          last = haircolour + 4,
          speed = 1,
        },
      },
      playing = "neat",
    }
  ))

  --add staff uniform
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(staffimg),
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
        event.notify("money.change", 0, -STAFF_WAGE)
        self.timer = self.timer + PAY_PERIOD
      end
    end,
  })
  local aiComponent = ai.new(id)
  aiComponent:addCleanGoal()
  entity.addComponent(id, aiComponent)
  
  local check = function (t)
    local epos = room.getPos(id)
    if t.floorNum == epos.floorNum and t.roomNum < epos.roomNum + 0.5 and t.roomNum + t.width > epos.roomNum + 0.5 then
      t.callback(id)
    end
  end
  
  event.subscribe("actor.check", 0, check)
  
  local function delete (e)
    event.unsubscribe("actor.check", 0, check)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("delete", id, delete)
  
  return id
end

return M
