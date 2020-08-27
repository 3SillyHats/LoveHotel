
local luatexts = require("luatexts")
local event = require("event")

-- Define constants
local ACHIEVEMENTS = {
  {
    name = "Utilitarian Love",
    desc = "Made a couple stay in a utility room.",
  },
  {
    name = "Buried Pleasure",
    desc = "Dug up buried treasure.",
  },
  {
    name = "Working Up A Debt",
    desc = "Went into debt.",
  },
  {
    name = "Electrical Dysfunction",
    desc = "Had two machines being fixed at once.",
  },
  {
    name = "The Full Monty",
    desc = "Had at least one of each suite.",
  },
  {
    name = "Going Down",
    desc = "Got an astronaut down to hell.",
  },
  {
    name = "Frisky Business",
    desc = "Had $999,999 in the bank.",
  },
  {
    name = "Full Contact Spa-ing",
    desc = "Had three couples in spas at once.",
  },
  {
    name = "Mile High Club",
    desc = "Reached the Skyfarers.",
  },
  {
    name = "Feeling Horny",
    desc = "Reached the Devilspawn.",
  },
  {
    name = "Business Is Mooning",
    desc = "Reached the Astronauts.",
  },
  {
    name = "Sex Star Hotel",
    desc = "Built a 6 star hotel.",
  },
}

local achieved = {}

local M = {}

M.CLOSET = 1
M.TREASURE = 2
M.DEBT = 3
M.FIX = 4
M.SUITES = 5
M.DOWN = 6
M.BANK = 7
M.SPA = 8
M.SKY = 9
M.GROUND = 10
M.SPACE = 11
M.SIXSTARS = 12

M.achieve = function (id)
  if achieved[id] ~= true then
    achieved[id] = true
    alert("achieve")
  end
end

M.getInfo = function (id)
  return ACHIEVEMENTS[id]
end

M.isDone = function (id)
  return achieved[id]
end

M.save = function ()
  love.filesystem.write(FILE_ACHIEVEMENTS, luatexts.save(achieved))
end

-- Load achievements form filesystem
if love.filesystem.getInfo(FILE_ACHIEVEMENTS) ~= nil then
  local success, result = luatexts.load(
    love.filesystem.read(FILE_ACHIEVEMENTS)
  )
  if success then
    achieved = result
  end
end

-- Setup specific achievement handlers
event.subscribe("floor.new", 0, function (level)
  if level == SKY_SPAWN then
    M.achieve(M.SKY)
  elseif level == GROUND_SPAWN then
    M.achieve(M.GROUND)
  elseif level == SPACE_SPAWN then
    M.achieve(M.SPACE)
  elseif level == TREASURE_LEVEL then -- treasure chest
    M.achieve(M.TREASURE)
  end
end)
event.subscribe("win", 0, function ()
  M.achieve(M.SIXSTARS)
end)

return M
