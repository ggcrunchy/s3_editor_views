--- Management of link view objects.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Exports --
local M = {}

-- Standard library imports --
local pairs = pairs
local ipairs = ipairs
local sort = table.sort

-- Corona globals --
local display = display

--
--
--

local Index, Tagged, ToRemove, ToSort

--- DOCME
function M.AssociateBoxAndObject (object, box, name)
	Tagged[object], object.m_link_index = { m_box = box, m_name = name }
end

--- DOCME
function M.GetBox (object)
	return Tagged[object].m_box
end

local function AuxRemovingIter (t, n)
	while n > 0 do
		local object = t[n]

		n, t[n] = n - 1

		if object then
			return n, object
		end
	end
end

local function SortByIndex (a, b)
	return a.m_link_index < b.m_link_index
end

--- DOCME
function M.IterateNewObjects (how)
	if how == "remove" then
		return AuxRemovingIter, ToSort, #ToSort
	else
		sort(ToSort, SortByIndex)

		return ipairs(ToSort)
	end
end

--- DOCME
function M.IterateRemovedObjects ()
	return AuxRemovingIter, ToRemove, #ToRemove
end

local function OnAssign (object)
	Tagged[object] = false -- exists but no box yet (might already have links, though)

	-- has template sublinks?
		-- attach appropriate box(es) (or get data ready, anyhow)
		-- put appropriate data in instance <-> label map

	object.m_link_index, Index = Index, Index + 1
end

local function OnRemove (object)
	ToRemove[#ToRemove + 1], Tagged[object] = Tagged[object]

	-- has template sublinks?
		-- remove instance / label from map
end

--- DOCME
function M.Load (links)
	Index, Tagged, ToRemove, ToSort = 1, {}, {}, {}

	links:SetAssignFunc(OnAssign)
	links:SetRemoveFunc(OnRemove)
end

--- DOCME
function M.Refresh ()
	Index = 1

	-- Cull any dangling objects and gather up new ones.
	for object, state in pairs(Tagged) do
		if not display.isValid(object) then
			Tagged[object] = nil
		elseif not state then
			ToSort[#ToSort + 1] = object
		end
	end

--[[
	local name = common.GetValuesFromRep(object).name

	if state.m_name.text ~= name then
		state.m_name.text = name
		-- TODO: might need resizing :/
		-- TODO: probably needs a Runtime event
	end
]]
end

--- DOCME
function M.Unload ()
	Tagged, ToRemove, ToSort = nil
end

-- Export the module.
return M