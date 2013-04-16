--The room "object" file

--Load required files and such
local achievement = require("achievement")
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
  component.reservations = 0
  component.assigned = 0
  component.messy = false
  if info.cleaningSupplies then
    component.stock = info.stock
  end
  if info.integrity then
    component.integrity = info.integrity
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

  local setDirty = function (value)
    component.messy = value
    if value then
      event.notify("sprite.play", id, "dirty")
    else
      event.notify("sprite.play", id, "clean")
    end
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
    if stock == 0 then
      local snd = resource.get("snd/empty.wav")
      love.audio.rewind(snd)
      love.audio.play(snd)
    end
  end

  local assign = function (e)
    component.assigned = component.assigned + 1
  end

  local unassign = function (e)
    component.assigned = component.assigned - 1
  end

  local checkAssigned = function (callback)
    callback(component.assigned)
  end

  local setReservations = function (r)
    if component.reservations ~= r then
      component.reservations = r
      event.notify("room.reservationChange", 0, {
        type = info.id,
        pos = pos,
        id = id,
        reservations = r,
      })
    end
  end

  local reserve = function (e)
    setReservations(component.reservations + 1)
  end

  local release = function (e)
    setReservations(component.reservations - 1)
  end

  local propagate_res
  if info.id == "elevator" then
    propagate_res = function (e)
      if e.pos.roomNum == pos.roomNum and
          (e.pos.floorNum == pos.floorNum - 1 or e.pos.floorNum == pos.floorNum + 1) and
          e.reservations ~= component.reservations and
          e.type == "elevator" then
        setReservations(e.reservations)
      end
    end
    event.subscribe("room.reservationChange", 0, propagate_res)
  end

  local checkReservations = function (callback)
    callback(component.reservations)
  end

  local enter = function ()
    component.occupied = component.occupied + 1
  end

  local exit = function ()
    if component.occupied > 0 then
      component.occupied = component.occupied - 1
    end
  end

  local occupy = function (e)
    if component.occupied < 2 then
      component.occupied = component.occupied + 1
      if component.occupied == 2 then
        event.notify("sprite.play", id, "closing")
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
    end
    if component.occupied <= 0 then
      component.occupied = 0
    end
  end

  local isBroken = function (callback)
    if info.integrity then
      callback(component.integrity <= 0)
    else
      callback(false)
    end
  end

  local setIntegrity = function (integrity)
    if integrity ~= component.integrity then
      if component.integrity <= 0 and integrity > 0 then
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
        elseif info.id == "spa" then
          event.notify("sprite.play", id, "idle")
        end
      elseif component.integrity > 0 and integrity <= 0 then
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
        local snd = resource.get("snd/break.wav")
        love.audio.rewind(snd)
        love.audio.play(snd)
      end
      component.integrity = integrity
      event.notify("room.integrityChange", 0, {
        type = info.id,
        id = id,
        pos = pos,
        integrity = component.integrity,
      })
      event.notify("room.integrityChange", id, {
        type = info.id,
        id = id,
        pos = pos,
        integrity = component.integrity,
      })
    end
  end

  local use = function ()
    if component.stock then
      setStock(component.stock - 1)
    end
    if info.integrity then
      setIntegrity(component.integrity - 1)
    end
  end

  local fix = function (t)
    if info.integrity then
      setIntegrity(t.integrity)
    end
  end

  local propagate
  if info.id == "elevator" then
    propagate = function (e)
      if e.pos.roomNum == pos.roomNum and
          (e.pos.floorNum == pos.floorNum - 1 or e.pos.floorNum == pos.floorNum + 1) and
          e.integrity ~= component.integrity and
          e.type == "elevator" then
        setIntegrity(e.integrity)
      end
    end
    event.subscribe("room.integrityChange", 0, propagate)
  end

  local function delete ()
    event.unsubscribe("room.check", 0, check)
    event.unsubscribe("room.all", 0, getRooms)
    event.unsubscribe("room.unoccupied", 0, unoccupied)
    event.unsubscribe("room.dirty", 0, dirtyRooms)
    event.unsubscribe("room.isDirty", id, isDirty)
    event.unsubscribe("room.setDirty", id, setDirty)
    event.unsubscribe("room.occupation", id, checkOccupied)
    event.unsubscribe("room.reservations", id, checkReservations)
    event.unsubscribe("room.getStock", id, getStock)
    event.unsubscribe("room.setStock", id, setStock)
    event.unsubscribe("room.assign", id, assign)
    event.unsubscribe("room.unassign", id, unassign)
    event.unsubscribe("room.assigned", id, checkAssigned)
    event.unsubscribe("room.reserve", id, reserve)
    event.unsubscribe("room.release", id, release)
    event.unsubscribe("room.enter", id, enter)
    event.unsubscribe("room.exit", id, exit)
    event.unsubscribe("room.occupy", id, occupy)
    event.unsubscribe("room.depart", id, depart)
    event.unsubscribe("room.isBroken", id, isBroken)
    event.unsubscribe("room.use", id, use)
    event.unsubscribe("room.fix", id, fix)
    event.unsubscribe("room.integrityChange", 0, propagate)
    event.unsubscribe("room.reservationChange", 0, propagate_res)
    event.unsubscribe("delete", id, delete)
  end

  event.subscribe("room.check", 0, check)
  event.subscribe("room.all", 0, getRooms)
  event.subscribe("room.unoccupied", 0, unoccupied)
  event.subscribe("room.dirty", 0, dirtyRooms)
  event.subscribe("room.isDirty", id, isDirty)
  event.subscribe("room.setDirty", id, setDirty)
  event.subscribe("room.occupation", id, checkOccupied)
  event.subscribe("room.reservations", id, checkReservations)
  event.subscribe("room.getStock", id, getStock)
  event.subscribe("room.setStock", id, setStock)
  event.subscribe("room.assign", id, assign)
  event.subscribe("room.unassign", id, unassign)
  event.subscribe("room.assigned", id, checkAssigned)
  event.subscribe("room.reserve", id, reserve)
  event.subscribe("room.release", id, release)
  event.subscribe("room.enter", id, enter)
  event.subscribe("room.exit", id, exit)
  event.subscribe("room.occupy", id, occupy)
  event.subscribe("room.depart", id, depart)
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
  local roomType = string.lower(roomType)
  local room = resource.get("scr/rooms/" .. roomType .. ".lua")
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
  if room.dirtyable then
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
      playing = "cleanless",
    }))
  end

  --Add love heart sprite components
  if room.visitable then
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
  end

  --Add position component
  entity.addComponent(roomId, transform.new(roomId, pos, {x = 0, y = 0}))

  --Add info component
  entity.addComponent(roomId, infoComponent(roomId, room, pos))
  
  -- Update room counts for achievement
  if gCounts.rooms[roomType] then
    gCounts.rooms[roomType] = gCounts.rooms[roomType] + 1
  else
    gCounts.rooms[roomType] = 1
  end
  
  -- Check if achievement triggered
  if gCounts.rooms["missionary"] and
      gCounts.rooms["spoon"] and
      gCounts.rooms["balloon"] and
      gCounts.rooms["moustache"] and
      gCounts.rooms["torture"] and
      gCounts.rooms["eco"] and
      gCounts.rooms["nazifurry"] then
    achievement.achieve(achievement.SUITES)
  end
  
  -- Cleanup rooms counts when room deleted
  local onDelete
  onDelete = function ()
    event.unsubscribe("delete", roomId, onDelete)
    if gCounts.rooms[roomType] then
      gCounts.rooms[roomType] = gCounts.rooms[roomType] - 1
      if gCounts.rooms[roomType] <= 0 then
        gCounts.rooms[roomType] = nil
      end
    end
  end
  event.subscribe("delete", roomId, onDelete)

  --Function returns the rooms id
  return roomId
end

M.all = function ()
  local rooms = {}
  event.notify("room.all", 0, function (id, type)
    table.insert(rooms, id)
  end)
  return rooms
end

M.getCount = function (type)
  return (gCounts.rooms[type] or 0)
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

M.getNearest = function (com, roomNum, floorNum, filter)
  local rooms = M.all()
  local nearest = nil
  local distance = 2^52 -- maximum integer
  for _,room in ipairs(rooms) do
    local pos = M.getPos(room)
    local d
    if pos.floorNum == floorNum then
      d = math.abs(pos.roomNum - roomNum)
    else
      -- d = dist to elevator + floor dist + dist to room
      d = math.abs(pos.floorNum - floorNum) + 14 - (roomNum + pos.roomNum)
    end
    if d < distance and (not filter or filter(com, room)) then
      nearest = room
      distance = d
    end
  end
  return nearest
end

M.isDirty = function (id)
  local info = M.getInfo(id)
  local dirty = false
  if info.dirtyable then
    event.notify("room.isDirty", id, function (e)
      dirty = dirty or e
    end)
  end
  return dirty
end

M.setDirty = function (id, value)
  local info = M.getInfo(id)
  if info.dirtyable then
    event.notify("room.setDirty", id, value)
  end
end

M.enter = function (id)
  event.notify("room.enter", id, nil)
end

M.exit = function (id)
  event.notify("room.exit", id, nil)
end

M.occupation = function (id)
  local occupation = nil
  event.notify("room.occupation", id, function (e)
    occupation = e
  end)
  return occupation
end

M.assign = function (id)
  event.notify("room.assign", id, nil)
end

M.unassign = function (id)
  event.notify("room.unassign", id, nil)
end

M.assigned = function (id)
  local assigned = nil
  event.notify("room.assigned", id, function (e)
    assigned = e
  end)
  return assigned
end

M.reserve = function (id)
  event.notify("room.reserve", id, nil)
end

M.release = function (id)
  event.notify("room.release", id, nil)
end

M.reservations = function (id)
  local reservations = nil
  event.notify("room.reservations", id, function (e)
    reservations = e
  end)
  return reservations
end

local heightUp
heightUp = function (roomNum, floorNum, cType)
  local id, type
  event.notify("room.check", 0, {
    roomNum = roomNum,
    floorNum = floorNum,
    callback = function (_id, _type)
      id = _id
      type = _type
    end,
  })
  if cType ~= type then
    return 0
  end
  return 1 + heightUp(roomNum, floorNum + 1, cType)
end
local heightDown
heightDown = function (roomNum, floorNum, cType)
  local id, type
  event.notify("room.check", 0, {
    roomNum = roomNum,
    floorNum = floorNum,
    callback = function (_id, _type)
      id = _id
      type = _type
    end,
  })
  if cType ~= type then
    return 0
  end
  return 1 + heightDown(roomNum, floorNum - 1, cType)
end

M.height = function (id)
  local info = M.getInfo(id)
  local type = info.id
  local pos = M.getPos(id)
  return (1 +
    heightUp(pos.roomNum, pos.floorNum + 1, type) +
    heightDown(pos.roomNum, pos.floorNum - 1, type))
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
  local broken = false
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
