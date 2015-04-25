module plugin.editor.panels.components;

import plugin.editor.panels.common;

@DontReflect
struct ComponentsPanelImpl
{
	import util.traits;
	int  selectedComponent;


	IEditorState state;
	Guid oldItem;

	//Gui state
	EditText textData;
	float2 scroll;
	float2 area;
	ulong active;

	this(IAllocator all)
	{
		textData   = EditText(all, 50);

		this.scroll = float2.zero;
		this.area   = float2.zero;
		this.active = 0;
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
		Rect addBox		 = Rect(defSpacing, offset - defSpacing, 100, defFieldSize);
		Rect compTypeBox = addBox;
		compTypeBox.x  = addBox.right + defSpacing;
		compTypeBox.w  = gui.area.w - defSpacing * 3 - addBox.w ; 

		import std.algorithm;
		gui.selectionfield(compTypeBox, selectedComponent, ComponentIDs);
		if(gui.button(addBox, "AddComp"))
		{
			ulong bit   = 1 << cast(ulong)selectedComponent;
			ulong comps = entity.components;
			if((comps & bit) != bit)
			{
				//Add the component to the entity;
				entity.components = (comps | bit); //This is how you do that :) 
				state.setRestorePoint();
			}
		}

		offset -= defFieldSize;

		ulong comps = entity.components;
		foreach(i; staticIota!(0, ComponentTypes.length))
		{
			alias CT = ComponentTypes[i];
			enum  CN = Identifier!CT;

			ulong bit = 1 << cast(ulong)i;
			if((comps & bit) == bit)
			{
				offset -= defFieldSize;
				Rect r = Rect(defSpacing, offset, gui.area.w - defSpacing, defFieldSize);
				gui.label(r, ComponentIDs[i], HorizontalAlignment.center);

				r.x += 2;
				r.y += 2;
				r.w = 16;
				r.h -= 4;

				bool act = (active & bit) == bit;
				gui.toggle(r, act, "", HashID("arrowToggle"));
				active = act ? (active | bit) : (active & ~bit);

				r.x = gui.area.w - 35;
				if(gui.button(r, "", HashID("deleteButton")))
				{
					entity.components = (comps & ~bit);
					auto proxy = state.proxy!(CT)(item);
					proxy.destroy();
				}

				if((active & bit) == bit) 
				{
					auto proxy = state.proxy!(CT)(item);
					CT inst = proxy.get();
					if(comp(gui, inst, offset,  gui.area.w - defSpacing * 2))
					{
						proxy.set(inst);
					}
				}

				offset -= defFieldSize + defSpacing;
				r = Rect(defSpacing, offset, gui.area.w - defSpacing * 2, defFieldSize);
				gui.separator(r, Color(0xFFB3B0A9));
			}
		}

		oldItem = item;
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