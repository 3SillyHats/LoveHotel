-- resource.lua

local M = {}

local resources = {}

local findPattern = function (text, pattern, start)
  return string.sub(text, string.find(text, pattern, start))
end

local loadRes = {}
loadRes[".png"] = function (name)
  local image = love.graphics.newImage(name)
  image:setFilter("nearest", "nearest")
  return image
end
loadRes[".wav"] = function (name)
  love.audio.newSource(name, "static")
end
loadRes[".mp3"] = function (name)
  love.audio.newSource(name, "streaming")
end
loadRes[".glsl"] = function (name)
  pixelEffect = nil
  local success, result = pcall(function ()
    return love.graphics.newPixelEffect(
        love.filesystem.read(name)
    )
  end)
  if success then
    pixelEffect = result
  end
  return pixelEffect
end
loadRes[".lua"] = function (name)
  local script = love.filesystem.load(name)
  local success, result = pcall(script)
  if success then
    return result
  else
    return nil
  end
end

M.get = function (name)
  if not resources[name] then
    local extension = findPattern(name, "\.[^.]+$")
    resources[name] = loadRes[extension]("resources/" .. name)
  end
  return resources[name]
end


return M
