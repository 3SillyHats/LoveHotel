-- builder.lua
-- GUI element for placing a new room

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

local placer = function (id, type, width, cost, t)
  local component = entity.newComponent({
    width = width,
    cost = cost,
    x = 0,
    y = 0,
    pixelWidth = t.width,
    pixelHeight = t.height,
  })
  
  local clear = true
  local occupation = 0
  local new = true
  local blink = false
  local blinkTimer = 0

  local okay = function ()
    return (
      clear and
      (gScrollPos <= gTopFloor and gScrollPos >= gBottomFloor) and
      (gRoomNum + component.width <= 8 and gRoomNum >= 1) and
      cost <= gMoney
    )
  end
  
  component.draw = function (self)
    if not blink then
      love.graphics.setColor(0, 0, 0)
      love.graphics.setLine(3, "rough")
      love.graphics.rectangle("line", self.x-.5, self.y-.5, self.pixelWidth+1, self.pixelHeight+1)
      
      if okay() then
        love.graphics.setColor(0,184,0)
      else
        love.graphics.setColor(172,16,0)
      end
      love.graphics.setLine(1, "rough")
      love.graphics.rectangle("line", self.x-.5, self.y-.5, self.pixelWidth+1, self.pixelHeight+1)
    end
  end
    
  local updatePosition = function()
    clear = true
    event.notify("entity.move", id, {roomNum = gRoomNum, floorNum = gScrollPos})
    
    for i = 1,component.width do
      event.notify("room.check", 0, {
        roomNum = gRoomNum + i - 1,
        floorNum = gScrollPos,
        callback = function (otherId)
          clear = false
        end,
      })
    end
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
        if gRoomNum+component.width <= 7 then
          gRoomNum = gRoomNum + 1
          updatePosition()
        end
      elseif key == "a" then
        if okay() then
          local pos = {roomNum = gRoomNum, floorNum = gScrollPos}
          local roomId = room.new(STATE_PLAY, type, pos)
          gMoney = gMoney - cost
            event.notify("money.change", 0, {
            amount = -cost,
            pos = pos,
          })
          event.notify("build", id, {id=roomId, pos=pos, type=type})
          event.notify("build", 0, {id=roomId, pos=pos, type=type})
          local snd = resource.get("snd/build.wav")
          love.audio.rewind(snd)
          love.audio.play(snd)
          
          clear = false
	  return true
        else
          local snd = resource.get("snd/error.wav")
          love.audio.rewind(snd)
          love.audio.play(snd)
          if cost > gMoney then
            alert("funds")
          end
        end
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
M.new = function (state, roomType)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  entity.setOrder(id, 100)
  menus[#menus+1] = id
  
  local room = resource.get("scr/rooms/" .. string.lower(roomType) .. ".lua")
  local roomWidth = room.width*32
  local roomHeight = 32
  local prefix = "img/rooms/" .. room.id .. "_"
  
  gRoomNum = math.min(8 - room.width, gRoomNum)
  
  --Add sprite components
  for _,s in ipairs(room.sprites) do
    entity.addComponent(id, sprite.new(id, {
      image = resource.get(prefix .. s.name .. ".png"),
      width = roomWidth,
      height = roomHeight,
      animations = s.animations,
      playing = "closed",
    }))
  end

  --Add position component
  entity.addComponent(id, transform.new(id, {roomNum = gRoomNum, floorNum = gScrollPos}))
  --Add placer component (including outline)
  entity.addComponent(id, placer(id, roomType, room.width, room.cost, {
    width = room.width*32,
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
