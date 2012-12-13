-- inspector.lua
-- GUI element for inspecting the properties of staff and clients

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")
local client = require("client")

--Create the module
local M = {}

--Constructor
M.new = function (state)
  --Create an entity and get the id for the new room
  local id = entity.new(state)
  entity.setOrder(id, 100)

  --Add sprite component
  entity.addComponent(id, sprite.new(
    id, {
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
      originX = 12-16,
      originY = 24-32+24,
    }
  ))
  entity.addComponent(id, transform.new(id, {roomNum = gRoomNum, floorNum = gScrollPos}))
  --Add position component
  entity.addComponent(id, transform.new(id, {roomNum = gRoomNum, floorNum = gScrollPos}))
  
  --Add demolisher component (including outline)
  demolishUtility = entity.newComponent({
    entity = id,
    selected = 1,
    update = function (self, dt)
      local clients = client.getAll()
      if #clients > 0 then
        self.selected = math.max(1, math.min(#clients, self.selected))
        local pos = transform.getPos(clients[self.selected].id)
        event.notify("entity.move", self.entity, pos)
        if clients[self.selected].ai.currentGoal then
          event.notify("menu.info", 0, {
            name = "Info",
            desc = clients[self.selected].ai.currentGoal.name,
          })
        end
      end
    end,
  })
  
  entity.addComponent(id, demolishUtility)
  
  local pressed = function (key)
    if gState == STATE_PLAY then
      if key == "left" then
        demolishUtility.selected = demolishUtility.selected - 1
      elseif key == "right" then
        demolishUtility.selected = demolishUtility.selected + 1
      end
    end
  end


  local delete
  delete = function ()
    event.unsubscribe("pressed", 0, pressed)
    event.unsubscribe("delete", id, delete)
  end
  
  event.subscribe("pressed", 0, pressed)
  event.subscribe("delete", id, delete)
  --Function returns the rooms id
  return id
end

--Return the module
return M
