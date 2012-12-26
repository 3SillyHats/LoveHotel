-- path.lua
-- Interface between rest of game and the astar pathfinder

require "astar_good"

M = {}

local pathMap = {}

local pos2loc = function (roomNum, floorNum)
  -- Assumes roomNum is integer or integer + 1/2, floorNum is integer
  return math.floor(roomNum*2+.5) + 14*math.floor(floorNum+.5) + 2
end

M.addNode = function (pos)
  local pathLoc = pos2loc(pos.roomNum, pos.floorNum)
  local neighbors = {}
  local distance = {}

  -- Make neighbouring connections on same floor
  for roomNum = 1, 14 do
    local other = pathMap[pos2loc(roomNum, pos.floorNum)]
    if other then
      -- same-floor neighbour
      local d = math.abs((roomNum-pos.roomNum)/2) * PERSON_MOVE
      table.insert(neighbors, other.pathLoc)
      table.insert(distance, d)
      table.insert(other.neighbors, pathLoc)
      table.insert(other.distance, d)
    end
  end

  -- Make neighbouring connections above
  local above = pathMap[pos2loc(pos.floorNum, pos.floorNum + 1)]
  if above then
    table.insert(neighbors, above.pathLoc)
    table.insert(distance, ELEVATOR_MOVE)
    table.insert(above.neighbors, pathLoc)
    table.insert(above.distance, ELEVATOR_MOVE)
  end

  -- Make neighbouring connections below
  local below = pathMap[pos2loc(pos.floorNum, pos.floorNum - 1)]
  if below then
    table.insert(neighbors, below.pathLoc)
    table.insert(distance, ELEVATOR_MOVE)
    table.insert(below.neighbors, pathLoc)
    table.insert(below.distance, ELEVATOR_MOVE)
  end

  -- Add new node
  local node = newNode(
    pathLoc, -- path index
    0, -- heuristic score
    neighbors, -- neighbors
    distance -- neighbour distances
  )
  node.roomNum = pos.roomNum
  node.floorNum = pos.floorNum
  pathMap[node.pathLoc] = node
end

M.removeNode = function (pos)
  
end

M.get = function (src, dst)
  local src_loc = pos2loc(src.roomNum, src.floorNum)
  local dst_loc = pos2loc(dst.roomNum, dst.floorNum)

  -- Set heuristic scores
  for pathLoc, node in pairs(pathMap) do
    node.hScore = math.abs(node.roomNum - dst.roomNum)*PERSON_MOVE +
      math.abs(node.floorNum - dst.floorNum)*ELEVATOR_MOVE
  end

  local p = startPathing(pathMap, src_loc, dst_loc)

  -- the path, or nil if no path found
  return p
end

M.getCost = function (src, dst)
  local p = M.get(src, dst)
  if p and #p > 1 then
    local d = 0
    for i = 1, #p - 1 do
      d = d + p[i].distance[p[i+1]]
    end
    return d
  end
  return -1
end

return M
