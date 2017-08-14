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
local max = math.max
local min = math.min
local next = next
local pairs = pairs
local sort = table.sort
local type = type

-- Modules --
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local grid = require("tektite_core.array.grid")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local link_group = require("corona_ui.widgets.link_group")
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
local ItemGroup

-- --
local LinkLayer

-- --
local Links

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

-- --
local X0, Y0

-- --
local XOff, YOff

-- Box drag listener --
local DragTouch

--
local function GetCells (box)
	local x, y, hw, hh = box.x, box.y, box.contentWidth / 2, box.contentHeight / 2
	local col1, row1 = grid.PosToCell(x - hw, y - hh, CellDim, CellDim)
	local col2, row2 = grid.PosToCell(x + hw, y + hh, CellDim, CellDim)

	return col1 - 1, row1 - 1, col2 - 1, row2 - 1
end

--
local function AddToCell (box)
	local col1, row1, col2, row2 = GetCells(box)

	for num in morton.Morton2_LineY(col1, row1, row2) do
		for col = col1, col2 do
			local cell = Occupied[num] or {}

			Occupied[num], num, cell[box] = cell, morton.MortonPairUpdate_X(num, col + 1), true
		end
	end
end

--
local function RemoveFromCell (box)
	local col1, row1, col2, row2 = GetCells(box)

	for num in morton.Morton2_LineY(col1, row1, row2) do
		for col = col1, col2 do
			local cell = Occupied[num]

			if cell then
				cell[box] = nil
			end

			num = morton.MortonPairUpdate_X(num, col + 1)
		end
	end
end

--
local function Connect (_, link1, link2, node)
	node.m_link = common.GetLinks():LinkObjects(link1.m_obj, link2.m_obj, link1.m_sub, link2.m_sub)
end

-- Lines (with "break" option) shown in between
local NodeTouch = link_group.BreakTouchFunc(function(node)
	node.m_link:Break()
end)

--
local function ConnectObjects (object, node)
	local links = common.GetLinks()
--[[
	for _, item, _, sub in BoxItems() do
		for link in links:Links(object, sub) do
			local obj, osub = link:GetOtherObject(object)

			if obj == Rep and osub == Sub then
				local join = link_group.Connect(item, node, NodeTouch, Links:GetGroups())

				join.m_link = link
			end
		end
	end]]
end

-- --
local CellFrac = .75

-- --
local NCells = ceil(1 / CellFrac) + 1

---
-- @pgroup view X
function M.Load (view)
	--
	Group, ItemGroup, LinkLayer = display.newGroup(), display.newGroup(), display.newGroup()
	Index, Occupied, Tagged, ToRemove, ToSort = 1, {}, {}, {}, {}

	view:insert(Group)

	local cont = display.newContainer(display.contentWidth - (X + 10), display.contentHeight - (Y + 10))

	Group:insert(cont)

	--
	CellDim = ceil(CellFrac * min(cont.width, cont.height))

	-- Keep a mostly up-to-date list of tagged objects.
	local links = common.GetLinks()

	links:SetAssignFunc(function(object)
		Tagged[object] = false -- exists but no box yet (might already have links, though)

		object.m_link_index, Index = Index, Index + 1
	end)
	links:SetRemoveFunc(function(object)
		ToRemove[#ToRemove + 1], Tagged[object] = Tagged[object]
	end)

	--
	local cw, ch = cont.width, cont.height

	cont:insert(ItemGroup)

	X0, Y0, XOff, YOff = -cw / 2, -ch / 2, 0, 0

	ItemGroup:translate(X0, Y0)

	cont:insert(LinkLayer)

	LinkLayer:translate(X0 - (X + 5), Y0 - (Y + 5))

	layout.PutRightOf(cont, X, 5)
	layout.PutBelow(cont, Y, 5)

	--
	DragTouch = touch.DragParentTouch_Child(1, {
		clamp = "max", ref = "object",

		on_move = function(_, box)
			RemoveFromCell(box)
			AddToCell(box)
		end
	})

	-- Draggable thing...
	local drag = display.newRect(Group, cont.x, cont.y, cw, ch)

	drag:addEventListener("touch", touch.DragViewTouch(ItemGroup, {
		x0 = "cur", y0 = "cur", xclamp = "view_max", yclamp = "view_max",

		on_move = function(ig)
			XOff, YOff = X0 - ig.x, Y0 - ig.y
		end
	}))
	drag:toBack()

	drag.isHitTestable, drag.isVisible = true, false

	--
	local seen = {}

	local function AddFromGroup (items, group)
		for i = 1, group.numChildren do
			items[#items + 1] = group[i]
		end
	end

	Links = link_group.LinkGroup(LinkLayer, Connect, NodeTouch, {
		-- Can Link --
		can_link = function(link1, link2)
			return common.GetLinks():CanLink(link1.m_obj, link2.m_obj, link1.m_sub, link2.m_sub)
		end,

		-- Gather --
		gather = function(items)
			local col1, row1 = grid.PosToCell(XOff, YOff, CellDim, CellDim)

			for num in morton.Morton2_LineY(col1 - 1, row1 - 1, row1 + NCells - 2) do
				for i = 0, NCells - 1 do
					local cell = Occupied[num]

					if cell then
						for box in pairs(cell) do
							if not seen[box] then
								AddFromGroup(items, box.m_lgroup)
								AddFromGroup(items, box.m_rgroup)

								seen[box] = true
							end
						end
					end

					num = morton.MortonPairUpdate_X(num, col1 + i)
				end
			end

			--
			for k in pairs(seen) do
				seen[k] = nil
			end
		end
	})

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
local function Align (group, is_rgroup)
	local w = group.m_w

	for i = 1, group.numChildren do
		local object = group[i]
		local dx = w - object.m_w

		if is_rgroup then
			object.x = object.x + dx
		else
			object.x = object.x - dx
		end
	end
end

--
local function FindBottom (group)
	local y2, n = 0, group.numChildren
	local line = n > 0 and group[n].m_line

	for i = n, 1, -1 do
		local object = group[i]

		if object.m_line ~= line then
			break
		else
			y2 = max(y2, object.y + object.height / 2)
		end
	end

	return y2
end

-- --
local BoxID = 0

--
local function AddObjectBox (group, tag_db, tag, object, sx, sy)
	local info, name, bgroup = common.AttachLinkInfo(object, nil), common.GetValuesFromRep(object).name, display.newGroup()

	group:insert(bgroup)

	local lgroup, rgroup = display.newGroup(), display.newGroup()

	bgroup:insert(lgroup)
	bgroup:insert(rgroup)

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
		local cur = is_source and rgroup or lgroup
		local n = cur.numChildren
		local link = display.newCircle(cur, 0, 0, 5)
		local stext = display.newText(cur, sub, 0, 0, native.systemFont, 12)

		link.strokeWidth = 3

		--
		local method, offset, lo, ro

		if is_source then
			method, offset, lo, ro = "PutLeftOf", -5, stext, link
		else
			method, offset, lo, ro = "PutRightOf", 5, link, stext
		end

		--
		layout[method](stext, link, offset)

		if text then
			-- hook up some touch listener, change appearance
		end

		--
		Links:AddLink(BoxID, not is_source, link)

		link.m_obj, link.m_sub = object, sub

		--
		local w, line = layout.RightOf(ro) - layout.LeftOf(lo), (cur.m_line or 0) + 1

		cur.m_w = max(cur.m_w or 0, w)

		for i = n + 1, cur.numChildren do
			local object = cur[i]

			if line > 1 then
				layout.PutBelow(object, cur.m_prev, 5)
			else
				cur.m_y1 = min(cur.m_y1 or 0, object.y - object.height / 2)
			end

			object.m_w = w
		end

		cur.m_line, cur.m_prev = line, link
	end

	--
	local w, y1, y2 = lgroup.m_w

	if w and rgroup.m_w then
		w = w + rgroup.m_w
		y1 = min(lgroup.m_y1, rgroup.m_y1)
		y2 = max(FindBottom(lgroup), FindBottom(rgroup))
	elseif w then
		y1, y2 = lgroup.m_y1, FindBottom(lgroup)
	else
		w, y1, y2 = rgroup.m_w, rgroup.m_y1, FindBottom(rgroup)
	end

	local ntext = display.newText(bgroup, name, 0, 0, native.systemFont, 12)

	w = max(w, ntext.width) + 35

	-- Make a new box at this spot.
	local box = display.newRoundedRect(bgroup, (sx + .5) * CellDim, (sy + .5) * CellDim, w, y2 - y1 + 30, 12)
	local hw, y = box.width / 2, box.y - box.height / 2 + 15

	box.m_lgroup, box.m_rgroup = lgroup, rgroup

	Align(lgroup, false)
	Align(lgroup, true)

	ntext.x, ntext.y = box.x, y - 5

	lgroup.y, rgroup.y = y + 15, y + 15

	lgroup.x = box.x - hw + 10
	rgroup.x, rgroup.anchorX = box.x + hw - 10, 1

	box:addEventListener("touch", DragTouch)
	box:setFillColor(.375, .675)
	box:setStrokeColor(.125)
	box:toBack()

	box.strokeWidth = 2

	BoxID = BoxID + 1

	return box, ntext
end

-- Helper to sort objects in creation order
local function SortByIndex (a, b)
	return a.m_link_index < b.m_link_index
end

---
-- @pgroup view X
function M.Enter (view)
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

	-- Remove any dead objects.
	for i = #ToRemove, 1, -1 do
		local state = ToRemove[i]

		if state then
			-- TODO: remove any link objects

			RemoveFromCell(state.m_box)

			state.m_box.parent:removeSelf()
		end

		ToRemove[i] = nil
	end

	-- Dole out spots to any new objects in creation order, adding boxes there.
	sort(ToSort, SortByIndex)

	local links, spot = common.GetLinks(), -1
	local tag_db = links:GetTagDatabase()

	for _, object in ipairs(ToSort) do
		repeat
			spot = spot + 1

			local cell = Occupied[spot]
		until (cell and next(cell, nil)) == nil

		local box, name = AddObjectBox(ItemGroup, tag_db, links:GetTag(object), object, morton.MortonPair(spot))

		Tagged[object], object.m_link_index = {	m_box = box, m_name = name }

		AddToCell(box)
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
	Group, ItemGroup, Occupied, Tagged, ToRemove, ToSort = nil
end

-- Export the module.
return M