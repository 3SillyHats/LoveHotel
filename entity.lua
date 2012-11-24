-- entity.lua

local M = {}

local entities = {}
local nextId = 1
local deleted = {}

M.new = function ()
  local entity = {
    id = nextId,
    components = {},
  }
  nextId = nextId + 1
  table.insert(entities, entity)
  return entity.id
end

local get = function (id)
  for _,entity in ipairs(entities) do
    if entity.id == id then
      return entity
    end
  end
end

M.delete = function (id)
  table.insert(deleted, id)
end

M.draw = function ()
  for _,entity in ipairs(entities) do
    for _,component in ipairs(entity.components) do
      component:draw()
    end
  end
end

M.update = function (dt)
  for _,entity in ipairs(entities) do
    for _,component in ipairs(entity.components) do
      component:update(dt)
    end
  end
  
  -- Remove deleted entities from entities list
  table.sort(deleted)
  local index = #entities
  while #deleted > 0 do
    if entities[index].id == deleted[#deleted] then
      table.remove(entities, index)
      table.remove(deleted, #deleted)
    end
    index = index - 1
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
  table.insert(get(id).components, component)
end

return M
