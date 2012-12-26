-- path.lua
-- Interface between rest of game and the astar pathfinder

local SRC_LOC = 1
local DST_LOC = 2

require "astar_good"

local M = {}

local pathMap = { -- initial, special nodes
  { -- source
    pathLoc = SRC_LOC,
    neighbors = {},
    distance = {},
  },
  { -- destination
    pathLoc = DST_LOC,
    neighbors = {},
    distance = {},
  },
  { -- this and the next allow walking in from the left screen edge
    pathLoc = 3,
    hScore = 0,
    neighbors = {4},
    distance = {1/PERSON_MOVE},
    roomNum = -.5,
    floorNum = 0,
  },
  {
    pathLoc = 4,
    hScore = 0,
    neighbors = {3},
    distance = {1/PERSON_MOVE},
    roomNum = .5,
    floorNum = 0,
  },
}

local pos2loc = function (roomNum, floorNum)
  if floorNum == 0 then
    if roomNum == -.5 then
      return 3 
    elseif roomNum == .5 then
      return 4
    end
  elseif floorNum < 0 then floorNum = 100 - floorNum end
  -- Assumes roomNum is integer or integer + 1/2, floorNum is integer
  return math.floor(roomNum*2+.5) + 15*math.floor(floorNum+.5) + 4
end

M.addNode = function (pos)
  local pathLoc = pos2loc(pos.roomNum, pos.floorNum)
  local neighbors = {}
  local distance = {}

  -- Make neighbouring connections on same floor
  for roomNum = .5, 7, .5 do
    local other = pathMap[pos2loc(roomNum, pos.floorNum)]
    if other then
      -- same-floor neighbour
      local d = math.abs(roomNum - pos.roomNum) / PERSON_MOVE
      table.insert(neighbors, other.pathLoc)
      table.insert(distance, d)
      table.insert(other.neighbors, pathLoc)
      table.insert(other.distance, d)
    end
  end

  -- Make neighbouring connections above
  local above = pathMap[pos2loc(pos.roomNum, pos.floorNum + 1)]
  if above then
    table.insert(neighbors, above.pathLoc)
    table.insert(distance, 1/ELEVATOR_MOVE)
    table.insert(above.neighbors, pathLoc)
    table.insert(above.distance, 1/ELEVATOR_MOVE)
  end

  -- Make neighbouring connections below
  local below = pathMap[pos2loc(pos.roomNum, pos.floorNum - 1)]
  if below then
    table.insert(neighbors, below.pathLoc)
    table.insert(distance, 1/ELEVATOR_MOVE)
    table.insert(below.neighbors, pathLoc)
    table.insert(below.distance, 1/ELEVATOR_MOVE)
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
  local pathLoc = pos2loc(pos.roomNum, pos.floorNum)

  print("BEFORE")
  for i,j in pairs(pathMap) do
    for k,l in ipairs(j.neighbors) do
      print(string.format("%u -> %u", j.pathLoc, l))
    end
  end

  -- Remove neighbouring connections
  for i,neighbor in ipairs(pathMap[pathLoc].neighbors) do
    for j,v in ipairs(pathMap[neighbor].neighbors) do
      if v == pathLoc and v > 4 then
        table.remove(pathMap[neighbor].neighbors, j)
        table.remove(pathMap[neighbor].distance, j)
        break -- to outer loop of our neighbours
      end
    end
  end

  -- Remove node
  pathMap[pathLoc] = nil

  print("AFTER")
  for i,j in pairs(pathMap) do
    for k,l in ipairs(j.neighbors) do
      print(string.format("%u -> %u", j.pathLoc, l))
    end
  end
end

M.get = function (src, dst)
  -- Add src and dst nodes
  pathMap[SRC_LOC].roomNum = src.roomNum
  pathMap[SRC_LOC].floorNum = src.floorNum
  pathMap[DST_LOC].roomNum = dst.roomNum
  pathMap[DST_LOC].floorNum = dst.floorNum
  for roomNum = .5, 7, .5 do
    local src_n = pathMap[pos2loc(roomNum, src.floorNum)]
    if src_n then
      table.insert(pathMap[SRC_LOC].neighbors, src_n.pathLoc)
      table.insert(pathMap[SRC_LOC].distance, math.abs(src.roomNum - src_n.roomNum)/PERSON_MOVE)
    end
    local dst_n = pathMap[pos2loc(roomNum, dst.floorNum)]
    if dst_n then
      table.insert(dst_n.neighbors, DST_LOC)
      table.insert(dst_n.distance, math.abs(dst.roomNum - dst_n.roomNum)/PERSON_MOVE)
    end
  end

  -- Set heuristic scores
  for pathLoc, node in pairs(pathMap) do
    node.hScore = math.abs(node.roomNum - dst.roomNum)/PERSON_MOVE +
      math.abs(node.floorNum - dst.floorNum)/ELEVATOR_MOVE
  end

  local p, c = startPathing(pathMap, SRC_LOC, DST_LOC)

  -- Remove src and dst nodes
  pathMap[SRC_LOC].neighbors = {}
  pathMap[SRC_LOC].distance = {}
  for roomNum = .5, 7, .5 do
    local dst_n = pathMap[pos2loc(roomNum, dst.floorNum)]
    if dst_n then
      table.remove(dst_n.neighbors)
      table.remove(dst_n.distance)
    end
  end

  -- the path, or nil if no path found
  return p, c
end

M.getCost = function (src, dst)
  local path, cost = M.get(src, dst)
  if path then
    return cost
  end
  return -1
end

return M
