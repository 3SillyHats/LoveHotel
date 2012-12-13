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
  if info.cleaningSupplies then
    component.stock = info.stock
  end
  if info.breakable then
    component.integrity = 3
  end
  
  local check = function (t)
    if math.ceil(t.floorNum) == pos.floorNum and
        t.roomNum >= pos.roomNum - 0.5 and
        t.roomNum <= pos.roomNum - 0.5 + info.width then
      t.callback(id, info.type)
    end
  end
  
  local getRooms = function (callback)
    callback(id, info.type)
  end
  
  local unoccupied = function (callback)
    if info.type ~= "elevator" and component.occupied == 0 and not component.messy then
      callback(id, info.type)
    end
  end
  
  local dirtyRooms = function (callback)
    if component.occupied == 0 and component.messy then
      callback(id, info.type)
    end
  end
  
  local isDirty = function (callback)
    callback(component.messy)
  end
  
  local checkOccupied = function (callback)
    callback(component.occupied)
  end
  
  local getStock = function (callback)
    callback(component.stock)
  end
  
  local setStock = function (stock)
    component.stock = stock
    event.notify("sprite.play", id, "stocked" .. stock)
  end
  
  local occupy = function (e)
    if component.occupied < 2 then
      component.occupied = component.occupied + 1
      if component.occupied == 2 then
        event.notify("sprite.play", id, "closing")
        if info.desirability then
          event.notify("sprite.play", id, "hearts")
        end
      end
      e.callback(true)
    else
      e.callback(false)
    end
  end
  
  local depart = function (e)
    if component.occupied > 0 then
      component.occupied = component.occupied - 1
    end
    if info.dirtyable and not component.messy then
      component.messy = true
      event.notify("sprite.play", id, "dirty")
    end
    if component.occupied <= 0 then
      component.occupied = 0
      event.notify("sprite.play", id, "opening")
      if info.desirability then
        event.notify("sprite.play", id, "heartless")
      end
    end
  end

  local beginRelax = function (e)
    if component.occupied > 0 then
      e.callback(false)
      return
    end
    
    component.occupied = component.occupied + 1

    e.callback(true)
  end
  
  local endRelax = function (e)
    component.occupied = 0
  end

  local beginCook = function (e)
    if component.occupied > 0 then
      e.callback(false)
      return
    end
    
    component.occupied = component.occupied + 1

    e.callback(true)
  end
  
  local endCook = function (e)
    component.occupied = 0
  end

  local beginFix = function (e)
    if component.occupied > 0 then
      e.callback(false)
      return
    end
    
    component.occupied = component.occupied + 1

    e.callback(true)
  end
  
  local endFix = function (e)
    component.occupied = 0
  end

  local beginClean = function (e)
    if component.occupied > 0 then
      e.callback(false)
      return
    end
    
    component.occupied = component.occupied + 1
    
    event.notify("sprite.hide", e.id, true)
    event.notify("sprite.play", id, "closing")
    event.notify("sprite.play", id, "cleaning")
    e.callback(true)
  end
  
  local endClean = function (e)
    component.occupied = 0
    component.messy = false
    
    event.notify("sprite.hide", e.id, false)
    event.notify("sprite.play", id, "clean")
    event.notify("sprite.play", id, "cleanless")
    event.notify("sprite.play", id, "opening")
  end
  
  local beginSupply = function (e)
    if component.occupied > 0 or component.stock == 0 then
      e.callback(false)
      return
    end
    
    component.occupied = component.occupied + 1
    
    if e.enter then
      event.notify("sprite.hide", e.id, true)
      event.notify("sprite.play", id, "closing")
    end
    
    e.callback(true)
  end
  
  local endSupply = function (e)
    component.occupied = 0
    component.stock = component.stock - 1
    
    event.notify("sprite.hide", e.id, false)
    event.notify("sprite.play", id, "stocked" .. component.stock)
    event.notify("sprite.play", id, "opening")
  end
  
  local isBroken = function (callback)
    if info.breakable then
      callback(component.integrity <= 0)
    else
      callback(false)
    end
  end
  
  local use = function ()
    if info.breakable then
      component.integrity = component.integrity - 1
      if component.integrity <= 0 then
        event.notify("sprite.play", id, "broken")
        event.notify("room.broken", id, {
          type = info.id,
          id = id,
          pos = pos,
        })
        event.notify("room.broken", 0, {
          type = info.id,
          id = id,
          pos = pos,
        })
      end
    end
  end
  local fix = function (t)
    component.integrity = t.integrity
    if t.integrity > 0 then
      event.notify("room.fixed", id, {
        type = info.id,
        id = id,
        pos = pos,
      })
      event.notify("room.fixed", 0, {
        type = info.id,
        id = id,
        pos = pos,
      })
      if info.stock ~= nil then
        event.notify("sprite.play", id, "stocked" .. component.stock)
      elseif info.id == "elevator" then
        event.notify("sprite.play", id, "closed")
      end
    end
  end
  
  if info.id == "elevator" then
    local propogate = function (f, e)
      return function (t)
        if not t then
          t = {}
        end
        local dir = t.__dir
        if dir ~= "up" then
          t.__dir = "down"
          event.notify("room.check", 0, {
            roomNum = pos.roomNum,
            floorNum = pos.floorNum - 1,
            callback = function (otherId, type)
              if type == "elevator" then
                event.notify(e, otherId, t)
              end
            end,
          })
        end
        if dir ~= "down" then
          t.__dir = "up"
          event.notify("room.check", 0, {
            roomNum = pos.roomNum,
            floorNum = pos.floorNum + 1,
            callback = function (otherId, type)
              if type == "elevator" then
                event.notify(e, otherId, t)
              end
            end,
          })
        end
        f(t)
      end
    end
    use = propogate(use, "room.use")
    fix = propogate(fix, "room.fix")
  end
  
  local function delete ()
    event.unsubscribe("room.check", 0, check)
    event.unsubscribe("room.all", 0, getRooms)
    event.unsubscribe("room.unoccupied", 0, unoccupied)
    event.unsubscribe("room.dirty", 0, dirtyRooms)
    event.unsubscribe("room.isDirty", id, isDirty)
    event.unsubscribe("room.occupation", id, checkOccupied)
    event.unsubscribe("room.getStock", id, getStock)
    event.unsubscribe("room.setStock", id, setStock)
    event.unsubscribe("room.occupy", id, occupy)
    event.unsubscribe("room.depart", id, depart)
    event.unsubscribe("room.beginRelax", id, beginRelax)
    event.unsubscribe("room.endRelax", id, endRelax)
    event.unsubscribe("room.beginCook", id, beginCook)
    event.unsubscribe("room.endCook", id, endCook)
    event.unsubscribe("room.beginFix", id, beginFix)
    event.unsubscribe("room.endFix", id, endFix)
    event.unsubscribe("room.beginClean", id, beginClean)
    event.unsubscribe("room.endClean", id, endClean)
    event.unsubscribe("room.beginSupply", id, beginSupply)
    event.unsubscribe("room.endSupply", id, endSupply)
    event.unsubscribe("room.isBroken", id, isBroken)
    event.unsubscribe("room.use", id, use)
    event.unsubscribe("room.fix", id, fix)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("room.check", 0, check)
  event.subscribe("room.all", 0, getRooms)
  event.subscribe("room.unoccupied", 0, unoccupied)
  event.subscribe("room.dirty", 0, dirtyRooms)
  event.subscribe("room.isDirty", id, isDirty)
  event.subscribe("room.occupation", id, checkOccupied)
  event.subscribe("room.getStock", id, getStock)
  event.subscribe("room.setStock", id, setStock)
  event.subscribe("room.occupy", id, occupy)
  event.subscribe("room.depart", id, depart)
  event.subscribe("room.beginRelax", id, beginRelax)
  event.subscribe("room.endRelax", id, endRelax)
  event.subscribe("room.beginCook", id, beginCook)
  event.subscribe("room.endCook", id, endCook)
  event.subscribe("room.beginFix", id, beginFix)
  event.subscribe("room.endFix", id, endFix)
  event.subscribe("room.beginClean", id, beginClean)
  event.subscribe("room.endClean", id, endClean)
  event.subscribe("room.beginSupply", id, beginSupply)
  event.subscribe("room.endSupply", id, endSupply)
  event.subscribe("room.isBroken", id, isBroken)
  event.subscribe("room.use", id, use)
  event.subscribe("room.fix", id, fix)
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
  local roomWidth = room.width*32
  local roomHeight = 32
  local prefix = "img/rooms/" .. room.id .. "_"
  
  --Add sprite components
  for _,s in pairs(room.sprites) do
    entity.addComponent(roomId, sprite.new(roomId, {
      image = resource.get(prefix .. s.name .. ".png"),
      width = roomWidth,
      height = roomHeight,
      animations = s.animations,
      playing = s.playing,
    }))
  end
  
  --Add cleaning sign sprite components
  entity.addComponent(roomId, sprite.new(roomId, {
    image = resource.get("img/rooms/cleaning.png"),
    width = 32,
    height = 32,
    originX = -(roomWidth/2),
    animations = {
      cleaning = {
        first = 1,
        last = 1,
        speed = 1,
      },
      cleanless = {
        first = 0,
        last = 0,
        speed = 1,
      },
    },
    playing = "heartless",
  }))
  
  --Add love heart sprite components
  entity.addComponent(roomId, sprite.new(roomId, {
    image = resource.get("img/rooms/love_hearts.png"),
    width = 32,
    height = 32,
    originX = 16 - (roomWidth/2),
    animations = {
      hearts = {
        first = 1,
        last = 8,
        speed = 0.1,
      },
      heartless = {
        first = 0,
        last = 0,
        speed = 1,
      },
    },
    playing = "heartless",
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

M.getStock = function (id)
  local stock = nil
  event.notify("room.getStock", id, function (e)
    stock = e
  end)
  return stock
end

M.setStock = function (id, stock)
  event.notify("room.setStock", id, stock)
end

M.isBroken = function (id)
  local broken
  event.notify("room.isBroken", id, function (e)
    broken = e
  end)
  return broken
end

M.use = function (id)
  event.notify("room.use", id, nil)
end

M.fix = function (id, newIntegrity)
  event.notify("room.fix", id, {integrity = newIntegrity})
end

--Return the module
return M
