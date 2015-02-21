module ui.tabcontrol;
import ui.base;
import ui.textfield;
import ui.controls;

struct GuiTabs
{
	struct Style
	{
		GuiFrame pageBg;
		HashID	 toolbarStyle; 
		float	toolbarSize;
	}

	struct State
	{
		float2 scroll;
		int    focused;
		bool   focusLocked;
	}
}

struct TabPage
{
	GuiElement element;
	void delegate(ref Gui) guidel;

	this(T)(auto ref T t, void delegate(ref Gui) guidel)
	{
		this.element = t;
		this.guidel = guidel;
	}
}

import std.range;
bool tabs(Pages)(ref Gui gui, Rect rect, ref int selected, Pages pages, HashID s = "tabs")
{
	auto style = gui.fetchStyle!(GuiTabs.Style)(s);
	auto hash  = bytesHash(rect);
	auto state = gui.fetchState(hash, GuiTabs.State(float2.zero, -1, false));
	scope(exit) gui.state(hash, state);

	auto toolbarRect = Rect(rect.x, rect.y + rect.h - style.toolbarSize, rect.w, style.toolbarSize); 
	auto select = gui.toolbar(toolbarRect, selected, pages.map!(x => x.element));
	auto pageRect = Rect(rect.x, rect.y, rect.w, rect.h - style.toolbarSize);

	if(selected != -1)
	{
		gui.scrollarea(pageRect, state.scroll, pages[selected].guidel, pageRect);
	}

	return select;
}