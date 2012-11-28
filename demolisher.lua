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

local demolisher = function (id, pos, cost, t)
  local component = entity.newComponent({
    room = pos.roomNum,
    floor = pos.floorNum,
    x = 0,
    y = 0,
    pixelWidth = t.width,
    pixelHeight = t.height,
  })
  
  local new = true

  component.draw = function (self)
    love.graphics.setColor(228,96,24)
    love.graphics.setLine(1, "rough")
    love.graphics.rectangle("line", self.x-.5, self.y-.5, self.pixelWidth+1, self.pixelHeight+1)
  end
    
  local updatePosition = function()
    clear = true
    support = 0
    event.notify("entity.move", id, {roomNum = component.room, floorNum = component.floor})
  end

  component.update = function (dt)
    if new then
      updatePosition()
      new = false
    end
  end
  
  local pressed = function (key)
    if key == "left" then
      if component.room > 1 then
        component.room = component.room - 1
        updatePosition()
      end
    elseif key == "right" then
      if component.room < 7 then
        component.room = component.room + 1
        updatePosition()
      end
    elseif key == "a" then
      local pos = {roomNum = component.room, floorNum = component.floor}
      local room = -1
      local type = ""
      event.notify("room.check", 0, {
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id, t)
          room = id
          type = t
        end
      })
      
      if room == -1 then
        return
      end

      local info = resource.get("scr/rooms/" .. string.lower(type) .. ".lua")

      local ok = true
      event.notify("actor.check", 0, {
        roomNum = component.room,
        floorNum = component.floor,
        width = info.width,
        callback = function (id)
          ok = false
        end,
      })

      if ok then
        entity.delete(room)
        
        event.notify("destroy", id, {id=room, pos=pos, type=type})
        event.notify("destroy", 0, {id=room, pos=pos, type=type})

        local snd = resource.get("snd/destroy.wav")
        love.audio.rewind(snd)
        love.audio.play(snd)
      end
    end
  end

  local scroll = function (scrollPos)
    component.floor = scrollPos
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
M.new = function (state, pos)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  entity.setOrder(id, 100)

  --Add position component
  entity.addComponent(id, transform.new(id, pos))
  --Add demolisher component (including outline)
  entity.addComponent(id, demolisher(id, pos, room.cost, {
    width = 32,
    height = 32,
  }))

  --Function returns the rooms id
  return id
end

--Return the module
return M
