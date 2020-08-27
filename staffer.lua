-- staffer.lua
-- GUI element for managing staff

local WAGES = {}
WAGES["bellhop"] = BELLHOP_WAGE
WAGES["cleaner"] = CLEANER_WAGE
WAGES["maintenance"] = MAINTENANCE_WAGE
WAGES["cook"] = COOK_WAGE
WAGES["stocker"] = STOCKER_WAGE

local entity = require("entity")
local resource = require("resource")
local event = require("event")
local transform = require("transform")
local staff = require("staff")

local M = {}

local menus = {}
local IconQuad = love.graphics.newQuad(
  128, 64,
  16, 16,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local DArrowQuad = love.graphics.newQuad(
  24, 168,
  8, 8,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local UArrowQuad = love.graphics.newQuad(
  24, 160,
  8, 8,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)

local offsets = {
  cleaner = 0,
  bellhop = 16,
  cook = 32,
  maintenance = 48,
  stocker = 62,
}

local staffer = function (id, type)
  local component = entity.newComponent()

  local new = true
  local blink = false
  local blinkTimer = 0

  gScrollable = false

  IconQuad:setViewport(128 + offsets[type], 64, 16, 16)

  component.draw = function (self)
    love.graphics.setColor(255.0/255.0, 255.0/255.0, 255.0/255.0)

    -- Staff icon
    love.graphics.draw(
      resource.get("img/hud.png"), IconQuad,
      116, CANVAS_HEIGHT - 24,
      0
    )

    -- Current staff number
    love.graphics.printf(
      tostring(gStaffTotals[type]),
      136, 203,
      16,
      "center"
    )

    -- TOTAL or MAX staff number
    love.graphics.setColor(123.0/255.0, 126.0/255.0, 127.0/255.0)
    if gStaffTotals[type] == STAFF_MAX[type] then
      love.graphics.print(
        string.format("MAX"),
        156, 203
      )
    else
      love.graphics.print(
        string.format("TOTAL"),
        156, 203
      )
    end
    love.graphics.setColor(255.0/255.0, 255.0/255.0, 255.0/255.0)

    -- Arrows
    if gStaffTotals[type] > 0 and not blink then
      love.graphics.draw(
        resource.get("img/hud.png"), DArrowQuad,
        140, CANVAS_HEIGHT - 10,
        0
      )
    end
    if gStaffTotals[type] < STAFF_MAX[type] and not blink then
      love.graphics.draw(
        resource.get("img/hud.png"), UArrowQuad,
        140, CANVAS_HEIGHT - 26,
        0
      )
    end
  end
  
  component.update = function (self, dt)
    if new then
      event.notify("menu.info", 0, {name = "", desc = ""})
      new = false
    end
    blinkTimer = blinkTimer + dt
    if (blink and blinkTimer > .5) or
        (not blink and blinkTimer > 1) then
      blinkTimer = 0
      blink = not blink
    end
  end
  
  local pressed = function (key)
    if gState ~= STATE_PLAY then return end
    blink = false
    blinkTimer = 0

    if key == "down" then
      if gStaffTotals[type] > 0 then
        gStaffTotals[type] = gStaffTotals[type] - 1
      else
        local snd = resource.get("snd/error.wav")
        snd:seek(0)
        love.audio.play(snd)
      end
    elseif key == "up" then
      if gStaffTotals[type] < STAFF_MAX[type] and gMoney >= WAGES[type] then
        staff.new(type)
      else
        local snd = resource.get("snd/error.wav")
        snd:seek(0)
        love.audio.play(snd)
        if WAGES[type] > gMoney then
          alert("funds")
        end
      end
    end
  end

  local function delete ()
    event.unsubscribe("pressed", 0, pressed)
    event.unsubscribe("delete", id, delete)
    gScrollable = true
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
  menus[#menus+1] = id

  --Add staffer component
  entity.addComponent(id, staffer(id, type))

  --Function returns the rooms id
  return id
end

M.clear = function ()
  for _,id in ipairs(menus) do
    entity.delete(id)
  end
  menus = {}
end

--Return the module
return M
