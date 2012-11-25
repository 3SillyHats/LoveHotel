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
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.pos = {roomNum = moveFrom.roomNum, floorNum = moveFrom.floorNum}
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

local groundFloorNode = function (pos)
  if pos < 0.5 then
    return 0
  else
    return -math.floor(pos+0.5)
  end
end

local addMoveToGoal = function (self, moveFrom, moveTo, moveSpeed)
  local goal = M.newGoal(self)
  goal.moveTo = moveTo
  goal.pos = moveFrom
  goal.speed = moveSpeed
  
  local src,dst
  if moveFrom.floorNum == 1 then
    src = groundFloorNode(moveFrom.roomNum)
  else
    event.notify("room.check", 0, {
      roomNum = moveFrom.roomNum,
      floorNum = moveFrom.floorNum,
      callback = function (id, type)
        src = id
      end,
    })
  end
  if moveTo.floorNum == 1 then
    dst = groundFloorNode(moveTo.roomNum)
  else
    event.notify("room.check", 0, {
      roomNum = moveTo.roomNum,
      floorNum = moveTo.floorNum,
      callback = function (id, type)
        dst = id
      end,
    })
  end
  local p
  if src and dst then
    p = path.get(src,dst)
  end
    
  if not p then
    goal.state = "failed"
  else
    local old = nil
    for _,node in ipairs(p) do
      local pos
      if node >= 1 then
        pos = room.getPos(node)
      elseif node == 0 then
        pos = {
          roomNum = -0.5,
          floorNum = 1,
        }
      else
        pos = {
          roomNum = -node,
          floorNum = 1,
        }
      end
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

for i = 0, -6, -1 do
  path.addEdge(i, i-1, 1)
  path.addEdge(i-1, 1, 1)
end
      
event.subscribe("build", 0, function (t)
  -- Check room to left
  event.notify("room.check", 0, {
    roomNum = t.pos.roomNum - 1,
    floorNum = t.pos.floorNum,
    callback = function (id, type)
      path.addEdge(t.id, id, 1)
      path.addEdge(id, t.id, 1)
    end,
  })
  -- Check room to Right
  event.notify("room.check", 0, {
    roomNum = t.pos.roomNum + 1,
    floorNum = t.pos.floorNum,
    callback = function (id, type)
      path.addEdge(t.id, id, 1)
      path.addEdge(id, t.id, 1)
    end,
  })
  
  if t.type == "elevator" then
    -- Check room above
    event.notify("room.check", 0, {
      roomNum = t.pos.roomNum,
      floorNum = t.pos.floorNum + 1,
      callback = function (id, type)
        if type == "elevator" then
          if t.pos.floorNum == 1 then
            path.addEdge(groundFloorNode(t.pos.roomNum), id, 1)
            path.addEdge(id, groundFloorNode(t.pos.roomNum), 1)
          else
            path.addEdge(t.id, id, 1)
            path.addEdge(id, t.id, 1)
          end
        end
      end,
    })
    
    -- Check room below
    event.notify("room.check", 0, {
      roomNum = t.pos.roomNum,
      floorNum = t.pos.floorNum - 1,
      callback = function (id, type)
        if type == "elevator" then
          if t.pos.floorNum == 2 then
            path.addEdge(t.id, groundFloorNode(t.pos.roomNum), 1)
            path.addEdge(groundFloorNode(t.pos.roomNum), t.id, 1)
          else
            path.addEdge(t.id, id, 1)
            path.addEdge(id, t.id, 1)
          end
        end
      end,
    })
  end
end)

return M
