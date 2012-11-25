-- ai.lua

local event = require("event")
local entity = require("entity")

local M = {}

local activate = function (self)
  if #self.subgoals > 0 then
    self.subgoals[1]:activate()
  end
end

local process = function (self, dt)
  -- Remove all completed and failed goals from the front of
  -- the subgoals list
  while #self.subgoals > 0 and
      (self.subgoals[1]:getStatus() == "complete" or
       self.subgoals[1]:getStatus() == "failed") do
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
    if status == "completed" and #self.subgoals > 1 then
      return "active"
    end
    return status
  end
  -- No more subgoals
  return "completed"
end

local terminate = function (self) end

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
  local desirabilityFactors = {
    horniness = 0.7,
  }
  local newGoal = self.goalEvaluator.arbitrate(self, desirabilityFactors)
  if newGoal ~= self.currentGoal then
    if self.currentGoal then self.currentGoal:terminate() end
    if newGoal then newGoal:activate() end
    self.currentGoal = newGoal
  end
  if self.currentGoal then
    self.currentGoal:process(dt)
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
  goal.moveTo = moveTo
  goal.pos = moveFrom
  goal.speed = moveSpeed
  local goto = function(pos)
    local passable = false
    event.notify("room.check", 0, {
      roomNum = pos.roomNum,
      floorNum = pos.floorNum,
      callback = function (id)
        passable = true
      end,
    })
    if pos.roomNum < 7.5 and pos.floorNum == 1 then passable = true end
    if passable then
      event.notify("entity.move", goal.component.entity, pos)
    else
      return "failed"
    end
  end
  goal.process = function (self, dt)
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
  goal.getDesirability = function (self, t)
    return 1
  end
  
  return goal
end

local addMoveToGoal = function (self, moveFrom, moveTo, moveSpeed)
  local goal = M.newGoal(self)
  goal.moveTo = moveTo
  goal.pos = moveFrom
  goal.speed = moveSpeed
  
  local seekGoal = newSeekGoal(self, moveFrom, moveTo, moveSpeed)
  goal:addSubgoal(seekGoal)
  
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
    addMoveToGoal = addMoveToGoal,
  })
  com.goalEvaluator = M.newGoal(com)
  com.goalEvaluator.arbitrate = arbitrate

  return com
end

return M
