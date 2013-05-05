-- stocker.lua
-- GUI element for restocking service rooms

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")
local room = require("room")

--Create the module
local M = {}

local getRoom = function ()
  local pos = {roomNum = gRoomNum, floorNum = gScrollPos}
  local roomId = -1
  local type = ""
  event.notify("room.check", 0, {
    roomNum = pos.roomNum,
    floorNum = pos.floorNum,
    callback = function (id, t)
      roomId = id
      type = t
    end
  })
  
  if roomId == -1 then
    return
  end
  
  return roomId, type
end

local stocker = function (id, cost, t)
  local component = entity.newComponent({
    x = 0,
    y = 0,
    pixelWidth = t.width,
    pixelHeight = t.height,
  })
  
  local new = true
  local stockable = false

  component.draw = function (self)
    if stockable then
      love.graphics.setColor(0,184,0)
    else
      love.graphics.setColor(172,16,0)
    end
    love.graphics.setLine(1, "rough")
    love.graphics.rectangle("line", self.x-.5, self.y-.5, self.pixelWidth+1, self.pixelHeight+1)
  end
    
  local updatePosition = function()
    event.notify("entity.move", id, {roomNum = gRoomNum, floorNum = gScrollPos})
    
    local roomId, type = getRoom()
    if roomId ~= nil then
      local info = resource.get("scr/rooms/" .. string.lower(type) .. ".lua")
      stockable = false
      if info.restockCost then
        if room.isBroken(roomId) then
          event.notify("menu.info", 0, {name = "Cost:", desc = "BROKEN"})
        elseif room.getStock(roomId) < info.stock then
          stockable = true
          event.notify("menu.info", 0, {
            name = "Cost:",
            desc = "$" .. info.restockCost,
          })
        else
          event.notify("menu.info", 0, {name = "Cost:", desc = "FULL"})
        end
      else
        event.notify("menu.info", 0, {name = "", desc = ""})
      end
    else
      event.notify("menu.info", 0, {name = "", desc = ""})
    end
  end

  component.update = function (dt)
    if new then
      updatePosition()
      new = false
    end
  end
  
  local pressed = function (key)
    if gState == STATE_PLAY then
      if key == "left" then
        if gRoomNum > 1 then
          gRoomNum = gRoomNum - 1
          updatePosition()
        end
      elseif key == "right" then
        if gRoomNum < 7 then
          gRoomNum = gRoomNum + 1
          updatePosition()
        end
      elseif key == "a" then
        local roomId, type = getRoom()

        if roomId == nil then
          local snd = resource.get("snd/error.wav")
          love.audio.rewind(snd)
          love.audio.play(snd)
          return
        end

        local info = resource.get("scr/rooms/" .. string.lower(type) .. ".lua")
        local stock = room.getStock(roomId)

        if not room.isBroken(roomId) and
            info.restockCost and
            stock < info.stock and
            room.occupation(roomId) == 0 and
            gMoney > info.restockCost then
          
          room.setStock(roomId, 8)
          moneyChange(-info.restockCost, {
            roomNum = gRoomNum,
            floorNum = gScrollPos,
          })
          
          stockable = false
          event.notify("menu.info", 0, {name = "Cost:", desc = "FULL"})

          local snd = resource.get("snd/select.wav")
          love.audio.rewind(snd)
          love.audio.play(snd)

	  return true
        else
          local snd = resource.get("snd/error.wav")
          love.audio.rewind(snd)
          love.audio.play(snd)
          if info.stock and info.restockCost > gMoney then
            alert("funds")
          end
        end
      end
    end
  end

  local scroll = function (scrollPos)
    component.floorNum = scrollPos
    updatePosition()
  end

  local move = function (pos)
    component.x = pos.x
    component.y = pos.y
  end

  local function delete ()
    event.unsubscribe("pressed", 0, pressed)
    event.unsubscribe("scroll", 0, scroll)
    event.unsubscribe("sprite.move", id, move)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("pressed", 0, pressed)
  event.subscribe("scroll", 0, scroll)
  event.subscribe("sprite.move", id, move)
  event.subscribe("delete", id, delete)
  
  return component
end

--Constructor
M.new = function (state)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  entity.setOrder(id, 100)

  --Add position component
  entity.addComponent(id, transform.new(id, {roomNum = gRoomNum, floorNum = gScrollPos}))
  --Add demolisher component (including outline)
  entity.addComponent(id, stocker(id, room.cost, {
    width = 32,
    height = 32,
  }))

  --Function returns the rooms id
  return id
end

--Return the module
return M
