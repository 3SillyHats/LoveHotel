-- staffer.lua
-- GUI element for managing staff

local entity = require("entity")
local resource = require("resource")
local event = require("event")
local transform = require("transform")
local staff = require("staff")

local M = {}

local LArrowQuad = love.graphics.newQuad(
  32, 160,
  8, 16,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local RArrowQuad = love.graphics.newQuad(
  40, 160,
  8, 16,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)

local staffer = function (id, type)
  local component = entity.newComponent()

  local max = STAFF_MAX[type]
  local new = true

  component.draw = function (self)
    love.graphics.setColor(255, 255, 255)
    
    -- Draw current number and max
    love.graphics.printf(
      string.format("%u/%u", gStaffTotals[type], max[gStars]),
      113, 209,
      79,
      "center"
    )
    
    -- Draw arrows
    if gStaffTotals[type] > 0 then
      love.graphics.drawq(
        resource.get("img/hud.png"), LArrowQuad,
        126, CANVAS_HEIGHT - 16,
        0
      )
    end
    if gStaffTotals[type] < max[gStars] then
      love.graphics.drawq(
        resource.get("img/hud.png"), RArrowQuad,
        170, CANVAS_HEIGHT - 16,
        0
      )
    end
  end
  
  component.update = function (self, dt)
    if new then
      event.notify("menu.info", 0, {name = conf.menu[type].name, desc = ""})
      new = false
    end
  end
  
  local pressed = function (key)
    if gState ~= STATE_PLAY then return end

    if key == "left" and gStaffTotals[type] > 0 then
      gStaffTotals[type] = gStaffTotals[type] - 1
    elseif key == "right" and
        gStaffTotals[type] < max[gStars] then
      staff.new(type)
    end
  end

  local function delete ()
    event.unsubscribe("pressed", 0, pressed)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("pressed", 0, pressed)
  event.subscribe("delete", id, delete)
  
  return component
end

--Constructor
M.new = function (state, type)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  entity.setOrder(id, 100)

  --Add staffer component
  entity.addComponent(id, staffer(id, type))

  --Function returns the rooms id
  return id
end

--Return the module
return M
