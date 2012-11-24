-- main.lua

-- Constants
CANVAS_WIDTH = 256
CANVAS_HEIGHT = 224
ROOM_INDENT = 16
FLOOR_OFFSET = 80

local event = require("event")
local entity = require("entity")
local input = require("input")
local resource = require("resource")
local sprite = require ("sprite")
local room = require("room")
local menu = require("menu")

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
  pixelEffect:send("rubyOutputSize", {conf.screen.width, conf.screen.height})
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
local tester = entity.new()
entity.addComponent(tester, sprite.new(
  tester,
  resource.get("img/typing1.png"),
  24, 24,
  {
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
  "idle"
))
entity.addComponent(tester, entity.newComponent({
  update = function (self, dt)
    event.notify("entity.move", tester, {x = 50, y = 50})
    event.notify("sprite.play", tester, "typing")
  end
}))
event.notify("sprite.move", tester, {x = 50, y = 50})

--Myles's Room Test
local roomTest = room.new("Utility", {roomNum = 3, floorNum = 1})
event.notify("scroll", 0, 2)

local gui = menu.new()

-- Begin input training
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

