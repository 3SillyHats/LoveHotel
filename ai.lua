-- ai.lua

local ARBITRATE_TICK = 1

local event = require("event")
local entity = require("entity")
local transform = require("transform")
local room = require("room")
local path = require("path")
local resource = require("resource")

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

  self.timer = self.timer + dt

  -- Arbitrate strategy-level goals only every ARBITRATE_TICK seconds
  if self.timer >= ARBITRATE_TICK then
    self.timer = self.timer - ARBITRATE_TICK
    local newGoal = self.goalEvaluator.arbitrate(self, desirabilityFactors)
    if newGoal ~= self.currentGoal then
      if self.currentGoal then self.currentGoal:terminate() end
      if newGoal then newGoal:activate() end
      self.currentGoal = newGoal
    end
  end

  -- Process current goal
  if self.currentGoal then
    local result = self.currentGoal:process(dt)
    self.currentGoal.status = result
    if result == "complete" or result == "failed" then
      self.currentGoal:terminate()
      self.currentGoal = self.goalEvaluator.arbitrate(self, desirabilityFactors)
      if self.currentGoal then self.currentGoal:activate() end
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

local cancelReservation = function (self)
  event.notify("reservation.cancelled", self.entity)
  if self.reserved ~= nil then
    self.beenServed = false
    room.release(self.reserved)
    self.reserved = nil
  end
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
  --if self.moveTo.floorNum ~= self.pos.floorNum then
  --  return "failed"
  --end
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
  goal.name = "seek"
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
      if roomType == "elevator" and not room.isBroken(id) then
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
  if self.waitStart then
    return "active"
  end
  if not self.waitEnd then
    return "complete"
  end
  if math.abs(self.moveTo.floorNum - self.pos.floorNum) < self.speed*dt then
    local result = elevatorGoto(self, {
      roomNum = self.moveTo.roomNum,
      floorNum = self.moveTo.floorNum,
    })
    if result then return result end
    self.roomIdEnd = nil
    event.notify("room.check", 0, {
      roomNum = self.pos.roomNum,
      floorNum = self.pos.floorNum,
      callback = function (id, type)
        if type == "elevator" then
          self.roomIdEnd = id
        end
      end,
    })
    if room.isBroken(self.roomIdEnd) then
      return "complete"
    else
      event.subscribe("sprite.onAnimationEnd", self.roomIdEnd, self.endHandler)
      event.notify("sprite.play", self.roomIdEnd, "opening")
    end
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
  goal.name = "elevator"
  goal.waitStart = true
  goal.waitEnd = true

  goal.startHandler = function (e)
    if e.animation == "opening" then
      event.notify("sprite.hide", goal.component.entity, true)
      goal.waitStart = false
    end
  end

  goal.endHandler = function (e)
    if e.animation == "opening" then
      goal.waitEnd = false
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

  local old_activate = goal.activate
  goal.activate = function (self)
    event.notify("sprite.play", self.component.entity, "idle")
    self.roomIdStart = nil
    event.notify("room.check", 0, {
      roomNum = self.pos.roomNum,
      floorNum = self.pos.floorNum,
      callback = function (id, type)
        if type == "elevator" then
          self.roomIdStart = id
        end
      end,
    })
    if not self.roomIdStart or room.isBroken(self.roomIdStart) then
      self.status = "failed"
      return
    else
      event.subscribe("sprite.onAnimationEnd", self.roomIdStart, self.startHandler)
      event.notify("sprite.play", self.roomIdStart, "opening")
    end
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    delete()
    event.notify("entity.move", goal.component.entity, {
      roomNum = goal.pos.roomNum,
      floorNum = math.floor(goal.pos.floorNum + .5)
    })
    local elevator
    event.notify("room.check", 0, {
      roomNum = self.pos.roomNum,
      floorNum = self.pos.floorNum,
      callback = function (id, type)
        elevator = id
      end,
    })

    room.use(elevator)
    event.notify("sprite.play", goal.component.entity, "idle")
    event.notify("sprite.hide", goal.component.entity, false)
    event.unsubscribe("sprite.onAnimationEnd", self.roomIdStart, self.startHandler)
    event.unsubscribe("sprite.onAnimationEnd", self.roomIdEnd, self.endHandler)
    old_terminate(self)
  end

  return goal
end

local newMoveToGoal = function (com, moveTo, moveSpeed)
  local goal = M.newGoal(com)
  goal.moveTo = {roomNum = moveTo.roomNum, floorNum = moveTo.floorNum}
  goal.speed = moveSpeed
  goal.name = "moveTo"

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
      local last = self.pos
      local old = nil
      for i = #p, 1, -1 do
        local pos = p[i]
        if old then
          if last.roomNum ~= old.roomNum and old.floorNum ~= pos.floorNum then
            self:addSubgoal(newSeekGoal(self.component, last, {roomNum = old.roomNum, floorNum = last.floorNum}, moveSpeed))
            last = {roomNum = old.roomNum, floorNum = last.floorNum}
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
        if last.roomNum ~= old.roomNum then
          self:addSubgoal(newSeekGoal(self.component, last, {roomNum = old.roomNum, floorNum = last.floorNum}, moveSpeed))
          last = {roomNum = old.roomNum, floorNum = last.floorNum}
        end
        if last.floorNum ~= old.floorNum then
          self:addSubgoal(newSeekGoal(self.component, last, {roomNum = last.roomNum, floorNum = old.floorNum}, moveSpeed))
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
  goal.name = "sleep"

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

local newPlayAnimationGoal = function (com, target, animation)
  local goal = M.newGoal(com)
  goal.target = target
  goal.animation = animation
  goal.name = "playAnimation"

  local old_activate = goal.activate
  goal.activate = function (self)
    event.notify("sprite.play", self.target, self.animation)
    old_activate(self)
    self.status = "complete"
  end

  goal.process = function (self, dt)
    return "complete"
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
  end

  return goal
end

local newWaitForAnimationGoal = function (com, target, animation)
  local goal = M.newGoal(com)
  goal.target = target
  goal.animation = animation
  goal.done = false
  goal.name = "waitForAnimation"

  local handler = function (e)
    if e.animation == goal.animation then
      goal.done = true
    end
  end

  local old_activate = goal.activate
  goal.activate = function (self)
    event.subscribe("sprite.onAnimationEnd", self.target, handler)
    event.notify("sprite.play", self.target, self.animation)
    old_activate(self)
  end

  goal.process = function (self, dt)
    if self.done then
      return "complete"
    else
      return "active"
    end
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.unsubscribe("sprite.onAnimationEnd", self.target, handler)
    old_terminate(self)
  end

  return goal
end

local newSexGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.profit = room.getInfo(goal.target).profit
  goal.inRoom = false
  goal.name = "sex"

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target then
      self.status = "failed"
      return
    end
    if self.component.leader then
      if self.component.supply == 0 or
          self.component.money < self.profit then
        self.status = "failed"
        return
      end
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

    if occupied then
      event.notify("sprite.hide", self.component.entity, true)
    else
      self.status = "failed"
      return
    end
    event.notify("sprite.play", self.target, "hearts")

    event.notify("enterRoom", self.component.entity, self.target)
    self.inRoom = true

    self:addSubgoal(newSleepGoal(self.component, SEX_TIME))
    self:addSubgoal(newPlayAnimationGoal(
      self.component,
      self.target,
      "heartless"
    ))
    self:addSubgoal(newPlayAnimationGoal(
      self.component,
      self.target,
      "dirty"
    ))
    self:addSubgoal(newWaitForAnimationGoal(
      self.component,
      self.target,
      "opening"
    ))

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    if self.inRoom then
      event.notify("room.depart", self.target, {
        id = self.component.entity,
      })
      self.inRoom = false

      -- Make sure graphics change even if terminated early
      event.notify("sprite.play", self.target, "heartless")
      event.notify("sprite.play", self.target, "dirty")
      event.notify("sprite.play", self.target, "open")

      -- Messify and unhide the departing person
      event.notify("sprite.play", self.component.entity, "messy")
      event.notify("sprite.hide", self.component.entity, false)
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
      self.component.needs.horniness = math.max(0, self.component.needs.horniness - SEX_HORNINESS)
      self.component.money = self.component.money - self.profit
      self.component.supply = self.component.supply - 1

      local clientInfo = resource.get("scr/people/" .. self.component.category .. ".lua")
      local roomInfo = room.getInfo(self.target)
      if roomInfo.id == "utility" then
        reputationChange(-clientInfo.influence)
      end
    end

    self.component.beenServed = false

    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local newDestroyGoal = function (self)
  local goal = M.newGoal(self)
  goal.name = "destroy"

  goal.process = function(self, dt)
    entity.delete(self.component.entity)
    return "complete"
  end

  return goal
end

local newRelaxGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "relax"

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

    if room.occupied(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    self.status = "active"
    old_activate(self)
  end

  goal.process = function (self, dt)
    self.component.needs.horniness = self.component.needs.horniness + (5 * dt)
    if self.component.needs.horniness >= 100 then
      self.component.needs.horniness = 100
      return "complete"
    end
    return "active"
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)
    room.use(self.target)

    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addSpaGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "spa"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    cancelReservation(self.component)

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    self.relax = newRelaxGoal(self.component, self.target)
    self:addSubgoal(self.relax)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    self.relax = nil

    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if t.needs.horniness < 100 then
      if self.relax then
        return 100 - t.needs.horniness
      elseif room.occupation(self.target) == 0 and
          not room.isBroken(self.target) then
        local myPos = transform.getPos(self.component.entity)
        local time = path.getCost(myPos, targetPos)
        if time == -1 then
          return -1
        end
        return (100 - t.needs.horniness) / (1 + time)
      end
    end
    return -1
  end

  local destroy
  destroy = function (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local newWaitForWaiterGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.name = "waitForWaiter"

  local queryHandler = function (e)
    if com.leader and not com.orderedMeal then
      e.callback(com.entity)
    end
  end

  local serveHandler = function (e)
    com.orderedMeal = true
  end

  goal.process = function (self, dt)
    if self.component.orderedMeal then
      return "complete"
    end
    return "active"
  end

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    event.subscribe("staff.queryServe", self.target, queryHandler)
    event.subscribe("staff.cook.serve", com.entity, serveHandler)

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    room.exit(self.target)

    event.unsubscribe("staff.queryServe", self.target, queryHandler)
    event.unsubscribe("staff.cook.serve", com.entity, serveHandler)

    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local newWaitForMealGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.name = "waitForMeal"

  local mealHandler = function (roomId)
    local myPos = transform.getPos(goal.component.entity)
    event.notify("room.check", 0, {
      roomNum = myPos.roomNum,
      floorNum = myPos.floorNum,
      callback = function (id, type)
        if id == roomId then
          com.orderedMeal = false
        end
      end,
    })
    local info = room.getInfo(roomId)
    if goal.component.money >= info.profit then
      goal.component.money = goal.component.money - info.profit
      moneyChange(info.profit, transform.getPos(goal.component.entity))
      goal.component.needs.hunger = 0
    end
  end

  goal.process = function (self, dt)
    if self.component.orderedMeal then
      return "active"
    end
    return "complete"
  end

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target then
      self.status = "failed"
      return
    end

    cancelReservation(self.component)

    event.subscribe("staff.cook.serveMeal", self.component.entity, mealHandler)

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    event.unsubscribe("staff.cook.serveMeal", self.component.entity, mealHandler)

    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local addOrderMealGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "orderMeal"

  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)

  local old_activate = goal.activate
  goal.activate = function (self)
    cancelReservation(self.component)
    goal:addSubgoal(newMoveToGoal(self.component, room.getPos(target), PERSON_MOVE))
    goal:addSubgoal(newWaitForWaiterGoal(self.component, target))
    goal:addSubgoal(newWaitForMealGoal(self.component, target))

    old_activate(self)
  end

  local old_process = goal.process
  goal.process = function (self, dt)
    self.component.patience = self.component.patience - 5*dt
    return old_process(self, dt)
  end

  goal.getDesirability = function (self, t)
    if self.component.patience > 0 and
        self.component.money >= info.profit and
        self.component.needs.hunger > 50 and
        self.component.needs.hunger > self.component.needs.horniness then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end
      return self.component.needs.hunger / (time + 1)
    else
      return -1
    end
  end

  local function destroy (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local newWaitForReceptionGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.name = "waitForReception"

  local queryHandler = function (e)
    if com.leader and not com.beenServed then
      e.callback(com.entity)
    end
  end

  local serveHandler = function (e)
    com.beenServed = true
  end

  goal.process = function (self, dt)
    if self.component.supply == 0 then
      return "failed"
    end
    if self.component.needs.horniness <= self.component.needs.hunger then
      return "failed"
    end
    if self.component.beenServed then
      local rooms = {}
      event.notify("room.all", 0, function (id, type)
        local roomInfo = room.getInfo(id)
        if roomInfo.visitable and
            self.component.money >= roomInfo.profit and
            not room.isDirty(id) and
            room.reservations(id) == 0 and
            room.occupation(id) == 0 then
          local myPos = transform.getPos(self.component.entity)
          local targetPos = transform.getPos(self.target)
          local time = path.getCost(myPos, targetPos)
          if time ~= -1 then
            local myInfo = resource.get("scr/people/" .. self.component.category .. ".lua")
            table.insert(rooms, {id = id, desirability = 1/(1+time) + myInfo.desirability[roomInfo.id]})
          end
        end
      end)

      if #rooms > 0 then
        table.sort(rooms, function (a,b)
          return a.desirability > b.desirability
        end)
        local id = rooms[1].id
        room.reserve(id)
        self.component.reserved = id
        return "complete"
      end

      return "failed"
    end

    self.component.patience = self.component.patience - 5*dt

    return "active"
  end

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    event.subscribe("staff.queryServe", self.target, queryHandler)
    event.subscribe("staff.bellhop.serve", com.entity, serveHandler)

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    room.exit(self.target)

    event.unsubscribe("staff.queryServe", self.target, queryHandler)
    event.unsubscribe("staff.bellhop.serve", com.entity, serveHandler)

    if self.status ~= "complete" then
      event.notify("reservation.cancelled", self.component.entity)
      self.component.beenServed = false
    end

    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local addCheckInGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "checkIn"

  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local receptionGoal = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    cancelReservation(self.component)
    goal:addSubgoal(newMoveToGoal(self.component, room.getPos(target), PERSON_MOVE))
    receptionGoal = newWaitForReceptionGoal(self.component, target)
    goal:addSubgoal(receptionGoal)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if not self.component.reserved and
        self.component.patience > 0 and
        self.component.needs.horniness > 0 and
        self.component.needs.horniness > self.component.needs.hunger and
        self.component.supply > 0 then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time ~= -1 then
        return 1/(1+time)
      end
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

local addVisitGoal = function (self)
  local goal = M.newGoal(self)
  goal.name = "visit"

  local sexGoal = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    local targetPos = room.getPos(self.component.reserved)
    goal:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    sexGoal = newSexGoal(self.component, self.component.reserved)
    goal:addSubgoal(sexGoal)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if not self.component.beenServed or
        not self.component.reserved then
      return -1
    end
    if sexGoal and sexGoal.status == "active" then
      return 1000
    end
    local roomInfo = room.getInfo(self.component.reserved)
    local cheapInfo = resource.get("scr/rooms/missionary.lua")
    if self.component.money < cheapInfo.profit or
        self.component.money < roomInfo.profit or
        self.component.supply <= 0 then
      cancelReservation(self.component)
      return -1
    end
    if t.needs.horniness > t.needs.hunger and
        not room.isDirty(self.component.reserved) and
        room.occupation(self.component.reserved) == 0 then
      local myInfo = resource.get("scr/people/" .. self.component.category .. ".lua")
      local myPos = transform.getPos(self.component.entity)
      local targetPos = room.getPos(self.component.reserved)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end
      return 1/(1+time) + myInfo.desirability[roomInfo.id]
    end
    return -1
  end

  self.goalEvaluator:addSubgoal(goal)
end

local addFollowGoal = function (self, target, type)
  local goal = M.newGoal(self)
  goal.target = target
  goal.type = type
  goal.room = nil
  goal.name = "follow"

  if type == "client" then
    goal.move = PERSON_MOVE
  elseif type == "staff" then
    goal.move = PERSON_MOVE
  end

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

  local onCancel = function ()
    if #goal.targetHist == 0 then
      table.insert(goal.targetHist, {
        pos = transform.getPos(goal.target),
      })
    end
    goal.cancelled = true
  end

  local old_activate = goal.activate
  goal.activate = function (self)
    if self.type == "staff" then
      self.followDist = BELLHOP_DISTANCE
    else
      self.followDist = FOLLOW_DISTANCE
    end
    self.targetHist = {{
      pos = transform.getPos(self.target),
    }}
    event.subscribe("sprite.hide", self.target, onHide)
    event.subscribe("sprite.play", self.target, onPlay)
    event.subscribe("sprite.flip", self.target, onFlip)
    event.subscribe("enterRoom", self.target, onEnter)
    event.subscribe("reservation.cancelled", self.target, onCancel)
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
      if goal.cancelled and self.type == "staff" then
        self.message = "staff cancelled"
        return "complete"
      end
      if goal.room then
        self.followDist = self.followDist - self.move*dt
      end
      while #self.targetHist > 0 and
          math.abs(myPos.roomNum - targetPos.roomNum) + math.abs(myPos.floorNum - targetPos.floorNum) >= self.followDist do
        local next = table.remove(self.targetHist, 1)
        event.notify("entity.move", self.component.entity, next.pos)
        if next.hide and not next.enterRoom then
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
          if self.type == "client" then
            sexGoal = newSexGoal(self.component, self.room)
            self:addSubgoal(sexGoal)
            sexGoal:activate()
          elseif self.type == "staff" then
            self.message = "staff complete"
            return "complete"
          end
        end
        myPos = transform.getPos(self.component.entity)
      end
      self.message = "active"
      return "active"
    end

    local status = old_process(self,dt)
    if status == "complete" then
      sexGoal = nil
      self.room = nil
      if self.type == "staff" then
        self.followDist = BELLHOP_DISTANCE
      else
        self.followDist = FOLLOW_DISTANCE
      end
      self.message = "sex complete"
      return "complete"
    end
    self.message = "subgoal "..status
    return status
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.unsubscribe("sprite.hide", self.target, onHide)
    event.unsubscribe("sprite.play", self.target, onPlay)
    event.unsubscribe("sprite.flip", self.target, onFlip)
    event.unsubscribe("enterRoom", self.target, onEnter)
    event.unsubscribe("reservation.cancelled", self.target, onCancel)
    if self.type == "staff" then
      self.component.following = false
      self.component.goalEvaluator:removeSubgoal(self)
    end
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if entity.get(self.target) then
      return 1001
    end
    return -1
  end

  self.goalEvaluator:addSubgoal(goal)
end

local addExitGoal = function (self)
  local goal = M.newGoal(self)
  goal.name = "exit"

  local old_activate = goal.activate
  goal.activate = function (self)
    cancelReservation(self.component)
    if self.component.leader then
      local info = resource.get("scr/people/" .. self.component.category .. ".lua")
      if self.component.needs.horniness <= 0 then
        event.notify("sprite.play", self.component.entity, "thoughtHappy")
        self.rep = info.influence
      elseif self.component.patience <= 0 then
        event.notify("sprite.play", self.component.entity, "thoughtImpatient")
        self.rep = -3*info.influence
      elseif self.component.needs.hunger > self.component.needs.horniness then
        event.notify("sprite.play", self.component.entity, "thoughtHungry")
        if gStars >= 2 then
          self.rep = -3*info.influence
        else
          self.rep = info.influence
        end
      elseif self.component.supply <= 0 then
        event.notify("sprite.play", self.component.entity, "thoughtCondomless")
        if gStars >= 3 then
          self.rep = -3*info.influence
        else
          self.rep = info.influence
        end
      else
        local minCost = 9999999999
        event.notify("room.all", 0, function (id, type)
          local info = room.getInfo(id)
          if info.visitable then
            local available = true
            local myPos = transform.getPos(self.component.entity)
            local targetPos = transform.getPos(id)
            if room.occupation(id) > 0 or
                (info.dirtyable and room.isDirty(id)) or
                path.getCost(myPos, targetPos) == -1 then
              available = false
            end
            if available and info.profit < minCost then
              minCost = info.profit
            end
          end
        end)
        if minCost == 9999999999 then
          event.notify("sprite.play", self.component.entity, "thoughtRoomless")
          self.rep = -3*info.influence
        else
          event.notify("sprite.play", self.component.entity, "thoughtBroke")
          self.rep = info.influence
        end
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

    goal:addSubgoal(newMoveToGoal(self.component, {roomNum = -.5, floorNum = level}, PERSON_MOVE))
    goal:addSubgoal(newDestroyGoal(self.component))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    event.notify("sprite.play", self.component.entity, "thoughtNone")
    if self.component.leader and self.status == "complete" and
        self.rep then
      reputationChange(self.rep)
    end

    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if self.component.patience <= 0 then
      return 1000
    end
    return 0
  end

  self.goalEvaluator:addSubgoal(goal)
end

local newFixGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "fix"

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

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, FIX_TIME))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)

    local info = room.getInfo(self.target)
    local integrity = info.integrity + math.random(1, info.integrity)
    room.fix(self.target, integrity)

    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addMaintenanceGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "maintenance"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local fixing = nil
  local reserved = false

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end
    room.reserve(self.target)
    reserved = true

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    fixing = newFixGoal(self.component, self.target)
    self:addSubgoal(fixing)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.release(self.target)
    reserved = false
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if fixing and fixing.status == "active" then
      return 1000
    end

    if room.isBroken(self.target) and
        room.occupation(self.target) == 0 and
        (room.reservations(self.target) == 0 or reserved) then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end
      time = time + FIX_TIME

      return 1/time
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

local newRestockGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "restock"

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

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, RESTOCK_TIME))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)

    local myPos = transform.getPos(self.component.entity)
    local info = room.getInfo(self.target)
    room.setStock(self.target, 8)
    moneyChange(-info.restockCost, {
      roomNum = myPos.roomNum,
      floorNum = myPos.floorNum,
    })

    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addStockGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "stock"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local restocking = nil
  local reserved = false

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    room.reserve(self.target)
    reserved = true

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    restocking = newRestockGoal(self.component, self.target)
    self:addSubgoal(restocking)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.release(self.target)
    reserved = false
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if restocking and restocking.status == "active" then
      return 1000
    end

    if room.getStock(self.target) == 0 and
        room.occupation(self.target) == 0 and
        (room.reservations(self.target) == 0 or reserved)then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end

      return 1 / (time + RESTOCK_TIME)
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

local newPerformCleanGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "performClean"

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

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    event.notify("sprite.hide", self.component.entity, true)
    event.notify("sprite.play", self.target, "closing")
    event.notify("sprite.play", self.target, "cleaning")

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, CLEAN_TIME))
    self:addSubgoal(newPlayAnimationGoal(
      self.component,
      self.target,
      "clean"
    ))
    self:addSubgoal(newWaitForAnimationGoal(
      self.component,
      self.target,
      "opening"
    ))

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)
    room.setDirty(self.target, false)

    event.notify("sprite.hide", self.component.entity, false)
    event.notify("sprite.play", self.target, "cleanless")

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
  goal.name = "clean"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local cleaning = nil
  local reserved = false

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    room.reserve(self.target)
    reserved = true

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    cleaning = newPerformCleanGoal(self.component, self.target)
    self:addSubgoal(cleaning)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.release(self.target)
    reserved = false
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if cleaning and cleaning.status == "active" then
      return 1000
    end
    if self.component.supply > 0 and
        room.occupation(self.target) == 0 and
        (room.reservations(self.target) == 0 or reserved) and
        room.isDirty(self.target) then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time ~= -1 then
        return info.profit / (CLEAN_TIME + time)
      end
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

local newGetSupplyGoal = function (self, target, hidden)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "getSupply"
  hidden = hidden or false

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

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, SUPPLY_TIME))

    if hidden then
      event.notify("sprite.hide", self.component.entity, true)
      event.notify("sprite.play", self.target, "closing")
      self:addSubgoal(newWaitForAnimationGoal(
        self.component,
        self.target,
        "opening"
      ))
    else
      event.notify("sprite.play", self.target, "opening")
      self:addSubgoal(newWaitForAnimationGoal(
        self.component,
        self.target,
        "closing"
      ))
    end

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)
    event.notify("sprite.hide", self.component.entity, false)
    room.use(self.target)

    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addSupplyGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "supply"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local supply = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    supply = newGetSupplyGoal(self.component, self.target, true)
    self:addSubgoal(supply)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    if self.status == "complete" then
      self.component.supply = 1
    end

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
  local info = room.getInfo(target)
  goal.name = "getCondom"

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

    if room.isBroken(self.target) then
      self.status = "failed"
      return
    end

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, CONDOM_TIME))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)

    if self.component.money >= info.profit then
      self.component.supply = self.component.supply + 1
      self.component.money = self.component.money - info.profit
      moneyChange(info.profit, transform.getPos(self.component.entity))
      room.use(self.target)
    end

    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addCondomGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "condom"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local condom = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
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

    if not room.isBroken(self.target) and
        self.component.money >= info.profit and
        room.getStock(self.target) > 0 and
        room.occupation(self.target) == 0 and
        self.component.supply == 0 then
        local myPos = transform.getPos(self.component.entity)
        local time = path.getCost(myPos, targetPos)
        if time == -1 then
          return -1
        end
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

local newGetSnackGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  local info = room.getInfo(goal.target)
  goal.name = "getSnack"

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

    if room.isBroken(self.target) then
      self.status = "failed"
      return
    end

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, EAT_TIME))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)

    if self.component.money >= info.profit then
      self.component.money = self.component.money - info.profit
      moneyChange(info.profit, transform.getPos(self.component.entity))
      self.component.needs.hunger = math.max(0, self.component.needs.hunger - 50)
      room.use(self.target)
    end

    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addSnackGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "snack"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local food = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    food = newGetSnackGoal(self.component, self.target)
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

    if not room.isBroken(self.target) and
        self.component.money >= info.profit and
        room.getStock(self.target) > 0 and
        room.occupation(self.target) == 0 and
        self.component.needs.hunger > self.component.needs.horniness then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end
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

local newWaitForOccupationGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.name = "waitForOccupation"

  local old_activate = goal.activate
  goal.activate = function(self)
    if not self.target then
      self.status = "failed"
      return
    end

    old_activate(self)
  end

  goal.process = function (self, dt)
    local occupation = room.occupation(self.target)

    if occupation == 0 then
      return "active"
    else
      return "complete"
    end
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local newReceptionGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.name = "reception"

  local old_activate = goal.activate
  goal.activate = function(self)
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

    self:addSubgoal(newWaitForOccupationGoal(self.component, self.target))

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    local client
    event.notify("staff.queryServe", target, {
      callback = function (id)
        client = id
      end,
    })
    if client then
      event.notify("staff.bellhop.serve", client, {})
      self.component:addFollowGoal(client, "staff")
      self.component.following = true
    end

    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local addBellhopGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "bellhop"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local reception = nil
  local reserved = false

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    room.reserve(self.target)
    reserved = true

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    reception = newReceptionGoal(self.component, self.target)
    self:addSubgoal(reception)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.release(self.target)
    reserved = false

    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if self.component.following == true then
      return -1
    end
    if reception and reception.status == "active" then
      return 1000
    end
    local myPos = transform.getPos(self.component.entity)
    local time = path.getCost(myPos, targetPos)
    if time == -1 then
      return -1
    end

    -- Use exponential to map potentially negative desirability to wholly positive range while preserving ordering
    -- prioritise by (client pairs - bellhops) then by distance
    local desirability = room.occupation(self.target) - room.reservations(self.target) + (1 / (1 + time))
    if reserved then
      desirability = desirability + 1
    end
    return math.exp(desirability)
  end

  local function destroy (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local addEnterGoal = function (self)
  local goal = M.newGoal(self)
  goal.pos = transform.getPos(self.entity)
  goal.name = "enter"

  local seek = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    seek = newSeekGoal(self.component, goal.pos, {roomNum = 1, floorNum = goal.pos.floorNum}, PERSON_MOVE)
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

local newPrepareFoodGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "prepareFood"

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

    if room.occupation(self.target) > 0 then
      self.status = "failed"
      return
    end

    room.enter(self.target)

    local time = COOK_TIME
    if self.component.supply > 0 then
      time = time / 4
    end

    self.status = "active"
    self:addSubgoal(newSleepGoal(self.component, time))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    room.exit(self.target)

    if self.status == "complete" then
      self.component.supply = math.max(0, self.component.supply - 1)
      self.component.hasMeal = true
      self.component.cooking = false
    end

    self.target = nil
    old_terminate(self)
    self.subgoals = {}
  end

  return goal
end

local addCookGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "cook"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local prepareGoal = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    prepareGoal = newPrepareFoodGoal(self.component, self.target)
    self:addSubgoal(prepareGoal)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if prepareGoal and prepareGoal.status == "active" then
      return 1000
    end

    if self.component.cooking and
        room.occupation(self.target) == 0 then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time == -1 then
        return -1
      end
      return (1 + self.component.supply)/(time + COOK_TIME)
    else
      return -1
    end
  end

  local function destroy (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local addIngredientsGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "ingredients"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local supply = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    supply = newGetSupplyGoal(self.component, self.target, false)
    self:addSubgoal(supply)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    if self.status == "complete" then
      self.component.supply = 1
    end

    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if supply and supply.status == "active" then
      return 1000
    end
    if self.component.cooking and
        self.component.supply == 0 and
        room.getStock(self.target) > 0 and
        room.occupation(self.target) == 0 then
      local myPos = transform.getPos(self.component.entity)
      local time = path.getCost(myPos, targetPos)
      if time ~= -1 then
        return 10 / (SUPPLY_TIME + time)
      end
    end
    return -1
  end

  local destroy
  destroy = function (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local newTakeOrderGoal = function (com, target)
  local goal = M.newGoal(com)
  goal.target = target
  goal.name = "takeOrder"

  local old_activate = goal.activate
  goal.activate = function(self)
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

    self:addSubgoal(newWaitForOccupationGoal(self.component, self.target))

    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function(self)
    local client
    event.notify("staff.queryServe", target, {
      callback = function (id)
        client = id
      end,
    })
    if client then
      event.notify("staff.cook.serve", client, {})
      self.component.client = client
      self.component.clientRoom = self.target
      self.component.cooking = true
    end

    old_terminate(self)
    goal.subgoals = {}
  end

  return goal
end

local addWaiterGoal = function (self, target)
  local goal = M.newGoal(self)
  goal.target = target
  goal.name = "wait"
  local info = room.getInfo(goal.target)
  local targetPos = room.getPos(goal.target)
  local takeOrder = nil

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.target then
      self.status = "failed"
      return
    end

    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    takeOrder = newTakeOrderGoal(self.component, self.target)
    self:addSubgoal(takeOrder)
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if self.component.cooking or self.component.hasMeal then
      return -1
    end
    local myPos = transform.getPos(self.component.entity)
    local time = path.getCost(myPos, targetPos)
    if time == -1 then
      return -1
    end

    return (1 + room.occupation(self.target)) / time
  end

  local function destroy (t)
    self.goalEvaluator:removeSubgoal(goal)
    event.unsubscribe("destroy", goal.target, destroy)
  end
  event.subscribe("destroy", goal.target, destroy)

  self.goalEvaluator:addSubgoal(goal)
end

local addServeMealGoal = function (self)
  local goal = M.newGoal(self)
  goal.name = "deliverMeal"

  local old_activate = goal.activate
  goal.activate = function (self)
    if not self.component.clientRoom or
        entity.get(self.component.clientRoom) == nil then
      self.status = "failed"
      return
    end

    local targetPos = room.getPos(self.component.clientRoom)
    self:addSubgoal(newMoveToGoal(self.component, targetPos, PERSON_MOVE))
    old_activate(self)
  end

  local old_terminate = goal.terminate
  goal.terminate = function (self)
    if self.status == "complete" then
      if self.component.hasMeal then
        event.notify("staff.cook.serveMeal", self.component.client, self.component.clientRoom)
      end
    end
    self.component.client = nil
    self.component.clientRoom = nil
    self.component.hasMeal = false

    old_terminate(self)
    self.subgoals = {}
  end

  goal.getDesirability = function (self, t)
    if self.component.hasMeal then
      return 1000
    end
    return -1
  end

  self.goalEvaluator:addSubgoal(goal)
end

local addWanderGoal = function (com)
  local goal = M.newGoal(com)
  goal.name = "wander"

  local old_activate = goal.activate
  goal.activate = function (self)
    local myPos = transform.getPos(self.component.entity)
    local targetPos = {
      floorNum = myPos.floorNum,
      roomNum = (6 * math.random()) + 1,
    }
    self:addSubgoal(newSeekGoal(com, myPos, targetPos, PERSON_MOVE))
    self:addSubgoal(newSleepGoal(com, (4*math.random())+1))
  end

  goal.getDesirability = function (self, t)
    return 0
  end

  com.goalEvaluator:addSubgoal(goal)
end

M.new = function (id)
  local com = entity.newComponent({
    entity = id,
    currentGoal = nil,
    timer = 0,

    update = update,
    addCleanGoal = addCleanGoal,
    addVisitGoal = addVisitGoal,
    addFollowGoal = addFollowGoal,
    addExitGoal = addExitGoal,
    addEnterGoal = addEnterGoal,
    addSupplyGoal = addSupplyGoal,
    addCondomGoal = addCondomGoal,
    addSnackGoal = addSnackGoal,
    addBellhopGoal = addBellhopGoal,
    addCheckInGoal = addCheckInGoal,
    addMaintenanceGoal = addMaintenanceGoal,
    addStockGoal = addStockGoal,
    addWaiterGoal = addWaiterGoal,
    addIngredientsGoal = addIngredientsGoal,
    addCookGoal = addCookGoal,
    addServeMealGoal = addServeMealGoal,
    addOrderMealGoal = addOrderMealGoal,
    addSpaGoal = addSpaGoal,
    addWanderGoal = addWanderGoal,
  })
  com.goalEvaluator = M.newGoal(com)
  com.goalEvaluator.arbitrate = arbitrate

  local onDelete
  event.subscribe("delete", id, onDelete)
  onDelete = function ()
    cancelReservation(com)
    event.unsubscribe("delete", id, onDelete)
  end

  return com
end

local addElevator = function (t)
  if t.type == "elevator" then
    path.addNode(t.pos)
  end
end

local removeElevator = function (t)
  if t.type == "elevator" then
    path.removeNode(t.pos)
  end
end

event.subscribe("build", 0, addElevator)
event.subscribe("room.fixed", 0, addElevator)
event.subscribe("destroy", 0, removeElevator)
event.subscribe("room.broken", 0, removeElevator)

return M
