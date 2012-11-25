-- sprite.lua

local event = require("event")
local entity = require("entity")

local M = {}

local draw = function (self)
  if not self.hidden then
    love.graphics.setColor(255,255,255)
    if self.flipped then
      love.graphics.drawq(self.image, self.quad, self.x, self.y, 0, -1, 1, self.originX, self.originY)
    else
      love.graphics.drawq(self.image, self.quad, self.x, self.y, 0, 1, 1, self.originX, self.originY)
    end
  end
end

local update = function (self, dt)
  if not self.animations or not self.playing then
    self.quad:setViewport(
      0, 0, -- x, y
      self.width, self.height -- width, height
    )
    return
  end
  self.timer = self.timer + dt
  local anim = self.animations[self.playing]
  local frameCount = math.abs(anim.last - anim.first) + 1
  while self.timer >= self.animations[self.playing].speed do
    self.frame = self.frame + 1
    self.timer = self.timer - self.animations[self.playing].speed
  end
  while self.frame >= frameCount do
    if self.animations[self.playing].goto then
      self:play(self.animations[self.playing].goto, self.flipped)
    else
      self.frame = self.frame - frameCount
    end
  end

  anim = self.animations[self.playing]
  local frame = anim.frames[self.frame + 1]
  local framesPerRow = self.image:getWidth() / self.width
  self.quad:setViewport(
    (frame % framesPerRow) * self.width, -- x
    math.floor(frame / framesPerRow) * self.height, -- y
    self.width, self.height -- width, height
  )
end

local play = function (self, animation)
  if self.animations[animation] and self.playing ~= animation then
      self.playing = animation
      self.frame = 0
      self.timer = 0
  end
end

local flip = function (self, f)
  if f == nil then
    self.flipped = not self.flipped
  else
    self.flipped = f and true
  end
end

local hide = function (self, h)
  self.hidden = h and true
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
    hidden = false,
    quad = love.graphics.newQuad(
      0, 0,
      t.width, t.height,
      t.image:getWidth(), t.image:getHeight()
    ),
    
    draw = draw,
    update = update,
    play = play,
    flip = flip,
    hide = hide,
  })
  
  -- Setup arrays of animation frames
  if sprite.animations then
    for _, anim in pairs(sprite.animations) do
      local frameCount = math.abs(anim.last - anim.first) + 1
      anim.frames = {}
      if anim.first < anim.last then
        for i = 0, frameCount - 1 do
          table.insert(anim.frames, anim.first + i)
        end
      else
        for i = 0, frameCount - 1 do
          table.insert(anim.frames, anim.first - i)
        end
      end
    end
  end
  
  local move = function (e)
    sprite.x = e.x
    sprite.y = e.y
  end
  
  local play = function (e)
    sprite:play(e)
  end
  
  local flip = function (e)
    sprite:flip(e)
  end
  
  local hide = function (e)
    sprite:hide(e)
  end
  
  local function delete (e)
    event.unsubscribe("sprite.move", id, move)
    event.unsubscribe("sprite.play", id, play)
    event.unsubscribe("sprite.flip", id, flip)
    event.unsubscribe("sprite.hide", id, hide)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("sprite.move", id, move)
  event.subscribe("sprite.play", id, play)
  event.subscribe("sprite.flip", id, flip)
  event.subscribe("sprite.hide", id, hide)
  event.subscribe("delete", id, delete)

  return sprite
end

return M
