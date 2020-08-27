
local event = require("event")
local luatexts = require("luatexts")
local room = require("room")
local staff = require("staff")
local transform = require("transform")

local vars

local M = {}

M.delete = function ()
  if love.filesystem.getInfo(FILE_SAVE) ~= nil then
    love.filesystem.remove(FILE_SAVE)
  end
end

M.load = function ()
  if love.filesystem.getInfo(FILE_SAVE) ~= nil then
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
    gTopFloor = gTopFloor + 1
    local newFloor = newFloor(gTopFloor)
  end
  conf.menu["floorUp"].desc = "$" .. thousandify(tostring(FLOOR_COSTS[gTopFloor + 1]))
  if gTopFloor >= 16 then
    conf.menu["floorUp"].desc = "MAXED"
  end

  gBottomFloor = 0
  for i=-1,vars.gBottomFloor,-1 do
    gBottomFloor = gBottomFloor - 1
    local newFloor = newFloor(gBottomFloor)
  end
  conf.menu["floorDown"].desc = "$" .. thousandify(tostring(FLOOR_COSTS[-gBottomFloor + 1] * 1.5))
  if gBottomFloor <= -8 then
    conf.menu["floorDown"].desc = "MAXED"
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
  gCounts = {
    fix = 0,
    rooms = {},
    spas = 0,
  }
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
