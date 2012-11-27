
local event = require("event")
local entity = require("entity")
local sprite = require("sprite")
local resource = require("resource")
local ai = require("ai")
local transform = require("transform")
local room = require("room")

local M = {}

M.new = function (target)
  local id = entity.new(2)
  entity.setOrder(id, 50)
  isMale = math.random(0,1)  --randomize male or female
  nudeimg = "resources/img/people_parts"
  hairimg = "resources/img/people_parts"
  topimg = "resources/img/people_parts"
  bottomimg = "resources/img/people_parts"
  if isMale==1 then
    nudeimg = nudeimg .. "/man/nude/"
    hairimg = hairimg .. "/man/hair/"
    topimg = topimg .. "/man/top/"
    bottomimg = bottomimg .. "/man/bottom/"
  else
    nudeimg = nudeimg .. "/woman/nude/"
    hairimg = hairimg .. "/woman/hair/"
    topimg = topimg .. "/woman/top/"
    bottomimg = bottomimg .. "/woman/bottom/"
  end
  nudes = love.filesystem.enumerate(nudeimg)
  hairs = love.filesystem.enumerate(hairimg)
  tops = love.filesystem.enumerate(topimg)
  bottoms = love.filesystem.enumerate(bottomimg)
  nudeimg = nudeimg .. nudes[math.random(1,#nudes)] --randomize skin colour, hair, clothes
  hairimg = hairimg .. hairs[math.random(1,#hairs)]
  topimg = topimg .. tops[math.random(1,#tops)] 
  bottomimg = bottomimg .. bottoms[math.random(1,#bottoms)]
  nudeimg = string.sub(nudeimg,10)        --remove "resources/"
  hairimg = string.sub(hairimg,10)
  topimg = string.sub(topimg,10)
  bottomimg = string.sub(bottomimg,10)
  haircolour = math.random(0,3)
      --add skin
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(nudeimg),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
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
      },
      playing = "idle",
    }
  ))  --add bottom
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(bottomimg),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
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
      },
      playing = "idle",
    }
  ))  --add top
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(topimg),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
        idle = {
          first = 0,
          last = 0,
          speed = 1,
        },
        walking = {
          first = 0,
          last = 0,
          speed = 1,
        },
      },
      playing = "idle",
    }
  ))  --add hair
  entity.addComponent(id, sprite.new(
    id, {
      image = resource.get(hairimg),
      width = 24, height = 24,
      originX = 8, originY = 24,
      animations = {
        neat = {
          first = haircolour,
          last = haircolour,
          speed = 1,
        },
        messy = {
          first = haircolour + 4,
          last = haircolour + 4,
          speed = 1,
        },
      },
      playing = "neat",
    }
  ))

  local pos = {roomNum = -.5, floorNum = 1}
  entity.addComponent(id, transform.new(
    id, pos, {x = 16, y = 30}
  ))
  local aiComponent = ai.new(id)
  entity.addComponent(id, aiComponent)
  aiComponent:addVisitGoal(target)
  
  local check = function (t)
    local epos = room.getPos(id)
    if t.floorNum == epos.floorNum and t.roomNum < epos.roomNum + 0.5 and t.roomNum + t.width > epos.roomNum + 0.5 then
      t.callback(id)
    end
  end
  
  event.subscribe("actor.check", 0, check)

  local function delete (e)
    event.unsubscribe("actor.check", 0, check)
    event.unsubscribe("delete", id, delete)
  end

  event.subscribe("delete", id, delete)
  
  return id
end

local spawner = entity.new(2)
local itime = math.random(SPAWN_MIN, SPAWN_MAX)
local com = entity.newComponent({
  timer = itime,
  timer2 = itime + .25,
  target = nil,
  pick_room = function (self)
    local rooms = {}
    event.notify("room.unoccupied", 0, function (id,type)
      table.insert(rooms,{id=id, type=type})
    end)
    if #rooms > 0 then
      self.target = rooms[math.random(1,#rooms)].id
    else
      self.target = nul
    end
  end,
  spawn = function (self)
    if self.target then
      M.new(self.target)
    end
  end,
  update = function (self, dt)
    if self.timer <= 0 then
      self.timer = math.random(SPAWN_MIN, SPAWN_MAX)
      self.pick_room(self)
      self.spawn(self)
    else
      self.timer = self.timer - dt
    end
    if self.timer2 <= 0 then
      self.timer2 = self.timer + .25
      self.spawn(self)
    else
      self.timer2 = self.timer2 - dt
    end
  end,
})
entity.addComponent(spawner, com)

return M
