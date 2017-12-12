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
local random = math.random
local tonumber = tonumber
local type = type

-- Modules --
local array_index = require("tektite_core.array.index")
local box_layout = require("s3_editor_views.link_imp.box_layout")
local button = require("corona_ui.widgets.button")
local cells = require("s3_editor_views.link_imp.cells")
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local connections = require("s3_editor_views.link_imp.connections")
local editable = require("corona_ui.patterns.editable")
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

local function IntegrateLink (link, object, sub, is_source, index)
	connections.AddLink(index or NodeListIndex, not is_source, link)

	link.m_obj, link.m_sub = object, sub
end

local BoxID, LastSpot = 0

local function FindFreeSpot (x, how)
	local sx, sy

	if x then
		LastSpot, sx, sy = cells.FindFreeCell_LeftOrRight(LastSpot, x, how)
	else
		LastSpot, sx, sy = cells.FindFreeCell(LastSpot)
	end

	return sx, sy
end

local function Add (button)
	button.parent[1]:m_add()
end

local function RemoveRange (list, last, n)
	for _ = 1, n do
		list:remove(last)

		last = last - 1
	end
end

local function Shift (items, shift, a, b, is_array)
	local delta = shift > 0 and 1 or -1

	for i = a, b, delta do
		local instance = is_array and items[i].m_instance

		if instance then
			common.SetLabel(instance, common.GetLabel(instance) + delta)
		end

		items[i].y = items[i + shift].y
	end
end

local function RemoveRow (list, row, n, is_array)
	local last = row * n

	Shift(list, -n, list.numChildren, last + 1, is_array)
	RemoveRange(list, last, n)
end

local Delete = touch.TouchHelperFunc(function(_, button)
	local fixed = button.parent
	local agroup = fixed.parent
	local row, items, links = button.m_row, agroup.items, agroup.links
	local nfixed, nlinks = fixed.numChildren, links.numChildren
	local neach = items.numChildren / nlinks -- only one link per row, but maybe more than one item
	local base = (row - 1) * neach

	for i = 1, neach do
		local instance = items[base + i].m_instance

		if instance then
			common.RemoveInstance(button.m_object, instance)
		end
	end

	RemoveRow(items, row, neach, items.m_is_array)
	RemoveRow(links, row, 1)
	RemoveRange(fixed, nfixed, nfixed / nlinks) -- as above, in case more than one fixed object per row
end)

local function GetFromItemInfo (items, fi, ti, n, is_array)
	for i = 0, n - 1 do
		local from_instance = is_array and items[ti - i].m_instance

		if from_instance then
			items[fi - i].m_old_index = common.GetLabel(from_instance)
		end

		items[fi - i].m_y = items[ti - i].y
	end
end

local function SetToItemInfo (items, _, ti, n)
	for i = 0, n - 1 do
		local item = items[ti - i]

		if item.m_old_index then
			common.SetLabel(item.m_instance, item.m_old_index)
		end

		item.y, item.m_old_index, item.m_y = item.m_y
	end
end

local function AuxMoveRow (items, stash, fi, ti, n, is_array)
	GetFromItemInfo(items, fi, ti, n, is_array)

	local tpos = ti - n + 1

	if fi < ti then
		Shift(items, -n, ti, fi + 1, is_array)
	else
		Shift(items, n, tpos, fi - n, is_array)
	end

	for i = 0, n - 1 do -- to avoid having to reason about how insert() works with elements already in the group,
						-- temporarily put them somewhere else, in reverse order...
		stash:insert(items[fi - i])
	end

	for i = 1, n do -- ...then stitch them back in where they belong
		items:insert(tpos, stash[stash.numChildren - n + i])
	end

	SetToItemInfo(items, fi, ti, n)
end

local function MoveRow (items, links, from, to)
	if from ~= to then
		local n = items.numChildren / links.numChildren -- only one link per row, but maybe more than one item
		local fi, ti = from * n, to * n

		AuxMoveRow(items, links, fi, ti, n, items.m_is_array)
		AuxMoveRow(links, items, from, to, 1)
	end
end

local function FindRow (drag_box, box, links)
	local row = array_index.FitToSlot(drag_box.y, box.y + box.height / 2, drag_box.height)

	return (row >= 1 and row <= links.numChildren) and row
end

local Move = touch.TouchHelperFunc(function(event, ibox)
	local items = ibox.parent
	local box = items.parent[1]
	local drag_box = box.m_drag

	drag_box.x, drag_box.y = ibox.x, ibox.y
	drag_box.isVisible = true

	ibox.m_dragy, ibox.m_from = ibox.y - event.y, FindRow(drag_box, box, items.parent.links)
end, function(event, ibox)
	local items = ibox.parent

	items.parent[1].m_drag.y = ibox.m_dragy + event.y
end, function(_, ibox)
	local items = ibox.parent
	local box = items.parent[1]
	local drag_box, links = box.m_drag, items.parent.links
	local row = FindRow(drag_box, box, items, links)

	if row then
		MoveRow(items, links, ibox.m_from, row)
	end

	drag_box.isVisible = false
end)

local function AddBox (group, w, h)
	local box = cells.NewBox(group, w, h, 12)

	box_layout.CommitLeftAndRightGroups(box, 10, 30)

	box:addEventListener("touch", DragTouch)
	box:setFillColor(.375, .675)
	box:setStrokeColor(.125)
	box:toBack()

	box.strokeWidth = 2

	box.m_id, BoxID = BoxID, BoxID + 1

	return box
end

--
local function IndexFromInstance (instance)
	return tonumber(common.GetLabel(instance))
end

local function Link (group)
	local link = display.newCircle(group, 0, 0, 5)

	link.strokeWidth = 1

	return link
end

local function AssembleArray (tag_db, tag, sub, instances)
	local arr

	for i = 1, #(instances or "") do
		local instance = instances[i]

		if tag_db:GetTemplate(tag, instance) == sub then
			arr = arr or {}
			arr[IndexFromInstance(instance)] = instance
		end
	end

	return arr
end

local EditOpts = {
	font = "PeacerfulDay", size = layout.ResolveY("3%"),

	get_editable_text = function(editable)
		return common.GetLabel(editable.m_instance)
	end,

	set_editable_text = function(editable, text)
		common.SetLabel(editable.m_instance, text)

		editable:SetStringText(text)
	end
}

local function AttachmentBox (group, object, tag_db, tag, sub, is_source, is_set)
	local agroup = display.newGroup()

	group:insert(agroup)

	local add, primary_link = button.Button(agroup, "4.25%", "4%", Add, "+"), Link(agroup)
	local lo, ro = box_layout.Arrange(not is_source, 10, add, primary_link)
	local box = AddBox(agroup, box_layout.GetLineWidth(lo, ro) + 25, add.height + 15)

	primary_link.x, box.primary = add.x - primary_link.x, primary_link

	--
	agroup.items, agroup.fixed, agroup.links = display.newGroup(), display.newGroup(), display.newGroup()

	agroup:insert(agroup.items)
	agroup:insert(agroup.fixed)
	agroup:insert(agroup.links)

	agroup.items.m_is_array = not is_set
	box.m_is_source, box.m_node_list_index = is_source, NodeListIndex

	function box:m_add (instance)
		local link = Link(agroup.links)
		local ibox = display.newRect(agroup.items, self.x, 0, self.width + (is_set and 15 or 0), is_set and 30 or 15)
		local below = self.y + self.height / 2

		ibox:addEventListener("touch", Move)
		ibox:setFillColor(.4)
		ibox:setStrokeColor(random(), random(), random())

		ibox.strokeWidth = 2

		local n = agroup.links.numChildren

		if not instance then
			instance = tag_db:Instantiate(tag, sub)

			common.AddInstance(object, instance)

			if not is_set then
				common.SetLabel(instance, n)
			end
		end

		if not self.m_drag then
			self.m_drag = display.newRect(agroup, 0, 0, ibox.width, ibox.height)

			self.m_drag:setFillColor(0, 0)
			self.m_drag:setStrokeColor(0, .9, 0)

			self.m_drag:toFront()

			self.m_drag.strokeWidth = 2
			self.m_drag.isVisible = false
		end

		ibox.y = below + (n - .5) * ibox.height
		link.y = ibox.y

		local hw = self.width / 2

		link.x = self.x + (is_source and hw or -hw)

		local delete = display.newCircle(agroup.fixed, 0, ibox.y, 7)

		delete:addEventListener("touch", Delete)
		delete:setFillColor(.9, 0, 0)
		delete:setStrokeColor(.3, 0, 0)

		delete.alpha = .5
		delete.strokeWidth = 2
		delete.x = self.x + (is_source and -hw or hw)

		delete.m_object, delete.m_row = object, n

		if is_set then
			local text = editable.Editable_XY(agroup.items, ibox.x, ibox.y, EditOpts)

			text.m_instance = instance

			text:SetText(common.GetLabel(instance) or "default")
		else
			ibox.m_instance = instance

			display.newText(agroup.fixed, ("#%i"):format(n), ibox.x, ibox.y, native.systemFontBold, 10)
		end

		IntegrateLink(link, object, instance, is_source, self.m_node_list_index)
	end

	local instances = common.GetInstances(object)

	if is_set then
		for i = 1, #(instances or "") do
			local instance = instances[i]

			if tag_db:GetTemplate(tag, instance) == sub then
				box:m_add(instance)
			end
		end
	else
		local arr = AssembleArray(tag_db, tag, sub, instances)

		for i = 1, #(arr or "") do
			box:m_add(arr[i])
		end
	end

	return box
end

local function SublinkInfo (info, tag_db, tag, sub)
	local iinfo = info and info[sub]
	local itype, is_source = iinfo and type(iinfo), tag_db:ImplementedBySublink(tag, sub, "event_source")

	if itype == "table" then
		if iinfo.is_source ~= nil then
			is_source = iinfo.is_source
		end

		return iinfo, is_source, iinfo.friendly_name
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
		attachments[#attachments + 1] = AttachmentBox(group, object, tag_db, tag, sub, is_source, is_set)
		attachments[sub] = #attachments
	end

	return attachments
end

local function AddNameText (group, object)
	local name = common.GetValuesFromRep(object).name
	local ntext = display.newText(group, name, 0, 0, native.systemFont, 12)

	ntext:setFillColor(0)

	return ntext
end

local function AssignPositions (primary, attachments)
	local x, y = FindFreeSpot()

	cells.PutBoxAt(primary, x, y)

	for i = 1, #(attachments or "") do
		local abox = attachments[i]

		cells.PutBoxAt(abox, FindFreeSpot(x, abox.m_is_source and "right_of" or "left_of"))	
	end
end

--
local function AddPrimaryBox (group, tag_db, tag, object)
	local info, bgroup = common.AttachLinkInfo(object, nil), display.newGroup()

	group:insert(bgroup)

	--
	local attachments = AddAttachments(group, object, info, tag_db, tag)

	for _, sub in tag_db:Sublinks(tag, "no_instances") do
		local ai, _, is_source, text = attachments and attachments[sub], SublinkInfo(info, tag_db, tag, sub)
		local cur = box_layout.ChooseLeftOrRightGroup(bgroup, is_source)
		local link, stext = Link(cur), display.newText(cur, text or sub, 0, 0, native.systemFont, 12)

		--
		local lo, ro = box_layout.Arrange(is_source, 5, link, stext)

		if text then
			-- hook up some touch listener, change appearance
		end

		--
		if ai then
			connections.LinkAttachment(link, attachments[ai])
		else
			IntegrateLink(link, object, sub, is_source)
		end

		--
		box_layout.AddLine(cur, lo, ro, 5, link)
	end

	--
	local w, h = box_layout.GetSize()
	local ntext = AddNameText(bgroup, object)
	local box = AddBox(bgroup, max(w, ntext.width) + 35, h + 30)

	connections.AddNodeList(NodeListIndex)

	box.m_attachments, box.m_node_list_index = attachments, NodeListIndex

	NodeListIndex = NodeListIndex + 1

	ntext.y = box_layout.GetY1(box) + 10

	AssignPositions(box, attachments)

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
function M.Enter (_)
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