-- path.lua
-- A* pathfinding algorithm

M = {
  edges = {},
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
end

M.removeEdges = function (src)
  local s_src = serialize(src)
  if M.edges[s_src] then
    for s_dst,_ in pairs(M.edges[s_src]) do
      M.edges[s_src][s_dst] = nil
      M.edges[s_dst][s_src] = nil
    end
  end
end

M.removeEdge = function (src, dst)
  local s_src = serialize(src)
  local s_dst = serialize(dst)
  if M.edges[s_src] then
    M.edges[s_src][s_dst] = nil
  end
end

M.get = function (src, dst, heuristic)
  local s_src = serialize(src)
  local s_dst = serialize(dst)

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
end

return M
