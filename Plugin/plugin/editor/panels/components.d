module plugin.editor.panels.components;

import plugin.editor.panels.common;

@DontReflect
struct ComponentsPanelImpl
{
	enum maxComponents = 100;

	import util.traits;
	int  selectedComponent;
	IEditorState state;
	Guid oldItem;

	//Gui state
	EditText textData;
	float2 scroll;
	float2 area;
	bool[]	activeComps;

	this(IAllocator all)
	{
		textData   = EditText(all, 50);

		this.scroll = float2.zero;
		this.area   = float2.zero;
		activeComps	= all.allocate!(bool[])(maxComponents);
		activeComps[] = true;
	}

	void show(PanelContext* context)
	{

		Rect area = context.area;
		this.area = float2(area.w, area.h);

		state = Editor.state;

		scrollarea(*context.gui, area,scroll, &show);
	}

	void name(ref Gui gui, ref Rect r, string name, int size)
	{
		gui.label(Rect(r.x, r.y, size, r.h), name);

		r.x += size + defSpacing;
		r.w -= size + defSpacing;
	}

	void show(ref Gui gui)
	{
		if(SharedData.selected.length != 1)	return;

		auto item = SharedData.selected[0];
		if(item != oldItem  && oldItem != 0)
		{
			activeComps[] = true;
			state.setRestorePoint();
		}

		auto entity	 = state.proxy!Entity(item);
		Rect nameBox = Rect(defSpacing, area.y - defFieldSize - defSpacing, gui.area.w - defSpacing * 2, defFieldSize);

		//Name field
		name(gui, nameBox, "Name", 100);
		textData ~= entity.name;
		if(gui.textfield(nameBox, textData))
		{
			auto m = Mallocator.it.allocate!(char[])(textData.length, 4);
			m[]    = textData.array;
			entity.name = cast(string)m;
		}
		textData.clear();
	
	
		//Add component field
		float offset = area.y - 43;	
		float width  = gui.area.w - defSpacing * 2;
		Rect addBox		 = Rect(defSpacing, offset - defSpacing, 100, defFieldSize);
		Rect compTypeBox = addBox;
		compTypeBox.x  = addBox.right + defSpacing;
		compTypeBox.w  = gui.area.w - defSpacing * 3 - addBox.w ; 


		import pluginshared.data;
		auto comps  = Editor.services.locate!(MetaComponents);

		import std.algorithm;
		gui.selectionfield(compTypeBox, selectedComponent, comps.components.map!(x => x.name));
		if(gui.button(addBox, "AddComp"))
		{
			auto selComp = comps.components[selectedComponent].hash;
			auto ecomps = entity.components.get();
			if(!ecomps.canFind!(x => x == selComp))
			{
				entity.components ~= selComp;
			}
		}
		import log;

		ubyte[256] buffer; 
		uint[100]  comp_copy;
		int length	= entity.components.get().length;
		comp_copy[0 .. length] = entity.components.get();

		make_seperator(gui, offset, width);
		foreach(i, comp_hash; comp_copy[0 .. length])
		{
			auto meta_comps = comps.components.find!(x => x.hash == comp_hash)[0];
			
			offset -= defFieldSize;
			Rect r = Rect(defSpacing, offset, gui.area.w - defSpacing, defFieldSize);
			gui.label(r, meta_comps.name, HorizontalAlignment.center);

			r.x += 2;
			r.y += 2;
			r.w = 16;
			r.h -= 4;

			gui.toggle(r, activeComps[i], "", HashID("arrowToggle"));

			r.x = gui.area.w - 35;
			if(gui.button(r, "", HashID("deleteButton")))
			{
				entity.components.removeAt(i);
			}

			if(activeComps[i])
			{
				meta_comps.load(state, item, buffer.ptr);
				meta_comps.show(gui, offset, width, buffer.ptr);
				meta_comps.store(state, item, buffer.ptr);
			}
			
			make_seperator(gui, offset, width);
		}
	}
	

	void make_seperator(ref Gui gui, ref float offset, float width)
	{
		offset -= defFieldSize + defSpacing;
		Rect r = Rect(defSpacing, offset, width, defFieldSize);
		gui.separator(r, Color(0xFFB3B0A9));
	}

	bool comp(T)(ref Gui gui, ref T t, ref float offset, float width)
	{
		auto size = gui.typefieldHeight(t);
		offset -= size + 5;
		return gui.typefield(Rect(5, offset, width, size), t, &this);
	}
	

	bool handle(ref Gui gui, Rect r, ref TextureID t, HashID styleID)
	{
		auto atlases = Editor.gameAssets.loadedAssets("atl");
		int aIdx    = cast(uint)atlases.countUntil!(x => x.name == t.atlas);
		int iIdx  = -1;
		if(aIdx != -1) 
		{
			iIdx = cast(uint)atlases[aIdx].subitems.countUntil!(x => x == t.image);
		}

		Rect atlasRect = Rect(r.x, r.y + 23, r.w, 20);
		Rect imgRect   = Rect(r.x, r.y, r.w, 20);

		bool result = false;
		if(gui.selectionfield(atlasRect, aIdx, atlases.array.map!(x => x.name)))
		{
			t.atlas = atlases[aIdx].name;
			result = true;
		}

		if(aIdx != -1 && gui.selectionfield(imgRect, iIdx, atlases[aIdx].subitems))
		{
			t.image = atlases[aIdx].subitems[iIdx];
			result = true;
		}

		return result;
	}

	
	bool handle(ref Gui gui, Rect r, ref FontID t, HashID styleID)
	{
		auto atlases = Editor.gameAssets.loadedAssets("fontatl");
		int aIdx = cast(int)atlases.countUntil!(x => x.name == t.atlas);
		int fIdx = -1;
		if(aIdx != -1) 
		{
			fIdx = cast(int)atlases[aIdx].subitems.countUntil!(x => x == t.font);
		}

		Rect atlasRect = Rect(r.x, r.y + 23, r.w, 20);
		Rect fntRect   = Rect(r.x, r.y, r.w, 20);

		bool result = false;
		if(gui.selectionfield(atlasRect, aIdx, atlases.array.map!(x => x.name)))
		{
			t.atlas = atlases[aIdx].name;
			result = true;
		}

		if(aIdx != -1 && gui.selectionfield(fntRect, fIdx, atlases[aIdx].subitems))
		{
			t.font = atlases[aIdx].subitems[fIdx];
			result = true;
		}

		return result;
	}
}

@EditorPanel("Components", PanelPos.right) 
struct ComponentsPanel
{
	ComponentsPanelImpl pimp;
	this(IAllocator all)
	{
		pimp = ComponentsPanelImpl(all);
	}

	void show(PanelContext* context) 
	{
		pimp.show(context);
	}
}


enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.panels.components);