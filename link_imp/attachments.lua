--- Management of link view attachments.

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

-- Standard library imports --
local random = math.random
local tonumber = tonumber

-- Modules --
local array_index = require("tektite_core.array.index")
local box_layout = require("s3_editor_views.link_imp.box_layout")
local button = require("corona_ui.widgets.button")
local editable = require("corona_ui.patterns.editable")
local common = require("s3_editor.Common")
local layout = require("corona_ui.utils.layout")
local table_view_patterns = require("corona_ui.patterns.table_view")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local native = native

-- Cached module references --

-- Exports --
local M = {}

--
--
--

local AddBox, IntegrateLink, Link

--- DOCME
function M.AddUtils (utils)
	AddBox, IntegrateLink, Link = utils.add_box, utils.integrate_link, utils.link
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

	common.Dirty()
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

local function IndexFromInstance (instance)
	return tonumber(common.GetLabel(instance))
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

-- --
local ListboxOpts

--
local function DefGetText (text)
	return text
end

--- DOCME
function M.Box (group, object, tag_db, tag, sub, is_source, set_style)
	local agroup, choice = display.newGroup()

	group:insert(agroup)

	local add, primary_link, lo, ro = button.Button(agroup, "4.25%", "4%", Add, "+"), Link(agroup)

	if set_style ~= "mixed" then
		lo, ro = box_layout.Arrange(not is_source, 10, primary_link, add)
	else
		ListboxOpts = ListboxOpts or {}

		local get_text = sub.get_text or DefGetText
		local opts, ctext = ListboxOpts[get_text] or {
			width = "8%", height = "5%", get_text = get_text, text_rect_height = "3%", text_size = "2.25%"
		}, sub.choice_text or "Choice:"

		choice, ListboxOpts[get_text] = table_view_patterns.Listbox(agroup, opts), opts
		ctext = display.newText(agroup, ctext, 0, 0, native.systemFont, 15)
		choice.y = ctext.y

		sub.add_choices(choice)

		if not choice:GetSelection() then
			choice:Select(1)
		end

		if is_source then
			lo, ro = box_layout.Arrange(false, 7, primary_link, ctext, choice, add)
		else
			lo, ro = box_layout.Arrange(false, 7, ctext, choice, add, primary_link)
		end
	end

	local w, midx = box_layout.GetLineWidth(lo, ro, "want_middle")
	local box = AddBox(agroup, w + 25, add.height + 15)

	box.primary, box.x = primary_link, agroup:contentToLocal(midx, 0)

	--
	agroup.items, agroup.fixed, agroup.links = display.newGroup(), display.newGroup(), display.newGroup()

	agroup:insert(agroup.items)
	agroup:insert(agroup.fixed)
	agroup:insert(agroup.links)

	agroup.items.m_is_array = not set_style
	box.m_is_source = is_source

	function box:m_add (instance)
		local link = Link(agroup.links)
		local n, w = agroup.links.numChildren, self.width + (set_style and 25 or 0)

		if not instance then
			if set_style ~= "mixed" then
				instance = tag_db:Instantiate(tag, sub)
			else
				instance = tag_db:Instantiate(tag, choice:GetSelectionData())
			end

			common.AddInstance(object, instance)

			if not set_style then
				common.SetLabel(instance, n)
			end

			common.Dirty()
		end

		local ibox = display.newRect(agroup.items, self.x, 0, w, set_style and 35 or 15)
		local below = self.y + self.height / 2

		ibox:addEventListener("touch", Move)
		ibox:setFillColor(.4)
		ibox:setStrokeColor(random(), random(), random())

		ibox.strokeWidth = 2

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

		local hw = w / 2

		link.x = self.x + (is_source and hw or -hw)

		local delete = display.newCircle(agroup.fixed, 0, ibox.y, 7)

		delete:addEventListener("touch", Delete)
		delete:setFillColor(.9, 0, 0)
		delete:setStrokeColor(.3, 0, 0)

		delete.alpha = .5
		delete.strokeWidth = 2
		delete.x = self.x + (is_source and -hw or hw)

		delete.m_object, delete.m_row = object, n

		if set_style then
			local text = editable.Editable_XY(agroup.items, ibox.x, ibox.y, EditOpts)

			text.m_instance = instance

			text:SetText(common.GetLabel(instance) or "default")

			if set_style == "mixed" then
				local atext = sub[tag_db:GetTemplate(tag, instance)]
				local about = display.newText(agroup.items, atext, 0, ibox.y, native.systemFont, 15)

				layout.PutLeftOf(about, text, -10)
			end
		else
			ibox.m_instance = instance

			display.newText(agroup.fixed, ("#%i"):format(n), ibox.x, ibox.y, native.systemFontBold, 10)
		end

		IntegrateLink(link, object, instance, is_source, self.m_knot_list_index)
	end

	local instances = common.GetInstances(object)

	if set_style then
		for i = 1, #(instances or "") do
			local instance = instances[i]
			local template = tag_db:GetTemplate(tag, instance)

			if set_style ~= "mixed" then
				if template == sub then
					box:m_add(instance)
				end
			elseif sub[template] then
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

--- DOCME
function M.GetLinksGroup (box)
	return box.parent.links
end

--- DOCME
function M.Unload ()
	ListboxOpts = nil
end

-- Export the module.
return M