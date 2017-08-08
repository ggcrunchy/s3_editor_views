--- Link editing.

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

-- Some sort of cloud of groups, probably made on the fly
-- Nodes moved in and out of those as they're moved around (groups will be somewhat generous, accommodate largest size)
-- Lines in separate groups? (Must allow for large distances, in general... but could use some bounding box analysis...)
-- Search feature? (Based on tag, then on list... essentially what's available now)
-- Would the above make LinkGroup obsolete? Would it promote the search box?

-- Standard library imports --
local ceil = math.ceil
local ipairs = ipairs
local min = math.min
local pairs = pairs
local sort = table.sort
local type = type

-- Modules --
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local morton = require("number_sequences.morton")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- --
local Group

-- --
local Tagged

-- --
local ToRemove

-- --
local ToSort

-- --
local X, Y = 120, 80

-- --
local Index

-- --
local Occupied

-- --
local CellDim

---
-- @pgroup view X
function M.Load (view)
	--
	Group, Index, Occupied, Tagged, ToRemove, ToSort = display.newGroup(), 1, {}, {}, {}, {}

	view:insert(Group)

	local cont = display.newContainer(display.contentWidth - (X + 10), display.contentHeight - (Y + 10))

	Group:insert(cont)

	--
	CellDim = ceil(min(cont.width, cont.height) / 5)

	-- Keep a mostly up-to-date list of tagged objects.
	local links = common.GetLinks()

	links:SetAssignFunc(function(object)
		Tagged[object] = false -- exists but no box yet (might already have links, though)

		object.m_link_index, Index = Index, Index + 1
	end)
	links:SetRemoveFunc(function(object)
		ToRemove[#ToRemove + 1], Tagged[object] = Tagged[object]
	end)

	-- TODO: ^^ Could this be deterministic?
	-- Cloud of links, etc.

	--
	local group, cw, ch = display.newGroup(), cont.width, cont.height

	cont:insert(group)

	group:translate(-cw / 2, -ch / 2)

--	local aa = display.newCircle(group, 20, 60, 35)
--	local bb = display.newCircle(group, 300, 200, 20)

	layout.PutRightOf(cont, X, 5)
	layout.PutBelow(cont, Y, 5)

	-- Draggable thing...
	local drag = display.newRect(Group, cont.x, cont.y, cw, ch)

	drag:addEventListener("touch", touch.DragViewTouch(group))

	drag.isHitTestable, drag.isVisible = true, false

	--
	common_ui.Frame(cont, 1, 0, 1)

	--
	Group.isVisible = false

	help.AddHelp("Link", { cont = cont })
	help.AddHelp("Link", {
		cont =  "Drag boxes to move them, or the background to move the world. Links can be established by dragging from an " ..
				"output node (on the right side) to a linkable input node (left side), or vice versa. Links are broken by " ..
				"clicking the dot on the line between the nodes. TODO: Far apart nodes"
	})
end

--
local function AddLineToGroup (bgroup, sub_group)
	if not sub_group then
		sub_group = display.newGroup()

		bgroup:insert(sub_group)
	end

	return sub_group, sub_group
end

-- Helper to sort objects in creation order
local function SortByIndex (a, b)
	return a.m_link_index < b.m_link_index
end

---
-- @pgroup view X
function M.Enter (view)
	-- Cull any dangling objects and gather up new ones.
	local group = Group[1][1]

	for object, state in pairs(Tagged) do
		if not display.isValid(object) then
			Tagged[object] = nil
		elseif not state then
			ToSort[#ToSort + 1] = object
		end
	end

	-- Remove any dead objects.
	for i = #ToRemove, 1, -1 do
		local state = ToRemove[i]

		if state then
			-- remove any link objects

			state.m_box:removeSelf()

			Occupied[state.m_spot] = Occupied[state.m_spot] - 1
		end

		ToRemove[i] = nil
	end

	-- Dole out spots to any new objects in creation order.
	sort(ToSort, SortByIndex)

	local links, spot = common.GetLinks(), -1
	local tag_db = links:GetTagDatabase()

	for _, object in ipairs(ToSort) do
		-- Find a relatively open spot and claim it.
		repeat
			spot = spot + 1
		until (Occupied[spot] or 0) == 0

		Occupied[spot] = (Occupied[spot] or 0) + 1

		--
		local info, tag = common.AttachLinkInfo(object, nil), links:GetTag(object)
		local bgroup, lgroup, rgroup = display.newGroup()

		group:insert(bgroup)

		for _, sub in tag_db:Sublinks(tag) do
			local iinfo, text = info and info[sub]
			local itype, is_source = iinfo and type(iinfo), tag_db:ImplementedBySublink(tag, sub, "event_source")

			--
			if itype == "table" then
				if iinfo.is_source ~= nil then
					is_source = iinfo.is_source
				end

				text = iinfo.text
			elseif itype == "string" then
				text = iinfo
			end

			--
			local cur

			if is_source then
				rgroup, cur = AddLineToGroup(bgroup, rgroup)
			else
				lgroup, cur = AddLineToGroup(bgroup, lgroup)
			end

			--
			local n = cur.numChildren
			local link = display.newCircle(cur, 0, 0, 5)
			local stext = display.newText(cur, sub, 0, 0, native.systemFont, 12)

			--
			local method, offset

			if is_source then
				method, offset = "PutLeftOf", -5
			else
				method, offset = "PutRightOf", 5
			end

			--
			layout[method](stext, link, offset)

			if text then
				--
			--	layout[method](text, stext, offset)
			end

			--
			for i = n > 0 and cur.numChildren or 0, n + 1, -1 do
				layout.PutBelow(cur[i], cur.m_prev, 5)
			end

			cur.m_prev = link
		end

		-- Make a new box at this spot.
		local sx, sy = morton.MortonPair(spot)
		local box
		-- (sx + .5) * CellDim, (sy + .5) * CellDim

		--
		Tagged[object], object.m_link_index = { m_box = box, m_spot = spot }
	end

	-- Now that our objects all exist, wire up any links and clear the list.
	for i = #ToSort, 1, -1 do
		-- add any already-existing links (if a scene was loaded)

		ToSort[i] = nil
	end

	--
	Group.isVisible = true

	help.SetContext("Link")
end

--- DOCMAYBE
function M.Exit ()
	-- Tear down link groups

	Group.isVisible, Index = false, 1
end

--- DOCMAYBE
function M.Unload ()
	Group, Occupied, Tagged, ToRemove, ToSort = nil
end

-- Export the module.
return M