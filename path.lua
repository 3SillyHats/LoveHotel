-- path.lua
-- A* pathfinding algorithm

M = {
  nodes = {},
  edges = {},
  costs = {},
  last = nil,
}

local serialize = function (f,r)
  return f .. "," .. r
end

M.addNode = function (node)
  local r = math.floor((node.roomNum+.5))
  local f = math.floor((node.floorNum+.5))
  
  if M.nodes[f] == nil then
    M.nodes[f] = {}
  end
  if M.nodes[f][r] ~= nil then
    error("E: Node already exists")
  end
  M.nodes[f][r] = {}
  
  M.addEdge(node, {roomNum = r, floorNum = f + 1}, 1/ELEVATOR_MOVE)
  M.addEdge(node, {roomNum = r, floorNum = f - 1}, 1/ELEVATOR_MOVE)
  for dst,_ in pairs(M.nodes[f]) do
    if dst ~= r then
      M.addEdge(node, {roomNum = dst, floorNum = f}, math.abs(r - dst)/CLIENT_MOVE)
    end
  end
end

M.addEdge = function (src, dst, cost)
  local f_src = math.floor((src.floorNum+.5))
  local r_src = math.floor((src.roomNum+.5))
  local s_src = serialize(f_src, r_src)
  local f_dst = math.floor((dst.floorNum+.5))
  local r_dst = math.floor((dst.roomNum+.5))
  local s_dst = serialize(f_dst, r_dst)
  if M.nodes[f_src] == nil or M.nodes[f_src][r_src] == nil then
    return
    --error("E: Source node does not exist")
  end
  if M.nodes[f_dst] == nil or M.nodes[f_dst][r_dst] == nil then
    return
    --error("E: Destination node does not exist")
  end
  M.nodes[f_src][r_src][s_dst] = cost
  M.nodes[f_dst][r_dst][s_src] = cost
  
  if M.edges[s_src] == nil then
    M.edges[s_src] = {}
  end
  M.edges[s_src][s_dst] = {
    cost = cost,
    src = {roomNum = r_src, floorNum = f_src},
    dst = {roomNum = r_dst, floorNum = f_dst},
  }
  if M.edges[s_dst] == nil then
    M.edges[s_dst] = {}
  end
  M.edges[s_dst][s_src] = {
    cost = cost,
    src = {roomNum = r_dst, floorNum = f_dst},
    dst = {roomNum = r_src, floorNum = f_src},
  }
  
  M.costs = {}
  M.last = nil
end

M.removeNode = function (src)
  local f_src = math.floor((src.floorNum+.5))
  local r_src = math.floor((src.roomNum+.5))
  local s_src = serialize(f_src, r_src)
  if M.nodes[f_src] and M.nodes[f_src][r_src] then
    for s_dst,e in pairs(M.edges[s_src][r_src]) do
      local f_dst = e.dst.floorNum
      local r_dst = e.dst.roomNum
      M.nodes[f_dst][r_dst][s_src] = nil
      M.edges[s_dst][s_src] = nil
    end
  end
  M.edges[f_src][r_src] = nil
  M.edges[s_src] = nil
  M.costs = {}
  M.last = nil
end

M.removeEdge = function (src, dst)
  local f_src = math.floor((src.floorNum+.5))
  local r_src = math.floor((src.roomNum+.5))
  local s_src = serialize(f_src, r_src)
  local f_dst = math.floor((dst.floorNum+.5))
  local r_dst = math.floor((dst.roomNum+.5))
  local s_dst = serialize(f_dst, r_dst)
  if M.nodes[f_src] and
      M.nodes[f_src][r_src] and
      M.nodes[f_src][r_src][f_dst] then
    M.nodes[f_src][r_src][f_dst][r_dst] = nil
  end
  if M.nodes[f_dst] and
      M.nodes[f_dst][r_dst] and
      M.nodes[f_dst][r_dst][f_src] then
    M.nodes[f_dst][r_dst][f_src][r_src] = nil
  end
  M.edges[s_dst][s_src] = nil
  M.edges[s_src][s_dst] = nil
  
  M.costs = {}
  M.last = nil
end

M.get = function (src, dst)
  local f_src = math.floor((src.floorNum+.5))
  local f_dst = math.floor((dst.floorNum+.5))
  
  if f_src == f_dst then
    return {
      {roomNum = src.roomNum, floorNum = f_src},
      {roomNum = dst.roomNum, floorNum = f_src},
      cost = math.abs(dst.roomNum - src.roomNum),
    }
  end
  
  if M.prev and M.prev.src.roomNum == src.roomNum and M.prev.src.floorNum == src.floorNum and
      M.prev.dst.roomNum == dst.roomNum and M.prev.dst.floorNum == dst.floorNum then
    return M.prev.path
  end

  local spt = {}
  local sf = {}
  local costs = {}
  local pq = {}
  
  costs[f_src] = {}
  if not M.nodes[f_src] then
    return nil
  end
  for r,_ in pairs(M.nodes[f_src]) do
    local s = serialize(f_src,r)
    costs[s] = math.abs(r - src.roomNum)/CLIENT_MOVE
    table.insert(pq, {costs[s], serialize(f_src, r), f_src, r})
  end
  
  while #pq > 0 do
    table.sort(pq, function(a,b)
      return a[1] > b[1]
    end)
    local next = table.remove(pq)
    local cost = next[1]
    local s = next[2]
    local f = next[3]
    local r = next[4]
    if sf[s] then
      spt[s] = sf[s]
    end
    
    if f == f_dst then
      local path = {
        {roomNum = r, floorNum = f_dst},
        {roomNum = dst.roomNum, floorNum = f_dst},
      }
      while path[1].floorNum ~= f_src do
        table.insert(path, 1, spt[serialize(path[1].floorNum, path[1].roomNum)])
      end
      path.cost = costs[s] + math.abs(r-dst.roomNum)/CLIENT_MOVE
      M.prev = {
        src = src,
        dst = dst,
        path = path,
      }
      return path
    end
    
    if M.edges[s] then
      for edst,edata in pairs(M.edges[s]) do
        local newCost = costs[s] + edata.cost
        local adjustedCost = newCost + math.abs(edata.dst.roomNum - dst.roomNum) / CLIENT_MOVE + math.abs(edata.dst.floorNum - dst.floorNum) / ELEVATOR_MOVE
        if sf[edst] == nil then
          costs[edst] = newCost
          table.insert(pq, {newCost,edst,edata.dst.floorNum,edata.dst.roomNum})
          sf[edst] = {roomNum = edata.src.roomNum, floorNum = edata.src.floorNum}
        elseif newCost < costs[edst] then
          costs[edst] = newCost
          for k,v in ipairs(pq) do
            if v[2] == edst then
              pq[k][1] = newCost
              break
            end
          end
          sf[edst] = {roomNum = edata.src.roomNum, floorNum = edata.src.floorNum}
        end
      end
    end
  end
  
  M.prev = {
    src = src,
    dst = dst,
    path = nil,
  }
  return nil
end

M.getCost = function (src, dst)
  --local s_src = serialize(src)
  --local s_dst = serialize(dst)
  
  --if M.costs[s_src] and M.costs[s_src][s_dst] then
    --return M.costs[s_src][s_dst]
  --end
  
  local p = M.get(src, dst)
  local cost = -1
  if p then
    cost = p.cost
  end
  --if not M.costs[s_src] then
    --M.costs[s_src] = {}
  --end
  --M.costs[s_src][s_dst] = cost
  return cost
end

return M
