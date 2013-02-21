
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")
local room = require("room")
local path = require("path")

local M = {}

local clients = {}
local leaders = {}
local followers = {}

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

local defaultPos = {roomNum = -1, floorNum = 0}
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

M.initialise = function (clientInfo, t)
  local isMale = math.random() < 0.5  --randomize male or female
  local hairColour = math.random(1, 4)
  local hatChance = 1
  
  local prefix
  if isMale then
    prefix = "resources/img/people/man/"
  else
    prefix = "resources/img/people/woman/"
  end
  local categoryPrefix = prefix .. t.category .. "/"
  if t.category == "poor" or t.category == "working" then
    hatChance = .125
  end

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
      clientInfo.sprite[part].image = resource.get(fname)
      clientInfo.sprite[part].frame = 0                       --XXX hair wont work properly like this
      if part == "nude" or part == "bottom" then
        clientInfo.sprite[part].playing = "walking"
      elseif part == "hair" then
        clientInfo.sprite[part].playing = "neat"
      else
       clientInfo.sprite[part].playing = nil
      end
    else
      clientInfo.sprite[part].image = nil
    end
  end

  clientInfo.ai.category = t.category
  clientInfo.ai.spent = 0
  clientInfo.ai.info = resource.get("scr/people/" .. t.category .. ".lua")
  clientInfo.ai.needs = {
    horniness = math.random(clientInfo.ai.info.minHorniness, clientInfo.ai.info.maxHorniness),
    hunger = math.random(clientInfo.ai.info.minHunger, clientInfo.ai.info.maxHunger),
  }
  clientInfo.ai.supply = math.random(clientInfo.ai.info.minSupply, clientInfo.ai.info.maxSupply)
  clientInfo.ai.money = math.random(clientInfo.ai.info.minMoney, clientInfo.ai.info.maxMoney)
  clientInfo.ai.patience = 100

  clientInfo.transform.pos = t.pos

  clientInfo.ai.alive = true
  
  
end

M.new = function (t)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, 50)
  
  local clientInfo = {
	id = id,
	sprite = {},
  }

  local spriteData = {
    width = 24, height = 24,
    originX = 8, originY = 24,
    image = resource.get("img/people/man/nude/white.png")
  }

  for _,part in ipairs(bodyParts) do
    
	if part == "nude" or part == "bottom" then
      spriteData.animations = bodyAnimations
    elseif part == "hair" then
	  spriteData.animations = hairAnimations[hairColour]
    else
     spriteData.animations = nil
    end
        
    -- Add the body part image as a sprite to the client
    local spriteCom = sprite.new(id, spriteData)
    entity.addComponent(id, spriteCom)
    clientInfo.sprite[part] = spriteCom

  end

  -- Add thought bubble sprite component if leader
  if t.leader then
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
      },
      playing = "thoughtNone",
    }))
  end

  clientInfo.transform = transform.new(
    id, t.pos, {x = 16, y = 30}
  )
  entity.addComponent(id, clientInfo.transform)
  local aiComponent = ai.new(id)
  clientInfo.ai = aiComponent
  aiComponent.leader = t.leader
  aiComponent.alive = false

  local addRoomGoal = function (roomId)
    local info = room.getInfo(roomId)
    if info.reception then
      aiComponent:addCheckInGoal(roomId)
    elseif info.condomSupplies then
      aiComponent:addCondomGoal(roomId)
    elseif info.foodSupplies then
      aiComponent:addSnackGoal(roomId)
    elseif info.id == "dining" then
      aiComponent:addOrderMealGoal(roomId)
    elseif info.id == "spa" then
      aiComponent:addSpaGoal(roomId)
    end
  end

  local onBuild = function (e)
    addRoomGoal(e.id)
  end
  if t and t.target then
    aiComponent:addFollowGoal(t.target, "client")
  else
    event.notify("room.all", 0, function (roomId,type)
      addRoomGoal(roomId)
    end)
    event.subscribe("build", 0, onBuild)
    aiComponent:addVisitGoal()
  end
  entity.addComponent(id, aiComponent)
  aiComponent:addExitGoal()

  local old_update = aiComponent.update
  aiComponent.update = function (self, dt)
    if aiComponent.alive then
      if not aiComponent.orderedMeal then
        aiComponent.needs.hunger = aiComponent.needs.hunger + dt
      end
      old_update(self, dt)
    end
  end

  local check = function (t)
    local epos = transform.getPos(id)
    if t.floorNum == epos.floorNum and t.roomNum < epos.roomNum + 0.5 and t.roomNum + t.width > epos.roomNum + 0.5 then
      t.callback(id)
    end
  end

  event.subscribe("actor.check", 0, check)

  local function delete (e)
    aiComponent.alive = false
  end

  event.subscribe("delete", id, delete)

  table.insert(clients, clientInfo)
  if t.leader then
    table.insert(leaders, clientInfo)
  else
    table.insert(followers, clientInfo)
  end

  return clientInfo
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
        for _,leader in ipairs(leaders) do
          if leader.ai.alive == false then
            M.initialise(leader, {
              category = category,
              pos = pos,
              leader = true,
            })
            self.target = leader.id
            break
          end
        end
        for _,follower in ipairs(followers) do
          if follower.ai.alive == false then
            M.initialise(follower, {
              target = self.target,
              category = category,
              pos = pos,
              leader = false,
            })
            break
          end
        end

      else
        self.timer = self.timer - dt
      end
    end,
  })
  entity.addComponent(spawner, com)
end
M.newSpawner(nil, {roomNum = -.5, floorNum = GROUND_FLOOR})

event.subscribe("floor.new", 0, function (level)
  if level == SKY_SPAWN then
    local pos = {roomNum = -.5, floorNum = SKY_SPAWN}
    M.newSpawner("sky", pos)
    path.addNode(pos)
  elseif level == GROUND_SPAWN then
    local pos = {roomNum = -.5, floorNum = GROUND_SPAWN}
    M.newSpawner("ground", pos)
    path.addNode(pos)
  elseif level == SPACE_SPAWN then
    local pos = {roomNum = -.5, floorNum = SPACE_SPAWN}
    M.newSpawner("space", pos)
    path.addNode(pos)
  end
end)

M.populate = function (num)
  for i = 1,num do
    M.new({
      leader = true,
      pos = defaultPos,
    })
    M.new({
      leader = false,
      pos = defaultPos,
    })    
  end
end

M.getAll = function ()
  return clients
end

M.getLeaders = function ()
  return leaders
end

return M
