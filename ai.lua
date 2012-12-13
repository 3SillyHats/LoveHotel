-- ai.lua

local event = require("event")
local entity = require("entity")
local transform = require("transform")
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
  if self.status ~= "complete" then
    self.status = "failed"
  end
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

local removeSubgoal = function (self, subgoal)
  for k,v in ipairs(self.subgoals) do
    if v == subgoal then
      table.remove(self.subgoals, k)
      break
    end
  end
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
    needs = self.needs,
    money = self.money,
    supply = self.supply,
  }
  local newGoal = self.goalEvaluator.arbitrate(self, desirabilityFactors)
  if newGoal ~= self.currentGoal then
    if self.currentGoal then self.currentGoal:terminate() end
    if newGoal then newGoal:activate() end
    self.currentGoal = newGoal
  end
  if self.currentGoal then
    local result = self.currentGoal:process(dt)
    self.currentGoal.status = result
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
    removeSubgoal = removeSubgoal,
    getDesirability = getDesirability,
  }
end

local seekGoto = function (self,pos)
  local passable = false
  if (pos.floorNum >= gBottomFloor and
      pos.floorNum <= gTopFloor) or
    (pos.roomNum < 7.5 and
     pos.floorNum == GROUND_FLOOR) then
      passable = true
  end
  if passable then
    event.notify("entity.move", self.component.entity, pos)
  else
    return "failed"
  end
end

local seekProcess = function  (self, dt)
  if not self.moveTo or not self.pos then
    return "failed"
  end
  if self.moveTo.floorNum ~= self.pos.floorNum then
    return "failed"
  end
  if math.abs(self.moveTo.roomNum - self.pos.roomNum) < self.speed*dt then
    local result = seekGoto(self, {
      roomNum = self.moveTo.roomNum,
      floorNum = self.pos.floorNum,
    })
    if result then return result end
    return "complete"
  else
    local delta = self.speed*dt
    if self.moveTo.roomNum < self.pos.roomNum then
      delta = delta * -1
      event.notify("sprite.flip", self.component.entity, true)
    else
      event.notify("sprite.flip", self.component.entity, false)
    end
    local result = seekGoto(self, {
      roomNum = self.pos.roomNum + delta,
      floorNum = self.pos.floorNum,
    })
    if result then return result end
    return "active"
  end
end

local newSeekGoal = function (com, moveFrom, moveTo, moveSpeed)
  local goal = M.newGoal(com)
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.pos = {roomNum = moveFrom.roomNum, floorNum = moveFrom.floorNum}
  goal.speed = moveSpeed
  goal.process = seekProcess
  local onMove = function (pos)
    goal.pos.roomNum = pos.roomNum
    goal.pos.floorNum = pos.floorNum
  end
  event.subscribe("entity.move", goal.component.entity, onMove)
  local function delete()
    event.unsubscribe("entity.move", goal.component.entity, onMove)
    event.unsubscribe("delete", goal.component.entity, delete)
  end
  event.subscribe("delete", goal.component.entity, delete)
  local old_activate = goal.activate
  goal.activate = function (self)
    event.notify("sprite.play", goal.component.entity, "walking")
    old_activate(self)
  end
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    delete()
    event.notify("sprite.play", goal.component.entity, "idle")
    old_terminate(self)
  end
  
  return goal
end

local elevatorGoto = function(self, pos)
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
    event.notify("entity.move", self.component.entity, pos)
  else
    return "failed"
  end
end

local elevatorProcess = function (self, dt)
  if not self.moveTo or not self.pos then
    return "failed"
  end
  if self.moveTo.roomNum ~= self.pos.roomNum then
    return "failed"
  end
  if math.abs(self.moveTo.floorNum - self.pos.floorNum) < self.speed*dt then
    local result = elevatorGoto(self, {
      roomNum = self.moveTo.roomNum,
      floorNum = self.pos.floorNum,
    })
    if result then return result end
    return "complete"
  else
    local delta = self.speed*dt
    if self.moveTo.floorNum < self.pos.floorNum then
      delta = delta * -1
    end
    local result = elevatorGoto(self, {
      roomNum = self.pos.roomNum,
      floorNum = self.pos.floorNum + delta,
    })
    if result then return result end
    return "active"
  end
end

local newElevatorGoal = function (com, moveFrom, moveTo)
  local goal = M.newGoal(com)
  goal.elevator = true
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.pos = {roomNum = moveFrom.roomNum, floorNum = moveFrom.floorNum}
  goal.speed = ELEVATOR_MOVE
  goal.process = elevatorProcess
  local onMove = function (pos)
    goal.pos.roomNum = pos.roomNum
    goal.pos.floorNum = pos.floorNum
  end
  event.subscribe("entity.move", goal.component.entity, onMove)
  local function delete()
    event.unsubscribe("entity.move", goal.component.entity, onMove)
    event.unsubscribe("delete", goal.component.entity, delete)
  end
  event.subscribe("delete", goal.component.entity, delete)
  local old_activate = goal.activate
  goal.activate = function (self)
    event.notify("sprite.play", goal.component.entity, "idle")
    event.notify("sprite.hide", goal.component.entity, true)
    old_activate(self)
  end
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    delete()
    event.notify("entity.move", goal.component.entity, {
      roomNum = goal.pos.roomNum,
      floorNum = math.floor(goal.pos.floorNum + .5)
    })
    event.notify("sprite.play", goal.component.entity, "idle")
    event.notify("sprite.hide", goal.component.entity, false)
    old_terminate(self)
  end
  
  return goal
end

local newMoveToGoal = function (com, moveTo, moveSpeed)
  local goal = M.newGoal(com)
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.pos = {}
  goal.speed = moveSpeed
  
  local old_activate = goal.activate
  goal.activate = function (self)
    self.pos = transform.getPos(self.component.entity)
    local src = self.pos
    local dst = self.moveTo
    
    local p = nil
    if src and dst then
      p = path.get(src, dst)
    end
    
    if not p then
      self.status = "failed"
    else
      local last = nil
      local old = nil
      for _,pos in ipairs(p) do
        if old then
          if last.floorNum == old.floorNum and last.roomNum ~= old.roomNum and old.floorNum ~= pos.floorNum then
            self:addSubgoal(newSeekGoal(self.component, last, old, moveSpeed))
            last = old
          end
          if last.roomNum == old.roomNum and last.floorNum ~= old.floorNum and old.roomNum ~= pos.roomNum then
            self:addSubgoal(newElevatorGoal(self.component, last, old))
            last = old
          end
        end
        old = pos
        if not last then last = old end
      end
      if last then
        if last.floorNum == old.floorNum and last.roomNum ~= old.roomNum then
          self:addSubgoal(newSeekGoal(self.component, last, old, moveSpeed))
        end
        if last.roomNum == old.roomNum and last.floorNum ~= old.floorNum then
          self:addSubgoal(newElevatorGoal(self.component, last, old))
        end
      end
    end
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
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
  
local newSexGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.time = t
  goal.profit = room.getInfo(goal.target).profit
  goal.inRoom = false

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target or
        self.component.supply == 0 or
        self.component.money < self.profit then
      self.status = "failed"
      return
    end
    
    local pos = transform.getPos(self.component.entity)
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
    
    event.notify("enterRoom", self.component.entity, self.target)
    self.inRoom = true

    self:addSubgoal(newSleepGoal(self.component, SEX_TIME))
    
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function(self)
    if self.inRoom then
      event.notify("room.depart", self.target, {
        id = self.component.entity,
      })
      self.inRoom = false
    end
    
    if self.status == "complete" and self.component.leader then
      moneyChange(self.profit)
      local roomPos = room.getPos(self.target)
      event.notify("money.change", 0, {
        amount = self.profit,
        pos = {
          roomNum = roomPos.roomNum,
          floorNum = roomPos.floorNum,
        },
      })
      self.component.needs.horniness = self.component.needs.horniness - 50
      self.component.money = self.component.money - self.profit
      self.component.supply = self.component.supply - 1
    end
    
    old_terminate(self)
    goal.subgoals = {}
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
  
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local sexGoal = nil
    
  local old_activate = goal.activate
  goal.activate = function (self)
    goal:addSubgoal(newMoveToGoal(self.component, room.getPos(target), CLIENT_MOVE))
    sexGoal = newSexGoal(self.component, target)
    goal:addSubgoal(sexGoal)
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if sexGoal and sexGoal.status == "active" then
      return 1000
    end
    if t.needs.horniness > t.needs.hunger and
        not room.isDirty(self.target) and
        room.occupation(self.target) == 0 and
        self.component.money >= info.profit and
        self.component.supply > 0 then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end
      return 1/(1+time) + info.desirability
    end
    return -1
  end
  
  local function destroy (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)
  
  self.goalEvaluator:addSubgoal(goal)
end

local addFollowGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.room = nil
  
  local sexGoal = nil
  
  local onHide = function (hide)
    if #goal.targetHist == 0 then
      table.insert(goal.targetHist, {
        pos = transform.getPos(goal.target),
      })
    end
    if hide then
      goal.targetHist[#goal.targetHist].hide = true
      goal.targetHist[#goal.targetHist].unhide = false
    else
      goal.targetHist[#goal.targetHist].hide = false
      goal.targetHist[#goal.targetHist].unhide = true
    end
  end
  
  local onFlip = function (to)
    if #goal.targetHist == 0 then
      table.insert(goal.targetHist, {
        pos = transform.getPos(goal.target),
      })
    end
    goal.targetHist[#goal.targetHist].flip = true
    goal.targetHist[#goal.targetHist].flipTo = to
  end
  
  local onPlay = function (animation)
    if #goal.targetHist == 0 then
      table.insert(goal.targetHist, {
        pos = transform.getPos(goal.target),
      })
    end
    goal.targetHist[#goal.targetHist].play = animation
  end
  
  local onEnter = function (room)
    if #goal.targetHist == 0 then
      table.insert(goal.targetHist, {
        pos = transform.getPos(goal.target),
      })
    end
    goal.targetHist[#goal.targetHist].enterRoom = true
    goal.room = room
  end
  
  local old_activate = goal.activate
  goal.activate = function (self)
    self.followDist = FOLLOW_DISTANCE
    self.targetHist = {{
      pos = transform.getPos(self.target),
    }}
    event.subscribe("sprite.hide", self.target, onHide)
    event.subscribe("sprite.play", self.target, onPlay)
    event.subscribe("sprite.flip", self.target, onFlip)
    event.subscribe("enterRoom", self.target, onEnter)
    old_activate(self)
  end
    
  local old_process = goal.process
  goal.process = function (self, dt)
    if not sexGoal then
      local targetPos = transform.getPos(self.target)
      local myPos = transform.getPos(self.component.entity)
      table.insert(self.targetHist, {
        pos = targetPos,
      })
      if goal.room then
        self.followDist = self.followDist - CLIENT_MOVE*dt
      end
      while #self.targetHist > 0 and
          math.abs(myPos.roomNum - targetPos.roomNum) + math.abs(myPos.floorNum - targetPos.floorNum) >= self.followDist do
        local next = table.remove(self.targetHist, 1)
        event.notify("entity.move", self.component.entity, next.pos)
        if next.hide then 
          event.notify("sprite.hide", self.component.entity, true)
        elseif next.unhide then
          event.notify("sprite.hide", self.component.entity, false)
        end
        if next.flip then
          event.notify("sprite.flip", goal.component.entity, next.flipTo)
        end
        if next.play then
          event.notify("sprite.play", goal.component.entity, next.play)
        end
        if next.enterRoom then
          sexGoal = newSexGoal(self.component, self.room)
          self:addSubgoal(sexGoal)
          sexGoal:activate()
        end
        myPos = transform.getPos(self.component.entity)
      end
      return "active"
    elseif sexGoal.status == "complete" then
      sexGoal = nil
      self.room = nil
      self.followDist = FOLLOW_DISTANCE
      return "complete"
    end
    return old_process(self,dt)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.unsubscribe("sprite.hide", self.target, onHide)
    event.unsubscribe("sprite.play", self.target, onPlay)
    event.unsubscribe("sprite.flip", self.target, onFlip)
    event.unsubscribe("enterRoom", self.target, onEnter)
    old_terminate(self)
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if entity.get(self.target) then
      return 1
    end
    return -1
  end
  
  self.goalEvaluator:addSubgoal(goal)
end
  
local addExitGoal = function (self)
  local goal = M.newGoal(self)
  
  local old_activate = goal.activate
  goal.activate = function (self)
    if self.component.needs.horniness <= 0 then
      event.notify("sprite.play", self.component.entity, "thoughtHappy")
    elseif self.component.needs.hunger > self.component.needs.horniness then
      event.notify("sprite.play", self.component.entity, "thoughtHungry")
    elseif self.component.supply <= 0 then
      event.notify("sprite.play", self.component.entity, "thoughtCondomless")
    else
      local minCost = 9999999999
      event.notify("room.all", 0, function (id, type)
        local info = room.getInfo(id)
        if info.profit then
          local available = true
          if room.occupation(id) > 0 or
              (info.dirtyable and room.isDirty(id)) then
            available = false
          end
          if avaialble and info.profit < minCost then
            minCost = info.profit
          end
        end
      end)
      if minCost == 9999999999 then
        event.notify("sprite.play", self.component.entity, "thoughtRoomless")
      elseif minCost > self.component.money then
        event.notify("sprite.play", self.component.entity, "thoughtBroke")
      end
    end
  
    local level = GROUND_FLOOR
    if self.component.category == "sky" then
      level = SKY_SPAWN
    elseif self.component.category == "ground" then
      level = GROUND_SPAWN
    elseif self.component.category == "space" then
      level = SPACE_SPAWN
    end
  
    goal:addSubgoal(newMoveToGoal(self.component, {roomNum = -.5, floorNum = level}, CLIENT_MOVE))
    goal:addSubgoal(newDestroyGoal(self.component))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    event.notify("sprite.play", self.component.entity, "thoughtNone")
    if self.component.leader and self.status == "complete" then
      if self.component.needs.horniness > 99 then
        reputationChange(-2.5)
      else
        reputationChange(.5)
      end
    end
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    return 0
  end
  
  self.goalEvaluator:addSubgoal(goal)
end

local newPerformCleanGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  
  local old_activate = goal.activate
  goal.activate = function(self, dt)
    if not self.target or self.component.supply == 0 then
      self.status = "failed"
      return 
    end
    
    local pos = transform.getPos(self.component.entity)
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
    
    local cleaning = false
    event.notify("room.beginClean", self.target, {
      id = self.component.entity,
      callback = function (res)
        cleaning = res
      end,
    })
    
    if not cleaning then
      self.status = "failed"
      return
    end
    
    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, CLEAN_TIME))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.notify("room.endClean", self.target, {
      id = self.component.entity,
    })
    
    self.component.supply = self.component.supply - 1
    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end
  
  return goal
end

local addCleanGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local cleaning = nil
  
  local old_activate = goal.activate
  goal.activate = function (self)    
    if not self.target then
      self.status = "failed"
      return
    end
    
    self:addSubgoal(newMoveToGoal(self.component, targetPos, STAFF_MOVE))
    cleaning = newPerformCleanGoal(self.component, self.target)
    self:addSubgoal(cleaning)
    old_activate(self)
  end
    
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if cleaning and cleaning.status == "active" then
      return 1000
    end
    if self.component.supply == 0 then
      return -1
    end
    local myPos = transform.getPos(self.component.entity)
    local time = path.getCost(myPos, targetPos) + CLEAN_TIME
    if time == -1 then
      return -1
    end
    if room.isDirty(self.target) then
      if room.occupation(self.target) == 0 then
        return info.profit/time
      else
        return -1
      end
    else
      if room.occupation(self.target) > 0 and info.dirtyable then
        return info.profit/math.max(time, SEX_TIME+CLEAN_TIME)
      else
        return -1
      end
    end
  end
  
  local function destroy (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)
  
  self.goalEvaluator:addSubgoal(goal)
end

local newGetSupplyGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  
  local old_activate = goal.activate
  goal.activate = function(self, dt)
    if not self.target then
      self.status = "failed"
      return 
    end
    
    local pos = transform.getPos(self.component.entity)
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
    
    local supplying = false
    event.notify("room.beginSupply", self.target, {
      id = self.component.entity,
      enter = true,
      callback = function (res)
        supplying = res
      end,
    })
    
    if not supplying then
      self.status = "failed"
      return
    end
    
    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, SUPPLY_TIME))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.notify("room.endSupply", self.target, {
      id = self.component.entity,
    })
    self.component.supply = 3
    
    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end
  
  return goal
end

local addSupplyGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local supply = nil
  
  local old_activate = goal.activate
  goal.activate = function (self)    
    if not self.target then
      self.status = "failed"
      return
    end
    
    self:addSubgoal(newMoveToGoal(self.component, targetPos, STAFF_MOVE))
    supply = newGetSupplyGoal(self.component, self.target)
    self:addSubgoal(supply)
    old_activate(self)
  end
    
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if supply and supply.status == "active" then
      return 1000
    end
    local myPos = transform.getPos(self.component.entity)
    local time = path.getCost(myPos, targetPos)
    if time == -1 then
      return -1
    end
    local stock = room.getStock(self.target)
    local occupation = room.occupation(self.target)
    if stock > 0 and occupation == 0 and self.component.supply == 0 then
      return 1 / time
    else
      return -1
    end
  end
  
  local destroy
  destroy = function (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local newGetCondomGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  
  local old_activate = goal.activate
  goal.activate = function(self, dt)
    if not self.target then
      self.status = "failed"
      return 
    end
    
    local pos = transform.getPos(self.component.entity)
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
    
    local supplying = false
    event.notify("room.beginSupply", self.target, {
      id = self.component.entity,
      enter = false,
      callback = function (res)
        supplying = res
      end,
    })
    
    if not supplying then
      self.status = "failed"
      return
    end
    
    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, CONDOM_TIME))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.notify("room.endSupply", self.target, {
      id = self.component.entity,
    })
    self.component.supply = self.component.supply + 3
    
    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end
  
  return goal
end

local addCondomGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local condom = nil
  
  local old_activate = goal.activate
  goal.activate = function (self)    
    if not self.target then
      self.status = "failed"
      return
    end
    
    self:addSubgoal(newMoveToGoal(self.component, targetPos, CLIENT_MOVE))
    condom = newGetCondomGoal(self.component, self.target)
    self:addSubgoal(condom)
    old_activate(self)
  end
    
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if condom and condom.status == "active" then
      return 1000
    end
    local myPos = transform.getPos(self.component.entity)
    local time = path.getCost(myPos, targetPos)
    if time == -1 then
      return -1
    end
    local stock = room.getStock(self.target)
    local occupation = room.occupation(self.target)
    if stock > 0 and occupation == 0 and self.component.supply == 0 then
      return 1 / time
    else
      return -1
    end
  end
  
  local destroy
  destroy = function (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end


local newGetFoodGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  
  local old_activate = goal.activate
  goal.activate = function(self, dt)
    if not self.target then
      self.status = "failed"
      return 
    end
    
    local pos = transform.getPos(self.component.entity)
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
    
    local eating = false
    event.notify("room.beginSupply", self.target, {
      id = self.component.entity,
      enter = false,
      callback = function (res)
        eating = res
      end,
    })
    
    if not eating then
      self.status = "failed"
      return
    end
    
    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, EAT_TIME))
    old_activate(self)
  end
  
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.notify("room.endSupply", self.target, {
      id = self.component.entity,
    })
    self.component.needs.hunger = math.max(0, self.component.needs.hunger - 30)
    
    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end
  
  return goal
end

local addFoodGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local food = nil
  
  local old_activate = goal.activate
  goal.activate = function (self)    
    if not self.target then
      self.status = "failed"
      return
    end
    
    self:addSubgoal(newMoveToGoal(self.component, targetPos, CLIENT_MOVE))
    food = newGetFoodGoal(self.component, self.target)
    self:addSubgoal(food)
    old_activate(self)
  end
    
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if food and food.status == "active" then
      return 1000
    end
    local myPos = transform.getPos(self.component.entity)
    local time = math.abs(myPos.floorNum - targetPos.floorNum) / ELEVATOR_MOVE
      + math.abs(myPos.roomNum - targetPos.roomNum) / CLIENT_MOVE
    local stock = room.getStock(self.target)
    local occupation = room.occupation(self.target)
    if stock > 0 and occupation == 0 and
        self.component.needs.hunger > self.component.needs.horniness then
      return self.component.needs.hunger / time
    else
      return -1
    end
  end
  
  local destroy
  destroy = function (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end


local addEnterGoal = function (self)
  local goal = M.newGoal(self)
  goal.pos = transform.getPos(self.entity)
  
  local seek = nil
  
  local old_activate = goal.activate
  goal.activate = function (self)
    seek = newSeekGoal(self.component, goal.pos, {roomNum = 1, floorNum = goal.pos.floorNum}, STAFF_MOVE)
    self:addSubgoal(seek)
    old_activate(self)
  end
    
  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    seek = nil
    self.subgoals = {}
  end
  
  goal.getDesirability = function (self, t)
    if self.pos.roomNum < .5 or (seek and seek.status == "active") then
      return 0
    else
      return -1
    end
  end
  
  local onMove = function (pos)
    goal.pos.roomNum = pos.roomNum
    goal.pos.floorNum = pos.floorNum
  end
  event.subscribe("entity.move", goal.component.entity, onMove)
  local function delete()
    event.unsubscribe("entity.move", goal.component.entity, onMove)
    event.unsubscribe("delete", goal.component.entity, delete)
  end
  event.subscribe("delete", goal.component.entity, delete)
  
  self.goalEvaluator:addSubgoal(goal)
end

M.new = function (id)
  local com = entity.newComponent({
    entity = id,
    currentGoal = nil,
    
    update = update,
    addGoal = addGoal,
    addCleanGoal = addCleanGoal,
    addVisitGoal = addVisitGoal,
    addFollowGoal = addFollowGoal,
    addExitGoal = addExitGoal,
    addEnterGoal = addEnterGoal,
    addSupplyGoal = addSupplyGoal,
    addCondomGoal = addCondomGoal,
    addFoodGoal = addFoodGoal,
  })
  com.goalEvaluator = M.newGoal(com)
  com.goalEvaluator.arbitrate = arbitrate

  return com
end

path.addEdge(
  {roomNum = -.5, floorNum = GROUND_FLOOR},
  {roomNum = 0, floorNum = GROUND_FLOOR},
  .5/CLIENT_MOVE
)
path.addEdge(
  {roomNum = 0, floorNum = GROUND_FLOOR},
  {roomNum = -.5, floorNum = GROUND_FLOOR},
  .5/CLIENT_MOVE
)
path.addEdge(
  {roomNum = 0, floorNum = GROUND_FLOOR},
  {roomNum = .5, floorNum = GROUND_FLOOR},
  .5/CLIENT_MOVE
)
path.addEdge(
  {roomNum = .5, floorNum = GROUND_FLOOR},
  {roomNum = 0, floorNum = GROUND_FLOOR},
  .5/CLIENT_MOVE
)

event.subscribe("floor.new", 0, function (level)
  for i = .5, 7, .5 do
    path.addEdge(
      {roomNum = i, floorNum = level},
      {roomNum = i+.5, floorNum = level},
      .5/CLIENT_MOVE
    )
    path.addEdge(
      {roomNum = i+.5, floorNum = level},
      {roomNum = i, floorNum = level},
      .5/CLIENT_MOVE
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
          path.addEdge(t.pos, dst, 1/ELEVATOR_MOVE)
          path.addEdge(dst, t.pos, 1/ELEVATOR_MOVE)
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
          path.addEdge(t.pos, dst, 1/ELEVATOR_MOVE)
          path.addEdge(dst, t.pos, 1/ELEVATOR_MOVE)
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
