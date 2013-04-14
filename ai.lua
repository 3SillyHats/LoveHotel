
local AI_TICK = 0.05

local entity = require("entity")
local event = require("event")
local resource = require("resource")
local room = require("room")
local transform = require("transform")

local M = {}

local pass = function () end

-- Filters
local cleanFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.dirtyable and
    room.isDirty(roomId))
end
local cleaningSupplyFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "utility" and
    room.getStock(roomId) > 0 and
    room.reservations(roomId) == 0)
end
local receptionFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "reception")
end
local restockFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.stock and
    room.getStock(roomId) <= 1 and
    room.reservations(roomId) == 0)
end
local sexFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.visitable and
    info.profit <= com.money and
    (not room.isDirty(roomId)) and
    room.reservations(roomId) == 0)
end
local snackFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "vending" and
    info.profit <= com.money and
    room.reservations(roomId) == 0 and
    room.getStock(roomId) > 0)
end

local states = {
  -- GENERAL
  wait = {
    enter = function (com)
      com.waitSuccess = false
    end,
    exit = pass,
    update = function (com, dt)
      com.waitTime = com.waitTime - dt
      if com.waitTime <= 0 then
        com.waitSuccess = true
        com:pop()
      end
    end,
    transition = pass,
  },
  moveTo = {
    enter = pass,
    exit = pass,
    update = function (com, dt)
      local pos = transform.getPos(com.entity)
      if pos.floorNum == com.moveFloor then
        if pos.roomNum == com.moveRoom then
          -- at destination
          com:pop()
        else
          -- move to room
          com:push("walk")
        end
      else
        if pos.roomNum == 7 then
          -- at elevator
          com:push("elevatorEnter")
        else
          -- move to elevator
          com:push("walk")
        end
      end
    end,
    transition = pass,
  },
  walk = {
    enter = function (com)
      local pos = transform.getPos(com.entity)
      local roomNum
      if pos.floorNum == com.moveFloor then
        roomNum = com.moveRoom
        if pos.roomNum < com.moveRoom then
          event.notify("sprite.flip", com.entity, false)
        else
          event.notify("sprite.flip", com.entity, true)
        end
      else
        roomNum = 7
        event.notify("sprite.flip", com.entity, false)
      end
      event.notify("sprite.play", com.entity, "walking")
      com.moveDelta = roomNum - pos.roomNum
      com.moveLength = math.abs(com.moveDelta)/PERSON_SPEED
      com.moveTime = 0
    end,
    exit = function (com)
      event.notify("sprite.play", com.entity, "idle")
      com.moveDelta = nil
      com.moveLength = nil
      com.moveTime = nil
    end,
    update = function (com, dt)
      com.moveTime = com.moveTime + dt
      local pos = transform.getPos(com.entity)
      local roomNum
      if pos.floorNum == com.moveFloor then
        roomNum = com.moveRoom
      else
        roomNum = 7
      end
      local newPos
      if com.moveTime < com.moveLength then
        newPos = { 
          roomNum = roomNum - (com.moveDelta*(com.moveLength - com.moveTime)/com.moveLength),
          floorNum = pos.floorNum,
        }
      else
        newPos = {
          roomNum = roomNum,
          floorNum = pos.floorNum,
        }
        com:pop()
      end
      event.notify("entity.move", com.entity, newPos)
    end,
    transition = pass,
  },
  elevatorEnter = {
    enter = function (com)
      local pos = transform.getPos(com.entity)
      event.notify("room.check",0,{
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id,roomType)
          if roomType == "elevator" and not room.isBroken(id) then
            com.moveFrom = id
          end
        end
      })
      if com.moveFrom == nil then 
        com:push("elevatorBroken")
      else
        com.moveHandler = function (e)
          if e.animation == "opening" then 
            com.moveWait = false
          end
        end
        com.moveWait = true
        event.subscribe("sprite.onAnimationEnd",com.moveFrom, com.moveHandler)
        event.notify("sprite.play",com.moveFrom, "opening")
      end
    end,
    exit = function (com)
      event.unsubscribe("sprite.onAnimationEnd", com.moveFrom, com.moveHandler)
      com.moveFrom = nil
      com.moveWait = nil
      com.moveHandler = nil
    end,
    update = function (com, dt)
      local pos = transform.getPos(com.entity)
      event.notify("room.check",0,{
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id,roomType)
          if roomType == "elevator" and room.isBroken(id) then
            com:push("elevatorBroken")
          end
        end
      })
    end,
    transition = function (com)
      if com.moveWait == false then 
        return "elevatorRide"
      end
    end,
  },
  elevatorRide = {
    enter = function (com)
      local pos = transform.getPos(com.entity)
      com.moveDelta = com.moveFloor - pos.floorNum
      com.moveLength = math.abs(com.moveDelta)/ELEVATOR_SPEED
      com.moveTime = 0
      event.notify("sprite.hide", com.entity, true)
    end,
    exit = function (com)
      com.moveDelta = nil
      com.moveLength = nil
      com.moveTime = nil
    end,
    update = function (com, dt)
      com.moveTime = com.moveTime + dt
      local pos
      if com.moveTime < com.moveLength then
        pos = { 
          roomNum = 7,
          floorNum = com.moveFloor - (com.moveDelta*(com.moveLength - com.moveTime)/com.moveLength),
        }
      else
        pos = {
          roomNum = 7,
          floorNum = com.moveFloor
        }
      end
      event.notify("entity.move", com.entity, pos)
      
      --check if elevator is broken
      event.notify("room.check", 0, {
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id, roomType)
          if roomType == "elevator" and room.isBroken(id) then
            com:push("elevatorBroken")
          end
        end
      })
    end,
    transition = function (com)
      if com.moveTime >= com.moveLength then 
        return "elevatorExit"
      end
    end,
  },
  elevatorExit = {
    enter = function (com)
      local pos = transform.getPos(com.entity)
      event.notify("room.check",0,{
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id,roomType)
          if roomType == "elevator" and not room.isBroken(id) then
            com.moveTo = id
          end
        end
      })
      if com.moveTo == nil then 
        com:push("elevatorBroken")
      else
        com.moveWait = true
        com.moveHandler = function (e)
          if e.animation == "opening" then 
            com.moveWait = false
          end
        end
        event.subscribe("sprite.onAnimationEnd", com.moveTo, com.moveHandler)
        event.notify("sprite.play", com.moveTo, "opening")
      end
    end,
    exit = function (com)
      event.notify("sprite.flip", com.entity, true)
      event.notify("sprite.hide", com.entity, false)
      event.unsubscribe("sprite.onAnimationEnd", com.moveTo, com.moveHandler)
      com.moveTo = nil
      com.moveWait = nil
      com.moveHandler = nil
    end,
    update = function (com, dt)
      -- check if elevator open
      if com.moveWait == false then
        com:pop()
        return
      end
      
      -- check if elevator is broken
      local pos = transform.getPos(com.entity)
      event.notify("room.check", 0, {
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id, roomType)
          if roomType == "elevator" and room.isBroken(id) then
            com:push("elevatorBroken")
          end
        end
      })
    end,
    transition = pass,
  },
  elevatorBroken = {
    enter = pass,
    exit = pass,
    update = function (com, dt)
      local passable = false
      local pos = transform.getPos(com.entity)
      event.notify("room.check",0,{
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
        callback = function (id,roomType)
          if roomType == "elevator" and not room.isBroken(id) then
            passable = true
          end
        end
      })
      if passable then
        com:pop()
      end
    end,
    transition = pass,
  },

  -- CLIENTS
  clientIdle = {
    enter = pass,
    exit = pass,
    update = pass,
    transition = function (com)
      local info = resource.get("scr/people/" .. com.class .. ".lua")
      local result = nil
      com.thought = "None"
      
      -- Check needs
      if com.horniness < 20 then
        com.happy = true
        com.thought = "Love"
        result = "leave"
      elseif com.money < (info.maxMoney / 10) then
        com.happy = true
        com.thought = "Broke"
        result = "leave"
      elseif com.satiety == 0 then
        com.happy = true
        com.thought = "HungryGood"
        result = "leave"
      elseif com.patience == 0 then
        com.happy = false
        com.thought = "Impatient"
        result = "leave"
      elseif com.satiety < 30 then
        result = "getSnack"
      else
        result = "visit"
      end
      
      -- Update speech bubble
      if com.thought then
        event.notify("sprite.play", com.entity, "thought" .. com.thought)
      end
      
      return result
    end,
  },
  leave = {
    enter = function (com)
      com.moveRoom = -1
      com.moveFloor = 0
      com:push("moveTo")
      
      local profit = com.profit
      if not com.happy then
        profit = math.floor(profit / 4)
      end
      local myPos = transform.getPos(com.entity)
      moneyChange(profit, {roomNum = myPos.roomNum, floorNum = myPos.floorNum})
    end,
    exit = function (com)
      
      entity.delete(com.entity)
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  
  -- SEXING
  visit = {
    enter = function (com)
      -- Find the nearest reception
      com.room = nil
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        receptionFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and get a suite
      local roomPos = room.getPos(com.room)
      com:push("checkIn")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = pass,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  checkIn = {
    enter = pass,
    exit = function (com)
      event.unsubscribe("serve", com.room, com.serveHandler)
      com.serveHandler = nil
      com.served = false
    end,
    update = function (com)
      if (not entity.get(com.room)) then
        com:pop()
        return
      end
      
      if not com.serveHandler then
        com.serveHandler = function (e)
          -- Find the nearest suite
          com.room = nil
          local myPos = transform.getPos(com.entity)
          com.room = room.getNearest(
            com,
            myPos.roomNum, myPos.floorNum,
            sexFilter
          )
          if com.room == nil then
            com:pop()
            return
          end
          local roomPos = room.getPos(com.room)

          -- Go to suite and sex
          com:pop()
          com:push("sex")
          com.moveRoom = roomPos.roomNum
          com.moveFloor = roomPos.floorNum
          com:push("moveTo")
          
          -- Tell bellhop
          e.com.querySuccess = true
          e.com.moveRoom = roomPos.roomNum
          e.com.moveFloor = roomPos.floorNum
          e.com:push("moveTo")
        end
        event.subscribe("serve", com.entity, com.serveHandler)
        
        com.served = false
        event.notify("queryServe", com.room, {entity = com.entity})
      end
    end,
    transition = pass,
  },
  sex = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local info = room.getInfo(com.room)
        room.setDirty(com.room, true)
        com.money = com.money - info.profit
        com.profit = com.profit + info.profit
        com.horniness = math.max(0, com.horniness - 20)
      end
      event.notify("sprite.play", com.room, "opening")
      event.notify("sprite.play", com.room, "heartless")
      event.notify("sprite.hide", com.entity, false)
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = SEX_TIME
        com:push("wait")
        event.notify("sprite.hide", com.entity, true)
        event.notify("sprite.play", com.room, "closing")
        event.notify("sprite.play", com.room, "hearts")
      end
    end,
    transition = pass,
  },

  -- EATING
  getSnack = {
    enter = function (com)
      -- Find the nearest vending machine
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        snackFilter
      )
      if com.room == nil then
        com:pop()
        com.happy = true
        com.thought = "HungryGood"
        event.notify("sprite.play", com.entity, "thought" .. com.thought)
        com:push("leave")
        return
      end
      
      -- Go there and eat
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("eat")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.release(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  eat = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local info = room.getInfo(com.room)
        room.setStock(com.room, room.getStock(com.room) - 1)
        com.money = com.money - info.profit
        com.profit = com.profit + info.profit
        com.satiety = math.min(100, com.satiety + 50)
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = EAT_TIME
        com:push("wait")
      end
    end,
    transition = pass,
  },

  -- STAFF
  staffIdle = {
    enter = pass,
    exit = pass,
    update = function (com, dt)
      if com.class == "bellhop" then
        com:push("receive")
      elseif com.class == "cleaner" then
        if com.supply == 0 then
          com:push("getSupply")
        else
          com:push("clean")
        end
      elseif com.class == "stocker" then
        com:push("restock")
      end
    end,
    transition = pass,
  },
  getSupply = {
    enter = function (com)
      local filter
      if com.class == "cleaner" then
        filter = cleaningSupplyFilter
      end
    
      -- Find the nearest stock room
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        filter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and restock
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("supply")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.release(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  supply = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local info = room.getInfo(com.room)
        room.setStock(com.room, room.getStock(com.room) - 1)
        com.supply = 1
      end
      event.notify("sprite.play", com.room, "opening")
      event.notify("sprite.hide", com.entity, false)
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = SUPPLY_TIME
        com:push("wait")
        event.notify("sprite.hide", com.entity, true)
        event.notify("sprite.play", com.room, "closing")
      end
    end,
    transition = pass,
  },
  
  -- BELLHOP
  receive = {
    enter = function (com)
      -- Find the nearest reception
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        receptionFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and serve
      local roomPos = room.getPos(com.room)
      com:push("serveReception")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  serveReception = {
    enter = pass,
    exit = function (com)
      event.unsubscribe("queryServe", com.room, com.queryHandler)
      com.room = nil
      com.queryHandler = nil
      com.querySuccess = nil
    end,
    update = function (com)
      if com.querySuccess then
        com:pop()
      elseif not com.queryHandler then
        com.queryHandler = function (e)
          event.notify("serve", e.entity, {
            com = com,
            entity = com.entity,
          })
        end
        event.subscribe("queryServe", com.room, com.queryHandler)
        com.querySuccess = false
      end
    end,
    transition = pass,
  },

  -- CLEANER
  clean = {
    enter = function (com)
      -- Find the nearest dirty room
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        cleanFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and restock
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("cleanRoom")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.release(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  cleanRoom = {
    enter = pass,
    exit = function (com)
      event.notify("sprite.play", com.room, "opening")
      event.notify("sprite.play", com.room, "cleanless")
      event.notify("sprite.hide", com.entity, false)
      if com.waitSuccess then
        room.setDirty(com.room, false)
        com.supply = com.supply - 1
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess then
        com:pop()
      else
        com.waitTime = CLEAN_TIME
        com:push("wait")
        event.notify("sprite.play", com.room, "closing")
        event.notify("sprite.hide", com.entity, true)
        event.notify("sprite.play", com.room, "cleaning")
      end
    end,
    transition = pass,
  },

  -- RESTOCKER
  restock = {
    enter = function (com)
      -- Find the nearest stockable room
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        restockFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and restock
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("restockRoom")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.release(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  restockRoom = {
    enter = pass,
    exit = function (com)
      event.notify("sprite.play", com.entity, "idle")
      local info = room.getInfo(com.room)
      if com.waitSuccess then
        room.setStock(com.room, info.stock)
        local myPos = transform.getPos(com.entity)
        moneyChange(-info.restockCost,
          {roomNum = myPos.roomNum, floorNum = myPos.floorNum})
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess then
        com:pop()
      else
        com.waitTime = RESTOCK_TIME
        com:push("wait")
        event.notify("sprite.play", com.entity, "stocking")
      end
    end,
    transition = pass,
  },
}

local truncate = function (com, table, i)
  n = #table
  while  n >= i do
    states[table[n]].exit(com)
    table[n] = nil
    n = n - 1
  end
end

local update = function (com, dt)
  com.timer = com.timer + dt
  if com.timer >= AI_TICK then
    com.timer = com.timer - AI_TICK
    
    -- Update needs for clients
    if com.type == "client" then
      com.satiety = math.max(0, com.satiety - AI_TICK)
    end
    
    -- Make Idle default state
    if #com.state == 0 then
      com.state[1] = com.type .. "Idle"
    end
    
    -- Update top state on stack
    states[com.state[#com.state]].update(com, AI_TICK)
    
    -- Check for state transition
    for i,state in ipairs(com.state) do
      newState = states[state].transition(com)
      if newState ~= state and newState ~= nil then
        truncate(com, com.state, i)
        com.state[i] = newState
        states[newState].enter(com)
        break
      end
    end
  end
end

local push = function (com, state)
  com.state[#com.state+1] = state
  states[state].enter(com)
end

local pop = function (com)
  states[com.state[#com.state]].exit(com)
  com.state[#com.state] = nil
end

local new = function (id, type)
  local com = entity.newComponent({
    entity = id,
    type = type,
    state = {},
    timer = 0,
    
    update = update,
    push = push,
    pop = pop,
  })
  for _,state in ipairs(com.state) do
    states[state].enter(com)
  end
  return com
end

M.newClient = function (id)
  local com = new(id, "client")
  com.condoms = 0
  com.money = 10000
  com.patience = 100
  com.horniness = 80
  com.satiety = 50
  com.profit = 0
  return com
end

M.newStaff = function (id, class)
  local com = new(id, "staff")
  com.class = class
  com.supply = 0
  return com
end

return M
