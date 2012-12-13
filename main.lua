-- main.lua

-- Constants
CANVAS_WIDTH = 256
CANVAS_HEIGHT = 224
ROOM_INDENT = 32*0.5
FLOOR_OFFSET = 32*2.5
GROUND_FLOOR = 0

STATE_TRAIN = 1
STATE_PLAY = 2
STATE_PAUSE = 3
STATE_DECISION = 4

STAFF_MOVE = 1
ELEVATOR_MOVE = 1
CLIENT_MOVE = 1
BELLHOP_DISTANCE = 0.8
FOLLOW_DISTANCE = 0.4

PAY_PERIOD = 60
CLEANER_WAGE = 10
BELLHOP_WAGE = 20
COOK_WAGE = 50
MAINTENANCE_WAGE = 100

SEX_TIME = 7
CLEAN_TIME = 10
SUPPLY_TIME = 4
CONDOM_TIME = 2
EAT_TIME = 3
FIX_TIME = 5
COOK_TIME = 10

SPAWN_MIN = 20
SPAWN_MAX = 30
SKY_SPAWN = 8
GROUND_SPAWN = -8
SPACE_SPAWN = 16

REP_INITIAL = 5
REP_MAX = 500
STARS_INITIAL = 1
STARS_MAX = 5
REP_THRESHOLDS = {
  0,
  20,
  40,
  80,
  160,
  500,
}

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
local staff = require("staff")
local client = require("client")
local transform = require("transform")
local path = require("path")
local decision = require("decision")

conf = {
  menu = {
    -- Main menu
    infrastructure =  {
      name="Structure",
      desc=""
    },
    suites =  {
      name="Suites",
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
      name="Stock",
      desc="",
    },
    inspect = {
      name="Inspect",
      desc="",
    },
    locked = {
      name="Locked",
      desc="Needs stars"
    },
    
    -- Structure
    floorUp =  {
      name="Build Up",
      desc="$500"
    },
    floorDown =  {
      name="Build Down",
      desc="$1000"
    },
    destroy =  {
      name="Destroy",
      desc=""
    },
    
    -- Staff
    cleaner = {
      name="Cleaner",
      desc="$" .. CLEANER_WAGE .. "/min"
    },
    bellhop = {
      name="Bellhop",
      desc="$" .. BELLHOP_WAGE .. "/min"
    },
    cook = {
      name="Cook",
      desc="$" .. COOK_WAGE .. "/min"
    },
    maintenance = {
      name="Maintenance",
      desc="$" .. MAINTENANCE_WAGE .. "/min"
    },
  },
}

gTopFloor = GROUND_FLOOR
gBottomFloor = GROUND_FLOOR
gScrollPos = GROUND_FLOOR
gRoomNum = 1
event.subscribe("scroll", 0, function (scrollPos)
  gScrollPos = scrollPos
end)
gState = STATE_TRAIN
event.subscribe("state.enter", 0, function (state)
  gState = state
end)
gGameSpeed = 1
gMoney = 200000
gReputation = REP_INITIAL
gStars = STARS_INITIAL

moneyChange = function (c, pos)
  gMoney = math.max(0, gMoney + c)
  
  if pos then
    event.notify("money.change", 0, {
      amount = c,
      pos = pos,
    })
  end
end

reputationChange = function (c)
  gReputation = math.max(math.min(gReputation + c, REP_MAX - 1), 0)

  if gStars < STARS_MAX and gReputation >= REP_THRESHOLDS[gStars + 1] then
    gStars = gStars + 1
  elseif gStars > 1 and gReputation < REP_THRESHOLDS[gStars] then
    gStars = gStars - 1
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
for _,fname in ipairs(love.filesystem.enumerate("resources/scr/rooms/")) do
  local room = resource.get("scr/rooms/" .. fname)
  conf.menu[room.id] = {
    name = room.name,
    desc = "$" .. room.cost,
  }
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
    x = 0, --math.floor((mode.width - (CANVAS_WIDTH * scale)) / 2),
    y = 0, --math.floor((mode.height - (CANVAS_HEIGHT * scale)) / 2),
    width = CANVAS_WIDTH * scale, --mode.width,
    height = CANVAS_HEIGHT * scale, --mode.height,
    scale = scale,
    fullscreen = false, --true,
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

love.filesystem.setIdentity("love-hotel")

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

--Menu spacing values
local mainMenuY = 32*6.5
local subMenuY = 32*6


local buildRoom = function (type, baseMenu)
  menu.disable(baseMenu)

  local buildUtility = builder.new(STATE_PLAY, type)
    
  local back = function () end
    
  local function onBuild ()
    event.unsubscribe("pressed", 0, back)
    event.unsubscribe("build", buildUtility, onBuild)
    menu.enable(baseMenu)
    entity.delete(buildUtility)
  end

  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      event.unsubscribe("build", buildUtility, onBuild)
      menu.enable(baseMenu)
      entity.delete(buildUtility)
    end
  end

  event.subscribe("pressed", 0, back)
  event.subscribe("build", buildUtility, onBuild)
end

local demolishRoom = function (baseMenu)
  menu.disable(baseMenu)

  local demolishUtility = demolisher.new(2)
    
  local back = function () end
    
  local function onDestroy ()
    event.unsubscribe("pressed", 0, back)
    event.unsubscribe("destroy", demolishUtility, onDestroy)
    menu.enable(baseMenu)
    entity.delete(demolishUtility)
  end

  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      event.unsubscribe("destroy", demolishUtility, onDestroy)
      menu.enable(baseMenu)
      entity.delete(demolishUtility)
    end
  end

  event.subscribe("pressed", 0, back)
  event.subscribe("destroy", demolishUtility, onDestroy)
end

local stockRoom = function (baseMenu)
  menu.disable(baseMenu)

  local stockUtility = stocker.new(STATE_PLAY)
    
  local back = function () end
    
  local function onStock ()
    event.unsubscribe("pressed", 0, back)
    event.unsubscribe("stock", stockUtility, onStock)
    menu.enable(baseMenu)
    entity.delete(stockUtility)
  end

  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      event.unsubscribe("stock", stockUtility, onStock)
      menu.enable(baseMenu)
      entity.delete(stockUtility)
    end
  end

  event.subscribe("pressed", 0, back)
  event.subscribe("stock", stockUtility, onStock)
end

local inspect = function (baseMenu)
  menu.disable(baseMenu)

  local inspectUtility = inspector.new(STATE_PLAY)
    
  local back
  back = function (key)
    if gState == STATE_PLAY and key == "b" then
      event.unsubscribe("pressed", 0, back)
      menu.enable(baseMenu)
      entity.delete(inspectUtility)
    end
  end

  event.subscribe("pressed", 0, back)
end

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
  event.notify("floor.new", 0, level)
  local snd = resource.get("snd/build.wav")
  love.audio.rewind(snd)
  love.audio.play(snd)
  return id
end
newFloor(GROUND_FLOOR)

local floorUp = function()
  local cost =  500 * (gTopFloor + 1)
  if gMoney >= cost then
    gMoney = gMoney - cost
    event.notify("money.change", 0, {
      amount = -cost,
    })
    gTopFloor = gTopFloor + 1
    conf.menu["floorUp"].desc = "$" .. (500 * (gTopFloor + 1))
    local newFloor = newFloor(gTopFloor)
  else
    local snd = resource.get("snd/error.wav")
    love.audio.rewind(snd)
    love.audio.play(snd)
  end
end

local floorDown = function()
  local cost =  1000 * (1 - gBottomFloor)
  if gMoney >= cost then
    gMoney = gMoney - cost
    event.notify("money.change", 0, {
      amount = -cost,
    })
    gBottomFloor = gBottomFloor - 1
    conf.menu["floorDown"].desc = "$" .. (1000 * (1 - gBottomFloor))
    local newFloor = newFloor(gBottomFloor)
  else
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

--Main menu
local gui = menu.new(STATE_PLAY, mainMenuY)

--The back button, quits the game at the moment
menu.setBack(gui, function ()
  --love.event.push("quit")
  --love.event.push("q")
end)

--Infrastructure button
menu.addButton(gui, menu.newButton("infrastructure", function ()
  menu.disable(gui)
  
  --Create the infrastructure menu
  local submenu = menu.new(STATE_PLAY, subMenuY)
  
  --[[Stairs
  menu.addButton(submenu, menu.newButton("stairs", function ()
    print("Stairs")
  end))---]]
  --Elevator
  menu.addButton(submenu, menu.newButton("elevator", function ()
    buildRoom("elevator", submenu)
  end)) 
  --Build floor up
  menu.addButton(submenu, menu.newButton("floorUp", function ()
    floorUp()
  end))
  --Build floor down
  menu.addButton(submenu, menu.newButton("floorDown", function ()
    floorDown()
  end))
  --Destroy tool
  menu.addButton(submenu, menu.newButton("destroy", function ()
    demolishRoom(submenu)
  end))

  --The back button deletes the submenu
  menu.setBack(submenu, function ()
    entity.delete(submenu)
    menu.enable(gui)
  end)
end))

--Suites button
menu.addButton(gui, menu.newButton("suites", function ()
  menu.disable(gui)
  
  --Create the suites menu
  local submenu = menu.new(STATE_PLAY, subMenuY)
 
  --Missionary
  menu.addButton(submenu, menu.newButton("missionary", function ()
    buildRoom("missionary", submenu)
  end))
 
  --Spoon
  menu.addButton(submenu, menu.newButton("spoon", function ()
    buildRoom("spoon", submenu)
  end))
  
   if gStars >= 2 then
    --Chocolate Moustache
    menu.addButton(submenu, menu.newButton("moustache", function ()
      buildRoom("moustache", submenu)
    end))
  else
    addLockButton(submenu)
  end

   if gStars >= 2 then
    --Balloon
    menu.addButton(submenu, menu.newButton("balloon", function ()
      buildRoom("balloon", submenu)
    end))
  else
    addLockButton(submenu)
  end
   
  if gStars >= 5 then
    --Tropical
    menu.addButton(submenu, menu.newButton("tropical", function ()
      buildRoom("tropical", submenu)
    end))
  else
    addLockButton(submenu)
  end

  --The back button deletes the submenu
  menu.setBack(submenu, function ()
    entity.delete(submenu)
    menu.enable(gui)
  end)
end))

--Food button
menu.addButton(gui, menu.newButton("food", function ()
  menu.disable(gui)
  
  --Create the food menu
  local submenu = menu.new(STATE_PLAY, subMenuY)
  
  --Vending machine
  menu.addButton(submenu, menu.newButton("vending", function ()
    buildRoom("vending", submenu)
  end))
  --Dining room
  menu.addButton(submenu, menu.newButton("dining", function ()
    buildRoom("dining", submenu)
  end))
  --Freezer Room
  menu.addButton(submenu, menu.newButton("freezer", function ()
    buildRoom("freezer", submenu)
  end))
  --Kitchen
  menu.addButton(submenu, menu.newButton("kitchen", function ()
    buildRoom("kitchen", submenu)
  end))


  --The back button deletes the submenu
  menu.setBack(submenu, function ()
    entity.delete(submenu)
    menu.enable(gui)
  end)
end))

--Services button
menu.addButton(gui, menu.newButton("services", function ()
  menu.disable(gui)
  
  --Create the services menu
  local submenu = menu.new(STATE_PLAY, subMenuY)

  --Reception
  menu.addButton(submenu, menu.newButton("reception", function ()
    buildRoom("reception", submenu)
  end))
  --Utility
  menu.addButton(submenu, menu.newButton("utility", function ()
    buildRoom("utility", submenu)
  end))
  --Condom machine
  menu.addButton(submenu, menu.newButton("condom", function ()
    buildRoom("condom", submenu)
  end))
  --Spa room
  menu.addButton(submenu, menu.newButton("spa", function ()
    buildRoom("spa", submenu)
  end))

   --The back button deletes the submenu
  menu.setBack(submenu, function ()
    entity.delete(submenu)
    menu.enable(gui)
  end)
end))

--Staff button
menu.addButton(gui, menu.newButton("staff", function ()
  menu.disable(gui)
  
  --Create the manage menu
  local submenu = menu.new(STATE_PLAY, subMenuY)
  
  --Hire staff
  menu.addButton(submenu, menu.newButton("cleaner", function ()
    staff.new("cleaner")
  end))
  menu.addButton(submenu, menu.newButton("bellhop", function ()
    staff.new("bellhop")
  end))
  menu.addButton(submenu, menu.newButton("cook", function ()
    staff.new("cook")
  end))
  menu.addButton(submenu, menu.newButton("maintenance", function ()
    staff.new("maintenance")
  end))

  --The back button deletes the submenu
  menu.setBack(submenu, function ()
    entity.delete(submenu)
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

-- Background music
event.subscribe("state.enter", 0, function (state)
  local bgm = resource.get("snd/gettingfreaky.ogg")
  if state == STATE_PLAY then
    love.audio.play(bgm)
  else
    love.audio.pause(bgm)
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
  draw = function (self)
    local desc = [[Controller Setup
    
    For each input pointed to, choose a key or gamepad button and press it.]]
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
      0, 8,
      256,
      "center"
    )
    love.graphics.setFont(gFont)
    love.graphics.printf(
      self.text,
      0, CANVAS_HEIGHT - 32,
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
  event.notify("state.enter", 0, 2)
end)

event.notify("training.begin", 0)
event.notify("training.load", 0)

local floorOccupation = 1

event.subscribe("pressed", 0, function (key)
  if gState == STATE_PLAY then
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
local hudBar = entity.new(STATE_PLAY)
entity.setOrder(hudBar, 90)
local hudCom = entity.newComponent()
hudCom.name = "Structure"
hudCom.desc = ""
hudCom.draw = function (self)
  love.graphics.drawq(
    resource.get("img/hud.png"), hudQuad,
    0, CANVAS_HEIGHT - 32,
    0
  )
  -- draw info
  love.graphics.setColor(255, 255, 255)
  love.graphics.setFont(gFont)
  love.graphics.printf(
    self.name,
    115, CANVAS_HEIGHT - 26,
    76,
    "left"
  )
  love.graphics.printf(
    self.desc,
    115, CANVAS_HEIGHT - 15,
    76,
    "left"
  )
end
entity.addComponent(hudBar, hudCom)
event.subscribe("menu.info", 0, function (e)
  if e.selected then
    local info = conf.menu[e.selected]
    hudCom.name = info.name
    hudCom.desc = info.desc
  else
    hudCom.name = e.name
    hudCom.desc = e.desc
  end
end)

-- Create the gMoney display
local moneyDisplay = entity.new(STATE_PLAY)
entity.setOrder(moneyDisplay, 100)
local moneyCom = entity.newComponent()
moneyCom.change = 0
moneyCom.changeTimer = 0
moneyCom.draw = function (self)
  love.graphics.setFont(gFont)
  love.graphics.setColor(255, 255, 255)
  love.graphics.printf(
    "$" .. gMoney,
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
    entity.setOrder(id, 100)
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
        str = "+"..self.amount
      elseif self.amount < 0 then
        colors[2] = {172, 16, 0}
        str = self.amount
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

-- GAME PAUSE MENU
local pauseMenu = entity.new(STATE_PAUSE)
local pauseCom = entity.newComponent({
  options = {
    {
      text = "Play",
      onPress = function ()
        event.notify("state.enter", 0, STATE_PLAY)
      end,
    },
    {
      text = "Controls",
      onPress = function ()
        event.notify("training.begin", 0)
      end,
    },
    {
      text = "Quit",
      onPress = function ()
        -- actually cause the app to quit
        love.event.push("quit")
        love.event.push("q")
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
        0, 128 + (16 * i),
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
    elseif button == "up" then
      pauseCom.selected = math.max(1, pauseCom.selected - 1)
    elseif button == "down" then
      pauseCom.selected = math.min(#pauseCom.options, pauseCom.selected + 1)
    end
  end
end)

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
    end
  elseif key == "f1" then
    event.notify("training.begin", 0)
  elseif key == "f11" then
    conf.screen.i = conf.screen.i + 1
    if conf.screen.i > #conf.screen.modes then
      conf.screen.i = 1
    end
    --love.graphics.setMode(
    --  conf.screen.modes[conf.screen.i].width,
    --  conf.screen.modes[conf.screen.i].height,
    --  conf.screen.modes[conf.screen.i].fullscreen
    --)
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

