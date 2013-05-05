
local event = require("event")
local luatexts = require("luatexts")
local room = require("room")
local staff = require("staff")
local transform = require("transform")

local vars

local M = {}

M.delete = function ()
  if love.filesystem.exists(FILE_SAVE) then
    love.filesystem.remove(FILE_SAVE)
  end
end

M.load = function ()
  if love.filesystem.exists(FILE_SAVE) then
    local success, result = luatexts.load(
      love.filesystem.read(FILE_SAVE)
    )
    if success then
      vars = result
    else
      return false
    end
  else
    return false
  end

  gTopFloor = 0
  for i=1,vars.gTopFloor do
    floorUp()
  end
  gBottomFloor = 0
  for i=1,vars.gBottomFloor do
    floorDown()
  end
  gScrollPos = vars.gScrollPos
  event.notify("scroll", 0 , gScrollPos)
  gMoney = vars.gMoney
  gReputation = vars.gReputation
  gStars = vars.gStars
  gStarsBest = vars.gStarsBest
  for s,c in pairs(vars.gStaffTotals) do
    for i=1,c do
      staff.new(s)
    end
  end
  gCounts = vars.gCounts
  gClientsSeen = vars.gClientsSeen

  for _,t in ipairs(vars.rooms) do
    id = room.new(STATE_PLAY, t.id, t.pos)
    event.notify("build", 0, {id=id, pos=t.pos, type=t.id})
  end
  
  return true
end

M.save = function ()
  vars = {
    rooms = {},
  }

  vars.gTopFloor = gTopFloor
  vars.gBottomFloor = gBottomFloor
  vars.gScrollPos = gScrollPos
  vars.gMoney = gMoney
  vars.gReputation = gReputation
  vars.gStars = gStars
  vars.gStarsBest = gStarsBest
  vars.gStaffTotals = gStaffTotals
  vars.gCounts = gCounts
  vars.gClientsSeen = gClientsSeen

  event.notify("room.all", 0, function (roomId, id)
    if id == "elevator" or id == "reception" then
      return
    end
    local pos = transform.getPos(roomId)
    vars.rooms[#vars.rooms+1] = {
      id = id,
      pos = {
        roomNum = pos.roomNum,
        floorNum = pos.floorNum,
      },
    }
  end)
  
  love.filesystem.write(FILE_SAVE, luatexts.save(vars))
end

return M
