-- main.lua

-- Constants
CANVAS_WIDTH = 256
CANVAS_HEIGHT = 224
ROOM_INDENT = 32*0.5
FLOOR_OFFSET = 32*2.5

STATE_TRAIN = 1
STATE_PLAY = 2

STAFF_MOVE = 1
STAFF_WAGE = 10
PAY_PERIOD = 30
CLIENT_MOVE = 1
SEX_TIME = 7
CLEAN_TIME = 15
SPAWN_MIN = 10
SPAWN_MAX = 20

local event = require("event")
local entity = require("entity")
local input = require("input")
local resource = require("resource")
local sprite = require ("sprite")
local room = require("room")
local menu = require("menu")
local ai = require("ai")
local builder = require("builder")
local staff = require("staff")
local client = require("client")
local transform = require("transform")
local path = require("path")

conf = {
  menu = {
    build =  {
      name="Build",
      desc=""
    },
    destroy = {
      name="Destroy",
      desc=""
    },
    hire = {
      name="Hire",
      desc="$10/hour"
    },
  },
}

gTopFloor = 1
gBottomFloor = 1
gScrollPos = 1
event.subscribe("scroll", 0, function (scrollPos)
  gScrollPos = scrollPos
end)

gGameSpeed = 1

money = 2000

-- Update menu tooltips
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
    x = math.floor((mode.width - (CANVAS_WIDTH * scale)) / 2),
    y = math.floor((mode.height - (CANVAS_HEIGHT * scale)) / 2),
    width = mode.width,
    height = mode.height,
    scale = scale,
    fullscreen = true,
  }
end
conf.screen = setupScreen(love.graphics.getModes())

love.filesystem.setIdentity("love-hotel")

-- Create the window
love.graphics.setMode(
  conf.screen.width,
  conf.screen.height,
  conf.screen.fullscreen
)
love.graphics.setBackgroundColor(0, 0, 0)

love.mouse.setVisible(false)

-- Create the canvas
if not love.graphics.newCanvas then
  -- Support love2d versions before 0.8
  love.graphics.newCanvas = love.graphics.newFramebuffer
  love.graphics.setCanvas = love.graphics.setRenderTarget
end
canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
canvas:setFilter("nearest", "nearest")

-- Create the pixel effect
if not love.graphics.newPixelEffect then
  -- Support love2d versions before 0.8
  love.graphics.setPixelEffect = function () end
else
  pixelEffect = resource.get("pfx/nes.glsl")
  pixelEffect:send("rubyTextureSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
  pixelEffect:send("rubyInputSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
  pixelEffect:send("rubyOutputSize", {CANVAS_WIDTH*conf.screen.scale, CANVAS_HEIGHT*conf.screen.scale})
end

-- Create screen frame
local frameImage = resource.get("img/frame.png")
frameImage:setWrap("repeat", "repeat")
local frameQuad = love.graphics.newQuad(
  0, 0,
  conf.screen.width / conf.screen.scale,
  conf.screen.height / conf.screen.scale,
  frameImage:getWidth(), frameImage:getHeight()
)

--Menu spacing values
local mainMenuY = 32*6.5
local subMenuY = 32*6


local buildRoom = function (type, pos, baseMenu)
  menu.disable(baseMenu)

  local buildUtility = builder.new(2, type, pos)
    
  local back = function () end
    
  local function onBuild ()
    event.unsubscribe("pressed", 0, back)
    event.unsubscribe("build", buildUtility, onBuild)
    menu.enable(baseMenu)
    entity.delete(buildUtility)
  end

  back = function (key)
    if key == "b" then
      event.unsubscribe("pressed", 0, back)
      event.unsubscribe("build", buildUtility, onBuild)
      menu.enable(baseMenu)
      entity.delete(buildUtility)
    end
  end

  event.subscribe("pressed", 0, back)
  event.subscribe("build", buildUtility, onBuild)
end

local gui = menu.new(2, mainMenuY)
--The Build button, opens build menu
menu.addButton(gui, menu.newButton("build", function ()
  menu.disable(gui)
  
  --Create the build menu
  local buildMenu = menu.new(2, subMenuY)
  
  --Build Elevator Room
  menu.addButton(buildMenu, menu.newButton("elevator", function ()
    buildRoom("elevator", {roomNum = 4, floorNum = gScrollPos}, buildMenu)
  end))
  --Build Utility Room button
  menu.addButton(buildMenu, menu.newButton("utility", function ()
    buildRoom("utility", {roomNum = 4, floorNum = gScrollPos}, buildMenu)
  end))
  --Build Flower Room button
  menu.addButton(buildMenu, menu.newButton("flower", function ()
    buildRoom("flower", {roomNum = 4, floorNum = gScrollPos}, buildMenu)
  end))
  --Build Heart Room
  menu.addButton(buildMenu, menu.newButton("heart", function ()
    buildRoom("heart", {roomNum = 4, floorNum = gScrollPos}, buildMenu)
  end))
  --Build Tropical Room
  menu.addButton(buildMenu, menu.newButton("tropical", function ()
    buildRoom("tropical", {roomNum = 4, floorNum = gScrollPos}, buildMenu)
  end))

  --The back button deletes the build menu
  menu.setBack(buildMenu, function ()
    entity.delete(buildMenu)
    menu.enable(gui)
  end)
end))

local newFloor = function (level)
  local id = entity.new(STATE_PLAY)
  entity.setOrder(id, -50)
  local pos = {roomNum = .5, floorNum = level }
  entity.addComponent(id, transform.new(id, pos))
  if level > 1 then
    entity.addComponent(id, sprite.new(id, {
      image = resource.get("img/floor.png"),
      width = 256, height = 64, originY = 32,
    }))
  end
  event.notify("floor.new", 0, {level = level, type = "top"})
  return id
end
newFloor(1)

--The Destroy button, for deleting rooms
menu.addButton(gui, menu.newButton("destroy", function ()
  gTopFloor = gTopFloor + 1
  local newFloor = newFloor(gTopFloor)
end))

--The Hire button, for hiring staff
menu.addButton(gui, menu.newButton("hire", function ()
  staff.new()

  --[[ HIRE MENU
  menu.disable(gui)
  --Create the hire menu
  local hireMenu = menu.new(2, subMenuY)

  --Hire a janitor
  menu.addButton(hireMenu, menu.newButton("utility", function ()
    print("Janitor Hired")
  end))

  --The back button deletes the hire menu
  menu.setBack(hireMenu, function ()
	  menu.enable(gui)
    entity.delete(hireMenu)
  end)
  --]]
end))
--The back button, quits the game at the moment
menu.setBack(gui, function ()
  --love.event.push("quit")
  --love.event.push("q")
end)

-- Input training
local controller = entity.new(1)
entity.addComponent(controller, sprite.new(controller, {
  image = resource.get("img/controller.png"),
  width = CANVAS_WIDTH, height = CANVAS_HEIGHT
}))

local inputLocations = {
  a={x=207, y=130},
  b={x=175, y=130},
  left={x=42, y=120},
  right={x=70, y=120},
  up={x=56, y=108},
  down={x=56, y=134},
  start={x=135, y=132},
  select={x=110, y=132},
}
local arrow = entity.new(1)
entity.addComponent(arrow, sprite.new(
  arrow, {
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
event.subscribe("training.current", 0, function (current)
  event.notify("sprite.move", arrow, inputLocations[current])
end)

event.subscribe("training.end", 0, function ()
  event.notify("state.enter", 0, 2)-- BGM
  local bgm = resource.get("snd/gettingfreaky.ogg")
  love.audio.play(bgm)
end)

event.notify("training.begin", 0)
event.notify("training.load", 0)

local floorOccupation = 1

event.subscribe("pressed", 0, function (key)
  if key == "up" and gScrollPos < gTopFloor then
    event.notify("scroll", 0 , gScrollPos + 1)
  elseif key == "down" and gScrollPos > gBottomFloor then
    event.notify("scroll", 0 , gScrollPos - 1)
  end
end)

event.subscribe("build", 0, function (t)
  if t.pos.floorNum == gScrollPos then
    floorOccupation = floorOccupation + 1
  end
end)

event.subscribe("destroy", 0, function (t)
  if t.pos.floorNum == gScrollPos then
    floorOccupation = floorOccupation - 1
  end
end)

-- Font
local font = love.graphics.newImageFont(
  resource.get("img/font.png"),
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890$+-./ "
)

-- Create the hud bar
local hudQuad = love.graphics.newQuad(
  0, 64,
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
hudCom.selected = "build"
hudCom.draw = function (self)
  love.graphics.drawq(
    resource.get("img/hud.png"), hudQuad,
    0, CANVAS_HEIGHT - 32,
    0
  )
  -- draw info
  love.graphics.setColor(255, 255, 255)
  love.graphics.setFont(font)
  love.graphics.printf(
    conf.menu[hudCom.selected].name,
    115, CANVAS_HEIGHT - 26,
    70,
    "left"
  )
  love.graphics.printf(
    conf.menu[hudCom.selected].desc,
    115, CANVAS_HEIGHT - 14,
    70,
    "left"
  )
end
entity.addComponent(hudBar, hudCom)
event.subscribe("menu.info", 0, function (e)
  hudCom.selected = e
end)

-- Create the money display
local moneyDisplay = entity.new(STATE_PLAY)
entity.setOrder(moneyDisplay, 100)
local moneyCom = entity.newComponent()
moneyCom.change = 0
moneyCom.changeTimer = 0
moneyCom.draw = function (self)
  love.graphics.setFont(font)
  love.graphics.printf(
    "$" .. money,
    200, CANVAS_HEIGHT - 26,
    56,
    "right"
  )
  local str = ""
  if self.change > 0 then 
    love.graphics.setColor(0, 88, 0)
    str = "+"..self.change
  elseif self.change < 0 then
    love.graphics.setColor(172, 16, 0)
    str = self.change
  end
  love.graphics.printf(
    str,
    200, CANVAS_HEIGHT - 14,
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
  moneyCom.change = moneyCom.change + e
  moneyCom.changeTimer = 3
end)

-- Create the backdrop
local backdrop = entity.new(STATE_PLAY)
local bdImg = resource.get("img/backdrop.png")
entity.setOrder(backdrop, -100)
local bdCom = entity.newComponent()
bdCom.draw = function (self)
  love.graphics.setColor(188, 184, 252)
  love.graphics.rectangle(
    "fill",
    0, 0,
    CANVAS_WIDTH, CANVAS_HEIGHT
  )
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(
    bdImg,
    0, 160 + (gScrollPos * 32) - bdImg:getHeight(),
    0
  )
end
entity.addComponent(backdrop, bdCom)

love.draw = function ()
  -- Draw to canvas without scaling
  love.graphics.setCanvas(canvas)
  love.graphics.clear()
  if love.graphics.newPixelEffect then
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
    conf.screen.scale, conf.screen.scale
  )
  -- Fill the screen area black for pixel effect
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle(
    "fill", 
    conf.screen.x,
    conf.screen.y,
    CANVAS_WIDTH * conf.screen.scale,
    CANVAS_HEIGHT * conf.screen.scale
  )
  
  if love.graphics.newPixelEffect then
    love.graphics.setPixelEffect(pixelEffect)
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(
    canvas,
    conf.screen.x,
    conf.screen.y,
    0,
    conf.screen.scale,
    conf.screen.scale
  )
end

love.update = function (dt)
  local dt = dt * gGameSpeed
  entity.update(dt)
  input.update(dt)
end

function love.keypressed(key)   -- we do not need the unicode, so we can leave it out
  if key == "escape" then
    love.event.push("quit")   -- actually causes the app to quit
    love.event.push("q")
  elseif key == "f1" then
    event.notify("training.begin", 0)
  else
    input.keyPressed(key)
  end
end

love.keyreleased = function (key)
  input.keyReleased(key)
end

love.joystickpressed = function (joystick, button)
  input.joystickPressed(joystick, button)
end

love.joystickreleased = function (joystick, button)
  input.joystickReleased(joystick, button)
end

