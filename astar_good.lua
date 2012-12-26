--[[
Copyright 2012 Michael Kosler <marekkpie@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.
--]]

-- Use this version in any projects you want to use LoveAStar in.

binary_heap = require "binary_heap"

--- Toggle off the pathMap toggles to set up for the next call
-- @param pathMap:		the flattened path map
-- @param openSet:		the open set
-- @param closedSet:	the closed set
local function cleanPathMap(pathMap, openSet, closedSet)
	for _,v in pairs(openSet) do
		if type(v) == "table" then
			pathMap[v.value.pathLoc].open = false
		end
	end
	for _,v in pairs(closedSet) do
		pathMap[v.pathLoc].closed = false
	end
end

--- Constructs the found path. This works in reverse from the 
--- pathfinding algorithm, by using parent values and the associated
--- location of that parent on the closed set to jump around until it
--- returns to the start node's position.
-- @param closedSet:	the closed set
-- @param startPos:		the position of the start node
-- #returns path:	the found path
local function buildPath(closedSet, startPos)
	local path = {closedSet[#closedSet]}
	while path[#path].pathLoc ~= startPos do
		table.insert(path, closedSet[path[#path].pCloseLoc])
	end
	return path
end

--- The A* search algorithm. Using imported heuristics and distance values
--- between individual nodes, this finds the shortest path from the start
--- node's position to the exit node's position.
-- @param pathMap:	the flattened path map
-- @param startPos:	the start node's position, relative to the pathMap
-- @param exitPos:	the exit node's position, relative to the pathMap
-- #returns path:	the found path (or empty if it failed to find a path)
function startPathing(pathMap, startPos, exitPos)
	pathMap[startPos].parent = pathMap[startPos]
	-- Initialize the gScore and fScore of the start node
	pathMap[startPos].gScore = 0
	pathMap[startPos].fScore =
		pathMap[startPos].gScore + pathMap[startPos].hScore
	-- Toggle the open trigger on pathMap for the start node
	pathMap[startPos].open = true
	-- Initialize the openSet and add the start node to it
	local openSet = binary_heap:new()
	openSet:insert(pathMap[startPos].fScore, pathMap[startPos])
	-- Initialize the closedSet and the testNode
	local closedSet = {}
	local testNode = {}
	
	-- The main loop for the algorithm. Will continue to check as long as
	-- there are open nodes that haven't been checked.
	while #openSet > 0 do
		-- Find the next node with the best fScore
		_, testNode = openSet:pop()
		pathMap[testNode.pathLoc].open = false
		-- Add that node to the closed set
		pathMap[testNode.pathLoc].closed = true
		table.insert(closedSet, testNode)
		-- Check to see if that is the exit node's position
		if closedSet[#closedSet].pathLoc == exitPos then
			-- Clean the path map
			cleanPathMap(pathMap, openSet, closedSet)
			-- Return the build path and total cost
			return buildPath(closedSet, startPos), pathMap[exitPos].gScore
		end
		
		-- Check all the (pre-assigned) neighbors. If they are not closed 
		-- already, then check to see if they are either not on the open
		-- or if they are on the open list, but their currently assigned
		-- distance score (either given to them when they were first added
		-- or reassigned earlier) is greater than the distance score that
		-- goes through the current test node. If either is true, then
		-- calculate their fScore and assign the current test node as their
		-- parent
		for k,v in pairs(testNode.neighbors) do
			if not pathMap[v].closed then
				local tempGScore = testNode.gScore + testNode.distance[k]
				if not pathMap[v].open then
					pathMap[v].open = true
					pathMap[v].parent = testNode
					pathMap[v].pCloseLoc = #closedSet
					pathMap[v].gScore = tempGScore
					pathMap[v].fScore = 
						pathMap[v].hScore + tempGScore
					openSet:insert(pathMap[v].fScore, pathMap[v])
				elseif tempGScore < pathMap[v].gScore then
					pathMap[v].parent = testNode
					pathMap[v].gScore = tempGScore
					pathMap[v].fScore = 
						pathMap[v].hScore + tempGScore
				end
			end
		end
	end
	-- Returns nil if it failed to find any path to the exit node
	return nil
end

--======================================================================
-- Helper functions for easier plug-in to other games
--======================================================================

function newNode(pathLoc, hScore, neighbors, distance)
	assert(type(pathLoc) == "number", "bad arg #1: needs number")
	assert(type(hScore) == "number", "bad arg #2: needs number")
	assert(type(neighbors) == "table", "bad arg #3: needs table")
	assert(type(distance) == "table", "bad arg #4: needs number")
	local n = {
		pathLoc = pathLoc,
		hScore = hScore,
		neighbors = neighbors,
		distance = distance,
	}
	return n
end































