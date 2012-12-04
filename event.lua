-- event.lua

local M = {}

local manager = {
  events = {}
}

local notifyDepth = 0
local subscribeQueue = {}
local unsubscribeQueue = {}
-- local n = 0
-- local nid = {}
-- local nevent = {}

M.notify = function (event, id, data)
  if notifyDepth == 0 then
    for _,t in ipairs(subscribeQueue) do
      -- n = n + 1
      -- if not nid[t[2]] then
      --   nid[t[2]] = 0
      -- end
      -- nid[t[2]] = nid[t[2]] + 1
      -- if not nevent[t[1]] then
      --   nevent[t[1]] = 0
      -- end
      -- nevent[t[1]] = nevent[t[1]] + 1
      -- print(n, nid[t[2]], nevent[t[1]], "subscribe", t[1], t[2])
      table.insert(manager.events[t[1]][t[2]], t[3])
    end
    for _,t in ipairs(unsubscribeQueue) do
      if manager.events[t[1]] and manager.events[t[1]][t[2]] then
        local del = -1
        for i,c in ipairs(manager.events[t[1]][t[2]]) do
          if c == t[3] then
            del = i
          end
        end
        if del ~= -1 then
          -- n = n - 1
          -- nid[t[2]] = nid[t[2]] - 1
          -- nevent[t[1]] = nevent[t[1]] - 1
          -- print(n, nid[t[2]], nevent[t[1]], "unsubscribe", t[1], t[2])
          table.remove(manager.events[t[1]][t[2]],del)
        end
      end
    end
    subscribeQueue = {}
    unsubscribeQueue = {}
  end
  
  notifyDepth = notifyDepth + 1
  if manager.events[event] and manager.events[event][id] then
    for _,callback in ipairs(manager.events[event][id]) do
      if callback(data) then break end
    end
  end
  notifyDepth = notifyDepth - 1
end

M.subscribe = function (event, id, callback)
  if not manager.events[event] then
    manager.events[event] = {}
  end
  if not manager.events[event][id] then
    manager.events[event][id] = {}
  end
  table.insert(subscribeQueue, {event, id, callback})
end

M.unsubscribe = function (event, id, callback)
  table.insert(unsubscribeQueue, {event, id, callback})
end

return M
