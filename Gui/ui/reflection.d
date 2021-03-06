module ui.reflection;

import ui;
import std.traits;
import util.traits;
import math.vector;
import graphics.color;
import collections.list;

struct DontShow { }

struct GuiTypeField
{
	struct Style
	{
		float itemSpacing;
		float fieldSize;
		float nameWidth;
		bool  topDown;
	}
}

float typefieldHeight(T)(ref Gui gui, ref T t, HashID styleID = HashID("typefield"))
{
	auto style = gui.fetchStyle!(GuiTypeField.Style)(styleID);
	return typefieldHeight!T(gui, t, style);
}

float typefieldHeight(T)(ref Gui gui, ref T t, ref GuiTypeField.Style style)
{
	static if(is(T == enum) || 
			  isNumeric!T   ||
			  is(T == float2)   ||
			  is(T == EditText) || 
			  is(T == bool) || 
			  is(T == Color) || 
			  is(T == string))
	{
		return style.fieldSize;
	}
	else static if(collections.list.isList!T ||
				   isArray!T)  
	{
		if(t.length == 0) return style.fieldSize;

		auto s = typefieldHeight(gui, t[0], style);
		return (s  + style.itemSpacing) * t.length + style.fieldSize + style.itemSpacing; 
	}
	else 
	{
		float height = -style.itemSpacing;
		foreach(i, dummy; t.tupleof)
		{
			static if(!hasAttribute!(T.tupleof[i], DontShow))
			{
				height += gui.typefieldHeight(t.tupleof[i], style);
				height += style.itemSpacing;
			}
		}

		return height;
	}
}

bool typefield(T)(ref Gui gui, Rect rect, ref T t, HashID styleID = HashID("typefield"))
{
	struct Context 
	{
	}

	Context c;
	return typefield!(T, Context)(gui, rect, t, &c, styleID);
}

bool typefield(T, C)(ref Gui gui, Rect rect, ref T t, C* context, HashID styleID = HashID("typefield"))
{
	enum context_compiles = __traits(compiles, () => context.handle(gui, rect, t, styleID));
	static if(context_compiles)
	{
		return context.handle(gui, rect, t, styleID);
	}
	else static if(hasMember!(T, "showGui"))
	{
		return t.showGui(gui, rect, context, styleID);
	}
	else static if(is(T == enum))
	{
		return gui.enumField!T(rect, t); 
	}
	else static if(isNumeric!T)
	{
		return gui.numberfield(rect, t);
	}
	else static if(is(T == float2))
	{
		return gui.vectorfield(rect, t);
	}
	else static if(is(T == Color))
	{
		return gui.colorfield(rect, t);
	}
	else static if(is(T == EditText))
	{
		return gui.textfield(rect, t);
	}
	else static if(is(T == string))
	{
		//Should place this someplace else!
		char[50] buffer;
		buffer[0 .. t.length] = t;
		EditText et = EditText(buffer.ptr, t.length, 50);
		bool res = gui.textfield(rect, et);
		if(res)
		{
			import allocation;
			auto data = Mallocator.it.allocate!(char[])(et.length);
			data[] = et.array;
			t = cast(string)data;
		}

		return res;
	}
	else static if(is(T == bool))
	{
		return gui.toggle(rect, t, "True", "False");
	}
	else static if(collections.list.isList!T)
	{
		alias E = typeof(t[0]);
		auto style = gui.fetchStyle!(GuiTypeField.Style)(styleID);
		bool changed = false;
		if(!t.length == 0)
		{
			float offset;
			float size = gui.typefieldHeight!E(t[0], style);
			if(style.topDown)
			{
				offset = style.fieldSize + style.itemSpacing;
			}
			else 
			{
				offset = rect.h - size;
			}

			foreach_reverse(i; 0 .. t.length)
			{
				Rect r = rect;
				r.y		 = rect.y + offset;
				r.h      = size;
				r.w		-= 30;

				changed = gui.typefield(r, t[i], context, styleID) || changed;

				r.x = r.x + r.w + 5;
				r.w = 25;
				if(gui.button(r, "X"))
				{
					t.removeAt(i);
				}

				if(style.topDown)
					offset += style.itemSpacing + r.h;
				else 
					offset -= style.itemSpacing + r.h;
			}
		}

		Rect add = rect;
		add.h = style.fieldSize;
		add.w = 25;
		if(gui.button(add, "+"))
		{
			t ~= E.init;
			changed = true;
		}

		return changed;
	}
	else 
	{
		auto style = gui.fetchStyle!(GuiTypeField.Style)(styleID);
		float offset;
		if(style.topDown)
		{
			offset = rect.h;
		}
		else 
		{
			offset = -gui.typefieldHeight(t.tupleof[0], style);
		}

		bool changed = false;

		foreach(i, dummy; t.tupleof)
		{
			static if(!hasAttribute!(T.tupleof[i], DontShow))
			{
				float h =  gui.typefieldHeight(t.tupleof[i], style);
				if(style.topDown)
					offset -= h + style.itemSpacing;
				else 
					offset += h + style.itemSpacing;

				Rect r = rect;
				r.y		 = rect.y + offset;
				r.h      = h;
			
				r.w = style.nameWidth;
				gui.label(r, Identifier!(t.tupleof[i]));
				
				r.x = rect.x + r.w + style.itemSpacing;
				r.w = rect.w - style.nameWidth - style.itemSpacing;
				changed = gui.typefield(r, t.tupleof[i], context, styleID) || changed;
			}
		}

		return changed;
	}
}
