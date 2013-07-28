-- main.lua

-- Constants
CANVAS_WIDTH = 256
CANVAS_HEIGHT = 224
ROOM_INDENT = 32*0.5
FLOOR_OFFSET = 32*2.5
GROUND_FLOOR = 0

FILE_SETTINGS = "settings"
FILE_ACHIEVEMENTS = "achievements"
FILE_SAVE = "save"

STATE_TRAIN = 1
STATE_PLAY = 2
STATE_PAUSE = 3
STATE_DECISION = 4
STATE_WIN = 5
STATE_START = 6
STATE_ACHIEVMENTS = 7
STATE_LOSE = 8
STATE_CREDITS = 9
STATE_HELP = 10

PERSON_SPEED = 1
ELEVATOR_SPEED = 1.2

UPKEEP_PERIOD = 60

PAY_PERIOD = 60
BELLHOP_WAGE = 50
CLEANER_WAGE = 80
MAINTENANCE_WAGE = 200
COOK_WAGE = 500
STOCKER_WAGE = 100
STAFF_MAX = {
  bellhop = 20,
  cleaner = 10,
  maintenance = 5,
  cook = 5,
  stocker = 5,
}

SEX_HORNINESS = 20

SEX_TIME = 16
CHECKIN_TIME = 0.5
CLEAN_TIME = 8
SUPPLY_TIME = 2
EAT_TIME = 4
FIX_TIME = 8
COOK_TIME = 16
RESTOCK_TIME = 4
BROKE_TIME = 30

CLIENTS = {
  "poor",
  "working",
  "rich",
  "sky",
  "ground",
  "space"
}
SPAWN_MIN = 20
SPAWN_MAX = 30
SPAWN_FACTOR = 3
SKY_SPAWN = 8
GROUND_SPAWN = -8
SPACE_SPAWN = 16
TREASURE_LEVEL = -5

FLOOR_COSTS = {
  1000,
  2000,
  3000,
  4000,
  5000,
  6000,
  7000,
  8000, -- 8th floor
  9000,
  10000,
  11000,
  12000,
  13000,
  14000,
  15000,
  16000, -- 16th floor
}

MONEY_INITIAL = FLOOR_COSTS[1] + BELLHOP_WAGE + CLEANER_WAGE + 20000
MONEY_MAX = 999999
REP_INITIAL = 25
REP_MAX = 20000
STARS_INITIAL = 1
STARS_MAX = 5
REP_THRESHOLDS = {
  0,
  100,
  500,
  2000,
  5000,
  20000,
}

local luatexts = require("luatexts")
local achievement = require("achievement")
local event = require("event")
local entity = require("entity")
local input = require("input")
local resource = require("resource")
local sprite = require ("sprite")
local room = require("room")
local menu = require("menu")
local ai = require("ai")
local builder = require("builder")
local demolisher = require("demolisher")
local stocker = require("stocker")
local inspector = require("inspector")
local staffer = require("staffer")
local staff = require("staff")
local client = require("client")
local transform = require("transform")
local decision = require("decision")
local save = require("save")

local thousandify = function (str)
  if (str:sub(1, 1) == "-" and str:len() > 4) or
      (str:sub(1, 1) ~= "-" and str:len() > 3) then
    str = str:sub(1, -4) .. "," .. str:sub(-3, -1)
  end
  return str
end

conf = {
  menu = {
    -- Main menu
    suites =  {
      name="Rooms",
      desc=""
    },
    infrastructure =  {
      name="Structure",
      desc=""
    },
    food = {
      name="Food",
      desc=""
    },
    services = {
      name="Services",
      desc="",
    },
    staff = {
      name="Staff",
      desc="",
    },
    stock = {
      name="Restock",
      desc="",
    },
    inspect = {
      name="Inspect",
      desc="",
    },
    locked = {
      name="Earn more",
      desc="stars!"
    },

    -- Structure
    floorUp =  {
      name="Skyward",
      desc="$" .. thousandify(tostring(FLOOR_COSTS[1])),
    },
    floorDown =  {
      name="Underground",
      desc="$" .. thousandify(tostring(FLOOR_COSTS[1]*2)),
    },
    destroy =  {
      name="Destroy",
      desc=""
    },

    -- Staff
    cleaner = {
      name="Cleaner",
      desc="$" .. CLEANER_WAGE .. "/min",
    },
    bellhop = {
      name="Bellhop",
      desc="$" .. BELLHOP_WAGE .. "/min",
    },
    cook = {
      name="Cook",
      desc="$" .. COOK_WAGE .. "/min",
    },
    maintenance = {
      name="Maintenance",
      desc="$" .. MAINTENANCE_WAGE .. "/min",
    },
    stocker = {
      name="Stocker",
      desc="$" .. STOCKER_WAGE .. "/min",
    },
  },
}

gTopFloor = GROUND_FLOOR
gBottomFloor = GROUND_FLOOR
gScrollPos = GROUND_FLOOR
gScrollable = true
gRoomNum = 1
event.subscribe("scroll", 0, function (scrollPos)
  gScrollPos = scrollPos
end)
gState = STATE_START
event.subscribe("state.enter", 0, function (state)
  gState = state
end)
gGameSpeed = 1
gMoney = MONEY_INITIAL
gReputation = REP_INITIAL
gStars = STARS_INITIAL
gStarsBest = STARS_INITIAL - 1
gStaffTotals = {
  bellhop = 0,
  cleaner = 0,
  maintenance = 0,
  cook = 0,
  stocker = 0,
}
gCounts = {
  fix = 0,
  rooms = {},
  spas = 0,
}
gClientsSeen = {
  poor = true,
  working = true,
  rich = true,
}
gShowHelp = true

event.subscribe("newSpawner", 0, function (type)
  if type ~= nil then
    gClientsSeen[type] = true
  end
end)

local alertEntity = entity.new(STATE_PLAY)
entity.setOrder(alertEntity, 110)
local alertCom = entity.newComponent({
  alert = nil,
  arg = nil,
  messages = {
    achieve = "Achievement unlocked",
    broke = "Out of money - staff leaving",
    funds = "Insufficient funds",
    upkeep = "Electricity bill: $%u",
  },
  timer = 0,
  update = function (self, dt)
    if self.alert then
      self.timer = self.timer - (dt / gGameSpeed)
      if self.timer <= 0 then
        self.alert = nil
      end
    end
  end,
  draw = function (self)
    if self.alert then
      love.graphics.setColor(140, 24, 0)
      love.graphics.rectangle("fill", 0, 180, 256, 12)
      love.graphics.setColor(255, 255, 255)
      love.graphics.printf(
        string.format(self.messages[self.alert], self.arg), -- string
        0, 182, -- x, y
        256, -- width
        "center" -- alignment
      )
    end
  end,
})
entity.addComponent(alertEntity, alertCom)
alert = function (msg, arg)
  alertCom.alert = msg
  alertCom.arg = arg
  alertCom.timer = 2
end

local upkeepEntity = entity.new(STATE_PLAY)
local upkeepCom = entity.newComponent({
  timer = 0,
  update = function (self, dt)
    self.timer = self.timer + dt
    if self.timer >= UPKEEP_PERIOD then
      self.timer = self.timer - UPKEEP_PERIOD
      
      -- charge upkeep
      local upkeep = 0
      for k,v in pairs(gCounts.rooms) do
        local info = resource.get("scr/rooms/"..k..".lua")
        if info.upkeep then
          upkeep = upkeep + (v * info.upkeep)
        end
      end
      
      moneyChange(-upkeep)
      alert("upkeep", upkeep)
    end
  end
})
entity.addComponent(upkeepEntity, upkeepCom)

local brokeEntity = entity.new(STATE_PLAY)
local brokeCom = entity.newComponent({
  timer = -1,
  update = function (self, dt)
    if gMoney >= 0 then
      self.timer = -1 -- stop timing
    elseif self.timer >= BROKE_TIME then
      self.timer = 0 -- keep timing
      gStaffTotals["bellhop"] = math.floor(gStaffTotals["bellhop"]/2)
      gStaffTotals["cleaner"] = math.floor(gStaffTotals["cleaner"]/2)
      gStaffTotals["maintenance"] = math.floor(gStaffTotals["maintenance"]/2)
      gStaffTotals["cook"] = math.floor(gStaffTotals["cook"]/2)
      gStaffTotals["stocker"] = math.floor(gStaffTotals["stocker"]/2)
      if gStaffTotals["bellhop"] <= 0 and
          gStaffTotals["cleaner"] <= 0 and
          gStaffTotals["maintenance"] <= 0 and
          gStaffTotals["cook"] <= 0 and
          gStaffTotals["stocker"] <= 0 then
        save.delete()
        event.notify("lose", 0, nil)
      else
        alert("broke")
      end
    elseif self.timer ~= -1 then
      self.timer = self.timer + dt
    end
  end
})
entity.addComponent(brokeEntity, brokeCom)

local moneySnd = resource.get("snd/coin.wav")
moneyChange = function (c, pos)
  gMoney = math.min(MONEY_MAX, gMoney + c)
  if c > 0 then
    love.audio.rewind(moneySnd)
    love.audio.play(moneySnd)
    if gMoney == 999999 then
      achievement.achieve(achievement.BANK)
    end
  elseif gMoney < 0 and brokeCom.timer == -1 then
    brokeCom.timer = 0
    achievement.achieve(achievement.DEBT)
  end
  if pos then
    event.notify("money.change", 0, {
      amount = c,
      pos = pos,
    })
  end
end

local won = false
reputationChange = function (c)
  gReputation = math.max(math.min(gReputation + c, REP_MAX), 0)

  if gStars < STARS_MAX and gReputation >= REP_THRESHOLDS[gStars + 1] then
    gStars = gStars + 1
    local oldBest = gStarsBest
    gStarsBest = math.max(gStarsBest, gStars)
    event.notify("stars", 0, {
      current = gStars,
      old = gStars - 1,
      best = oldBest
    })
  elseif gStars > 1 and gReputation < REP_THRESHOLDS[gStars] then
    gStars = gStars - 1
    event.notify("stars", 0, {
      current = gStars,
      old = gStars + 1,
      best = gStarsBest
    })
  elseif not won and gReputation == REP_MAX then
    won = true
    event.notify("win", 0)
  end
end

-- Font
gFont = love.graphics.newImageFont(
  resource.get("img/font.png"),
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ..
  "abcdefghijklmnopqrstuvwxyz" ..
  "1234567890!,.;:$*-+=/#_%^@\\&|?'\" "
)

-- Update menu tooltips (get names, costs of rooms)
local maxProfit = math.sqrt(resource.get("scr/rooms/banana.lua").profit)
local maxRep = resource.get("scr/rooms/spa.lua").desirability
local clientInfo = {}
for _,c in ipairs(CLIENTS) do
  clientInfo[c] = resource.get("scr/people/" .. c .. ".lua")
end
for _,fname in ipairs(love.filesystem.enumerate("data/scr/rooms/")) do
  local room = resource.get("scr/rooms/" .. fname)
  conf.menu[room.id] = {
    name = room.name,
    desc = "$" .. thousandify(tostring(room.cost)),
  }
  if room.profit then
    conf.menu[room.id].profit = math.sqrt(room.profit) / maxProfit
  end
  if room.desirability then
    conf.menu[room.id].rep = math.max(0, room.desirability) / maxRep
  end
  if room.visitable then
    conf.menu[room.id].desirable = {}
    for _,client in ipairs(CLIENTS) do
      local desire = false
      for _,suite in ipairs(clientInfo[client].preferences) do
        if suite == room.id then
          desire = true
        end
      end
      conf.menu[room.id].desirable[client] = desire
    end
  end
end

-- Allow game fast-forwarding
event.subscribe("pressed", 0, function (key)
  if key == "select" then
    gGameSpeed = 5
  end
end)
event.subscribe("released", 0, function (key)
  if key == "select" then
    gGameSpeed = 1
  end
end)

-- Setup the window
local setupScreen = function (modes)
  table.sort(modes, function (a, b)
      return a.width * a.height < b.width * b.height
  end)
  local mode = modes[#modes]
  local scale = 1
  while CANVAS_WIDTH * (scale + 1) <= mode.width and
        CANVAS_HEIGHT * (scale + 1) <= mode.height do
      scale = scale + 1
  end

  return {
    x = math.floor((mode.width - (CANVAS_WIDTH * scale)) / 2),
    y = math.floor((mode.height - (CANVAS_HEIGHT * scale)) / 2),
    width = mode.width,
    height = mode.height,
    scale = scale,
    fullscreen = true,
  }
end
conf.screen = {
  modes = {
    setupScreen(love.graphics.getModes()),
    {
      x = 0, y = 0,
      width = CANVAS_WIDTH, height = CANVAS_HEIGHT,
      scale = 1,
      fullscreen = false,
    },
    {
      x = 0, y = 0,
      width = CANVAS_WIDTH * 2, height = CANVAS_HEIGHT * 2,
      scale = 2,
      fullscreen = false,
    },
    {
      x = 0, y = 0,
      width = CANVAS_WIDTH * 3, height = CANVAS_HEIGHT * 3,
      scale = 3,
      fullscreen = false,
    },
    {
      x = 0, y = 0,
      width = CANVAS_WIDTH * 4, height = CANVAS_HEIGHT * 4,
      scale = 4,
      fullscreen = false,
    },
  },
  i = 1
}

-- Create the window
love.graphics.setMode(
  conf.screen.modes[conf.screen.i].width,
  conf.screen.modes[conf.screen.i].height,
  conf.screen.modes[conf.screen.i].fullscreen
)
love.graphics.setBackgroundColor(0, 0, 0)

love.mouse.setVisible(false)

-- Create the canvas
createCanvas = function ()
  if not love.graphics.newCanvas then
    -- Support love2d versions before 0.8
    love.graphics.newCanvas = love.graphics.newFramebuffer
    love.graphics.setCanvas = love.graphics.setRenderTarget
  end
  canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
  canvas:setFilter("nearest", "nearest")
end
createCanvas()

-- Create the pixel effect
if not love.graphics.newPixelEffect then
  -- Support love2d versions before 0.8
  love.graphics.setPixelEffect = function () end
else
  pixelEffect = resource.get("pfx/nes.glsl")
  if pixelEffect then
    pixelEffect:send("rubyTextureSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
    pixelEffect:send("rubyInputSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
    pixelEffect:send("rubyOutputSize", {CANVAS_WIDTH*conf.screen.modes[conf.screen.i].scale, CANVAS_HEIGHT*conf.screen.modes[conf.screen.i].scale})
  end
end

-- Create screen frame
local frameImage = resource.get("img/frame.png")
frameImage:setWrap("repeat", "repeat")
local frameQuad = love.graphics.newQuad(
  0, 0,
  conf.screen.modes[conf.screen.i].width / conf.screen.modes[conf.screen.i].scale,
  conf.screen.modes[conf.screen.i].height / conf.screen.modes[conf.screen.i].scale,
  frameImage:getWidth(), frameImage:getHeight()
)

-- Roof entity
local roof = entity.new(STATE_PLAY)
entity.setOrder(roof, -50)
entity.addComponent(roof, transform.new(roof, {
  roomNum = .5,
  floorNum = GROUND_FLOOR
}))
entity.addComponent(roof, sprite.new(
  roof, {
    image = resource.get("img/floor.png"),
    width = 256, height = 32,
    originY = 32,
  }
))
event.subscribe("floor.new", 0, function (level)
  if level > 0 then
    event.notify("entity.move", roof, {roomNum=.5, floorNum=level})
  end
end)

local floors = {}

-- Create an empty floor entity
local newFloor = function (level)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, -50)
  local pos = {roomNum = .5, floorNum = level }
  entity.addComponent(id, transform.new(id, pos))
  if level ~= 0 then
    entity.addComponent(id, sprite.new(id, {
      image = resource.get("img/floor.png"),
      width = 256, height = 32,
      animations = {
        idle = {
          first = 1,
          last = 1,
          speed = 1
        }
      },
      playing = "idle",
    }))
  end

  -- build default elevator on right hand side
  local epos = {roomNum = 7, floorNum = level}
  local eid = room.new(STATE_PLAY, "elevator", epos)
  event.notify("build", 0, {id=eid, pos=epos, type="elevator"})
  
  event.notify("floor.new", 0, level)
  local snd = resource.get("snd/build.wav")
  love.audio.rewind(snd)
  love.audio.play(snd)
  floors[level] = id
  return id
end

--Menu spacing values
local mainMenuY = 32*6.5
local subMenuY = 32*6

--Main menu
local gui = nil
  
local submenu = nil
local submenuConstructor = nil

local buildRoom = function (type)
  menu.disable(submenu)

  local buildUtility = builder.new(STATE_PLAY, type)

  local back

  local function onBuild ()
    event.unsubscribe("pressed", 0, back)
    event.unsubscribe("build", buildUtility, onBuild)
    menu.enable(submenu)
    entity.delete(buildUtility)
  end

  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      event.unsubscribe("build", buildUtility, onBuild)
      menu.enable(submenu)
      entity.delete(buildUtility)
      return true
    end
  end

  event.subscribe("pressed", 0, back)
  event.subscribe("build", buildUtility, onBuild)
end

local demolishRoom = function ()
  menu.disable(submenu)

  local demolishUtility = demolisher.new(2)

  local back

  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      menu.enable(submenu)
      entity.delete(demolishUtility)
      return true
    end
  end

  event.subscribe("pressed", 0, back)
end

local stockRoom = function (gui)
  menu.disable(gui)

  local stockUtility = stocker.new(STATE_PLAY)

  local back

  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      menu.enable(gui)
      entity.delete(stockUtility)
      return true
    end
  end

  event.subscribe("pressed", 0, back)
end

local inspect = function (gui)
  menu.disable(gui)

  local inspectUtility = inspector.new(STATE_PLAY)

  local back
  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      menu.enable(gui)
      entity.delete(inspectUtility)
      return true
    end
  end

  event.subscribe("pressed", 0, back)
end

local staffManage = function (type)
  menu.disable(submenu)

  local staffUtility = staffer.new(STATE_PLAY, type)

  local back
  back = function (key)
    if gState == STATE_PLAY and
        (key == "a" or key == "b") then
      event.unsubscribe("pressed", 0, back)
      menu.enable(submenu)
      entity.delete(staffUtility)
      return true
    end
  end

  event.subscribe("pressed", 0, back)
end

floorUp = function()
  if gTopFloor >= 16 then return end
  local cost = FLOOR_COSTS[gTopFloor + 1]
  if gMoney >= cost then
    gMoney = gMoney - cost
    event.notify("money.change", 0, {
      amount = -cost,
    })
    gTopFloor = gTopFloor + 1
    conf.menu["floorUp"].desc = "$" .. thousandify(tostring(FLOOR_COSTS[gTopFloor + 1]))
    if gTopFloor >= 16 then
      conf.menu["floorUp"].desc = "MAXED"
    end
    event.notify("menu.info", 0, {selected = "floorUp"})
    event.notify("scroll", 0 , gTopFloor)
    local newFloor = newFloor(gTopFloor)
  else
    alert("funds")
    local snd = resource.get("snd/error.wav")
    love.audio.rewind(snd)
    love.audio.play(snd)
  end
end

floorDown = function()
  if gBottomFloor <= -8 then return end
  local cost = FLOOR_COSTS[-gBottomFloor + 1] * 1.5
  if gMoney >= cost then
    gMoney = gMoney - cost
    event.notify("money.change", 0, {
      amount = -cost,
    })
    gBottomFloor = gBottomFloor - 1
    conf.menu["floorDown"].desc = "$" .. thousandify(tostring(FLOOR_COSTS[-gBottomFloor + 1] * 1.5))
    if gBottomFloor <= -8 then
      conf.menu["floorDown"].desc = "MAXED"
    end
    event.notify("menu.info", 0, {selected = "floorDown"})
    event.notify("scroll", 0 , gBottomFloor)
    local newFloor = newFloor(gBottomFloor)
  else
    alert("funds")
    local snd = resource.get("snd/error.wav")
    love.audio.rewind(snd)
    love.audio.play(snd)
  end
end

local addLockButton = function (submenu)
  local callback = function ()
    local snd = resource.get("snd/error.wav")
    love.audio.rewind(snd)
    love.audio.play(snd)
  end
  menu.addButton(submenu, menu.newButton("locked", callback))
end

local onStars = function (e)
  if submenu ~= nil then
    selected = menu.selected(submenu)
    enabled = menu.enabled(submenu)

    entity.delete(submenu)
    submenu = submenuConstructor()

    menu.select(submenu, selected)
    if enabled then
      menu.enable(submenu)
    else
      menu.disable(submenu)
    end

    menu.setBack(submenu, function ()
      entity.delete(submenu)
      submenu = nil
      menu.enable(gui)
    end)
  end
end
event.subscribe("stars", 0, onStars)

local newGui = function ()
  local gui = menu.new(STATE_PLAY, mainMenuY)

  --The back button
  menu.setBack(gui, function () end)
  
  local newSuiteMenu = function ()
    local m = menu.new(STATE_PLAY, subMenuY)
  
    --Missionary
    menu.addButton(m, menu.newButton("missionary", function ()
      buildRoom("missionary")
    end))
    
    --Spoon
    menu.addButton(m, menu.newButton("spoon", function ()
      buildRoom("spoon")
    end))
  
    if gStarsBest >= 2 then
      --Balloon
      menu.addButton(m, menu.newButton("balloon", function ()
        buildRoom("balloon")
      end))
    else
      addLockButton(m)
    end
  
    if gStarsBest >= 3 then
      --Chocolate Moustache
      menu.addButton(m, menu.newButton("moustache", function ()
        buildRoom("moustache")
      end))
    else
      addLockButton(m)
    end
  
    if gStarsBest >= 4 then
      --Torture
      menu.addButton(m, menu.newButton("heaven", function ()
        buildRoom("heaven")
      end))
    else
      addLockButton(m)
    end
  
    --Eco
    menu.addButton(m, menu.newButton("tropical", function ()
      buildRoom("tropical")
    end))
  
    if gStarsBest >= 5 then
      --Nazi Furry
      menu.addButton(m, menu.newButton("banana", function ()
        buildRoom("banana")
      end))
    else
      addLockButton(m)
    end
    
    return m
  end
  
  local newInfrastructureMenu = function ()
    local m = menu.new(STATE_PLAY, subMenuY)
  
    --Build floor up
    menu.addButton(m, menu.newButton("floorUp", function ()
      floorUp()
    end))
    --Build floor down
    menu.addButton(m, menu.newButton("floorDown", function ()
      floorDown()
    end))
    --Destroy tool
    menu.addButton(m, menu.newButton("destroy", function ()
      demolishRoom(submenu)
    end))
    
    return m
  end
  
  local newServicesMenu = function ()
    local m = menu.new(STATE_PLAY, subMenuY)
  
    --Utility
    menu.addButton(m, menu.newButton("utility", function ()
      buildRoom("utility")
    end))
    if gStarsBest >= 2 then
      --Condom machine
      menu.addButton(m, menu.newButton("condom", function ()
        buildRoom("condom")
      end))
    else
      addLockButton(m)
    end
    if gStarsBest >= 5 then
      --Spa room
      menu.addButton(m, menu.newButton("spa", function ()
        buildRoom("spa")
      end))
    else
      addLockButton(m)
    end
  
    return m
  end
  
  local newFoodMenu = function ()
    local m = menu.new(STATE_PLAY, subMenuY)
  
    --Vending machine
    menu.addButton(m, menu.newButton("vending", function ()
      buildRoom("vending")
    end))
  
    if gStarsBest >= 3 then
      --Dining room
      menu.addButton(m, menu.newButton("dining", function ()
        buildRoom("dining")
      end))
      --Kitchen
      menu.addButton(m, menu.newButton("kitchen", function ()
        buildRoom("kitchen")
      end))
    else
      addLockButton(m)
      addLockButton(m)
    end
  
    if gStarsBest >= 4 then
      --Freezer Room
      menu.addButton(m, menu.newButton("freezer", function ()
        buildRoom("freezer")
      end))
    else
      addLockButton(m)
    end
    return m
  end
  
  local newStaffMenu = function ()
    local m = menu.new(STATE_PLAY, subMenuY)
  
    --Hire staff
    menu.addButton(m, menu.newButton("bellhop", function ()
      staffManage("bellhop")
    end))
    menu.addButton(m, menu.newButton("cleaner", function ()
      staffManage("cleaner")
    end))
    menu.addButton(m, menu.newButton("maintenance", function ()
      staffManage("maintenance")
    end))
    if gStarsBest >= 3 then
      menu.addButton(m, menu.newButton("cook", function ()
        staffManage("cook")
      end))
    else
      addLockButton(m)
    end
    if gStarsBest >= 4 then
      menu.addButton(m, menu.newButton("stocker", function ()
        staffManage("stocker")
      end))
    else
      addLockButton(m)
    end
  
    return m
  end
  
  --Suites button
  menu.addButton(gui, menu.newButton("suites", function ()
    menu.disable(gui)
  
    --Create the suites menu
    submenu = newSuiteMenu()
    submenuConstructor = newSuiteMenu
  
    --The back button deletes the submenu
    menu.setBack(submenu, function ()
      entity.delete(submenu)
      submenu = nil
      menu.enable(gui)
    end)
  end))
  
  --Infrastructure button
  menu.addButton(gui, menu.newButton("infrastructure", function ()
    menu.disable(gui)
  
    --Create the infrastructure menu
    submenu = newInfrastructureMenu()
    submenuConstructor = newInfrastructureMenu
  
    --The back button deletes the submenu
    menu.setBack(submenu, function ()
      entity.delete(submenu)
      submenu = nil
      menu.enable(gui)
    end)
  end))
  
  
  --Services button
  menu.addButton(gui, menu.newButton("services", function ()
    menu.disable(gui)
  
    --Create the services menu
    submenu = newServicesMenu()
    submenuConstructor = newServicesMenu
  
     --The back button deletes the submenu
    menu.setBack(submenu, function ()
      entity.delete(submenu)
      submenu = nil
      menu.enable(gui)
    end)
  end))
  
  --Food button
  menu.addButton(gui, menu.newButton("food", function ()
    menu.disable(gui)
  
    --Create the food menu
    submenu = newFoodMenu()
    submenuConstructor = newFoodMenu
  
    --The back button deletes the submenu
    menu.setBack(submenu, function ()
      entity.delete(submenu)
      submenu = nil
      menu.enable(gui)
    end)
  end))
  
  --Staff button
  menu.addButton(gui, menu.newButton("staff", function ()
    menu.disable(gui)
  
    --Create the manage menu
    submenu = newStaffMenu()
    submenuConstructor = newStaffMenu
  
    --The back button deletes the submenu
    menu.setBack(submenu, function ()
      entity.delete(submenu)
      submenu = nil
      menu.enable(gui)
    end)
  end))
  
  --Stock tool
  menu.addButton(gui, menu.newButton("stock", function ()
    stockRoom(gui)
  end))
  
  --Inspect tool
  menu.addButton(gui, menu.newButton("inspect", function ()
    inspect(gui)
  end))
  
  return gui
end
gui = newGui()

-- Background music
event.subscribe("state.enter", 0, function (state)
  local bgm = resource.get("snd/love-hotel.mp3")
  if state == STATE_PLAY or state == STATE_DECISION then
    bgm:setVolume(0.1)
    love.audio.play(bgm)
  end
end)

-- Input training
local controller = entity.new(1)
entity.addComponent(controller, sprite.new(controller, {
  image = resource.get("img/controller.png"),
  width = CANVAS_WIDTH, height = CANVAS_HEIGHT
}))

local inputLocations = {
  a={x=206, y=130, text="Select"},
  b={x=174, y=130, text="Back"},
  left={x=42, y=120, text="Left"},
  right={x=68, y=120, text="Right"},
  up={x=55, y=108, text="Up"},
  down={x=55, y=134, text="Down"},
  start={x=135, y=132, text="Pause"},
  select={x=110, y=132, text="Fast Foward"},
}
local trainArrow = entity.new(STATE_TRAIN)
entity.addComponent(trainArrow, sprite.new(
  trainArrow, {
    image = resource.get("img/arrow.png"),
    width = 24, height = 24,
    animations = {
      idle = {
        first = 0,
        last = 7,
        speed = .1
      },
    },
    playing = "idle",
    originX = 12,
    originY = 24,
  }
))
local trainText = entity.new(STATE_TRAIN)
trainTextCom = entity.newComponent({
  text = "",
  draw = function (self)
    local desc = [[Bind keys or controller buttons to the NES controller.
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    At any time press F1 to rebind controls,
    or F11 to toggle screen mode.]]
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(
      desc,
      1, 9,
      256,
      "center"
    )
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(
      desc,
      0, 24,
      256,
      "center"
    )
    love.graphics.setFont(gFont)
    love.graphics.printf(
      self.text,
      0, CANVAS_HEIGHT - 60,
      256,
      "center"
    )
  end,
})
entity.addComponent(trainText, trainTextCom)
event.subscribe("training.current", 0, function (current)
  event.notify("sprite.move", trainArrow, inputLocations[current])
  trainTextCom.text = inputLocations[current].text
end)

event.subscribe("training.end", 0, function ()
  if gShowHelp then
    event.notify("state.enter", 0, STATE_HELP)
  else
    event.notify("state.enter", 0, STATE_PLAY)
    -- Show starting title card
    submenu = nil -- XXX prevent rare crash when submenu is garbage
    submenuConstructor = nil
    event.notify("stars", 0, {
      current = 1,
      old = 0,
      best = 1,
    })
  end
end)

local floorOccupation = 1

event.subscribe("pressed", 0, function (key)
  if gState == STATE_PLAY and gScrollable then
    if key == "up" and gScrollPos < gTopFloor then
      event.notify("scroll", 0 , gScrollPos + 1)
    elseif key == "down" and gScrollPos > gBottomFloor then
      event.notify("scroll", 0 , gScrollPos - 1)
    end
  end
end)

event.subscribe("build", 0, function (t)
  if t.pos.floorNum == gScrollPos then
    floorOccupation = 0
    for i = 1,7 do
      event.notify("room.check", 0, {
        roomNum = i,
        floorNum = gScrollPos,
        callback = function (otherId)
          floorOccupation = floorOccupation + 1
        end,
      })
    end
  end
end)

event.subscribe("destroy", 0, function (t)
  if t.pos.floorNum == gScrollPos then
    floorOccupation = 0
    for i = 1,7 do
      event.notify("room.check", 0, {
        roomNum = i,
        floorNum = gScrollPos,
        callback = function (otherId)
          floorOccupation = floorOccupation + 1
        end,
      })
    end
  end
end)

-- Create the hud bar
local hudQuad = love.graphics.newQuad(
  0, 128,
  CANVAS_WIDTH, 32,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local buttQuad = love.graphics.newQuad(
  0, 0,
  16, 16,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local statsQuad = love.graphics.newQuad(
  80, 176,
  80, 32,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local inspectorQuad = love.graphics.newQuad(
  0, 176,
  80, 32,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local condomQuad = love.graphics.newQuad(
  16, 160,
  8, 8,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local iconQuads = {}
iconPosX = {}
iconPosY = {}
for i,client in ipairs(CLIENTS) do
  -- lit
  iconQuads[client] = love.graphics.newQuad(
    24 + (8 * i), 160,
    5, 5,
    resource.get("img/hud.png"):getWidth(),
    resource.get("img/hud.png"):getHeight()
  )
  -- unlit
  iconQuads[client.."Off"] = love.graphics.newQuad(
    24 + (8 * i), 168,
    5, 5,
    resource.get("img/hud.png"):getWidth(),
    resource.get("img/hud.png"):getHeight()
  )
  local dx = (i - 1) % 3
  local dy = math.floor((i - 1) / 3)
  iconPosX[client] = 173 + (6 * dx)
  iconPosY[client] = 196 + (6 * dy)
end
local hudBar = entity.new(STATE_PLAY)
entity.setOrder(hudBar, 90)
local hudCom = entity.newComponent()
hudCom.name = ""
hudCom.desc = ""
hudCom.profit = nil
hudCom.rep = nil
hudCom.desirable = nil
hudCom.draw = function (self)
  love.graphics.setColor(255, 255, 255)
  love.graphics.drawq(
    resource.get("img/hud.png"), hudQuad,
    0, CANVAS_HEIGHT - 32,
    0
  )
  if self.inspector then
    love.graphics.drawq(
      resource.get("img/hud.png"), inspectorQuad,
      112, CANVAS_HEIGHT - 32,
      0
    )
    -- draw condoms
    for i = 0, self.inspector.condoms - 1 do
      love.graphics.drawq(
        resource.get("img/hud.png"), condomQuad,
        170 + (7 * i), 197,
        0
      )
    end
    -- draw needs bars
    love.graphics.setColor(0, 114, 0)
    love.graphics.rectangle("fill", 124, 207, self.inspector.money * 26, 2)
    love.graphics.setColor(172, 128, 0)
    love.graphics.rectangle("fill", 163, 207, self.inspector.patience * 26, 2)
    love.graphics.setColor(172, 16, 0)
    love.graphics.rectangle("fill", 124, 215, self.inspector.horniness * 26, 2)
    love.graphics.setColor(148, 0, 140)
    love.graphics.rectangle("fill", 163, 215, self.inspector.hunger * 26, 2)
  end
  -- draw info text
  love.graphics.setColor(255, 255, 255)
  love.graphics.setFont(gFont)
  if self.name then
    love.graphics.printf(
      self.name,
      115, CANVAS_HEIGHT - 26,
      76,
      "left"
    )
  end
  if self.desc then
    love.graphics.printf(
      self.desc,
      115, CANVAS_HEIGHT - 15,
      76,
      "left"
    )
  end
  -- draw stats bars
  if self.profit or self.rep then
    love.graphics.drawq(
      resource.get("img/hud.png"), statsQuad,
      112, CANVAS_HEIGHT - 32,
      0
    )
    local profit = self.profit or 0
    love.graphics.setColor(0, 114, 0)
    love.graphics.rectangle("fill", 169, 210, profit * 20, 2)
    local rep = self.rep or 0
    love.graphics.setColor(252, 184, 0)
    love.graphics.rectangle("fill", 169, 217, rep * 20, 2)
  end
  -- draw desirability icons
  if self.desirable then
    love.graphics.setColor(255, 255, 255)
    for _,client in ipairs(CLIENTS) do
      if gClientsSeen[client] then
        local quad
        if self.desirable[client] then
          quad = iconQuads[client]
        else
          quad = iconQuads[client.."Off"]
        end
        love.graphics.drawq(
          resource.get("img/hud.png"), quad,
          iconPosX[client], iconPosY[client],
          0
        )
      end
    end
  end
end
entity.addComponent(hudBar, hudCom)
event.subscribe("menu.info", 0, function (e)
  if e.selected then
    local info = conf.menu[e.selected]
    hudCom.name = info.name
    hudCom.desc = info.desc
    hudCom.profit = info.profit
    hudCom.rep = info.rep
    hudCom.desirable = info.desirable
  else
    hudCom.name = e.name
    hudCom.desc = e.desc
    hudCom.profit = e.profit
    hudCom.rep = e.rep
    hudCom.desirable = e.desirable
  end
  hudCom.inspector = e.inspector
end)

-- Create the gMoney display
local moneyDisplay = entity.new(STATE_PLAY)
entity.setOrder(moneyDisplay, 100)
local moneyCom = entity.newComponent()
moneyCom.change = 0
moneyCom.changeTimer = 0
moneyCom.draw = function (self)
  local money 
  if gMoney < 0 then
    love.graphics.setColor(172, 16, 0)
    money = "-$" .. thousandify(tostring(-gMoney))
  else
    love.graphics.setColor(255, 255, 255)
    money = "$" .. thousandify(tostring(gMoney))
  end
  love.graphics.setFont(gFont)
  love.graphics.printf(
    money,
    196, CANVAS_HEIGHT - 28,
    56,
    "right"
  )
end
moneyCom.update = function (self, dt)
  self.changeTimer = self.changeTimer - dt
  if moneyCom.change ~= 0 and self.changeTimer <= 0 then
    moneyCom.change = 0
  end
end
entity.addComponent(moneyDisplay, moneyCom)
local moneyChange = 0
event.subscribe("money.change", 0, function (e)
  moneyCom.change = moneyCom.change + e.amount
  moneyCom.changeTimer = 3

  -- Create in-world gMoney popup
  if e.pos then
    local id = entity.new(STATE_PLAY)
    entity.setOrder(id, 80)
    entity.addComponent(id, transform.new(
      id, e.pos, {x = 0, y = 0}
    ))
    local com = entity.newComponent({
      amount = e.amount,
      timer = 3,
      pos = {roomNum = e.pos.roomNum, floorNum = e.pos.floorNum},
      screenPos = {x=0, y=0},
    })
    com.update = function (self, dt)
      self.timer = self.timer - dt
      self.pos = {
        roomNum = self.pos.roomNum,
        floorNum = self.pos.floorNum + dt
      }
      event.notify("entity.move", id, self.pos)
      if self.timer <= 0 then
        entity.delete(id)
      end
    end
    com.draw = function (self)
      love.graphics.setFont(gFont)
      local colors = { {0, 0, 0} }
      local str = ""
      if self.amount > 0 then
        colors[2] = {0, 184, 0}
        str = "+$"..thousandify(tostring(self.amount))
      elseif self.amount < 0 then
        colors[2] = {172, 16, 0}
        str = "-$" .. thousandify(tostring(math.abs(self.amount)))
      end
      for i = 1, #colors do
        love.graphics.setColor(colors[i])
        love.graphics.print(
          str,
          self.screenPos.x+1-i, self.screenPos.y-i+1
        )
      end
    end
    local onMove = function (e)
      com.screenPos = {x = e.x, y = e.y}
    end
    local function delete ()
      event.unsubscribe("sprite.move", id, onMove)
      event.unsubscribe("delete", id, delete)
    end
    event.subscribe("sprite.move", id, onMove)
    event.subscribe("delete", id, delete)
    entity.addComponent(id, com)
  end
end)

-- Create the Reputation display
local hudImage = resource.get("img/hud.png")
local repQuad = love.graphics.newQuad(
  0, 160, -- x, y
  16, 16, -- viewport width, height
  hudImage:getWidth(), hudImage:getHeight() -- image width, height
)
local repDisplay = entity.new(STATE_PLAY)
entity.setOrder(repDisplay, 100)
local repCom = entity.newComponent()
repCom.draw = function (self)
  if gReputation > 0 then
    local a = gReputation - REP_THRESHOLDS[gStars]
    local b = REP_THRESHOLDS[gStars + 1] - REP_THRESHOLDS[gStars]
    love.graphics.setColor(252, 184, 0)
    local w = 57 * math.min(a / b, 1)
    love.graphics.rectangle("fill", 196, 219, w, 2)
  end
  love.graphics.setColor(255, 255, 255)
  for i=1,gStars do
    love.graphics.drawq(
      hudImage, repQuad,
      184 + (i * 11), 208 -- x, y
    )
  end
end
entity.addComponent(repDisplay, repCom)

-- Create the backdrop
local backdrop = entity.new(STATE_PLAY)
local bdImg = resource.get("img/backdrop.png")
local bdQuad = love.graphics.newQuad(
  0, 0,
  256, 64,
  bdImg:getWidth(), bdImg:getHeight()
)
entity.setOrder(backdrop, -100)
local bdCom = entity.newComponent()
bdCom.draw = function (self)
  love.graphics.setColor(255, 255, 255)
  if gScrollPos > 0 then
    -- Aboveground
    bdQuad:setViewport(0, 0, 256, 64)
  else
    -- Underground
    bdQuad:setViewport(0, bdImg:getHeight() - 64, 256, 64)
  end
  local yOffset = 32 * (gScrollPos % 2) - 16
  for i = 0, 3 do
    love.graphics.drawq(bdImg, bdQuad, 0, (64 * i) + yOffset)
  end
  love.graphics.draw(
    bdImg,
    0, 496 + (gScrollPos * 32) - bdImg:getHeight(),
    0
  )
end
entity.addComponent(backdrop, bdCom)

local initialised = false

-- Create default rooms and staff
local init = function ()
  newFloor(GROUND_FLOOR)
  event.notify("menu.info", 0, {selected = "infrastructure"})
  
  local id, pos
    
  pos = {roomNum = 4, floorNum = 0}
  id = room.new(STATE_PLAY, "reception", pos)
  event.notify("build", 0, {id=id, pos=pos, type="reception"})

  if not save.load() then
    floorUp()
    staff.new("bellhop")
    staff.new("cleaner")
    
    pos = {roomNum = 1, floorNum = 1}
    id = room.new(STATE_PLAY, "missionary", pos)
    event.notify("build", 0, {id=id, pos=pos, type="missionary"})
    
    pos = {roomNum = 6, floorNum = 1}
    id = room.new(STATE_PLAY, "utility", pos)
    event.notify("build", 0, {id=id, pos=pos, type="utility"})
    -- reduce initial stock
    room.setStock(id, 3)
  end
  
  event.notify("menu.info", 0, {selected = "suites"})

  initialised = true
end
init()
  
local reset = function ()
  gTopFloor = GROUND_FLOOR
  gBottomFloor = GROUND_FLOOR
  gScrollPos = GROUND_FLOOR
  event.notify("scroll", 0, gScrollPos)
  gMoney = MONEY_INITIAL
  gReputation = REP_INITIAL
  gStars = STARS_INITIAL
  gStarsBest = STARS_INITIAL - 1
  gStaffTotals = {
    bellhop = 0,
    cleaner = 0,
    maintenance = 0,
    cook = 0,
    stocker = 0,
  }
  gCounts = {
    fix = 0,
    rooms = {},
    spas = 0,
  }
  gClientsSeen = {
    poor = true,
    working = true,
    rich = true,
  }
  upkeepCom.timer = 0 -- reset electricity bill timer
  brokeCom.timer = -1 -- disable game over timer
  
  -- reset floor costs
  conf.menu.floorUp.desc = "$" .. thousandify(tostring(FLOOR_COSTS[1]))
  conf.menu.floorDown.desc = "$" .. thousandify(tostring(FLOOR_COSTS[1]*2))

  event.notify("room.all", 0, function (roomId, type)
    local pos = transform.getPos(roomId)
    entity.delete(roomId)
    
    event.notify("destroy", id, {id=roomId, pos=pos, type=type})
    event.notify("destroy", roomId, {id=roomId, pos=pos, type=type})
    event.notify("destroy", 0, {id=roomId, pos=pos, type=type})
  end)

  for _,c in ipairs(client.getAll()) do
    entity.delete(c.id)
  end
  for _,s in ipairs(staff.getAll()) do
    entity.delete(s.id)
  end
  
  for k,v in pairs(floors) do
    if k ~= GROUND_FLOOR then
      entity.delete(v)
    end
  end
  floors = {floors[GROUND_FLOOR]}
  event.notify("entity.move", roof, {roomNum=.5, floorNum=GROUND_FLOOR})
  
  event.notify("reset", 0, nil) -- deletes spawners
  client.newSpawner(nil, {roomNum = -1, floorNum = GROUND_FLOOR})
  
  menu.clear()
  builder.clear()
  demolisher.clear()
  staffer.clear()
  stocker.clear()
  gui = newGui()
  
  event.notify("state.enter", 0, STATE_PLAY)
  entity.update(0)
  
  event.notify("menu.info", 0, {selected = "suites"})
  
  save.delete()
  
  won = false

  initialised = false
end

local quit = function ()
  -- actually cause the app to quit
  love.event.push("quit")
  love.event.push("q")
end

-- GAME PAUSE MENU
local pauseMenu = entity.new(STATE_PAUSE)
local pauseCom = entity.newComponent({
  options = {
    {
      text = "Continue",
      onPress = function ()
        event.notify("state.enter", 0, STATE_PLAY)
      end,
    },
    {
      text = "Restart",
      onPress = function ()
        decision.confirm("Are you sure you want to restart?\nYou will lose all progress!", reset)
      end,
    },
    {
      text = "Achievements",
      onPress = function ()
        event.notify("state.enter", 0, STATE_ACHIEVMENTS)
      end,
    },
    {
      text = "Controls",
      onPress = function ()
        event.notify("training.begin", 0)
      end,
    },
    {
      text = "Help",
      onPress = function ()
        event.notify("state.enter", 0, STATE_HELP)
      end,
    },
    {
      text = "Credits",
      onPress = function ()
        event.notify("state.enter", 0, STATE_CREDITS)
      end,
    },
    {
      text = "Quit",
      onPress = function ()
        decision.confirm("Are you sure you want to quit?\nYour progress will be saved.", function ()
          quit()
        end)
      end,
    },
  },
  selected = 1,

  draw = function (self)
    -- Draw title
    local img = resource.get("img/title.png")
    love.graphics.draw(img, 0, 0)

    -- Draw menu
    love.graphics.setFont(gFont)
    for i,option in ipairs(self.options) do
      if i == self.selected then
        love.graphics.setColor(255, 255, 255)
      else
        love.graphics.setColor(89, 89, 89)
      end
      love.graphics.printf(
        option.text,
        0, 112 + (14 * i),
        256,
        "center"
      )
    end
  end,
})
entity.addComponent(pauseMenu, pauseCom)
event.subscribe("pressed", 0, function (key)
  if key == "start" then
    if gState == STATE_PLAY then
      event.notify("state.enter", 0, STATE_PAUSE)
    elseif gState == STATE_PAUSE then
      event.notify("state.enter", 0, STATE_PLAY)
    end
  end
end)
event.subscribe("pressed", 0, function (button)
  if gState == STATE_PAUSE then
    if button == "a" then
      pauseCom.options[pauseCom.selected].onPress()
      return true
    elseif button == "up" then
      pauseCom.selected = math.max(1, pauseCom.selected - 1)
    elseif button == "down" then
      pauseCom.selected = math.min(#pauseCom.options, pauseCom.selected + 1)
    end
  end
end)

-- GAME WIN SCREEN
local winScreen = entity.new(STATE_WIN)
local winCom = entity.newComponent({
  draw = function (self)
    -- Draw win screen
    local img = resource.get("img/win.png")
    love.graphics.draw(img, 0, 0)

    love.graphics.setFont(gFont)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(
      "Press START",
      0, CANVAS_HEIGHT - 9,
      CANVAS_WIDTH,
      "center"
    )
  end
})
entity.addComponent(winScreen, winCom)
event.subscribe("win", 0, function ()
  event.notify("state.enter", 0, STATE_WIN)
end)
event.subscribe("pressed", 0, function (button)
  if gState == STATE_WIN then
    if button == "start" then
      event.notify("state.enter", 0, STATE_CREDITS)
    end
  end
end)

-- GAME LOSE SCREEN
local loseScreen = entity.new(STATE_LOSE)
local loseCom = entity.newComponent({
  draw = function (self)
    -- Draw lose screen
    local img = resource.get("img/lose.png")
    love.graphics.draw(img, 0, 0)

    love.graphics.setFont(gFont)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(
      "Press START",
      0, CANVAS_HEIGHT - 9,
      CANVAS_WIDTH,
      "center"
    )
  end
})
entity.addComponent(loseScreen, loseCom)
event.subscribe("lose", 0, function ()
  event.notify("state.enter", 0, STATE_LOSE)
end)
event.subscribe("pressed", 0, function (button)
  if gState == STATE_LOSE then
    if button == "start" then
      decision.confirm("Play again?", reset, quit, true)
    end
  end
end)

-- GAME CREDITS SCREEN
local creditsScreen = entity.new(STATE_CREDITS)
local creditsCom = entity.newComponent({
  draw = function (self)
    -- Draw credits screen
    local img = resource.get("img/credits.png")
    love.graphics.draw(img, 0, 0)
  end
})
entity.addComponent(creditsScreen, creditsCom)
event.subscribe("pressed", 0, function (button)
  if gState == STATE_CREDITS and
      (button == "b" or button == "start") then
    event.notify("state.enter", 0, STATE_PAUSE)
  end
end)

-- GAME HELP SCREEN
local helpScreen = entity.new(STATE_HELP)
local helpImgCom = sprite.new(helpScreen, {
  image = resource.get("img/help.png"),
  width = CANVAS_WIDTH,
  height = CANVAS_HEIGHT,
  animations = {
    idle = {
      first = 0,
      last = 1,
      speed = .5,
    },
  },
  playing = "idle",
})
entity.addComponent(helpScreen, helpImgCom)
local helpTextCom = entity.newComponent({
  draw = function (self)
    -- Draw help screen text
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(
      "Restock when empty.",
      110, 20,
      150,
      "left"
    )
    love.graphics.printf(
      "Watch your electricity bill.",
      0, 100,
      140,
      "right"
    )
    love.graphics.printf(
      "See if your clients are happy, and what they've run out of.",
      110, 170,
      150,
      "left"
    )
  end
})
entity.addComponent(helpScreen, helpTextCom)
event.subscribe("pressed", 0, function (button)
  if gState == STATE_HELP and
      (button == "a" or button == "b" or button == "start") then
    if gShowHelp then
      gShowHelp = false
      event.notify("training.end", 0)
    else
      event.notify("state.enter", 0, STATE_PAUSE)
    end
  end
end)

-- GAME ACHIEVEMENTS SCREEN
local achieveCursorQuad = love.graphics.newQuad(
  192, 160,
  64, 64,
  resource.get("img/hud.png"):getWidth(),
  resource.get("img/hud.png"):getHeight()
)
local achieveIconQuad = love.graphics.newQuad(
  0, 0,
  48, 48,
  resource.get("img/achievements.png"):getWidth(),
  resource.get("img/achievements.png"):getHeight()
)
local achieveScreen = entity.new(STATE_ACHIEVMENTS)
local achieveCom = entity.newComponent({
  selected = 0,
  draw = function (self)
    love.graphics.setColor(255, 255, 255)
    
    -- icons
    for i = 0, 11 do
      local x = 20 + (i % 4) * 56
      local y = 8 + math.floor(i / 4) * 56
      local xoffset = 0
      if achievement.isDone(i + 1) then xoffset = 48 end
      achieveIconQuad:setViewport(
        xoffset, 48 * i,
        48, 48
      )
      love.graphics.drawq(
        resource.get("img/achievements.png"), achieveIconQuad,
        x, y
      ) 
    end

    -- cursor
    love.graphics.drawq(
      resource.get("img/hud.png"),
      achieveCursorQuad,
      12 + (self.selected % 4) * 56, math.floor(self.selected / 4) * 56
    )
  
    -- name and description
    local current = achievement.getInfo(self.selected + 1)
    love.graphics.printf(
      current.name,
      0, CANVAS_HEIGHT - 40,
      CANVAS_WIDTH,
      "center"
    )
    if achievement.isDone(self.selected + 1) then
      love.graphics.setColor(123, 126, 127)
      love.graphics.printf(
        current.desc,
        0, CANVAS_HEIGHT - 28,
        CANVAS_WIDTH,
        "center"
      )
    end
  end,
})
entity.addComponent(achieveScreen, achieveCom)
event.subscribe("pressed", 0, function (button)
  if gState == STATE_ACHIEVMENTS then
    if button == "b" or button == "start" then
      event.notify("state.enter", 0, STATE_PAUSE)
    elseif button == "up" and achieveCom.selected > 3 then
      achieveCom.selected = achieveCom.selected - 4
    elseif button == "down" and achieveCom.selected < 8 then
      achieveCom.selected = achieveCom.selected + 4
    elseif button == "left" and (achieveCom.selected % 4) > 0 then
      achieveCom.selected = achieveCom.selected - 1
    elseif button == "right" and (achieveCom.selected % 4) < 3 then
      achieveCom.selected = achieveCom.selected + 1
    end
  end
end)

-- GAME START SCREEN
local startScreen = entity.new(STATE_START)
local startCom = entity.newComponent({
  timer = 3,
  draw = function (self)
    -- Draw logo
    local img = resource.get("img/logo.png")
    love.graphics.draw(img, 0, 0)
  end,
  update = function (self, dt)
    self.timer = self.timer - dt
    if self.timer <= 0 then
      event.notify("training.begin", 0)
      event.notify("training.load", 0)
    end
  end,
})
entity.addComponent(startScreen, startCom)
event.notify("state.enter", 0, STATE_START)

love.draw = function ()
  -- Draw to canvas without scaling
  love.graphics.setCanvas(canvas)
  love.graphics.clear()
  if pixelEffect then
    love.graphics.setPixelEffect()
  end
  love.graphics.setColor(255, 255, 255)

  entity.draw()

  -- Draw to screen with scaling
  love.graphics.setCanvas()

  -- Draw the screen frame
  love.graphics.setColor(255,255,255)
  love.graphics.drawq(
    frameImage, frameQuad,
    0, 0,
    0,
    conf.screen.modes[conf.screen.i].scale, conf.screen.modes[conf.screen.i].scale
  )
  -- Fill the screen area black for pixel effect
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle(
    "fill",
    conf.screen.modes[conf.screen.i].x,
    conf.screen.modes[conf.screen.i].y,
    CANVAS_WIDTH * conf.screen.modes[conf.screen.i].scale,
    CANVAS_HEIGHT * conf.screen.modes[conf.screen.i].scale
  )

  if pixelEffect then
    love.graphics.setPixelEffect(pixelEffect)
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(
    canvas,
    conf.screen.modes[conf.screen.i].x,
    conf.screen.modes[conf.screen.i].y,
    0,
    conf.screen.modes[conf.screen.i].scale,
    conf.screen.modes[conf.screen.i].scale
  )
end

love.update = function (dt)
  if not initialised then
    init()
  end
  
  local dt = dt * gGameSpeed
  entity.update(dt)
  input.update(dt)
end

local returnDown = false

function love.keypressed(key)   -- we do not need the unicode, so we can leave it out
  if key == "escape" then
    if gState == STATE_PLAY then
      event.notify("state.enter", 0, STATE_PAUSE)
    elseif gState == STATE_PAUSE then
      event.notify("state.enter", 0, STATE_PLAY)
    elseif gState == STATE_WIN then
      event.notify("state.enter", 0, STATE_PLAY)
    elseif gState == STATE_ACHIEVMENTS then
      event.notify("state.enter", 0, STATE_PAUSE)
    end
  elseif key == "f1" then
    event.notify("training.begin", 0)
  elseif key == "f11" then
    conf.screen.i = conf.screen.i + 1
    if conf.screen.i > #conf.screen.modes then
      conf.screen.i = 1
    end
    love.graphics.setMode(
      conf.screen.modes[conf.screen.i].width,
      conf.screen.modes[conf.screen.i].height,
      conf.screen.modes[conf.screen.i].fullscreen
    )
    -- Need to force reload of fragment shader
    if pixelEffect then
      pixelEffect:send("rubyTextureSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
      pixelEffect:send("rubyInputSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
      pixelEffect:send("rubyOutputSize", {CANVAS_WIDTH*conf.screen.modes[conf.screen.i].scale, CANVAS_HEIGHT*conf.screen.modes[conf.screen.i].scale})
    end
  elseif key == "return" and (gState == STATE_PAUSE or gState == STATE_DECISION) and not input.isMapped("return") then
    returnDown = true
    event.notify("pressed", 0, "a")
  else
    input.keyPressed(key)
  end
end

love.keyreleased = function (key)
  if returnDown and key == "return" then
    event.notify("released", 0, "a")
    returnDown = false
  end
  input.keyReleased(key)
end

love.joystickpressed = function (joystick, button)
  input.joystickPressed(joystick, button)
end

love.joystickreleased = function (joystick, button)
  input.joystickReleased(joystick, button)
end

love.quit = function ()
  achievement.save()
  save.save()
end
