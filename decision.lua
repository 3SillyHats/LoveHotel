-- decision.lua

local event = require("event")
local entity = require("entity")
local input = require("input")

local M = {}

local decisions = {
  skySpawn = {
    prompt = "Skyfarers are arriving at Love Hotel!" ..
    "\nThey are highly influential so show them a good time.",
    alert = true,
  },
  groundSpawn = {
    prompt = "Devilspawn are arriving at Love Hotel!" ..
    "\nThey didn't think to bring condoms but they're all horny.",
    alert = true,
  },
  spaceSpawn = {
    prompt = "Starfarers are arriving at Love Hotel!" ..
    "\nThey have tons of space cash, so lighten their return trip by taking.",
    alert = true,
  },
  star1 = {
    prompt = "Love Hotel is a luxury hotel for couples. Grow your business " ..
    "by satisfying clients and keeping supplies in stock. Become the best " ..
    "romantic hotel in the world!",
    alert = true,
  },
  star2 = {
    prompt = "Good job - 2 stars!\nYou can now build " ..
    "Condom Machines, Spoon suites and Balloon suites.",
    alert = true,
  },
  star3 = {
    prompt = "Nice work - 3 stars!\nYou can now hire Cooks and build " ..
    "Dining Rooms, Kitchens, Receptions and Chocolate Moustache suites." ..
    "\nBut now people will be upset if they run out of condoms!",
    alert = true,
  },
  star4 = {
    prompt = "Excellent - 4 stars!\nYou can now hire Stockers and build " ..
    "Torture suites and Freezers to speed up cooking time." ..
    "\nBut now people will be upset if they get too hungry!",
    alert = true,
  },
  star5 = {
    prompt = "Amazing - 5 stars!\nYou can now build " ..
    "Nazi Furry suites and Spas so people can have a good time." ..
    "\nGet to 6 stars to become the best love hotel in the world!",
    alert = true,
  },
  treasure = {
    prompt = "While digging out the new floor the construction crew " ..
    "found a buried chest full of treasure. Even after giving the " ..
    "crew a cut, you've earned $20,000!",
    alert = function ()
      moneyChange(20000)
    end,
  },
}

-- Create and reuse the same decision menu entity
local decisionMenu = entity.new(STATE_DECISION)
local decisionCom = entity.newComponent({
  decision = nil,
  selected = nil,
  result = nil,
  
  draw = function (self)
    love.graphics.setFont(gFont)
    love.graphics.setColor(255, 255, 255)
    
    if self.result then
      love.graphics.printf(
        self.result,
        8, 96,
        240,
        "center"
        )
    else
      love.graphics.printf(
      self.decision.prompt,
      8, 32,
      240,
      "center"
      )

      if self.decision.alert then
      love.graphics.printf(
          "Press START to continue",
          8, 128,
          240,
          "center"
        )
      else
        for i,option in ipairs(self.decision.options) do
          if i == self.selected then
            love.graphics.setColor(255, 255, 255)
          else
            love.graphics.setColor(89, 89, 89)
          end
          love.graphics.printf(
            option.text,
            8, 128 + (16 * i),
            240,
            "center"
          )
        end
      end
    end
  end,
})
entity.addComponent(decisionMenu, decisionCom)

-- Bring up the decision screen
M.prompt = function (decision)
  decisionCom.decision = decisions[decision]
  decisionCom.selected = 1
  decisionCom.result = nil
  event.notify("state.enter", 0, STATE_DECISION)
end
event.subscribe("decision.prompt", 0, function (e)
  M.prompt(e.decision)
end)

M.confirm = function (prompt, action)
  decisionCom.decision = {
    prompt = prompt,
    options = {
      {
        text = "Yes",
        func = action,
      },
      {
        text = "No",
        func = nil,
      },
    },
  }
  decisionCom.selected = 2
  decisionCom.result = nil
  event.notify("state.enter", 0, STATE_DECISION)
end

-- Handle input on decision screen
event.subscribe("pressed", 0, function (button)
  if gState == STATE_DECISION then
    if decisionCom.decision.alert then
      if button == "start" then
        if type(decisionCom.decision.alert) == "function" then
          decisionCom.decision.alert()
        end
        event.notify("state.enter", 0, STATE_PLAY)
      end
    elseif button == "a" then
      if decisionCom.result then
        event.notify("state.enter", 0, STATE_PLAY)
      else
        local func = decisionCom.decision.options[decisionCom.selected].func
        if func then
          decisionCom.result = func()
        end
        if not decisionCom.result then
          event.notify("state.enter", 0, STATE_PLAY)
        end
      end
    elseif button == "up" then
      decisionCom.selected = math.max(1, decisionCom.selected - 1)
    elseif button == "down" then
      decisionCom.selected = math.min(#decisionCom.decision.options,
          decisionCom.selected + 1)
    end
    return true
  end
end)

-- Setup some handlers to prompt decisions
local topStar = 0
event.subscribe("stars", 0, function (stars)
  if stars > topStar then
    topStar = stars
    M.prompt("star" .. topStar)
  end
end)
event.subscribe("floor.new", 0, function (level)
  if level == TREASURE_LEVEL then
    M.prompt("treasure")
    return
  elseif level == SKY_SPAWN then
    M.prompt("skySpawn")
    return
  elseif level == GROUND_SPAWN then
    M.prompt("groundSpawn")
    return
  elseif level == SPACE_SPAWN then
    M.prompt("spaceSpawn")
    return
  end
end)

return M
