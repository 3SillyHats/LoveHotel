-- inspector.lua
-- GUI element for inspecting the properties of staff and clients

--Load required files and such
local entity = require("entity")
local resource = require("resource")
local event = require("event")
local sprite = require("sprite")
local transform = require("transform")
local client = require("client")
local staff = require("staff")

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
    inspectClients = false,
    update = function (self, dt)
      local clients = client.getAll()
      local staff = staff.getAll()
      if #clients > 0 or #staff > 0 then
        local max
        if inspectClients then
          max = #clients
        else
          max = #staff
        end
        while self.selected < 1 or self.selected > max do
          if self.selected < 1 then
            inspectClients = not inspectClients
            if inspectClients then
              max = #clients
            else
              max = #staff
            end
            self.selected = max
          elseif self.selected > max then
            inspectClients = not inspectClients
            if inspectClients then
              max = #clients
            else
              max = #staff
            end
            self.selected = 1
          end
        end
        local target = nil
        if inspectClients then
          target = clients[self.selected]
        else
          target = staff[self.selected]
        end
        local pos = transform.getPos(target.id)
        event.notify("entity.move", self.entity, pos)
        local name = "none"
        local desc = "none"
        if target.ai.currentGoal then
          name = target.ai.currentGoal.name
          local g = target.ai.currentGoal
          if #g.subgoals > 0 then
            while #g.subgoals > 0 do
              g = g.subgoals[1]
            end
            desc = g.name
          end
        end
        event.notify("menu.info", 0, {
          name = name,
          desc = desc,
        })
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
