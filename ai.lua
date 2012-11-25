-- ai.lua

local event = require("event")
local entity = require("entity")

local M = {}

local activate = function (self) end

local process = function (self)
  -- Remove all completed and failed goals from the front of
  -- the subgoals list
  while #self.subgoals > 0 and
      self.subgoals[1].getStatus() == "complete" or
      self.subgoals[1].getStatus() == "failed" do
    self.subgoals[1].terminate()
    table.remove(self.subgoals, 1)
  end
  -- If any subgoals remain, process the one at the
  -- front of the list
  if #self.subgoals > 0 then
    local status = self.subgoals[1]
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
  self.currentGoal = self.goalEvaluator.arbitrate(self, desirabilityFactors)
  if self.currentGoal then    
    self.currentGoal.process(self)
  end
end

M.new = function (id, t)
  local com = entity.newComponent({
    entity = id,
    currentGoal = nil,
    
    update = update,
  })
  com.goalEvaluator = M.newGoal(com)
  com.goalEvaluator.arbitrate = arbitrate
  for _,sg in ipairs(t.subgoals) do
    goalEvaluator:addSubgoal(sg)
  end

  return com
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

M.newMoveToGoal = function (moveTo)
  local goal = M.newGoal()
  goal.moveTo = moveTo
  local process = goal.process
  goal.process = function (self)
    event.notify("sprite.move", self.component.entity, {
      x = 0, y = 0,
    })
    process(self)
  end
  goal.getDesirability = function (self, t)
    return t.horniness
  end
end

return M
