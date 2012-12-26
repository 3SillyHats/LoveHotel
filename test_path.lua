
PERSON_MOVE = 1
ELEVATOR_MOVE = 2

local path = require("path")

-- Create a navigation graph

for floorNum = 1, 100 do
  path.addNode({ roomNum = 1, floorNum = floorNum })
  if floorNum % 2 > 0 then
    path.addNode({ roomNum = 3, floorNum = floorNum })
  end
  if floorNum % 3 > 0 then
    path.addNode({ roomNum = 5, floorNum = floorNum })
  end
  if floorNum % 4 > 0 then
    path.addNode({ roomNum = 7, floorNum = floorNum })
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
    roomNum = 1,
    floorNum = 25,
  },
  {
    roomNum = 5,
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
    roomNum = 5,
    floorNum = 50,
  },
  {
    roomNum = 5,
    floorNum = 40,
  })
end

print(string.format("elapsed time: %.2f\n", os.clock() - start))
