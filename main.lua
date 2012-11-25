-- main.lua

-- Constants
CANVAS_WIDTH = 256
CANVAS_HEIGHT = 224
ROOM_INDENT = 32*0.5
FLOOR_OFFSET = 32*2.5

local event = require("event")
local entity = require("entity")
local input = require("input")
local resource = require("resource")
local sprite = require ("sprite")
local room = require("room")
local menu = require("menu")
local ai = require("ai")

conf = {}

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

-- XXX: Test entity
local tester = entity.new(2)
entity.addComponent(tester, sprite.new(
  tester, {
    image = resource.get("img/typing1.png"),
    width = 24, height = 24,
    animations = {
      idle = {
        first = 0,
        last = 0,
        speed = 1,
      },
      typing = {
        first = 0,
        last = 3,
        speed = .1,
      },
    },
    playing = "idle"
  }
))
entity.addComponent(tester, entity.newComponent({
  update = function (self, dt)
    event.notify("entity.move", tester, {x = 50, y = 50})
    event.notify("sprite.play", tester, "typing")
  end
}))
entity.addComponent(tester, ai.new(tester, {
  subgoals = {
    ai.newMoveToGoal({x = 0, y = 0})
  }
}))

--Myles's Room Test
local roomTest = room.new(2, "Utility", {roomNum = 3, floorNum = 1})
event.notify("scroll", 0, 2)

local gui = menu.new(2, 32*6)
menu.addButton(gui, menu.newButton("build", function ()
  print("Hello")
  local buildMenu = menu.new(2, 32*5)

  menu.addButton(buildMenu, menu.newButton("build", function ()
    print("Building in Build")
  end))

  menu.setBack(buildMenu, function ()
    entity.delete(buildMenu)
  end)
end))
menu.addButton(gui, menu.newButton("destroy", function ()
  print("World")
end))
menu.addButton(gui, menu.newButton("hire", function ()
  print("You're Hired!")
end))
menu.setBack(gui, function ()
  --love.event.push("quit")   -- actually causes the app to quit
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

local endTraining = function()
  event.notify("state.enter", 0, 2)
  event.unsubscribe("training.end", 0, endTraining)
end
event.subscribe("training.end", 0, endTraining)

event.notify("training.begin", 0)

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
  entity.update(dt)
  input.update(dt)
end

function love.keypressed(key)   -- we do not need the unicode, so we can leave it out
  if key == "escape" then
    love.event.push("quit")   -- actually causes the app to quit
    love.event.push("q")
  end
  input.keyPressed(key)
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

