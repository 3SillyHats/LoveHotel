-- sprite.lua

local event = require("event")
local entity = require("entity")

local M = {}

local draw = function (self)
  if self.flipped then
    love.graphics.drawq(self.image, self.quad, self.x + self.width, self.y, 0, -1, 1, self.originX, self.originY)
  else
    love.graphics.drawq(self.image, self.quad, self.x, self.y, 0, 1, 1, self.originX, self.originY)
  end
end

local update = function (self, dt)
  if not (self.animations or self.playing) then
    self.quad:setViewport(
      0, 0, -- x, y
      self.width, self.height -- width, height
    )
    return
  end
  self.timer = self.timer + dt
  local frameCount = self.animations[self.playing].last -
    self.animations[self.playing].first + 1
  while self.timer >= self.animations[self.playing].speed do
    self.frame = self.frame + 1
    self.timer = self.timer - self.animations[self.playing].speed
  end
  if self.frame >= frameCount then
    if self.animations[self.playing].goto then
      self:play(self.animations[self.playing].goto, self.flipped)
    else
      self.frame = self.frame - frameCount
    end
  end

  local frame = self.frame + self.animations[self.playing].first
  local framesPerRow = self.image:getWidth() / self.width
  self.quad:setViewport(
    (frame % framesPerRow) * self.width, -- x
    math.floor(frame / framesPerRow) * self.height, -- y
    self.width, self.height -- width, height
  )
end

local play = function (self, animation, flipped)
  self.flipped = flipped or false
  if self.playing ~= animation then
      self.playing = animation
      self.frame = 0
      self.timer = 0
  end
end

M.new = function (id, t)
	local sprite = entity.newComponent({
    entity = id,
    x = 0,
    y = 0,
    image = t.image,
    width = t.width,
    height = t.height,
    originX = t.originX or 0,
    originY = t.originY or 0,
    animations = t.animations or nil,
    playing = t.playing or nil,
    frame = 0,
    timer = 0,
    flipped = false,
    quad = love.graphics.newQuad(
      0, 0,
      t.width, t.height,
      t.image:getWidth(), t.image:getHeight()
    ),
    
    draw = draw,
    update = update,
    play = play,
  })
  
  event.subscribe("sprite.move", id, function (e)
    sprite.x = e.x
    sprite.y = e.y
  end)
  
  event.subscribe("sprite.play", id, function (e)
    sprite.playing = e
  end)

  return sprite
end

return M
