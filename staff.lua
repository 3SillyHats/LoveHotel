
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local room = require("room")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")

local M = {}

local staff = {}

M.new = function (type)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, 50)
  isMale = math.random() < .5  --randomize male or female

  local prefix = "data/img/people"
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
  local nudes = love.filesystem.getDirectoryItems(nudeimg)
  local hairs = love.filesystem.getDirectoryItems(hairimg)
  nudeimg = nudeimg .. nudes[math.random(1,#nudes)]
  nudeimg = string.sub(nudeimg,5)  -- remove "data/"
  hairimg = string.sub(hairimg,5)
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
        cooking = {
          frames = {3,4,3,4,3,4,3,4,5,6,5,6,5,6,5,6},
          speed = .2,
        },
        fixing = {
          first = 7,
          last = 10,
          speed = .2,
        },
        stocking = {
          first = 11,
          last = 14,
          speed = .2,
        },
      },
      playing = "idle",
    }
  ))

  --add hair
  if type ~= "cook" and type ~= "stocker" then
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
  end

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
        cooking = {
          frames = {3,4,3,4,3,4,3,4,5,6,5,6,5,6,5,6},
          speed = .2,
        },
        fixing = {
          first = 3,
          last = 6,
          speed = .2,
        },
        stocking = {
          first = 3,
          last = 6,
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
        local pos = transform.getPos(id)
        moneyChange(-self.wage, pos)
        self.timer = self.timer + PAY_PERIOD
      end
    end,
  }
  entity.addComponent(id, payCom)

  -- update global staff totals
  gStaffTotals[type] = gStaffTotals[type] + 1

  -- Add AI component
  local aiComponent = ai.newStaff(id, type, gStaffTotals[type])
  entity.addComponent(id, aiComponent)
  aiComponent.moveRoom = 1
  aiComponent.moveFloor = 0
  aiComponent:push("moveTo")
  
   -- Type-specific initialisation
  if type == "cleaner" then
    payCom.wage = CLEANER_WAGE
  elseif type == "bellhop" then
    payCom.wage = BELLHOP_WAGE
  elseif type == "cook" then
    payCom.wage = COOK_WAGE
  elseif type == "maintenance" then
    payCom.wage = MAINTENANCE_WAGE
  elseif type == "stocker" then
    payCom.wage = STOCKER_WAGE
  end

  local check = function (t)
    local epos = transform.getPos(id)
    if t.floorNum == epos.floorNum and t.roomNum < epos.roomNum + 0.5 and t.roomNum + t.width > epos.roomNum + 0.5 then
      t.callback(id)
    end
  end

  event.subscribe("actor.check", 0, check)

  local function delete (e)
    for k,v in ipairs(staff) do
      if v.id == id then
        table.remove(staff,k)
      end
    end
    event.unsubscribe("build", 0, onBuild)
    event.unsubscribe("actor.check", 0, check)
    event.unsubscribe("delete", id, delete)
  end

  event.subscribe("delete", id, delete)

  table.insert(staff, {
    id = id,
    ai = aiComponent,
  })

  return id
end

M.getAll = function ()
  return staff
end

return M
