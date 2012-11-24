-- event.lua

local M = {}

local manager = {
  events = {}
}

M.notify = function (event, id, data)
  if manager.events[event] and manager.events[event][id] then
    for _,callback in ipairs(manager.events[event][id]) do
      callback(data)
    end
  end
end

M.subscribe = function (event, id, callback)
  if not manager.events[event] then
    manager.events[event] = {}
  end
  if not manager.events[event][id] then
    manager.events[event][id] = {}
  end
  table.insert(manager.events[event][id], callback)
end

M.unsubscribe = function (event, id, callback)
  if manager.events[event] and manager.events[event][id] then
    local del = -1
    for i,c in ipairs(manager.events[event][id]) do
      if c == callback then
        del = i
      end
    end
    if del ~= -1 then
      table.remove(manager.events[event][id],del)
    end
  end
end

return M
