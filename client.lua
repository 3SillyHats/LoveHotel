
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")
local room = require("room")

local M = {}

local categories = {}
local totalChance = {0, 0, 0, 0, 0}
local files = love.filesystem.enumerate("resources/scr/people/")
for _, fname in ipairs(files) do
  local info = resource.get("scr/people/" .. fname)
  table.insert(categories, info.name)
  for i,c in ipairs(info.spawnChance) do
    totalChance[i] = totalChance[i] + c
  end
end

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
  local isMale = math.random() < 0.5  --randomize male or female
  local hairColour = math.random(1, 4)
  local hatChance = .125
  
  local prefix
  if isMale then
    prefix = "resources/img/people/man/"
  else
    prefix = "resources/img/people/woman/"
  end
  local categoryPrefix = prefix .. t.category .. "/"
  if t.category == "rich" then
    hatChance = 1
  end
  local spriteData = {
    width = 24, height = 24,
    originX = 8, originY = 24,
  }
  
  for _,part in ipairs(bodyParts) do
    -- Everything but nude and hair parts are category-specific
    local dir
    if part == "nude" or part == "hair" then
      dir = prefix .. part
    else
      dir = categoryPrefix .. part
    end
    local images = love.filesystem.enumerate(dir)

    -- Skip part if no images exist, and only give a chance of a hat
    if #images > 0 and 
        (part ~= "hat" or math.random() < hatChance) then
      -- Pick a random image for this body part
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
  
  -- Add thought bubble sprite component
  entity.addComponent(id, sprite.new(id, {
    image = resource.get("img/people/bubbles.png"),
    width = 16,
    height = 8,
    originY = 24,
    animations = {
      thoughtNone = {
        first = 0,
        last = 0,
        speed = 1,
      },
      thoughtHappy = {
        first = 1,
        last = 1,
        speed = 1,
      },
      thoughtBroke = {
        first = 2,
        last = 2,
        speed = 1,
      },
      thoughtHungry = {
        first = 3,
        last = 3,
        speed = 1,
      },
      thoughtCondomless = {
        first = 4,
        last = 4,
        speed = 1,
      },
      thoughtRoomless = {
        first = 5,
        last = 5,
        speed = 1,
      },
    },
    playing = "thoughtNone",
  }))

  local pos = {roomNum = -.5, floorNum = GROUND_FLOOR}
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  local aiComponent = ai.new(id)
  aiComponent.leader = t.leader
  
  local addRoomGoal = function (id)
    local info = room.getInfo(id)
    if info.desirability then
      aiComponent:addVisitGoal(id)
    elseif info.reception then
      aiComponent:addCheckInGoal(id)
    elseif info.condomSupplies then
      aiComponent:addCondomGoal(id)
    elseif info.foodSupplies then
      aiComponent:addFoodGoal(id)
    end
  end
  
  if t and t.target then
    aiComponent:addFollowGoal(t.target, "client")
  else
    event.notify("room.all", 0, function (id,type)
      addRoomGoal(id)
    end)
    event.subscribe("build", 0, function (e)
      addRoomGoal(e.id)
    end)
  end
  entity.addComponent(id, aiComponent)
  aiComponent:addExitGoal()
  
  local info = resource.get("scr/people/" .. t.category .. ".lua")
  aiComponent.needs = {
    horniness = math.random(info.minHorniness, info.maxHorniness),
    hunger = math.random(info.minHunger, info.maxHunger),
  }
  aiComponent.supply = math.random(info.minSupply, info.maxSupply)
  aiComponent.money = math.random(info.minMoney, info.maxMoney)

  local old_update = aiComponent.update
  aiComponent.update = function (self, dt)
    aiComponent.needs.hunger = aiComponent.needs.hunger + dt
    old_update(self, dt)
  end
  
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
      local category
      local c = math.random() * totalChance[gStars]

      for _,cat in ipairs(categories) do
        local info = resource.get("scr/people/" .. cat .. ".lua")
        if c < info.spawnChance[gStars] then
          category = cat
          break
        else
          c = c - info.spawnChance[gStars]
        end
      end
      
      local spawnMin = SPAWN_MIN * (3 / (2 + gStars))
      local spawnMax = SPAWN_MAX * (3 / (2 + gStars))
      self.timer = math.random(spawnMin, spawnMax)
      self.target = M.new({
        category = category,
        leader = true,
      })
      M.new({
        target = self.target,
        category = category,
        leader = false,
      })
    else
      self.timer = self.timer - dt
    end
  end,
})
entity.addComponent(spawner, com)

return M
