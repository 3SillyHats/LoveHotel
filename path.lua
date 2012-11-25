-- path.lua
-- A* pathfinding algorithm

M = {
  edges = {},
}

M.addEdge = function (src, dst, cost)
  if M.edges[src] == nil then
    M.edges[src] = {}
  end
  M.edges[src][dst] = cost
end

M.get = function (src, dst, heuristic)
  local spt = {}
  local sf = {}
  local costs = {}
  local pq = {}
  
  costs[src] = 0
  pq[1] = {0, src}
  while #pq > 0 do
    table.sort(pq, function(a,b)
      return a[1] > b[1]
    end)
    local next = table.remove(pq)
    local cost = next[1]
    local node = next[2]
    spt[node] = sf[node]
    
    if node == dst then
      local path = {dst}
      while path[1] ~= src do
        table.insert(path, 1, spt[path[1]])
      end
      return path
    end
    
    if M.edges[node] then
      for edst,ecost in pairs(M.edges[node]) do
        local newCost = costs[node] + ecost
        if heuristic then
          newCost = newCost + heuristic(edst, dst)
        end
        if sf[edst] == nil then
          costs[edst] = newCost
          table.insert(pq, {newCost,edst})
          sf[edst] = node
        elseif newCost < costs[edst] then
          costs[edst] = newCost
          for k,v in ipairs(pq) do
            if v[2] == edst then
              pq[k][1] = newCost
              break
            end
          end
          sf[edst] = node
        end
      end
    end
  end
end

return M
