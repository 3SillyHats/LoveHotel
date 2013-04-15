-- inspector.lua
-- GUI element for inspecting the properties of staff and clients

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")
local client = require("client")
local staff = require("staff")

--Create the module
local M = {}

local richestInfo = resource.get("scr/people/space.lua")
local MAX_MONEY = richestInfo.money
local info = {
  condoms = 0,
  money = 0,
  patience = 0,
  horniness = 0,
  hunger = 0,
}

--Constructor
M.new = function (state)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  entity.setOrder(id, 100)

  --Add sprite component
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get("img/arrow.png"),
      width = 24, height = 24,
      animations = {
        idle = {
          first = 0,
          last = 7,
          speed = .1
        },
      },
      playing = "idle",
      originX = 12-16,
      originY = 24-32+24,
      hidden = true,
    }
  ))
  
  --Add position component
  entity.addComponent(id, transform.new(id, {roomNum = gRoomNum, floorNum = gScrollPos}))

  local unselectedInfo = {
    name = "Inspect",
    desc = "Select client",
  }
  event.notify("menu.info", 0, unselectedInfo)

  local getNext = function (self, scale)
    local clients = client.getAll()
    local minPosA = 20
    local minEntA = nil
    local minPosB = 20
    local minEntB = nil
    local cutoff = 20
    if self.target then
      local pos = transform.getPos(self.target.id)
      if pos then
        cutoff = pos.roomNum*scale
      end
    end
    for _,c in ipairs(clients) do
      local pos = transform.getPos(c.id)
      if pos and math.floor(pos.floorNum+0.5) == self.floor then
        if (not self.target or c.id ~= self.target.id) and
            pos.roomNum*scale < minPosA and pos.roomNum*scale >= cutoff then
          minPosA = pos.roomNum*scale
          minEntA = c
        end
        if pos.roomNum*scale < minPosB then
          minPosB = pos.roomNum*scale
          minEntB = c
        end
      end
    end
    if minEntA then
      return minEntA
    else
      return minEntB
    end
  end

  --Add inspector component
  inspectorUtility = entity.newComponent({
    entity = id,
    hidden = true,
    target = nil,
    floor = gScrollPos,
    update = function (self, dt)
      if not self.target or not entity.get(self.target.id) then
        self.target = getNext(self, 1)
      end
      
      if not self.target or not entity.get(self.target.id) then
        if not self.hidden then
          event.notify("sprite.hide", self.entity, true)
          self.hidden = true
          event.notify("menu.info", 0, unselectedInfo)
        end
      else
        if self.hidden then
          event.notify("sprite.hide", self.entity, false)
          self.hidden = false
        end
        local pos = transform.getPos(self.target.id)
        event.notify("entity.move", self.entity, pos)

        local floor = math.floor(pos.floorNum+0.5)
        if floor ~= self.floor then
          self.floor = floor
          event.notify("scroll", 0, floor)
        end

        info.condoms = self.target.ai.condoms
        info.money = math.sqrt(self.target.ai.money) / math.sqrt(MAX_MONEY)
        info.patience = self.target.ai.patience / 100
        info.horniness = self.target.ai.horniness / 100
        info.hunger = self.target.ai.satiety / 100

        event.notify("menu.info", 0, {
          inspector = info,
        })
      end
    end,
  })

  entity.addComponent(id, inspectorUtility)

  local pressed = function (key)
    if gState == STATE_PLAY then
      if key == "left" then
        inspectorUtility.target = getNext(inspectorUtility, -1)
      elseif key == "right" then
        inspectorUtility.target = getNext(inspectorUtility,  1)
      end
    end
  end

  local scroll = function (floor)
    if floor ~= inspectorUtility.floor then
      inspectorUtility.floor = floor
      inspectorUtility.target = getNext(inspectorUtility,  1)
    end
  end

  local delete
  delete = function ()
    event.unsubscribe("pressed", 0, pressed)
    event.unsubscribe("scroll", 0, scroll)
    event.unsubscribe("delete", id, delete)
  end

  event.subscribe("pressed", 0, pressed)
  event.subscribe("scroll", 0, scroll)
  event.subscribe("delete", id, delete)
  --Function returns the rooms id
  return id
end

--Return the module
return M
