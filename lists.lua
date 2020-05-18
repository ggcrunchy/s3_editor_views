--- Some structure common to various list views.

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
local ipairs = ipairs
local pairs = pairs
local sort = table.sort

-- Modules --
local dialog = require("s3_editor.Dialog")
local editor_strings = require("config.EditorStrings")
local events = require("s3_editor.Events")
local help = require("s3_editor.Help")
local layout = require("solar2d_ui.utils.layout")
local list_views = require("s3_editor.ListViews")
local menu = require("solar2d_ui.widgets.menu")
local strings = require("tektite_core.var.strings")
local table_funcs = require("tektite_core.table.funcs")
local table_view_patterns = require("solar2d_ui.patterns.table_view")

-- Corona globals --
local display = display
local native = native
local Runtime = Runtime

-- Cached module references --
local _ListOfItemsMaker_

-- Exports --
local M = {}

--
--
--

local function List (group, str, view, top, r, g, b, help_context)
	local text = display.newText(group, str, 0, 0, native.systemFont, layout.ResolveY("5%"))

	layout.PutRightOf(text, "15.625%")
	layout.PutBelow(text, top)

	local list, bottom = view:Load(group, layout.Below(text), layout.LeftOf(text), help_context)

	list:Frame(r, g, b)

	return list, bottom
end

--- DOCME
function M.ListOfItemsMaker (name, mod, params, name_func)
	-- --
	local LVM = {}

	-- --
	local Group

	-- --
	local Dialog = dialog.DialogWrapper(mod.EditorEvent)

	-- --
	local ListView = list_views.EditErase(Dialog, name_func or name)

	-- --
	local HelpContext

	---
	-- @pgroup view X
	function LVM.Load (view)
		Group = display.newGroup()
		HelpContext = help.NewContext()

		--
		local list, bottom = List(Group, params.text, ListView, "16.67%", 0, 0, 1, HelpContext)

		HelpContext:Add(list, editor_strings(name .. "_choices"))
	
		if params.add_elements then
			params.add_elements(Group, list, bottom, name, HelpContext)
		end

		--
		Group.isVisible = false

		view:insert(Group)
		HelpContext:Register()
		HelpContext:Show(false)
	end

	---
	-- @pgroup view X
	function LVM.Enter (view)
		Group.isVisible = true

		ListView:Enter(view)
		HelpContext:Show(true)
	end

	--- DOCMAYBE
	function LVM.Exit ()
		ListView:Exit()
		HelpContext:Show(false)

		Group.isVisible = false
	end

	--- DOCMAYBE
	function LVM.Unload ()
		ListView:Unload()

		Group, HelpContext = nil

		if params.unload then
			params.unload()
		end
	end

	for k, v in pairs{
		build_level = function(level)
			--
			local builds

			for _, entry in pairs(level[name].entries) do
				builds = events.BuildEntry(level, mod, entry, builds)
			end

			level[name] = builds

			if params.build_level then
				params.build_level(level, builds)
			end
		end,

		load_level_wip = function(level)
			events.LoadGroupOfValues_List(level, name, mod, ListView)

			if params.load_level_wip then
				params.load_level_wip(level)
			end
		end,

		save_level_wip = function(level)
			events.SaveGroupOfValues(level, name, mod, ListView)

			if params.save_level_wip then
				params.save_level_wip(level)
			end
		end,

		verify_level_wip = function(verify)
			if verify.pass == 1 then
				events.CheckNamesInValues(name, verify, ListView)
			end

			events.VerifyValues(verify, mod, ListView)

			if params.verify_level_wip then
				params.verify_level_wip(verify, ListView)
			end
		end
	} do
		Runtime:addEventListener(k, v)
	end

	return LVM
end

local function CombineHelpVars (h1, h2)
	if h1 and h2 then
		for k, v in pairs(h2) do
			h1[k] = v
		end
	end

	return h1 or h2
end

local function Augment (params, name, func, combine)
	local cur = params[name]

	if cur then
		params[name] = function(a, b, c)
			local r1 = cur(a, b, c)
			local r2 = func(a, b, c)

			if combine then
				return combine(r1, r2)
			end
		end
	else
		params[name] = func
	end
end

--- DOCME
function M.ListOfItemsMaker_Choices (name, mod, params)
	params = table_funcs.Copy(params)

	local Choices, Dropdown, Names, Categories, Scratch

	local function GetText (data)
		local i1, i2 = data:find(Dropdown:GetSelection("text"))

		if i1 == 1 then
			data = data:sub(i2 + 2) -- trim following underscore...
		elseif i2 == #data then
			data = data:sub(1, i1 - 2) -- ...or preceding...
		elseif i1 then
			data = data:sub(1, i1 - 1) .. data:sub(i2 + 2) -- ...arbitrarily keep one and trim the other
		end

		return strings.SplitIntoWords(data, "on_pattern")
	end

	Augment(params, "add_elements", function(group, list, _, name, help_context)
		Scratch, Names, Categories = {}, mod.GetTypes()

		for _, name in ipairs(Names) do
			local category = Categories[name]

			if not Scratch[category] then
				Scratch[#Scratch + 1], Scratch[category] = category, true
			end
		end

		sort(Scratch)

		local text = display.newText(group, "Categories: ", 0, 0, native.systemFont, 16)

		layout.PutRightOf(text, list, "5%")

		Dropdown = menu.Dropdown{ group = group, column = Scratch, how = "no_op", column_width = "20%" }

		Dropdown:addEventListener("item_change", function(event)
			local category, n = event.text, 0

			for _, name in ipairs(Names) do
				if Categories[name] == category then
					n, Scratch[n + 1] = n + 1, name
				end
			end

			for i = #Scratch, n + 1, -1 do
				Scratch[i] = nil
			end

			sort(Scratch)

			Choices:AssignList(Scratch)
		end)

		local stash = Dropdown:StashDropdowns()

		layout.PutRightOf(Dropdown, text, "2%")
		layout.BottomAlignWith(Dropdown, layout.Above(list))
		layout.CenterAtY(text, Dropdown:GetHeadingCenterY())

		local below, bottom = layout.Below(Dropdown, "7.5%"), layout.Below(list)

		help_context:Add(Dropdown, editor_strings(name .. "_category"))
		Dropdown:RestoreDropdowns(stash)

		Choices = table_view_patterns.Listbox(group, {
			width = "30%", height = bottom - below, get_text = GetText, text_rect_height = "6%", text_size = "3.25%"
		})

		Dropdown:Select(Scratch[1])
		help_context:Add(Choices, editor_strings(name .. "_types"))

		layout.PutRightOf(Choices, list, "5%")
		layout.BottomAlignWith(Choices, bottom)

		local ttext = display.newText(group, "Types", 0, 0, native.systemFont, layout.ResolveY("5%"))

		layout.LeftAlignWith(ttext, Choices)
		layout.PutAbove(ttext, Choices)

		Dropdown:toFront()

		return { choices = Choices }
	end, CombineHelpVars)

	Augment(params, "unload", function()
		Choices, Dropdown, Names, Categories, Scratch = nil
	end)

	return _ListOfItemsMaker_(name, mod, params, function()
		return Choices:GetSelectionData()
	end)
end

_ListOfItemsMaker_ = M.ListOfItemsMaker

return M