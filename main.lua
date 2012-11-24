-- main.lua

-- Constants
CANVAS_WIDTH = 256
CANVAS_HEIGHT = 224

local event = require("event")
local entity = require("entity")
local res = require("res")
local sprite = require ("sprite")

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
love.graphics.setDefaultImageFilter("nearest", "nearest")
love.graphics.setBackgroundColor(0, 0, 0)

-- Create the canvas
canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
canvas:setFilter("nearest", "nearest")

-- Create the pixel effect
pixelEffect = res.get("pfx/nes.glsl")
pixelEffect:send("rubyTextureSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
pixelEffect:send("rubyInputSize", {CANVAS_WIDTH, CANVAS_HEIGHT})
pixelEffect:send("rubyOutputSize", {conf.screen.width, conf.screen.height})

-- XXX: Test entity
local tester = entity.new()
entity.addComponent(tester, sprite.new(
  tester,
  res.get("img/typing1.png"),
  24, 24,
  {
    idle = {
      first = 0,
      last = 3,
      speed = .1,
    },
  },
  "idle"
))
entity.addComponent(tester, entity.newComponent({
  update = function (self, dt)
    event.notify("sprite.play", tester, "idle")
  end
}))
event.notify("entity.move", tester, {x = 50, y = 50})

love.draw = function ()
  -- Draw to canvas without scaling
  love.graphics.setCanvas(canvas)
  love.graphics.clear()
  love.graphics.setPixelEffect()

  entity.draw()
  
  -- Draw to screen with scaling
  love.graphics.setCanvas()
  love.graphics.setPixelEffect(pixelEffect)
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
end

-- XXX: temporary fix
function love.keypressed(key)   -- we do not need the unicode, so we can leave it out
  if key == "escape" then
    love.event.push("quit")   -- actually causes the app to quit
  end
end
