-- entity.lua

local event = require("event")

local M = {}

local currentState = 1
local entities = {}
local nextId = 1
local deleted = {}

event.subscribe("state.enter", 0, function (state)
  if state ~= currentState then
    event.notify("state.exit",0,  currentState)
    currentState = state
  end
end)

M.new = function (state)
  local state = state or currentState
  local entity = {
    id = nextId,
    components = {},
    z = 0
  }
  nextId = nextId + 1
  if not entities[state] then
    entities[state] = {}
  end
  table.insert(entities[state], entity)
  return entity.id
end

M.get = function (id)
  for _,e in pairs(entities) do
    for _,entity in ipairs(e) do
      if entity.id == id then
        return entity
      end
    end
  end
end

M.delete = function (id)
  table.insert(deleted, id)
end

M.draw = function ()
  if entities[currentState] then
	-- Sort entities by z
	local sorted = {}
	for _,entity in ipairs(entities[currentState]) do
	  table.insert(sorted, entity)
	end
	table.sort(sorted, function (a, b)
	  return a.z < b.z
	end)
	
	-- Draw sorted
    for _,entity in ipairs(sorted) do
      for _,component in ipairs(entity.components) do
        component:draw()
      end
    end
  end
end

M.update = function (dt)
  if entities[currentState] then
    for _,entity in ipairs(entities[currentState]) do
      for _,component in ipairs(entity.components) do
        component:update(dt)
      end
    end
  
    -- Remove deleted entities from entities list
    table.sort(deleted)
    local index = #entities[currentState]
    local notDeleted = 0
    while #deleted-notDeleted > 0 and index >= 1 do
      while notDeleted < #deleted - 1 and entities[currentState][index].id < deleted[#deleted-notDeleted] do
        notDeleted = notDeleted + 1
      end
      if entities[currentState][index].id == deleted[#deleted-notDeleted] then
        local id = entities[currentState][index].id
        table.remove(entities[currentState], index)
        table.remove(deleted, #deleted-notDeleted)
        event.notify("delete", id)
      end
      index = index - 1
    end
  end
end

local componentDraw = function (self) end
local componentUpdate = function (self, dt) end

M.newComponent = function (prototype)
  local component = {
    draw = componentDraw,
    update = componentUpdate,
  }
  if prototype then
    for k,v in pairs(prototype) do
      component[k] = v 
    end
  end
  return component
end

M.addComponent = function (id, component)
  table.insert(M.get(id).components, component)
end

M.setOrder = function (id, z)
  M.get(id).z = z
end

return M
