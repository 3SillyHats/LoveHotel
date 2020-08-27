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
  local snd = love.audio.newSource(name, "static")
  snd:setVolume(0.2)
  return snd
end
loadRes[".ogg"] = function (name)
  local snd = love.audio.newSource(name, "stream")
  snd:setVolume(1)
  snd:setLooping(true)
  return snd
end
loadRes[".mp3"] = function (name)
  local snd = love.audio.newSource(name, "stream")
  snd:setVolume(0.2)
  snd:setLooping(true)
  return snd
end

local vertexcode = [[
    vec4 position( mat4 transform_projection, vec4 vertex_position )
    {
        return transform_projection * vertex_position;
    }
]]

loadRes[".glsl"] = function (name)
  shader = nil
  local success, result = pcall(function ()
    if love.graphics.newShader then
        return love.graphics.newShader(
            love.filesystem.read(name),
            vertecode
        )
    else
        return love.graphics.newPixelEffect(
            love.filesystem.read(name)
        )
    end
  end)
  if success then
    shader = result
  end
  return shader
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
    local extension = findPattern(name, "[.][^.]+$")
    resources[name] = loadRes[extension]("data/" .. name)
  end
  return resources[name]
end


return M
