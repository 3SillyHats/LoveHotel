--The room "object" file

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")

--Create the module
local M = {}

--Room information component
local infoComponent = function (id, info, pos)
  --Create a new component to store information in,
  --then store the info table into it.
  local component = entity.newComponent(info)
  component.occupied = 0
  component.messy = false
  
  local check = function (t)
    if math.ceil(t.floorNum) == pos.floorNum and
        t.roomNum >= pos.roomNum - 0.5 and
        t.roomNum <= pos.roomNum - 0.5 + info.width then
      t.callback(id, info.type)
    end
  end
  
  event.subscribe("room.check", 0, check)
  
  local getRooms = function (callback)
    callback(id, info.type)
  end
  
  event.subscribe("room.all", 0, getRooms)
  
  local unoccupied = function (callback)
    if info.type ~= "elevator" and component.occupied == 0 and not component.messy then
      callback(id, info.type)
    end
  end
  
  event.subscribe("room.unoccupied", 0, unoccupied)
  
  local dirtyRooms = function (callback)
    if component.occupied == 0 and component.messy then
      callback(id, info.type)
    end
  end
  
  event.subscribe("room.dirty", 0, dirtyRooms)
  
  local isDirty = function (callback)
    callback(component.messy)
  end
  
  event.subscribe("room.isDirty", id, isDirty)
  
  local checkOccupied = function (callback)
    callback(component.occupied)
  end
  
  event.subscribe("room.occupation", id, checkOccupied)
  
  local occupy = function (e)
    if component.occupied < 2 then
      component.occupied = component.occupied + 1
      event.notify("sprite.hide", e.id, true)
      if component.occupied == 2 then
        event.notify("sprite.play", id, "closing")
      end
      e.callback(true)
    else
      e.callback(false)
    end
  end
  
  event.subscribe("room.occupy", id, occupy)
  
  local depart = function (e)
    if component.occupied > 0 then
      component.occupied = component.occupied - 1
    end
    if info.dirtyable and not component.messy then
      component.messy = true
    end
    -- Messify and unhide the departing person
    event.notify("sprite.play", e.id, "messy")
    event.notify("sprite.hide", e.id, false)
    if component.occupied <= 0 then
      gMoney = gMoney + info.profit
      local roomPos = M.getPos(id)
      event.notify("money.change", 0, {
        amount = info.profit,
        pos = {
          roomNum = roomPos.roomNum,
          floorNum = roomPos.floorNum,
        },
      })
      component.occupied = 0
      event.notify("sprite.play", id, "dirty")
      event.notify("sprite.play", id, "opening")
    end
  end
  
  event.subscribe("room.depart", id, depart)
  
  local beginClean = function (e)
    if component.occupied > 0 then
      e.callback(false)
      return
    end
    
    component.occupied = component.occupied + 1
    
    event.notify("sprite.hide", e.id, true)
    event.notify("sprite.play", id, "closing")
    e.callback(true)
  end
  
  event.subscribe("room.beginClean", id, beginClean)
  
  local endClean = function (e)
    component.occupied = 0
    component.messy = false
    
    event.notify("sprite.hide", e.id, false)
    event.notify("sprite.play", id, "clean")
    event.notify("sprite.play", id, "opening")
  end
  
  event.subscribe("room.endClean", id, endClean)
  
  local function delete ()
    event.unsubscribe("room.check", 0, check)
    event.unsubscribe("room.unoccupied", 0, unoccupied)
    event.unsubscribe("room.isDirty", id, isDirty)
    event.unsubscribe("room.occupation", id, checkOccupied)
    event.unsubscribe("room.occupy", id, occupy)
    event.unsubscribe("room.depart", id, depart)
    event.unsubscribe("room.beginClean", id, beginClean)
    event.unsubscribe("room.endClean", id, endClean)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("delete", id, delete)

  --Return the room info table.
  return component
end

local roomInfo = {}

--Room constructor
M.new = function (state, roomType, pos)
  --Create an entity and get the id for the new room
  local roomId = entity.new(state)
  local room = resource.get("scr/rooms/" .. string.lower(roomType) .. ".lua")
  roomInfo[roomId] = room
  room.type = roomType
  local background = resource.get("img/rooms/" .. room.id .. "_background.png")
  local foreground = resource.get("img/rooms/" .. room.id .. "_foreground.png")
  local roomWidth = room.width*32
  local roomHeight = 32

  --Add a sprite component for the back layer of the room
  entity.addComponent(roomId, sprite.new(roomId, {
    image = background,
    width = roomWidth,
    height = roomHeight,
    animations = room.backgroundAnimations,
    playing = room.defaultBackgroundAnim,
  }))
  --Add a sprite component for the front layer of the room
  entity.addComponent(roomId, sprite.new(roomId, {
    image = foreground,
    width = roomWidth,
    height = roomHeight,
    animations = room.foregroundAnimations,
    playing = room.defaultForegroundAnim,
  }))

  --Add position component
  entity.addComponent(roomId, transform.new(roomId, pos, {x = 0, y = 0}))
  
  --Add info component
  entity.addComponent(roomId, infoComponent(roomId, room, pos))

  --Function returns the rooms id
  return roomId
end

M.all = function (id)
  local rooms = {}
  event.notify("room.all", id, function (id, type)
    table.insert(rooms, id)
  end)
  return rooms
end

M.getInfo = function (id)
  return roomInfo[id] 
end

M.getPos = function (id)
  pos = transform.getPos(id)
  width = M.getInfo(id).width
  return {
    roomNum = pos.roomNum + width/2 - 0.5, 
    floorNum = pos.floorNum,
  }
end

M.isDirty = function (id)
  local dirty = false
  event.notify("room.isDirty", id, function (e)
    dirty = dirty or e
  end)
  return dirty
end

M.occupation = function (id)
  local occupation = nil
  event.notify("room.occupation", id, function (e)
    occupation = e
  end)
  return occupation
end

--Return the module
return M
