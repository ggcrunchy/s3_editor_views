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
local transition = transition

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
	local bbounds = box.contentBounds
	local x, y = ItemGroup:contentToLocal(bbounds.xMin, bbounds.yMin)
	local col1, row1 = grid.PosToCell(x, y, CellDim, CellDim)
	local col2, row2 = grid.PosToCell(x + box.contentWidth, y + box.contentHeight, CellDim, CellDim)

	return max(col1 - 1, 0), max(row1 - 1, 0), max(col2 - 1, 0), max(row2 - 1, 0)
end

--
local function WithCells (action)
	return function(box)
		local col1, row1, col2, row2 = GetCells(box)
	
		for num in morton.Morton2_LineY(col1, row1, row2) do
			for col = col1, col2 do
				local cnum = morton.MortonPairUpdate_X(num, col)

				action(Occupied[cnum], box, cnum)
			end
		end
	end
end

--
local AddToCell = WithCells(function(cell, box, num)
	cell = cell or {}

	Occupied[num], cell[box] = cell, true
end)

--
local RemoveFromCell = WithCells(function(cell, box)
	if cell then
		cell[box] = nil
	end
end)

-- --
local NodeLists

--
local function Connect (_, link1, link2, node)
	local links, nlink = common.GetLinks()
	local obj1, obj2 = link1.m_obj, link2.m_obj

	for link in links:Links(obj1, link1.m_sub) do
		if link:GetOtherObject(obj1) == obj2 then
			nlink = link
		end
	end

	node.m_link = nlink or links:LinkObjects(link1.m_obj, link2.m_obj, link1.m_sub, link2.m_sub)

	local id1, id2 = link_group.GetLinkInfo(link1), link_group.GetLinkInfo(link2)
	local nl1, nl2 = NodeLists[id1], NodeLists[id2]

	node.m_id1, node.m_id2 = id1, id2
	nl1[node], nl2[node] = true, true
end

-- Get a list of nodes matching the ID; since we'll just be nil'ing the entry anyway, supply the list-of-lists on failure (where that will no-op)
local function GetList (id)
	return NodeLists[id] or NodeLists
end

-- Lines (with "break" option) shown in between
local NodeTouch = link_group.BreakTouchFunc(function(node)
	node.m_link:Break()

	GetList(node.m_id1)[node], GetList(node.m_id2)[node] = nil
end)

-- TODO: Add some way to call up an overlay to label / order a list
-- This could be a link info option... probably best, so we don't have to track it in all build info
-- That said, could be more general with the overlays, e.g. this would be where "tooltip" stuff is shown too

-- --
local CellFrac = .35

-- --
local NCells = ceil(1 / CellFrac) + 1

-- --
local DoingLinks

---
-- @pgroup view X
function M.Load (view)
	--
	Group, ItemGroup, LinkLayer = display.newGroup(), display.newGroup(), display.newGroup()
	Index, Occupied, NodeLists, Tagged, ToRemove, ToSort = 1, {}, {}, {}, {}, {}

	view:insert(Group)

	local cont = display.newContainer(display.contentWidth - (X + 10), display.contentHeight - (Y + 10))

	Group:insert(cont)

	--
	CellDim = ceil(CellFrac * min(cont.width, cont.height))

	-- Keep a mostly up-to-date list of tagged objects.
	local links = common.GetLinks()

	links:SetAssignFunc(function(object)
		Tagged[object] = false -- exists but no box yet (might already have links, though)

		-- has template sublinks?
			-- attach appropriate box(es) (or get data ready, anyhow)
			-- put appropriate data in instance <-> label map

		object.m_link_index, Index = Index, Index + 1
	end)
	links:SetRemoveFunc(function(object)
		ToRemove[#ToRemove + 1], Tagged[object] = Tagged[object]

		-- has template sublinks?
			-- remove instance / label from map
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

		on_began = function(_, box)
			RemoveFromCell(box)
		end,

		on_ended = function(_, box)
			AddToCell(box)
		end
	})

	-- Draggable thing...
	local drag = display.newRect(Group, cont.x, cont.y, cw, ch)

	drag:addEventListener("touch", touch.DragViewTouch(ItemGroup, {
		x0 = "cur", y0 = "cur", xclamp = "view_max", yclamp = "view_max",

		on_post_move = function(ig)
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

	local function SortByID (box1, box2)
		return box1.m_id > box2.m_id
	end

	local FadeParams = {}

	Links = link_group.LinkGroup(LinkLayer, Connect, NodeTouch, {
		-- Can Link --
		can_link = function(link1, link2)
			return DoingLinks or common.GetLinks():CanLink(link1.m_obj, link2.m_obj, link1.m_sub, link2.m_sub)
		end,

		-- Emphasize --
		emphasize = function(item, how, link, source_to_target, not_owner)
			local r, g, b = 1

			if how == "began" then
				if not not_owner then
					r = 0
				elseif not source_to_target then
					r = .25
				elseif links:CanLink(link.m_obj, item.m_obj, link.m_sub, item.m_sub) then
					r, g, b = 1, 0, 1
				else
					r, g, b = .2, .3, .2
				end
			end

			FadeParams.r, FadeParams.g, FadeParams.b = r, g or r, b or r

			transition.to(item.fill, FadeParams)
		end,

		-- Gather --
		gather = function(items)
			-- Gather each unique box in the mostly-in-view cells.
			local col1, row1 = grid.PosToCell(XOff, YOff, CellDim, CellDim)

			for num in morton.Morton2_LineY(col1 - 1, row1 - 1, row1 + NCells - 2) do
				for i = 0, NCells - 1 do
					local cell = Occupied[num]

					if cell then
						for box in pairs(cell) do
							if not seen[box] then
								seen[#seen + 1], seen[box] = box, true
							end
						end
					end

					num = morton.MortonPairUpdate_X(num, col1 + i)
				end
			end

			-- Order the boxes by ID so that any arbitration during the linking process
			-- agrees with the render order. Wipe the list for next time.
			sort(seen, SortByID)

			for _, box in ipairs(seen) do
				AddFromGroup(items, box.m_lgroup)
				AddFromGroup(items, box.m_rgroup)
			end

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

--
local function ArrayBox (group, object, is_source)
	-- "+" -> append instance
	-- List (anchored at top?) of entries, each with:
		-- "X", to delete the entry
		-- "up / down" (except at top / bottom), to move entry within list
		-- Index text ("1", "2", ...)
		-- Link
	-- The "+" and "X" will resize the box
		-- Probably no sensible way to bound the size, owing to link visibility
	-- The "up / down" will adjust most if not all instance <-> label mappings for this object
end

--
local function SetBox (group, object, is_source)
	-- "+" -> add new instance with default label
	-- Per-instance boxes, each with:
		-- "X", to delete this entry and remove the box
		-- Name field, to assign the label
		-- Link
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
-- TODO: handle any templates... then see if array or set
-- These each have some UI considerations
	-- Auxiliary box(es) of links, rather than raw links
	-- Do a raw link_group.Connect(), omitting touch handler to avoid node
	-- Must also track some state for save / load / build, for labels
-- iinfo and iinfo.is_set?
	-- In either case, have text, a "+" to add an entry, then a link to the box(es) of links
		local cur = is_source and rgroup or lgroup
		local n, link = cur.numChildren, display.newCircle(cur, 0, 0, 5)
		local stext = display.newText(cur, iinfo and iinfo.friendly_name or sub, 0, 0, native.systemFont, 12)

		link.strokeWidth = 1

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

	ntext:setFillColor(0)

	w = max(w, ntext.width) + 35

	-- Make a new box at this spot.
	local box = display.newRoundedRect(bgroup, (sx + .5) * CellDim, (sy + .5) * CellDim, w, y2 - y1 + 30, 12)
	local hw, y = box.width / 2, box.y - box.height / 2 + 15

	box.m_lgroup, box.m_rgroup, box.m_id = lgroup, rgroup, BoxID

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

	NodeLists[BoxID], BoxID = {}, BoxID + 1

	return box, ntext
end

--
local function FindLink (group, sub)
	for i = 1, group.numChildren do
		local item = group[i]

		if item.m_sub == sub then
			return item
		end
	end
end

--
local function DoLinks (links, group, object)
	for i = 1, group.numChildren do
		local lobj = group[i]
		local lsub = lobj.m_sub

		if lsub then
			for link in links:Links(object, lsub) do
				if DoingLinks == true then
					DoingLinks = {}
				end

				if not DoingLinks[link] then
					local obj, osub = link:GetOtherObject(object)
					local obox = Tagged[obj].m_box
					local olink = FindLink(obox.m_lgroup, osub) or FindLink(obox.m_rgroup, osub)
					local node = Links:ConnectObjects(lobj, olink)

					node.m_link, DoingLinks[link] = link, true
				end
			end
		end
	end
end

--
local function ConnectObject (object)
	local links, box = common.GetLinks(), Tagged[object].m_box

	DoLinks(links, box.m_lgroup, object)
	DoLinks(links, box.m_rgroup, object)
end

-- Helper to sort objects in creation order
local function SortByIndex (a, b)
	return a.m_link_index < b.m_link_index
end

-- --
local FakeTouch

--
local function SpoofTouch (box, phase)
	FakeTouch = FakeTouch or { id = "ignore_me", name = "touch" }

	FakeTouch.target, FakeTouch.phase = box, phase

	if phase == "began" then
		FakeTouch.x, FakeTouch.y = box:localToContent(0, 0)
	end

	box:dispatchEvent(FakeTouch)

	FakeTouch.target = nil
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
			--
			local box = state.m_box
			local id = box.m_id

			for node in pairs(NodeLists[id]) do
				link_group.Break(node)
			end

			-- release template instances
			-- likewise, kill attached boxes

			NodeLists[id] = nil

			--
			RemoveFromCell(box)

			--
			box.parent:removeSelf()
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

		SpoofTouch(box, "began")
		SpoofTouch(box, "moved")
		SpoofTouch(box, "ended")
	end

	-- Now that our objects all exist, wire up any links and clear the list.
	DoingLinks = true

	for i = #ToSort, 1, -1 do
		ConnectObject(ToSort[i])

		ToSort[i] = nil
	end

	DoingLinks = false

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
	FakeTouch, Group, ItemGroup, NodeLists, Occupied, Tagged, ToRemove, ToSort = nil
end

-- Export the module.
return M