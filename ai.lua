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

local goal = {
  subgoals = {},
  status = "inactive",
  
  activate = activate,
  process = process,
  terminate = terminate,
  getStatus = getStatus,
}

local update = function (self, dt)
	self.goal:process()
end

M.new = function (entity, t)
  local com = entity.newComponent({
    entity = entity,
    goal = goal,
    
    update = update,
  })

  return com
end

return M
