
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")
local room = require("room")

local M = {}

local clients = {}

local categories = {}
local totalChance = {0, 0, 0, 0, 0}
local files = love.filesystem.enumerate("data/scr/people/")
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

local thoughtAnimations = {
  thoughtNone = {
    first = 0,
    last = 0,
    speed = 1,
  },
  thoughtBroke = {
    frames = {1, 3},
    speed = 1,
  },
  thoughtLove = {
    frames = {1, 4},
    speed = 1,
  },
  thoughtHungryGood = {
    frames = {1, 5},
    speed = 1,
  },
  thoughtHungryBad = {
    frames = {2, 6},
    speed = 1,
  },
  thoughtCondomlessGood = {
    frames = {1, 7},
    speed = 1,
  },
  thoughtCondomlessBad = {
    frames = {2, 8},
    speed = 1,
  },
  thoughtImpatient = {
    frames = {2, 9},
    speed = 1,
  },
  thoughtRoomless = {
    frames = {2, 10},
    speed = 1,
  },
}

local addSprites = function (id, category, offset)
  local isMale = math.random() < 0.5  --randomize male or female
  local hairColour = math.random(1, 4)
  local hatChance = 1

  local prefix
  if isMale then
    prefix = "data/img/people/man/"
  else
    prefix = "data/img/people/woman/"
  end
  local categoryPrefix = prefix .. category .. "/"
  if category == "poor" or category == "working" then
    hatChance = .125
  end
  local spriteData = {
    width = 24, height = 24,
    originX = offset,
    originY = 24,
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

      -- Remove 'data/' from the start of the filename for resource.get()
      fname = string.sub(fname, 5)

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
end

M.new = function (t)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, 50)
  
  -- Create leader and follower sprites
  addSprites(id, t.category, 4)
  addSprites(id, t.category, 12)

  -- Add thought bubble sprite
  entity.addComponent(id, sprite.new(id, {
    image = resource.get("img/people/bubbles.png"),
    width = 16,
    height = 8,
    originY = 24,
    animations = thoughtAnimations,
    playing = "thoughtNone",
  }))

  local pos = {
    roomNum = t.pos.roomNum,
    floorNum = t.pos.floorNum,
  }
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  
  local info = resource.get("scr/people/" .. t.category .. ".lua")
  
  local aiComponent = ai.newClient(id, info)
  entity.addComponent(id, aiComponent)
  aiComponent.class = t.category
  aiComponent.moveRoom = 1
  aiComponent.moveFloor = pos.floorNum
  aiComponent:push("moveTo")

  local check = function (t)
    local epos = transform.getPos(id)
    if t.floorNum == epos.floorNum and t.roomNum < epos.roomNum + 0.5 and t.roomNum + t.width > epos.roomNum + 0.5 then
      t.callback(id)
    end
  end

  event.subscribe("actor.check", 0, check)

  local function delete (e)
    for k,v in ipairs(clients) do
      if v.id == id then
        table.remove(clients, k)
        break
      end
    end
    old_update = nil
    event.unsubscribe("build", 0, onBuild)
    event.unsubscribe("actor.check", 0, check)
    event.unsubscribe("delete", id, delete)
  end

  event.subscribe("delete", id, delete)

  table.insert(clients, {
    id = id,
    ai = aiComponent,
  })

  return id
end

-- SPAWNER
local getRandomCategory = function ()
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

  return category
end

M.newSpawner = function (type, pos)
  local spawner = entity.new(STATE_PLAY)
  local itime = SPAWN_MIN
  
  event.subscribe("reset", 0, function ()
    entity.delete(spawner)
  end)

  local com = entity.newComponent({
    timer = itime,
    target = nil,
    update = function (self, dt)
      if self.timer <= 0 then
        local category
        if type then
          category = type
        else
          category = getRandomCategory()
        end

        local spawnAdjust = SPAWN_FACTOR * gStars
        if type then
          spawnAdjust = 0
        end
        local spawnMin = SPAWN_MIN - spawnAdjust
        local spawnMax = SPAWN_MAX - spawnAdjust
        self.timer = math.random(spawnMin, spawnMax)
        self.target = M.new({
          category = category,
          pos = pos,
        })
      else
        self.timer = self.timer - dt
      end
    end,
  })
  entity.addComponent(spawner, com)
  
  event.notify("newSpawner", 0, type)
end

M.newSpawner(nil, {roomNum = -1, floorNum = GROUND_FLOOR})

event.subscribe("floor.new", 0, function (level)
  local pos
  if level == SKY_SPAWN then
    pos = {roomNum = -1, floorNum = SKY_SPAWN}
    M.newSpawner("sky", pos)
  elseif level == GROUND_SPAWN then
    pos = {roomNum = -1, floorNum = GROUND_SPAWN}
    M.newSpawner("ground", pos)
  elseif level == SPACE_SPAWN then
    pos = {roomNum = -1, floorNum = SPACE_SPAWN}
    M.newSpawner("space", pos)
  end
  
  if pos then
    local pos2 = {
      roomNum = 4,
      floorNum = pos.floorNum,
    }
    room.new(STATE_PLAY, "reception", pos2)
    event.notify("build", 0, {id=id, pos=pos2, type="reception"})
  end
end)

M.getAll = function ()
  return clients
end

return M
