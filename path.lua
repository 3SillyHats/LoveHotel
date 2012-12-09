-- path.lua
-- A* pathfinding algorithm

M = {
  edges = {},
  costs = {},
  last = nil,
}

local serialize = function (t)
  -- Assumes roomNum is integer or integer + 1/2, floorNum is integer
  return math.floor((t.roomNum+.25)*2)/2 .. ","
      .. math.floor((t.floorNum+.5))
end

M.addEdge = function (src, dst, cost)
  local s_src = serialize(src)
  local s_dst = serialize(dst)
  if M.edges[s_src] == nil then
    M.edges[s_src] = {}
  end
  M.edges[s_src][s_dst] = {
    cost = cost,
    src = src,
    dst = dst,
  }
  M.costs = {}
  M.last = nil
end

M.removeEdges = function (src)
  local s_src = serialize(src)
  if M.edges[s_src] then
    for s_dst,_ in pairs(M.edges[s_src]) do
      M.edges[s_src][s_dst] = nil
      M.edges[s_dst][s_src] = nil
    end
  end
  M.costs = {}
  M.last = nil
end

M.removeEdge = function (src, dst)
  local s_src = serialize(src)
  local s_dst = serialize(dst)
  if M.edges[s_src] then
    M.edges[s_src][s_dst] = nil
  end
  M.costs = {}
  M.last = nil
end

M.get = function (src, dst, heuristic)
  local s_src = serialize(src)
  local s_dst = serialize(dst)
  
  if M.prev and M.prev.src == s_src and M.prev.dst == s_dst then
    return M.prev.path
  end

  local spt = {}
  local sf = {}
  local costs = {}
  local pq = {}
  
  costs[s_src] = 0
  pq[1] = {0, s_src, src}
  while #pq > 0 do
    table.sort(pq, function(a,b)
      return a[1] > b[1]
    end)
    local next = table.remove(pq)
    local cost = next[1]
    local node = next[2]
    local node_pos = next[3]
    if sf[node] then
      spt[node] = sf[node][2]
    end
    
    if node == s_dst then
      local path = {dst}
      while serialize(path[1]) ~= s_src do
        table.insert(path, 1, spt[serialize(path[1])])
      end
      path.cost = costs[s_dst]
      M.prev = {
        src = s_src,
        dst = s_dst,
        path = path,
      }
      return path
    end
    
    if M.edges[node] then
      for edst,edata in pairs(M.edges[node]) do
        local ecost = edata.cost
        local newCost = costs[node] + ecost
        if heuristic then
          newCost = newCost + heuristic(edst, s_dst)
        end
        if sf[edst] == nil then
          costs[edst] = newCost
          table.insert(pq, {newCost,edst,edata.dst})
          sf[edst] = {node, node_pos}
        elseif newCost < costs[edst] then
          costs[edst] = newCost
          for k,v in ipairs(pq) do
            if v[2] == edst then
              pq[k][1] = newCost
              break
            end
          end
          sf[edst] = {node, node_pos}
        end
      end
    end
  end
  
  M.prev = {
    src = s_src,
    dst = s_dst,
    path = nil,
  }
  return nil
end

M.getCost = function (src, dst)
  local s_src = serialize(src)
  local s_dst = serialize(dst)
  
  if M.costs[s_src] and M.costs[s_src][s_dst] then
    return M.costs[s_src][s_dst]
  end
  
  local p = M.get(src, dst)
  local cost = -1
  if p then
    cost = p.cost
  end
  if not M.costs[s_src] then
    M.costs[s_src] = {}
  end
  M.costs[s_src][s_dst] = cost
  return cost
end

return M
