
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
  room.isDirty(roomId) and
  room.reservations(roomId) == 0)
end
local cleaningSupplyFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "utility" and
    room.getStock(roomId) > 0 and
    room.reservations(roomId) == 0)
end
local condomFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "condom" and
    info.profit <= com.money and
    room.getStock(roomId) > 0 and
    room.isBroken(roomId) == false and
    room.reservations(roomId) == 0)
end
local fixFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (room.isBroken(roomId) and
  room.assigned(roomId) == 0)
end
local freezerFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "freezer" and
    room.getStock(roomId) > 0 and
    room.isBroken(roomId) == false and
    room.reservations(roomId) == 0)
end
local kitchenFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "kitchen" and
    room.reservations(roomId) == 0)
end
local mealFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "dining" and
    info.profit <= com.money and
    room.reservations(roomId) < math.min(3, room.getStock(roomId)))
end
local bellhopFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "reception" and
  room.assigned(roomId) <= com.limit)
end
local relaxFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "spa" and
    room.isBroken(roomId) == false and
    room.reservations(roomId) == 0)
end
local restockFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.restockCost and
    info.restockCost <= gMoney and
    room.getStock(roomId) <= 1 and
    room.reservations(roomId) == 0)
end
local serveFoodFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "dining" and
    room.getStock(roomId) <= (8 - com.meals) and
    room.assigned(roomId) == 0)
end
local sexFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.visitable and
    info.id == com.preference and
    info.profit <= com.money and
    room.isDirty(roomId) == false and
    room.reservations(roomId) == 0)
end
local snackFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "vending" and
    info.profit <= com.money and
    room.getStock(roomId) > 0 and
    room.isBroken(roomId) == false and
    room.reservations(roomId) == 0)
end
local visitFilter = function (com, roomId)
  local info = room.getInfo(roomId)
  return (info.id == "reception")
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
      if com.money < (info.money / 4) then
        com.happy = true
        com.thought = "Broke"
        result = "leave"
      elseif com.satiety < 30 then
        result = "getMeal"
      elseif com.condoms == 0 then
        result = "getCondoms"
      elseif com.horniness < 30 then
        result = "relax"
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
      if com.class == "ground" then
        com.moveFloor = -8
      elseif com.class == "sky" then
        com.moveFloor = 8
      elseif com.class == "space" then
        com.moveFloor = 16
      end
      com:push("moveTo")
      
      local myInfo = resource.get("scr/people/" .. com.class .. ".lua")
      if com.happy == false then
        reputationChange(myInfo.influence * -5)
      end
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
        visitFilter
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
    enter = function (com)
      com.served = false
    end,
    exit = function (com)
      event.unsubscribe("serve", com.room, com.serveHandler)
      com.serveHandler = nil
      com.served = nil
      com.waitSuccess = nil
    end,
    update = function (com, dt)
      if (not entity.get(com.room)) then
        com:pop()
        return
      end
      
      if com.waitSuccess then
        com:pop()
        com:push("sex")
        com:push("moveTo")
      end
      
      if com.serveHandler then
        com.patience = math.max(0, com.patience - (5 * dt))
        if com.patience == 0 then
          com:pop()
          com.happy = false
          com.thought = "Impatient"
          event.notify("sprite.play", com.entity, "thought" .. com.thought)
          com:push("leave")
        end
      else
        com.serveHandler = function (e)
          if com.served == false then
            com.served = true
            
            -- Find the nearest prefered suite
            com.room = nil
            local myPos = transform.getPos(com.entity)
            local info = resource.get("scr/people/" .. com.class .. ".lua")
            for _,preference in ipairs(info.preferences) do
              com.preference = preference
              com.room = room.getNearest(
                com,
                myPos.roomNum, myPos.floorNum,
                sexFilter
              )
              if com.room ~= nil then break end
            end
            com.preference = nil
            if com.room == nil then
              -- Pop serveReception and receive on bellhop
              e.com:pop()
              e.com:pop()
            
              com:pop()
              com.happy = false
              com.thought = "Roomless"
              event.notify("sprite.play", com.entity, "thought" .. com.thought)
              com:push("leave")
              return
            end
            local roomPos = room.getPos(com.room)
  
            -- Go to suite and sex
            room.reserve(com.room)
            com.moveRoom = roomPos.roomNum
            com.moveFloor = roomPos.floorNum
            com.waitTime = CHECKIN_TIME
            com:push("wait")
            
            -- Tell bellhop
            e.com:pop()
            e.com.moveRoom = roomPos.roomNum
            e.com.moveFloor = roomPos.floorNum
            e.com:push("moveTo")
          end
        end
        event.subscribe("serve", com.entity, com.serveHandler)
      end
      
      event.notify("queryServe", com.room, {entity = com.entity})
    end,
    transition = pass,
  },
  sex = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local myInfo = resource.get("scr/people/" .. com.class .. ".lua")
        local roomInfo = room.getInfo(com.room)
        room.exit(com.room)
        room.setDirty(com.room, true)
        com.condoms = com.condoms - 1
        com.horniness = math.max(0, com.horniness - 20)
        com.money = com.money - roomInfo.profit
        local myPos = transform.getPos(com.entity)
        moneyChange(roomInfo.profit, {roomNum = myPos.roomNum, floorNum = myPos.floorNum})
        reputationChange(myInfo.influence * roomInfo.desirability)
      end
      room.release(com.room)
      event.notify("sprite.play", com.room, "opening")
      event.notify("sprite.play", com.room, "heartless")
      event.notify("sprite.hide", com.entity, false)
      com.room = nil
      com.waitSuccess = nil
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
        room.enter(com.room)
      end
    end,
    transition = pass,
  },

  -- CONDOMS
  getCondoms = {
    enter = function (com)
      -- Find the nearest condom machine
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        condomFilter
      )
      if com.room == nil then
        com:pop()
        local myInfo = resource.get("scr/people/" .. com.class .. ".lua")
        if myInfo.demandsCondoms then
          com.happy = false
          com.thought = "CondomlessBad"
        else
          com.happy = true
          com.thought = "CondomlessGood"
        end
        event.notify("sprite.play", com.entity, "thought" .. com.thought)
        com:push("leave")
        return
      end
      
      -- Go there and buy condoms
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("buyCondoms")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  buyCondoms = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        room.use(com.room)
        local roomInfo = room.getInfo(com.room)
        com.money = com.money - roomInfo.profit
        local myPos = transform.getPos(com.entity)
        moneyChange(roomInfo.profit, {roomNum = myPos.roomNum, floorNum = myPos.floorNum})
        com.condoms = 3
      end
      com.waitSuccess = nil
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = SUPPLY_TIME
        com:push("wait")
      end
    end,
    transition = pass,
  },

  -- RELAXING
  relax = {
    enter = function (com)
      -- Find the nearest spa
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        relaxFilter
      )
      if com.room == nil then
        com:pop()
        com.happy = true
        com.thought = "Love"
        event.notify("sprite.play", com.entity, "thought" .. com.thought)
        com:push("leave")
        return
      end
      
      -- Go there and relax
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("useSpa")
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
  useSpa = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local myInfo = resource.get("scr/people/" .. com.class .. ".lua")
        local roomInfo = room.getInfo(com.room)
        room.exit(com.room)
        room.use(com.room)
        com.horniness = 100
        reputationChange(myInfo.influence * roomInfo.desirability)
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = SEX_TIME
        com:push("wait")
        room.enter(com.room)
      end
    end,
    transition = pass,
  },

  -- EATING
  getSnack = {
    enter = function (com)
      -- Find the nearest vending machine
      local myInfo = resource.get("scr/people/" .. com.class .. ".lua")
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        snackFilter
      )
      if com.room == nil then
        com:pop()
        if myInfo.demandsFood then
          com.happy = false
          com.thought = "HungryBad"
        else
          com.happy = true
          com.thought = "HungryGood"
        end
        event.notify("sprite.play", com.entity, "thought" .. com.thought)
        com:push("leave")
        return
      end
      
      -- Go there and eat
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("eatSnack")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  eatSnack = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local roomInfo = room.getInfo(com.room)
        room.use(com.room)
        com.money = com.money - roomInfo.profit
        local myPos = transform.getPos(com.entity)
        moneyChange(roomInfo.profit, {roomNum = myPos.roomNum, floorNum = myPos.floorNum})
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
  getMeal = {
    enter = function (com)
      -- Find the nearest dining room
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        mealFilter
      )
      if com.room == nil then
        com:pop()
        com:push("getSnack")
        return
      end

      -- Go there (to a random spot) and eat
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("eatMeal")
      com.moveRoom = roomPos.roomNum - 1.3 + (2.6 * math.random())
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  eatMeal = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local myInfo = resource.get("scr/people/" .. com.class .. ".lua")
        local roomInfo = room.getInfo(com.room)
        room.setStock(com.room, room.getStock(com.room) - 1)
        com.money = com.money - roomInfo.profit
        local myPos = transform.getPos(com.entity)
        moneyChange(roomInfo.profit, {roomNum = myPos.roomNum, floorNum = myPos.floorNum})
        com.satiety = 100
        reputationChange(myInfo.influence * roomInfo.desirability)
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
      -- IDLE WANDER
      com.idleTimer = com.idleTimer - dt
      if com.idleTimer <= 0 then
        com.idleTimer = math.random(1, 4)
        if math.random() < 0.5 then
          com.facingLeft = true
        else
          com.facingLeft = false
        end
      end
      event.notify("sprite.flip", com.entity, com.facingLeft)
      event.notify("sprite.play", com.entity, "walking")
      local delta = 1
      if com.facingLeft then
        delta = -1
      end
      local pos = transform.getPos(com.entity)
      local newPos = {
        roomNum = pos.roomNum + (delta * dt),
        floorNum = pos.floorNum,
      }
      if newPos.roomNum < 1 or newPos.roomNum > 7 then
        com.facingLeft = not com.facingLeft
        com.idleTimer = math.random(1, 4)
      else
        event.notify("entity.move", com.entity, newPos)
      end
    
      -- DO JOB
      if com.class == "bellhop" then
        com:push("receive")
      elseif com.class == "cleaner" then
        if com.supply == 0 then
          com:push("getSupplies")
        else
          com:push("clean")
        end
      elseif com.class == "cook" then
        if com.meals == 0 then
          com:push("cook")
        else
          com:push("serveFood")
        end
      elseif com.class == "maintenance" then
        com:push("fix")
      elseif com.class == "stocker" then
        com:push("restock")
      end
    end,
    transition = function (com)
      if com.order and com.order > gStaffTotals[com.class] then
        return "quit"
      end
    end,
  },
  quit = {
    enter = function (com)
      com.moveRoom = -1
      com.moveFloor = 0
      com:push("moveTo")
    end,
    exit = pass,
    update = pass,
    transition = pass,
  },

  -- BELLHOP
  receive = {
    enter = function (com)
      -- Find the nearest reception
      local myPos = transform.getPos(com.entity)
      for i = 0, 8 do
        com.limit = i
        com.room = room.getNearest(
          com,
          myPos.roomNum, myPos.floorNum,
          bellhopFilter
        )
        if com.room ~= nil then break end
      end
      com.limit = nil
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and serve
      room.assign(com.room)
      local roomPos = room.getPos(com.room)
      com:push("serveReception")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.unassign(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  serveReception = {
    -- com:pop() is called by client's checkIn state
    enter = pass,
    exit = function (com)
      event.unsubscribe("queryServe", com.room, com.queryHandler)
      com.queryHandler = nil
    end,
    update = function (com)
      if not com.queryHandler then
        com.queryHandler = function (e)
          event.notify("serve", e.entity, {
            com = com,
            entity = com.entity,
          })
        end
        event.subscribe("queryServe", com.room, com.queryHandler)
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
      
      -- Go there and clean
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("cleanRoom")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  cleanRoom = {
    enter = pass,
    exit = function (com)
      room.exit(com.room)
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
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = CLEAN_TIME
        com:push("wait")
        event.notify("sprite.play", com.room, "closing")
        event.notify("sprite.hide", com.entity, true)
        event.notify("sprite.play", com.room, "cleaning")
        room.enter(com.room)
      end
    end,
    transition = pass,
  },
  getSupplies = {
    enter = function (com)
      -- Find the nearest stock room
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        cleaningSupplyFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and restock
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("useUtility")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  useUtility = {
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

  -- MAINTENANCE
  fix = {
    enter = function (com)
      -- Find the nearest broken machine
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        fixFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and fix
      room.assign(com.room)
      local roomPos = room.getPos(com.room)
      com:push("fixMachine")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.unassign(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  fixMachine = {
    enter = pass,
    exit = function (com)
      event.notify("sprite.play", com.entity, "idle")
      local info = room.getInfo(com.room)
      if com.waitSuccess then
        room.fix(com.room, info.integrity)
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = FIX_TIME
        com:push("wait")
        event.notify("sprite.play", com.entity, "fixing")
      end
    end,
    transition = pass,
  },
  
  -- COOK
  cook = {
    enter = function (com)
      local myPos = transform.getPos(com.entity)
      if room.getCount("freezer") > 0 and com.frozen == 0 and
        room.getNearest(com, myPos.roomNum, myPos.floorNum, freezerFilter) then
        com:pop()
        com:push("getFrozen")
        return
      end
      
      -- Find the nearest kitchen
      
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        kitchenFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and cook
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("useKitchen")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  useKitchen = {
    enter = pass,
    exit = function (com)
      event.notify("sprite.play", com.entity, "idle")
      if com.waitSuccess then
        if com.frozen > 0 then
          com.frozen = com.frozen - 1
          com.meals = 8
        else
          com.meals = 2
        end
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess then
        com:pop()
      else
        com.waitTime = COOK_TIME
        com:push("wait")
      event.notify("sprite.play", com.entity, "cooking")
      end
    end,
    transition = pass,
  },
  serveFood = {
    enter = function (com)
      -- Find the nearest dining room
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        serveFoodFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and restock
      room.assign(com.room)
      local roomPos = room.getPos(com.room)
      com:push("useDining")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      room.unassign(com.room)
      com.room = nil
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  useDining = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        local info = room.getInfo(com.room)
        local newStock = math.min(8, room.getStock(com.room) + com.meals)
        room.setStock(com.room, newStock)
        com.meals = 0
      end
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = COOK_TIME
        com:push("wait")
      end
    end,
    transition = pass,
  },
  getFrozen = {
    enter = function (com)
      -- Find the nearest freezer
      local myPos = transform.getPos(com.entity)
      com.room = room.getNearest(
        com,
        myPos.roomNum, myPos.floorNum,
        freezerFilter
      )
      if com.room == nil then
        com:pop()
        return
      end
      
      -- Go there and get frozen
      room.reserve(com.room)
      local roomPos = room.getPos(com.room)
      com:push("useFreezer")
      com.moveRoom = roomPos.roomNum
      com.moveFloor = roomPos.floorNum
      com:push("moveTo")
    end,
    exit = function (com)
      if com.room then
        room.release(com.room)
        com.room = nil
      end
    end,
    update = function (com, dt)
      com:pop()
    end,
    transition = pass,
  },
  useFreezer = {
    enter = pass,
    exit = function (com)
      if com.waitSuccess and entity.get(com.room) then
        room.use(com.room)
        com.frozen = 1
      end
      event.notify("sprite.play", com.room, "closing")
      com.waitSuccess = false
    end,
    update = function (com)
      if com.waitSuccess or (not entity.get(com.room)) then
        com:pop()
      else
        com.waitTime = SUPPLY_TIME
        com:push("wait")
        event.notify("sprite.play", com.room, "opening")
      end
    end,
    transition = pass,
  },

  -- STOCKER
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
      if com.room then
        room.release(com.room)
        com.room = nil
      end
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
  while com.timer >= AI_TICK do
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

  local delete = function ()
    while #com.state > 0 do
      com:pop()
    end
    event.unsubscribe("delete", id, delete)
  end
  event.subscribe("delete", id, delete)

  return com
end

M.newClient = function (id, info)
  local com = new(id, "client")
  com.condoms = info.condoms
  com.money = info.money
  com.patience = 100
  com.horniness = info.horniness
  com.satiety = info.satiety
  return com
end

M.newStaff = function (id, class, order)
  local com = new(id, "staff")
  com.class = class
  com.order = order
  com.idleTimer = 0
  if class == "cleaner" then
    com.supply = 0
  elseif class == "cook" then
    com.frozen = 0
    com.meals = 0
  end
  return com
end

return M
