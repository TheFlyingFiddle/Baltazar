module plugin.editor.panels;

import ui;
import math.vector;
import collections.list;
import allocation;
import reflection;

import std.typetuple;
import std.algorithm;

import common.attributes;
import common.identifiers;
import bridge;

import plugin.editor.commands;
import plugin.editor.data;

enum defFieldSize = 20;
enum defSpacing   = 3;


@DontReflect
struct ComponentsPanelImpl
{
	import util.traits;

	WorldData* state;
	EditText textData;
	float2 scroll;
	float2 area;
	int selectedComponent;

	List!MetaType components;
	List!bool active;

	this(IAllocator all)
	{
		textData   = EditText(all, 50);

		this.scroll = float2.zero;
		this.area   = float2.zero;
		this.components = List!MetaType(all, 50);
		this.active = List!bool(all, 20);
		this.active.length = 20;
		this.active[] = false;
	}

	void show(PanelContext* context)
	{

		Rect area = context.area;
		this.area = float2(area.w, area.h);

		state = Editor.data.locate!(WorldData);

		scrollarea(*context.gui, area,scroll, &show);
	}

	void show(ref Gui gui)
	{
		auto item = state.selected.proxy;
		if(item)
		{
			auto plugin  = Editor.services.locate!(Plugins);
			auto doUndo	 = Editor.data.locate!(DoUndo);
			

			auto comps = plugin.attributeTypes!EntityComponent;
			components.clear();
			foreach(ref comp; comps)
			{
				components ~= comp;
			}

			Rect nameBox = Rect(defSpacing, area.y - defFieldSize - defSpacing, gui.area.w - defSpacing * 2, defFieldSize);
	
			textData ~= item.name;
			name(gui, nameBox, "Name", 100);
			if(gui.textfield(nameBox, textData))
			{
			    doUndo.apply(ChangeItemName(textData.array));
			}

			textData.clear();

			float offset = area.y - 43;	
			Rect addBox		 = Rect(defSpacing, offset - defSpacing, 100, defFieldSize);
			Rect compTypeBox = addBox;
			compTypeBox.x  = addBox.right + defSpacing;
			compTypeBox.w  = gui.area.w - defSpacing * 3 - addBox.w ;

			import std.algorithm;
			gui.selectionfield(compTypeBox, selectedComponent, components.map!(x => x.typeInfo.name));
			if(gui.button(addBox, "AddComp"))
			{
				auto type = &components[selectedComponent];
				if(!item.hasComponent(type.typeInfo))
				{
					doUndo.apply(AddComponent(type.initial!48));
				}
			}
			offset -= 15;

			int toRemove = -1;
			foreach(i, ref component; item.components)
			{
				auto type = &components.find!(x => x.isTypeOf(component))[0];

				offset -= defFieldSize;
				Rect r = Rect(defSpacing, offset, gui.area.w - defSpacing, defFieldSize);
				gui.label(r, type.typeInfo.name, HorizontalAlignment.center);

				r.x += 2;
				r.y += 2;
				r.w = 16;
				r.h -= 4;

				gui.toggle(r, active[i], "", HashID("arrowToggle"));
				r.x = gui.area.w - 35;
				if(gui.button(r, "", HashID("deleteButton")))
					toRemove = i;

				offset -= defFieldSize + defSpacing;
				if(active[i]) 
					comp(gui, component.data.ptr, type.typeInfo, offset, defSpacing, gui.area.w - defSpacing * 2);

				r = Rect(defSpacing, offset, gui.area.w - defSpacing * 2, 20);
				gui.separator(r, Color(0xFFB3B0A9));
			}

			if(toRemove != -1)
			{
				doUndo.apply(RemoveComponent(toRemove));
			}
		}
	}

	float size(ref Gui gui, const(RTTI)* info, void* value)
	{
		//Add identifiers here aswell!
		alias base		 = TypeTuple!(ubyte,  byte, 
									  ushort, short, 
									  uint,   int,
									  float,  double, 
									  real,   bool,
									  string,
									  float2, float3,
									  float4, Color,
									  Structs!(common.identifiers));

		enum Dummy { a, b };
		if(info.type == RTTI.Type.enum_)
		{
			Dummy d;
			return gui.typefieldHeight(d);
		}

		foreach(type; base)
		{
			if(info.isTypeOf!type)
			{
				return gui.typefieldHeight(*cast(type*)value);
			}
		}

		return 0;
	}

	bool comp(ref Gui gui, void* value, const(RTTI)* t, ref float offset, float left, float width)
	{
		alias base		 = TypeTuple!(ubyte,  byte, 
									  ushort, short, 
									  uint,   int,
									  float,  double, 
									  real,   bool,
									  float2, float3,
									  float4, Color);
		foreach(type; base)
		{
			if(t.isTypeOf!type)
			{
				Rect r   = Rect(left, offset, width, size(gui, t, value));
				return gui.typefield(r, *cast(type*)value);
			}
		}

		auto style = gui.fetchStyle!(GuiTypeField.Style)(HashID("typefield"));
		final switch(t.type) with(RTTI.Type)
		{
			case enum_:
				Rect r   = Rect(left, offset, width, size(gui, t, value));
				auto m   = t.metaEnum.constants.map!(x => x.name);
				auto idx = t.metaEnum.constants.countUntil!(x => x.value == *cast(uint*)value); 
				auto res = gui.selectionfield(r, idx, m);
				if(res)
					*cast(uint*)value = t.metaEnum.constants[idx].value;
				return res;
			case array:
				if(t.isTypeOf!(char[]))
				{
					Rect r   = Rect(left, offset, width, size(gui, t, value));
					return gui.typefield(r, *cast(string*)value);
				}
				break;
			case struct_:
				alias identifiers		= Structs!(common.identifiers);
				foreach(id; identifiers)
				{
					if(t.isTypeOf!id)
					{
						Rect r   = Rect(left, offset, width, size(gui, t, value)); 	
						return handle(gui, r, *cast(id*)value, HashID("typefield"));
					}
				}

				offset += 20;

				bool changed = false;
				foreach(field; t.metaType.instanceFields)
				{
					auto   s = size(gui, field.typeInfo, value);
					offset  -= style.itemSpacing + s;

					Rect r   = Rect(left, offset, width, s);
					r.w = style.nameWidth + style.itemSpacing;
					gui.label(r, field.name);
					changed |= comp(gui, value + field.offset, field.typeInfo, offset, r.w, width - r.w + defSpacing);
				}

				offset -= 20;

				return changed;
			case pointer:
				break;
			case primitive:
			case class_: assert(0, "Cannot show classes!");

		}

		return false;
	}

	bool handle(ref Gui gui, Rect r, ref TextureID t, HashID styleID)
	{
		auto atlases = Editor.assets.loadedAssets("atl");
		auto aIdx = atlases.countUntil!(x => x.name == t.atlas);
		auto iIdx = -1;
		if(aIdx != -1) 
		{
			iIdx = atlases[aIdx].subitems.countUntil!(x => x == t.image);
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
		auto atlases = Editor.assets.loadedAssets("fontatl");
		auto aIdx = atlases.countUntil!(x => x.name == t.atlas);
		auto fIdx = -1;
		if(aIdx != -1) 
		{
			fIdx = atlases[aIdx].subitems.countUntil!(x => x == t.font);
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

	bool handle(ref Gui gui, Rect r, ref ParticleID t, HashID styleID)
	{
		/*
		auto idx = state.particleSystems.countUntil!(x => x == t.name);
		if(gui.selectionfield(r, idx, state.particleSystems))
		{
			t.name = state.particleSystems[idx];
			return true;
		}
		*/

		return false;
	}

	bool handle(ref Gui gui, Rect r, ref EntityRef t, HashID styleID)
	{
		auto idx = state.items.countUntil!(x => x.id == t.id);
		if(gui.selectionfield(r, idx, state.items.array.map!(x => x.name)))
		{
			t.id = state.items[idx].id;
			return true;
		}

		return false;
	}

	bool handle(ref Gui gui, Rect r, ref ArchetypeID t, HashID styleID) 
	{
		/*
		auto idx = state.archetypes.countUntil!(x => x.name == t.name);
		if(gui.selectionfield(r, idx, state.archetypes.array.map!(x => x.name)))
		{
			t.name = state.archetypes[idx].name;
			return true;
		}
		*/

		return false;
	}

	void name(ref Gui gui, ref Rect r, string name, int size)
	{
		gui.label(Rect(r.x, r.y, size, r.h), name);

		r.x += size + defSpacing;
		r.w -= size + defSpacing;
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

@EditorPanel("Entity", PanelPos.left)
struct EntityPanel
{
	this(IAllocator all) { }
	void show(PanelContext* context)
	{
		auto gui		   = context.gui;
		auto data		   = Editor.data.locate!(WorldData);
		auto doundo		   = Editor.data.locate!(DoUndo);

		Rect lp			   = context.area;
		Rect newItemBox    = Rect(lp.x, lp.y, lp.w / 2 - defSpacing, defFieldSize);
		Rect deleteItemBox = Rect(newItemBox.right + defSpacing * 2, lp.y, newItemBox.w, defFieldSize);
		Rect itemBox	   = Rect(lp.x, newItemBox.top + defSpacing, lp.w, lp.h - (newItemBox.top + defSpacing * 2 - lp.y));

		(*gui).listbox(itemBox, data.selectedItem, data.items.array.map!(x => x.name));
		if(data.selectedItem < data.items.length)
		{	
			data.select(data.selectedItem, 0);
		}

		if((*gui).button(newItemBox, "New"))
		{
			doundo.apply(AddItem(0));
		}

		if((*gui).button(deleteItemBox, "Delete"))
		{
			if(data.selectedItem < data.items.length)
			{
				data.select(data.selectedItem, 0);
				doundo.apply(RemoveItem(0));		

				data.selectedItem = max(0, min(data.selectedItem, data.items.length));
			}
		}
	}
}

@EditorPanel("Archetypes", PanelPos.left)
struct ArchetypesPanel
{
	this(IAllocator all) { }
	void show(PanelContext* context)
	{
		auto gui		   = context.gui;
		auto data		   = Editor.data.locate!(WorldData);
		auto doundo		   = Editor.data.locate!(DoUndo);

		Rect lp			   = context.area;
		Rect newItemBox    = Rect(lp.x, lp.y, lp.w / 2 - defSpacing, defFieldSize);
		Rect deleteItemBox = Rect(newItemBox.right + defSpacing * 2, lp.y, newItemBox.w, defFieldSize);
		Rect itemBox	   = Rect(lp.x, newItemBox.top + defSpacing, lp.w, lp.h - (newItemBox.top + defSpacing * 2 - lp.y));

		(*gui).listbox(itemBox, data.selectedArchetype, data.archetypes.array.map!(x => x.name));
		if(data.selectedArchetype < data.archetypes.length)
		{	
			data.select(data.selectedArchetype, 1);
		}

		if((*gui).button(newItemBox, "New"))
		{
			doundo.apply(AddArchetype(0));
		}

		if((*gui).button(deleteItemBox, "Delete"))
		{
			if(data.selectedArchetype < data.archetypes.length)
			{
				data.select(data.selectedArchetype, 1);
				doundo.apply(RemoveItem(0));
				data.selectedArchetype = max(0, min(data.selectedArchetype, data.items.length));
			}
		}
	}
}

@EditorPanel("World", PanelPos.center)
struct WorldPanel
{
	import plugin.attributes;

	this(IAllocator all) { }
	void show(PanelContext* context) 
	{
		auto data     = Editor.data.locate!(WorldData);
		auto camera   = Editor.data.locate!(Camera);
		auto renderer = context.gui.renderer;
		auto plugin   = Editor.services.locate!(Plugins);

		auto rcontext = RenderContext(data, camera, renderer);

		camera.viewport = context.area.toFloat4;
		foreach(ref func; plugin.attributeFunctions!WorldRenderer)
		{
			func.invoke(&rcontext);
		}
	}
}