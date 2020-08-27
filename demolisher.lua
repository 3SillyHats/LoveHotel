-- demolisher.lua
-- GUI element for destroying a placed room

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")
local room = require("room")

--Create the module
local M = {}

local menus = {}

local demolisher = function (id, cost, t)
  local component = entity.newComponent({
    x = 0,
    y = 0,
    pixelWidth = t.width,
    pixelHeight = t.height,
  })
  
  local new = true
  local blink = false
  local blinkTimer = 0

  component.draw = function (self)
    if not blink then
      love.graphics.setColor(0.0/255.0, 0.0/255.0, 0.0/255.0)
      love.graphics.setLineWidth(3)
      love.graphics.setLineStyle("rough")      
      love.graphics.rectangle("line", self.x-.5, self.y-.5, self.pixelWidth+1, self.pixelHeight+1)
      
      love.graphics.setColor(228.0/255.0,96.0/255.0,24.0/255.0)
      love.graphics.setLineWidth(1)
      love.graphics.setLineStyle("rough")
      love.graphics.rectangle("line", self.x-.5, self.y-.5, self.pixelWidth+1, self.pixelHeight+1)
    end
  end
    
  local updatePosition = function()
    event.notify("entity.move", id, {roomNum = gRoomNum, floorNum = gScrollPos})
  end

  component.update = function (self, dt)
    if new then
      updatePosition()
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
    if gState == STATE_PLAY then
      blink = false
      blinkTimer = 0
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
        
        if roomId == -1 or type == "elevator" or type == "reception" then
          local snd = resource.get("snd/error.wav")
          snd:seek(0)
          love.audio.play(snd)
          return
        end

        local info = resource.get("scr/rooms/" .. string.lower(type) .. ".lua")

        if room.occupation(roomId) == 0 then
          entity.delete(roomId)
          event.notify("destroy", roomId, {id=roomId, pos=pos, type=type})
          event.notify("destroy", 0, {id=roomId, pos=pos, type=type})

          local snd = resource.get("snd/destroy.wav")
          snd:setVolume(1)
          snd:seek(0)
          love.audio.play(snd)
	  return true
        else
          local snd = resource.get("snd/error.wav")
          snd:seek(0)
          love.audio.play(snd)
        end
      end
    end
  end

  local scroll = function (scrollPos)
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
  menus[#menus+1] = id

  --Add position component
  entity.addComponent(id, transform.new(id, {roomNum = gRoomNum, floorNum = gScrollPos}))
  --Add demolisher component (including outline)
  entity.addComponent(id, demolisher(id, room.cost, {
    width = 32,
    height = 32,
  }))

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
