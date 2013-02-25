
local AI_TICK = 1

local transform = require("transform")
local entity = require("entity")
local event = require("event")

local M = {}

local states = {
  idle = {
    enter = function (com)
    end,
    exit = function (com)
    end,
    update = function (com,dt)
    end,
    transition = function (com)   --Do we want to transition states?
    end,
  },
  moveTo = {
    enter = function (com)
      local pos = transform.getPos(com.entity)
      if pos.floorNum == com.target.floorNum then
        com.moveRoom = com.target.roomNum
      else
        com.moveRoom = 7
      end
      if pos.roomNum < com.moveRoom then
        event.notify("sprite.flip", com.entity, false)
      else
        event.notify("sprite.flip", com.entity, true)
      end
      event.notify("sprite.play", com.entity, "walking")
      com.moveFloor = com.target.floorNum
      com.moveDelta = com.moveRoom - pos.roomNum
      com.moveLength = math.abs(com.moveDelta)/com.moveSpeed
      com.moveTime = 0
      print("enter")
    end,
    exit = function (com)
      event.notify("sprite.play", com.entity, "idle")
      com.moveRoom = nil
      com.moveFloor = nil
      com.moveDelta = nil
      com.moveLength = nil
      com.moveTime = nil
    end,
    update = function (com,dt)
      com.moveTime = com.moveTime + dt
      local pos
      if com.moveTime < com.moveLength then
        pos = { 
          roomNum = com.moveRoom - com.moveDelta*(com.moveLength - com.moveTime)/com.moveLength,
          floorNum = com.moveFloor
        }
      else
        pos = {roomNum = com.moveRoom, floorNum = com.moveFloor}
      end
      print(pos.roomNum)
      event.notify("entity.move", com.entity, pos)
      if pos.roomNum == com.target.roomNum and pos.floorNum == com.target.floorNum then
        com:pop()
      end
    end,
    transition = function (com)   --What state do we want to transition to?
      local pos = transform.getPos(com.entity)
      if pos.roomNum == 7 and pos.floorNum ~= com.target.floorNum then
        return "elevatorEnter"
      end
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
    update = function (com,dt)
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
      com.moveRoom = pos.roomNum
      com.moveFloor = com.target.floorNum
      com.moveDelta = com.moveFloor - pos.floorNum
      com.moveLength = math.abs(com.moveDelta)/com.elevatorSpeed
      com.moveTime = 0
      event.notify("sprite.hide", com.entity, true)
    end,
    exit = function (com)
      com.moveFloor = nil
      com.moveDelta = nil
      com.moveLength = nil
      com.moveTime = nil
    end,
    update = function (com,dt)
      --move
      local pos
      com.moveTime = com.moveTime + dt
      if com.moveTime < com.moveLength then
        pos = { 
          roomNum = com.moveRoom,
          floorNum = com.moveFloor - com.moveDelta*(com.moveLength - com.moveTime)/com.moveLength,
        }
      else
        pos = {roomNum = com.moveRoom, floorNum = com.moveFloor}
      end
      event.notify("entity.move", com.entity, pos)
      --check broken elevator
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
        com.moveHandler = function (e)
          if e.animation == "opening" then 
            com.moveWait = false
          end
        end
        com.moveWait = true
        event.subscribe("sprite.onAnimationEnd",com.moveTo, com.moveHandler)
        event.notify("sprite.play",com.moveTo, "opening")
      end
    end,
    exit = function (com)
      event.unsubscribe("sprite.onAnimationEnd", com.moveTo, com.moveHandler)
      com.moveTo = nil
      com.moveWait = nil
      com.moveHandler = nil
    end,
    update = function (com,dt)
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
        return "moveTo"
      end
    end,
  },
  elevatorBroken = {
    enter = function (com)
    end,
    exit = function (com)
    end,
    update = function (com,dt)
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
    transition = function (com)   --What state do we want to transition to?
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
  print("update", com.timer)
  if com.timer >= AI_TICK then
    com.timer = com.timer - AI_TICK
    states[com.state[#com.state]].update(com.dt)
    for i,state in ipairs(com.state) do
      newState = states[state].transition(com)
      if newState ~= state and newState ~= nil then
        truncate(com, com.state,i)
        com.state[i] = newState
        states[newState].enter(com)
        break
      end
    end
  end
end

local push = function (com, state)
  table.insert(com.state, state)
  states[state].enter(com)
end

local pop = function (com)
  states[com.state[#com.state]].exit(com)
  table.remove(com.state, #com.state)
end


M.new = function (id)
  local com = entity.newComponent({
    entity = id,
    state = {"idle"},
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


