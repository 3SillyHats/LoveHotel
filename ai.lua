
local AI_TICK = 0.05

local entity = require("entity")
local event = require("event")
local room = require("room")
local transform = require("transform")


local M = {}

local states = {
  idle = {
    enter = function (com)
    end,
    exit = function (com)
    end,
    update = function (com, dt)
    end,
    transition = function (com)   --Do we want to transition states?
    end,
  },
  moveTo = {
    enter = function (com)
    end,
    exit = function (com)
    end,
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
    transition = function (com)
    end,
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
    transition = function (com)
    end,
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
    transition = function (com)   --What state do we want to transition to?
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
    transition = function (com)
    end,
  },
  elevatorBroken = {
    enter = function (com)
    end,
    exit = function (com)
    end,
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
    transition = function (com)
    end,
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
    states[com.state[#com.state]].update(com, AI_TICK)
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


M.new = function (id)
  local com = entity.newComponent({
    entity = id,
    state = { "idle" },
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

return M
