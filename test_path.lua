
H_COST = 1
V_COST = 2

CLIENT_MOVE = H_COST
ELEVATOR_MOVE = V_COST

local path = require("path")

-- Create a navigation graph

local addH = function(roomNum, floorNum)
  path.addEdge({
    floorNum = floorNum,
    roomNum = roomNum,
  }, {
    floorNum = floorNum,
    roomNum = roomNum + 1,
  }, H_COST)
  path.addEdge({
    floorNum = floorNum,
    roomNum = roomNum + 1,
  }, {
    floorNum = floorNum,
    roomNum = roomNum,
  }, H_COST)
end

local addV = function(roomNum, floorNum)
  path.addEdge({
    floorNum = floorNum,
    roomNum = roomNum,
  }, {
    floorNum = floorNum + 1,
    roomNum = roomNum,
  }, V_COST)
  path.addEdge({
    floorNum = floorNum + 1,
    roomNum = roomNum,
  }, {
    floorNum = floorNum,
    roomNum = roomNum,
  }, V_COST)
end

for floorNum = 1, 99 do
  for roomNum = 1, 6 do
    addH(roomNum, floorNum)
  end
  
  addV(1, floorNum)
  if floorNum % 2 > 0 then
    addV(3, floorNum)
  end
  if floorNum % 3 > 0 then
    addV(5, floorNum)
  end
  if floorNum % 4 > 0 then
    addV(7, floorNum)
  end
end

-- Find several paths using A* search

local start = os.clock()

for i = 1, 1000 do

  -- 1
  path.get({
    roomNum = 1,
    floorNum = 1,
  },
  {
    roomNum = 7,
    floorNum = 99,
  })
  
  -- 2
  path.get({
    roomNum = 7,
    floorNum = 50,
  },
  {
    roomNum = 3,
    floorNum = 97,
  })
  
  -- 3
  path.get({
    roomNum = 2,
    floorNum = 25,
  },
  {
    roomNum = 6,
    floorNum = 75,
  })
  
  -- 4
  path.get({
    roomNum = 7,
    floorNum = 15,
  },
  {
    roomNum = 7,
    floorNum = 85,
  })
  
  -- 5
  path.get({
    roomNum = 4,
    floorNum = 50,
  },
  {
    roomNum = 4,
    floorNum = 40,
  })
end

print(string.format("elapsed time: %.2f\n", os.clock() - start))
