
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")
local room = require("room")

local M = {}

local bodyParts = {
  "nude",
  "bottom",
  "top",
  "hair",
  "hat",
}

local bodyAnimations = {
  idle = {
    first = 0,
    last = 0,
    speed = 1,
  },
  walking = {
    first = 1,
    last = 2,
    speed = .2,
  },
}

local hairAnimations = {}
for i = 1, 4 do
  hairAnimations[i] = {
    neat = {
      first = i - 1,
      last = i - 1,
      speed = 1,
    },
    messy = {
      first = i + 3,
      last = i + 3,
      speed = 1,
    },
  }
end

M.new = function (t)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, 50)
  isMale = math.random() < 0.5  --randomize male or female
  hairColour = math.random(1, 4)
  
  local prefix
  if isMale then
    prefix = "resources/img/people/man/"
  else
    prefix = "resources/img/people/woman/"
  end
  local spriteData = {
    width = 24, height = 24,
    originX = 8, originY = 24,
  }
  
  for _,part in ipairs(bodyParts) do
    if part ~= "hat" or math.random() < 0.125 then
      -- Pick a random image for this body part
      local dir = prefix .. part
      local images = love.filesystem.enumerate(dir)
      local fname = dir .. "/" .. images[math.random(1, #images)]
      
      -- Remove 'resources/' from the start of the filename for resource.get()
      fname = string.sub(fname, 10)
      
      -- Prepare the sprite data based on body part type
      spriteData.image = resource.get(fname)
      if part == "nude" or part == "bottom" then
        spriteData.animations = bodyAnimations
        spriteData.playing = "walking"
      elseif part == "hair" then
        spriteData.animations = hairAnimations[hairColour]
        spriteData.playing = "neat"
      else
       spriteData.animations = nil
       spriteData.playing = nil
      end
      
      -- Add the body part image as a sprite to the client
      entity.addComponent(id, sprite.new(id, spriteData))
    end
  end

  local pos = {roomNum = -.5, floorNum = GROUND_FLOOR}
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  local aiComponent = ai.new(id)
  if t and t.target then
    aiComponent:addFollowGoal(t.target)
  else
    event.notify("room.all", 0, function (id,type)
      local info = room.getInfo(id)
      if info.desirability then
        aiComponent:addVisitGoal(id)
      end
    end)
    event.subscribe("build", 0, function (t)
      local info = room.getInfo(t.id)
      if info.desirability then
        aiComponent:addVisitGoal(t.id)
      end
    end)
  end
  entity.addComponent(id, aiComponent)
  aiComponent:addExitGoal()
  aiComponent.horny = true
  
  local check = function (t)
    local epos = transform.getPos(id)
    if t.floorNum == epos.floorNum and t.roomNum < epos.roomNum + 0.5 and t.roomNum + t.width > epos.roomNum + 0.5 then
      t.callback(id)
    end
  end
  
  event.subscribe("actor.check", 0, check)

  local function delete (e)
    event.unsubscribe("actor.check", 0, check)
    event.unsubscribe("delete", id, delete)
  end

  event.subscribe("delete", id, delete)
  
  return id
end

local spawner = entity.new(STATE_PLAY)
local itime = math.random(SPAWN_MIN, SPAWN_MAX)
local com = entity.newComponent({
  timer = itime,
  target = nil,
  update = function (self, dt)
    if self.timer <= 0 then
      local spawnMin = SPAWN_MIN * SPAWN_FACTOR / (gReputation + 1)
      local spawnMax = SPAWN_MAX * SPAWN_FACTOR / (gReputation + 1)
      self.timer = math.random(spawnMin, spawnMax)
      self.target = M.new()
      M.new({
        target = self.target,
      })
    else
      self.timer = self.timer - dt
    end
  end,
})
entity.addComponent(spawner, com)

return M
