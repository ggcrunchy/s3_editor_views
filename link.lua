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
local ipairs = ipairs
local max = math.max
local sort = table.sort
local tonumber = tonumber
local type = type

-- Modules --
local box_layout = require("s3_editor_views.link_imp.box_layout")
local cells = require("s3_editor_views.link_imp.cells")
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local connections = require("s3_editor_views.link_imp.connections")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local objects = require("s3_editor_views.link_imp.objects")
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
local X, Y = 120, 80

-- --
local X0, Y0

-- --
local XOff, YOff

-- Box drag listener --
local DragTouch

--
local FadeParams = {}

local function EmphasizeLinks (item, how, link, source_to_target, not_owner)
	local r, g, b = 1

	if how == "began" then
		if not not_owner then
			r = 0
		elseif not source_to_target then
			r = .25
		elseif common.GetLinks():CanLink(link.m_obj, item.m_obj, link.m_sub, item.m_sub) then
			r, g, b = 1, 0, 1
		else
			r, g, b = .2, .3, .2
		end
	end

	FadeParams.r, FadeParams.g, FadeParams.b = r, g or r, b or r

	transition.to(item.fill, FadeParams)
end

local function SortByID (box1, box2)
	return box1.m_id > box2.m_id
end

local function GatherLinks (items)
	local boxes_seen = items.m_boxes_seen or {}

	cells.GatherVisibleBoxes(XOff, YOff, boxes_seen)

	sort(boxes_seen, SortByID) -- make links agree with render order

	for _, box in ipairs(boxes_seen) do
		for _, group in box_layout.IterateGroupsOfLinks(box) do
			for i = 1, group.numChildren do
				items[#items + 1] = group[i]
			end
		end
	end

	items.m_boxes_seen = boxes_seen
end

-- --
cells.SetCellFraction(.35)

---
-- @pgroup view X
function M.Load (view)
	box_layout.Load()

	--
	Group, ItemGroup = display.newGroup(), display.newGroup()

	view:insert(Group)

	local cont = display.newContainer(display.contentWidth - (X + 10), display.contentHeight - (Y + 10))

	Group:insert(cont)

	--
	cells.Load(cont)
	objects.Load()

	--
	local cw, ch = cont.width, cont.height

	cont:insert(ItemGroup)

	X0, Y0, XOff, YOff = -cw / 2, -ch / 2, 0, 0

	ItemGroup:translate(X0, Y0)

	local link_layer = display.newGroup()

	cont:insert(link_layer)

	link_layer:translate(X0 - (X + 5), Y0 - (Y + 5))

	layout.PutRightOf(cont, X, 5)
	layout.PutBelow(cont, Y, 5)
	common_ui.Frame(cont, 1, 0, 1)

	--
	DragTouch = touch.DragParentTouch_Child(1, {
		clamp = "max", ref = "object",

		on_began = function(_, box)
			cells.RemoveFromCell(ItemGroup, box)
		end,

		on_ended = function(_, box)
			cells.AddToCell(ItemGroup, box)
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
	connections.Load(link_layer, EmphasizeLinks, GatherLinks)

	Group.isVisible = false

	help.AddHelp("Link", { cont = cont })
	help.AddHelp("Link", {
		cont =  "Drag boxes to move them, or the background to move the world. Links can be established by dragging from an " ..
				"output node (on the right side) to a linkable input node (left side), or vice versa. Links are broken by " ..
				"clicking the dot on the line between the nodes. TODO: Far apart nodes"
	})
end

-- --
local NodeListIndex = 0

local function IntegrateLink (link, object, sub, is_source)
	connections.AddLink(NodeListIndex, not is_source, link)

	link.m_obj, link.m_sub = object, sub
end

local function AddArrayRow (arr, row, sub)

end

local function AddSetRow (set, row, sub)

end

local function DeleteArrayRow (arr, row)
end

local function DeleteSetRow (set, row)
end

local function MeasureRow (group, add, count)
	if not count then
		local items, links = group.items, group.links
		local n, left_object, right_object, newn = links.numChildren

		if links.numChildren == 0 then
			left_object, right_object = add(group)
			newn = items.numChildren - n

			for i = items.numChildren, n + 1, -1 do
				items:remove(i)
			end

			links:remove(links.numChildren)
		else
			newn = n / links.numChildren
			left_object, right_object = items[n - newn + 1], items[n]
		end

		return newn, box_layout.GetLineWidth(left_object, right_object) -- TODO: re-add remembering width
	end
end

local BoxID, LastSpot = 0

local function FindFreeSpot ()
	local sx, sy

	LastSpot, sx, sy = cells.FindFreeCell(LastSpot)

	return sx, sy
end

local function AddBoxAtSpot (group, name, min_w)
	--
	local w, h = box_layout.GetSize()
	local ntext = display.newText(group, name, 0, 0, native.systemFont, 12)

	ntext:setFillColor(0)

	-- Make a new box at this spot.
	local sx, sy = FindFreeSpot()
	local box = cells.NewBox(group, sx, sy, max(w, ntext.width, min_w or 0) + 35, h + 30, 12)

	box_layout.AddNameAndCommit(box, ntext, 10, 30, 10)

	box:addEventListener("touch", DragTouch)
	box:setFillColor(.375, .675)
	box:setStrokeColor(.125)
	box:toBack()

	box.strokeWidth = 2

	box.m_id = BoxID

	BoxID = BoxID + 1

	touch.Spoof(box) -- trigger began / ended logic

	return box, ntext
end

--
local ArrayN, SetN

local function IndexFromInstance (instance)
	return tonumber(common.GetLabel(instance))
end

local function Link (group)
	local link = display.newCircle(group, 0, 0, 5)

	link.strokeWidth = 1

	return link
end

local function MaxIndex (tag_db, tag, sub)
	local count, used = 0

	for _, instance in tag_db:Sublinks(tag, sub) do
		local index = IndexFromInstance(instance)

		used, count = used or {}, max(used, count)
		used[index] = instance
	end

	return count, used
end

local function AttachmentBox (group, object, tag_db, tag, sub, is_source, is_set)
	local agroup, a, b, c, d, e = display.newGroup()

	-- main box
	-- choose add / remove functions
	-- foreach
		-- append
	-- set box size
	-- push back

	--
	agroup.items, agroup.links = display.newGroup(), display.newGroup()

	group:insert(agroup)
	agroup:insert(agroup.items)
	agroup:insert(agroup.links)

	box_layout.AliasToLeftAndRight(agroup.items, agroup.links, is_source)
--[[
	for _, sub in tag_db:Sublinks(tag, "instances") do
		-- populate box(es), in case of a load
		-- must be able to tie these to the object
			-- probably the same state that must maintain for save / load
		-- should we just do this when iterating templates?
			-- somehow need to keep per-object distinction on hand anyhow...
	end
]]
	-- Add first line
	-- Add any already-available lines

	-- a = delete button
	-- local link = ...

	-- List (anchored at top?) of entries, each with:
		-- Link (invisible)
	local w

	if is_set then
		agroup.m_append, agroup.m_delete, agroup.m_rown = AddSetRow, DeleteSetRow, SetN
		-- "+" -> append instance
		-- Name field, to assign the label
		-- insert / delete into / from set
		-- b = name field
		-- c = link
		for _, instance in tag_db:Sublinks(tag, sub) do
			local link = Link(agroup.links)

			-- use label to assign name

			IntegrateLink(link, object, instance, is_source)
		end

		SetN, w = MeasureRow(agroup, AddSetRow, SetN)
	else
		agroup.m_append, agroup.m_delete, agroup.m_rown = AddArrayRow, DeleteArrayRow, ArrayN

		local maxn, used = MaxIndex(tag_db, tag, sub)

		for i = 1, maxn do
			local link = Link(agroup.links)

			-- put somewhere...
			local instance = used[i] or tag_db:Instantiate(tag, sub)

			IntegrateLink(link, object, instance, is_source)
			-- TODO: do we care about setting labels?
		end

		ArrayN, w = MeasureRow(agroup, AddArrayRow, ArrayN)

		-- "+" -> add new instance with default label
		-- 
		-- insert / delete into / from array
		-- "up / down" (except at top / bottom), to move entry within list
			-- Will adjust most if not all instance <-> label mappings for this object
		-- if not at top then
			-- b = up
		-- if not at bottom then
			-- b or c = down
		-- b, c, or d = Index text ("1", "2", ...)
		-- c, d, or e = link
	end
		-- "X", to delete the entry
	-- The "+" and "X" will resize the box
		-- Probably no sensible way to bound the size, owing to link visibility

--	local method, offset, a, b, c, d, e = Arrange(is_source, 5, link, b, c, d, e)
-- Put a somewhere
-- add b relative to a
-- add c relative to b
-- if d, add relative to c
-- if e, add relative to e
-- ^^^ Do this wherever Add / Delete is... also on initial population
-- Keep a tally to allow reserving room?
-- Need to account for empty case, so minimum space (probably also to include "+")
	return AddBoxAtSpot(agroup, "WONK")
end

local function SublinkInfo (info, tag_db, tag, sub)
	local iinfo = info and info[sub]
	local itype, is_source = iinfo and type(iinfo), tag_db:ImplementedBySublink(tag, sub, "event_source")

	--
	if itype == "table" then
		if iinfo.is_source ~= nil then
			is_source = iinfo.is_source
		end

		return iinfo, is_source, iinfo.text
	else
		return nil, is_source, itype == "string" and iinfo or nil
	end
end

--
local function AddAttachments (group, object, info, tag_db, tag)
	local attachments

	for _, sub in tag_db:Sublinks(tag, "templates") do
		local iinfo, is_source = SublinkInfo(info, tag_db, tag, sub)
		local is_set = iinfo and iinfo.is_set

		attachments = attachments or {}
		-- These each have some UI considerations
			-- Auxiliary box(es) of links, rather than raw links
			-- Must also track some state for save / load / build, for labels
		attachments[#attachments + 1] = AttachmentBox(group, object, tag_db, tag, sub, is_source, is_set)
		attachments[sub] = #attachments
	end

	return attachments
end

--
local function AddPrimaryBox (group, tag_db, tag, object)
	local info, name, bgroup = common.AttachLinkInfo(object, nil), common.GetValuesFromRep(object).name, display.newGroup()

	group:insert(bgroup)

	--
	local attachments = AddAttachments(group, object, info, tag_db, tag)

	for _, sub in tag_db:Sublinks(tag, "no_instances") do
		local ai, iinfo, is_source, text = attachments and attachments[sub], SublinkInfo(info, tag_db, tag, sub)
		local cur = box_layout.ChooseLeftOrRightGroup(bgroup, is_source)
		local n, link = cur.numChildren, Link(cur)
		local stext = display.newText(cur, iinfo and iinfo.friendly_name or sub, 0, 0, native.systemFont, 12)

		--
		local method, offset, lo, ro = box_layout.Arrange(is_source, 5, link, stext)

		layout[method](stext, link, offset)

		if text then
			-- hook up some touch listener, change appearance
		end

		--
		if ai then
			connections.LinkAttachment(link, attachments[ai])

			link.alpha = .025
		else
			IntegrateLink(link, object, sub, is_source)
		end

		--
		box_layout.AddLine(cur, lo, ro, link, n, 5)
	end

	--
	local box, ntext = AddBoxAtSpot(bgroup, name)

	connections.AddNodeList(NodeListIndex)

	box.m_attachments, box.m_node_list_index = attachments, NodeListIndex

	NodeListIndex = NodeListIndex + 1

	return box, ntext
end

local function RemoveBox (box)
	cells.RemoveFromCell(ItemGroup, box)

	box.parent:removeSelf()
end

--
local function RemoveAttachment (tag_db, sbox, tag)
	local links = sbox.parent.links

	for k = 1, links.numChildren do
		tag = tag or tag_db:GetTag(links[k].m_obj)

		local instance = links[k].m_sub

		common.SetLabel(instance, nil)

		tag_db:Release(tag, instance)
	end

	RemoveBox(sbox)

	return tag
end

local function RemoveDeadObjects ()
	local tag_db = common.GetLinks():GetTagDatabase()

	for _, state in objects.IterateRemovedObjects() do
		local box, tag = state.m_box

		connections.RemoveNodeList(box.m_node_list_index)

		for j = 1, #(box.m_attachments or "") do
			tag = RemoveAttachment(tag_db, box.m_attachments[j], tag)
		end

		RemoveBox(box)
	end	
end

local function AddNewObjects ()
	local links = common.GetLinks()
	local tag_db = links:GetTagDatabase()

	LastSpot = -1

	for _, object in objects.IterateNewObjects() do
		local box, name = AddPrimaryBox(ItemGroup, tag_db, links:GetTag(object), object)

		objects.AssociateBoxAndObject(object, box, name)
	end
end

local function MakeConnections ()
	for _, object in objects.IterateNewObjects("remove") do
		connections.ConnectObject(object)
	end

	connections.FinishConnecting()
end

---
-- @pgroup view X
function M.Enter (view)
	objects.Refresh()

	RemoveDeadObjects()
	AddNewObjects()
	MakeConnections()

	--
	Group.isVisible = true

	help.SetContext("Link")
end

--- DOCMAYBE
function M.Exit ()
	-- Tear down link groups

	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	Group, ItemGroup = nil

	box_layout.Unload()
	cells.Unload()
	connections.Unload()
	objects.Unload()
end

-- Export the module.
return M