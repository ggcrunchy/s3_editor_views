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
local pairs = pairs
local sort = table.sort

-- Modules --
local common_ui = require("s3_editor.CommonUI")
local dialog = require("s3_editor.Dialog")
local events = require("s3_editor.Events")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local list_views = require("s3_editor.ListViews")
local strings = require("tektite_core.var.strings")
local table_funcs = require("tektite_core.table.funcs")
local table_view_patterns = require("corona_ui.patterns.table_view")

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

local function List (group, str, view, top, r, g, b)
	local text = display.newText(group, str, 0, 0, native.systemFont, layout.ResolveY("5%"))

	layout.PutRightOf(text, "15.625%")
	layout.PutBelow(text, top)

	local list, bottom = view:Load(group, layout.Below(text), layout.LeftOf(text))

	common_ui.Frame(list, r, g, b)

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
	local HelpName = name:sub(1, 1):upper() .. name:sub(2)

	---
	-- @pgroup view X
	function LVM.Load (view)
		--
		Group = display.newGroup()

		--
		local hvars, list, bottom = nil, List(Group, params.text, ListView, "16.67%", 0, 0, 1)

		if params.add_elements then
			hvars = params.add_elements(Group, list, bottom)
		end

		--
		Group.isVisible = false

		view:insert(Group)

		--
		hvars = hvars or {}
		hvars[name] = list

		help.AddHelp(HelpName, hvars)
		help.AddHelp(HelpName, params.help_text)
	end

	---
	-- @pgroup view X
	function LVM.Enter (view)
		Group.isVisible = true

		ListView:Enter(view)

		help.SetContext(HelpName)
	end

	--- DOCMAYBE
	function LVM.Exit ()
		ListView:Exit()

		Group.isVisible = false
	end

	--- DOCMAYBE
	function LVM.Unload ()
		ListView:Unload()

		if params.unload then
			params.unload()
		end
	end

	-- Listen to events.
	for k, v in pairs{
		-- Build Level --
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

		-- Load Level WIP --
		load_level_wip = function(level)
			events.LoadGroupOfValues_List(level, name, mod, ListView)

			if params.load_level_wip then
				params.load_level_wip(level)
			end
		end,

		-- Save Level WIP --
		save_level_wip = function(level)
			events.SaveGroupOfValues(level, name, mod, ListView)

			if params.save_level_wip then
				params.save_level_wip(level)
			end
		end,

		-- Verify Level WIP --
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

local function GetText (data)
	return strings.SplitIntoWords(data, "on_pattern")
end

--- DOCME
function M.ListOfItemsMaker_Choices (name, mod, params)
	params = table_funcs.Copy(params)

	local Choices

	Augment(params, "add_elements", function(group, list)
		Choices = table_view_patterns.Listbox(group, {
			width = "30%", height = list.height, get_text = GetText, text_rect_height = "6%", text_size = "3.25%"
		})

		layout.PutRightOf(Choices, list, "5%")
		layout.BottomAlignWith(Choices, list)

		local ttext = display.newText(group, "Types", 0, 0, native.systemFont, layout.ResolveY("5%"))

		layout.LeftAlignWith(ttext, Choices)
		layout.PutAbove(ttext, Choices)

		local names = mod.GetTypes()

		sort(names)

		Choices:AppendList(names)

		return { choices = Choices }
	end, CombineHelpVars)

	return _ListOfItemsMaker_(name, mod, params, function()
		return Choices:GetSelectionData()
	end)
end

-- Cached module members.
_ListOfItemsMaker_ = M.ListOfItemsMaker

-- Export the module.
return M