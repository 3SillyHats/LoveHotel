
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local room = require("room")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")

local M = {}

M.new = function (type)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, 50)
  isMale = math.random() < .5  --randomize male or female

  local prefix = "resources/img/people"
  local nudeimg
  local hairimg
  local staffimg
  if isMale then
    nudeimg = prefix .. "/man/nude/"
    hairimg = prefix .. "/man/hair/crewcut.png"
    staffimg = "img/people/man/staff/" .. type .. ".png"
  else
    nudeimg = prefix .. "/woman/nude/"
    hairimg = prefix .. "/woman/hair/curled.png"
    staffimg = "img/people/woman/staff/" .. type .. ".png"
  end
  local nudes = love.filesystem.enumerate(nudeimg)
  local hairs = love.filesystem.enumerate(hairimg)
  nudeimg = nudeimg .. nudes[math.random(1,#nudes)]
  nudeimg = string.sub(nudeimg,10)  -- remove "resources/"
  hairimg = string.sub(hairimg,10)
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
  
  local pos = {roomNum = -.5, floorNum = GROUND_FLOOR}
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  local payCom = entity.newComponent{
    timer = 0,
    update = function (self,dt)
      self.timer = self.timer - dt
      if self.timer <= 0 then
        gMoney = gMoney - self.wage
        local pos = nil
        event.notify("entity.pos", id, function (e)
          pos = e
        end)
        event.notify("money.change", 0, {
          amount = -self.wage,
          pos = pos,
        })
        self.timer = self.timer + PAY_PERIOD
      end
    end,
  }
  entity.addComponent(id, payCom)
  
  local aiComponent = ai.new(id)
  local addRoomGoal
  
  -- Type-specific initialisation
  if type == "cleaner" then
    payCom.wage = CLEANER_WAGE
    
    -- start with no cleaning supplies
    aiComponent.supply = 0
  
    addRoomGoal = function (id)
      local info = room.getInfo(id)
      if info.dirtyable then
        aiComponent:addCleanGoal(id)
      elseif info.cleaningSupplies then
        aiComponent:addSupplyGoal(id)
      end
    end
  elseif type == "bellhop" then
    payCom.wage = BELLHOP_WAGE
    
    addRoomGoal = function (id)
      local info = room.getInfo(id)
      if info.reception then
        aiComponent:addBellhopGoal(id)
      end
    end
  elseif type == "cook" then
    payCom.wage = COOK_WAGE
  elseif type == "maintenance" then
    payCom.wage = MAINTENANCE_WAGE
  
    addRoomGoal = function (id)
      local info = room.getInfo(id)
      if info.breakable then
        aiComponent:addMaintenanceGoal(id)
      end
    end
  end

  event.notify("room.all", 0, function (id,type)
    addRoomGoal(id)
  end)
  event.subscribe("build", 0, function (t)
    addRoomGoal(t.id)
  end)

  aiComponent:addEnterGoal() -- First goal: enter building
  entity.addComponent(id, aiComponent)
  
  local check = function (t)
    local epos = transform.getPos(id)
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
