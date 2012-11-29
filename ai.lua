-- ai.lua

local event = require("event")
local entity = require("entity")
local room = require("room")
local path = require("path")

local M = {}

local activate = function (self)
  if #self.subgoals > 0 then
    self.subgoals[1]:activate()
  end
end

local process = function (self, dt)
  -- Remove all completed and failed goals from the front of
  -- the subgoals list
  while #self.subgoals > 0 and (self.subgoals[1]:getStatus() == "complete" or
      self.subgoals[1]:getStatus() == "failed") do
    if self.subgoals[1]:getStatus() == "failed" then
      return "failed"
    end
    self.subgoals[1]:terminate()
    table.remove(self.subgoals, 1)
    if #self.subgoals > 0 then
      self.subgoals[1]:activate()
    end
  end
  -- If any subgoals remain, process the one at the
  -- front of the list
  if #self.subgoals > 0 then
    local status = self.subgoals[1]:process(dt)
    self.subgoals[1].status = status
    -- If it finished but more remain, we should return
    -- the status 'active' ourselves
    if status == "complete" and #self.subgoals > 1 then
      return "active"
    end
    if status == "failed" or status == "complete" then
      self.subgoals[1]:terminate()
    end
    return status
  end
  
  -- No more subgoals
  return "complete"
end

local terminate = function (self)
  if #self.subgoals > 0 and self.subgoals[1].status == "active" then
    self.subgoals[1]:terminate()
  end
end

local getStatus = function (self)
  return self.status
end

local addSubgoal = function (self, subgoal)
  table.insert(self.subgoals, subgoal)
end

local getDesirability = function (self, t)
  return 0
end

local arbitrate = function (self, t)
  local best = 0
  local mostDesirable = nil
  for _,goal in ipairs(self.goalEvaluator.subgoals) do
    local d = goal:getDesirability(t)
    if d >= best then
      best = d
      mostDesirable = goal
    end
  end
  return mostDesirable
end

local update = function (self, dt)
  local desirabilityFactors = {horny = self.horny}
  local newGoal = self.goalEvaluator.arbitrate(self, desirabilityFactors)
  if newGoal ~= self.currentGoal then
    if self.currentGoal then self.currentGoal:terminate() end
    if newGoal then newGoal:activate() end
    self.currentGoal = newGoal
  end
  if self.currentGoal then
    local result = self.currentGoal:process(dt)
    if result == "complete" or result == "failed" then
      self.currentGoal:terminate()
      self.currentGoal = nil
    end
  end
end

M.newGoal = function (com)
  return {
    component = com,
    subgoals = {},
    status = "inactive",
    
    activate = activate,
    process = process,
    terminate = terminate,
    getStatus = getStatus,
    addSubgoal = addSubgoal,
    getDesirability = getDesirability,
  }
end

local newSeekGoal = function (com, moveFrom, moveTo, moveSpeed)
  local goal = M.newGoal(com)
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.pos = {roomNum = moveFrom.roomNum, floorNum = moveFrom.floorNum}
  goal.speed = moveSpeed
  local goto = function(pos)
    local passable = false
    if (pos.floorNum >= gBottomFloor and
        pos.floorNum <= gTopFloor) or
        (pos.roomNum < 7.5 and
        pos.floorNum == GROUND_FLOOR) then
      passable = true
    end
    if passable then
      event.notify("entity.move", goal.component.entity, pos)
    else
      return "failed"
    end
  end
  goal.process = function (self, dt)
    if not self.moveTo or not self.pos then
      return "failed"
    end
    if self.moveTo.floorNum ~= self.pos.floorNum then
      return "failed"
    end
    if math.abs(self.moveTo.roomNum - self.pos.roomNum) < self.speed*dt then
      local result = goto{
        roomNum = self.moveTo.roomNum,
        floorNum = self.pos.floorNum,
      }
      if result then return result end
      return "complete"
    else
      local delta = self.speed*dt
      if self.moveTo.roomNum < self.pos.roomNum then
        delta = delta * -1
        event.notify("sprite.flip", goal.component.entity, true)
      else
        event.notify("sprite.flip", goal.component.entity, false)
      end
      local result = goto{
        roomNum = self.pos.roomNum + delta,
        floorNum = self.pos.floorNum,
      }
      if result then return result end
      return "active"
    end
  end
  event.subscribe("entity.move", goal.component.entity, function (pos)
    goal.pos.roomNum = pos.roomNum
    goal.pos.floorNum = pos.floorNum
  end)
  goal.activate = function (self)
    event.notify("sprite.play", goal.component.entity, "walking")
  end
  goal.terminate = function (self)
    event.notify("sprite.play", goal.component.entity, "idle")
  end
  
  return goal
end

local newElevatorGoal = function (com, moveFrom, moveTo)
  local goal = M.newGoal(com)
  goal.elevator = true
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.pos = {roomNum = moveFrom.roomNum, floorNum = moveFrom.floorNum}
  goal.speed = 1
  local goto = function(pos)
    local passable = false
    event.notify("room.check", 0, {
      roomNum = pos.roomNum,
      floorNum = pos.floorNum,
      callback = function (id, roomType)
        if roomType == "elevator" then
          passable = true
        end
      end,
    })
    if passable then
      event.notify("entity.move", goal.component.entity, pos)
    else
      return "failed"
    end
  end
  goal.process = function (self, dt)
    if not self.moveTo or not self.pos then
      return "failed"
    end
    if self.moveTo.roomNum ~= self.pos.roomNum then
      return "failed"
    end
    if math.abs(self.moveTo.floorNum - self.pos.floorNum) < self.speed*dt then
      local result = goto{
        roomNum = self.moveTo.roomNum,
        floorNum = self.pos.floorNum,
      }
      if result then return result end
      return "complete"
    else
      local delta = self.speed*dt
      if self.moveTo.floorNum < self.pos.floorNum then
        delta = delta * -1
      end
      local result = goto{
        roomNum = self.pos.roomNum,
        floorNum = self.pos.floorNum + delta,
      }
      if result then return result end
      return "active"
    end
  end
  event.subscribe("entity.move", goal.component.entity, function (pos)
    goal.pos.roomNum = pos.roomNum
    goal.pos.floorNum = pos.floorNum
  end)
  goal.activate = function (self)
    event.notify("sprite.play", goal.component.entity, "idle")
    event.notify("sprite.hide", goal.component.entity, true)
  end
  goal.terminate = function (self)
    event.notify("entity.move", goal.component.entity, {
      roomNum = goal.pos.roomNum,
      floorNum = math.floor(goal.pos.floorNum + .5)
    })
    event.notify("sprite.play", goal.component.entity, "idle")
    event.notify("sprite.hide", goal.component.entity, false)
  end
  
  return goal
end

local newMoveToGoal = function (self, moveTo, moveSpeed)
  local goal = M.newGoal(self)
  goal.moveTo = moveTo
  goal.pos = {}
  goal.speed = moveSpeed
  
  goal.activate = function ()
    goal.pos = room.getPos(self.entity)
    local src = goal.pos
    local dst = goal.moveTo
    
    local p = nil
    if src and dst then
      p = path.get(src, dst)
    end
    
    if not p then
      goal.status = "failed"
    else
      local old = nil
      for _,pos in ipairs(p) do
        if old then
          if old.floorNum == pos.floorNum then
            goal:addSubgoal(newSeekGoal(self, old, pos, moveSpeed))
          else
            goal:addSubgoal(newElevatorGoal(self, old, pos))
          end
        end
        old = pos
      end
    end
  end
  
  return goal
end

local newSleepGoal = function (self, t)
  local goal = M.newGoal(self)
  goal.time = t
  
  goal.process = function(self, dt)
    goal.time = goal.time - dt
    if goal.time <= 0 then
      return "complete"
    else
      return "active"
    end
  end
  
  return goal
end
  
local newSexGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.time = t

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target then
      self.status = "failed"
      return
    end
    
    local pos = room.getPos(self.component.entity)
    local atRoom = false
    event.notify("room.check", 0, {
      roomNum = pos.roomNum,
      floorNum = pos.floorNum,
      callback = function (id)
        if id == self.target then
          atRoom = true
        end
      end,
    })
    if not atRoom then
      self.status = "failed"
      return
    end
    
    local occupied = false
    event.notify("room.occupy", self.target, {
      id = self.component.entity,
      callback = function (success)
        occupied = success
      end,
    })
    
    if not occupied then
      self.status = "failed"
      return
    end

    goal:addSubgoal(newSleepGoal(self, SEX_TIME))
    
    old_activate(self)
  end
  
  local old_teminate = goal.terminate
  goal.terminate = function(self)
    event.notify("room.depart", self.target, {
      id = self.component.entity,
    })
    
    self.component.horny = false
    old_teminate(self)
  end
  
  return goal
end

local newDestroyGoal = function (self)
  local goal = M.newGoal(self)
  
  goal.process = function(self, dt)
    entity.delete(self.component.entity)
    return "complete"
  end
  
  return goal
end

local addVisitGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
    
  local old_activate = goal.activate
  goal.activate = function (self)
    goal:addSubgoal(newMoveToGoal(self.component, room.getPos(target), CLIENT_MOVE))
    goal:addSubgoal(newSexGoal(self.component, target))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    self.subgoals = {}
    old_terminate(self)
  end
  
  goal.getDesirability = function (self, t)
    if t.horny then
      return 1
    else
      return -1
    end
  end
  
  self.goalEvaluator:addSubgoal(goal)
end
  
local addExitGoal = function (self)
  local goal = M.newGoal(self)
    
  local old_activate = goal.activate
  goal.activate = function (self)
    goal:addSubgoal(newMoveToGoal(self.component, {roomNum = -.5, floorNum = GROUND_FLOOR}, CLIENT_MOVE))
    goal:addSubgoal(newDestroyGoal(self.component))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    self.subgoals = {}
    old_terminate(self)
  end
  
  goal.getDesirability = function (self, t)
    return 0
  end
  
  self.goalEvaluator:addSubgoal(goal)
end

local newBeginCleanGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  
  goal.process = function(self, dt)
    if not self.target then
      return "failed"
    end
    
    local pos = room.getPos(self.component.entity)
    local atRoom = false
    event.notify("room.check", 0, {
      roomNum = pos.roomNum,
      floorNum = pos.floorNum,
      callback = function (id)
        if id == self.target then
          atRoom = true
        end
      end,
    })
    if not atRoom then
      return "failed"
    end
    
    local cleaning = false
    event.notify("room.beginClean", self.target, {
      id = self.component.entity,
      callback = function (res)
        cleaning = res
      end,
    })
    
    if cleaning then
      return "complete"
    else
      return "failed"
    end
  end
  
  goal.terminate = function (self)
    self.target = nil
  end
  
  return goal
end

local newEndCleanGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  
  goal.process = function(self, dt)
    if not self.target then
      return "failed"
    end
    
    local pos = room.getPos(self.component.entity)
    local atRoom = false
    event.notify("room.check", 0, {
      roomNum = pos.roomNum,
      floorNum = pos.floorNum,
      callback = function (id)
        if id == self.target then
          atRoom = true
        end
      end,
    })
    if not atRoom then
      return "failed"
    end
    
    event.notify("room.endClean", self.target, {
      id = self.component.entity,
    })
    
    return "complete"
  end
  
  goal.terminate = function (self)
    self.target = nil
  end
  
  return goal
end

local addCleanGoal = function (self)
  local goal = M.newGoal(self)
  
  local old_activate = goal.activate
  goal.activate = function (self)
    self.status = "active"
    local target = nil
    local rooms = {}
    event.notify("room.dirty", 0, function (id,type)
      table.insert(rooms,{id=id, type=type})
    end)
    if #rooms > 0 then
      target = rooms[math.random(1,#rooms)].id
    end
    
    if not target then
      self.status = "failed"
      return
    end
    
    self:addSubgoal(newMoveToGoal(self.component, room.getPos(target), STAFF_MOVE))
    self:addSubgoal(newBeginCleanGoal(self.component, target))
    self:addSubgoal(newSleepGoal(self.component, CLEAN_TIME))
    self:addSubgoal(newEndCleanGoal(self.component, target))
    old_activate(self)
  end
    
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    self.subgoals = {}
    old_terminate(self)
  end
  
  goal.getDesirability = function (self, t)
    return 1
  end
  
  self.goalEvaluator:addSubgoal(goal)
end

M.new = function (id)
  local com = entity.newComponent({
    entity = id,
    currentGoal = nil,
    
    update = update,
    addGoal = addGoal,
    addVisitGoal = addVisitGoal,
    addCleanGoal = addCleanGoal,
    addExitGoal = addExitGoal,
  })
  com.goalEvaluator = M.newGoal(com)
  com.goalEvaluator.arbitrate = arbitrate

  return com
end

path.addEdge(
  {roomNum = -.5, floorNum = GROUND_FLOOR},
  {roomNum = .5, floorNum = GROUND_FLOOR},
  1
)
path.addEdge(
  {roomNum = .5, floorNum = GROUND_FLOOR},
  {roomNum = -.5, floorNum = GROUND_FLOOR},
  1
)

event.subscribe("floor.new", 0, function (t)
  for i = .5, 7, .5 do
    path.addEdge(
      {roomNum = i, floorNum = t.level},
      {roomNum = i+.5, floorNum = t.level},
      1
    )
    path.addEdge(
      {roomNum = i+.5, floorNum = t.level},
      {roomNum = i, floorNum = t.level},
      1
    )
  end
end)


event.subscribe("build", 0, function (t)
  if t.type == "elevator" then
    -- Check for elevator above
    event.notify("room.check", 0, {
      roomNum = t.pos.roomNum,
      floorNum = t.pos.floorNum + 1,
      callback = function (id, type)
        if type == "elevator" then
          local dst = {
            roomNum = t.pos.roomNum,
            floorNum = t.pos.floorNum + 1,
          }
          path.addEdge(t.pos, dst, 1)
          path.addEdge(dst, t.pos, 1)
        end
      end,
    })
    
    -- Check for elevator below
    event.notify("room.check", 0, {
      roomNum = t.pos.roomNum,
      floorNum = t.pos.floorNum - 1,
      callback = function (id, type)
        if type == "elevator" then
          local dst = {
            roomNum = t.pos.roomNum,
            floorNum = t.pos.floorNum - 1,
          }
          path.addEdge(t.pos, dst, 1)
          path.addEdge(dst, t.pos, 1)
        end
      end,
    })
  end
end)

event.subscribe("destroy", 0, function (t)
  if t.type == "elevator" then
    local dst = {
      roomNum = t.pos.roomNum,
      floorNum = t.pos.floorNum + 1,
    }
    path.removeEdge(t.pos,dst)
    path.removeEdge(dst,t.pos)
    
    dst = {
      roomNum = t.pos.roomNum,
      floorNum = t.pos.floorNum - 1,
    }
    path.removeEdge(t.pos,dst)
    path.removeEdge(dst,t.pos)
  end
end)

return M
