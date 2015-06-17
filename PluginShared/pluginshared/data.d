module pluginshared.data;

import allocation;
import collections.list;
import util.variant;
import math.vector;

enum Fonts			= "Fonts";
enum Consola		= "consola";
enum Atlas			= "GuiAtlas";
enum Pixel			= "pixel";
enum EntitySet		= "entities";
enum ArchetypeSet	= "archetypes";

enum Mode
{
	entity, tile
}

struct Entity
{
	import bridge.core, bridge.data;

	string name;
	uint[] components;

	static auto create(IEditorState state, string name, string set)
	{
		auto obj   = state.createObject();
		state.appendArrayElement(Guid.init, set, obj);
		auto proxy = state.proxy!(Entity)(obj);
		proxy.name = name;

		return obj;
	}

	static void destroy(IEditorState state, Guid guid, string set)
	{
		state.removeArrayElement(Guid.init, set, toByteArray(guid)); 
		state.destroy(guid);
	}

	static bool hasComponents(T...)(Guid entity)
	{
		auto proxy = Editor.state.proxy!(Entity)(entity);
		auto comps = proxy.components.get();

		import util.hash;
		
		foreach(type; T)
		{
			bool found = false;
			foreach(hs; comps)
			{
				if(typeHash!type.value == hs)
				{
					found = true;		 
					break;
				}
			}

			return found;
		}

		return true;
	}
}

struct Camera
{
	float4 viewport = float4.zero;
	float2 position = float2.zero;
	float  scale	= 32;

	float2 screenToWorld(float2 screenPos)
	{
		screenPos = (screenPos + position * scale) - viewport.xy - (viewport.zw - viewport.xy) / 2;
		return screenPos / scale;
	}

	float2 worldToScreen(float2 world)
	{
		world = (world - position) * scale;
		return world + viewport.xy + (viewport.zw - viewport.xy) / 2;
	}
}

struct SharedDataCont
{
	uint			    archetype;
	GrowingList!(uint)  selected;
	Camera			    camera;
	Mode			    mode;

	static SharedDataCont* initialize(IAllocator allocator)
	{
		auto d = allocator.allocate!SharedDataCont;
		d.archetype = 0;
		d.selected  = GrowingList!(uint)(allocator, 10);
		d.camera    = Camera.init;
		d.mode	    = Mode.entity;

		SharedData = d;

		return d;
	}
}

__gshared SharedDataCont* SharedData;

import ui.base, bridge.data;
alias showFunction = bool function(ref Gui, ref float, float, void*);
alias loadComponent = void* function(IEditorState, uint, void*);
alias storeComponent = void function(IEditorState, uint, void*);

struct MetaComponent
{
	string name;
	uint   hash;
	uint size;
	showFunction show;
	loadComponent load;
	storeComponent store;
}

struct MetaComponents
{
	GrowingList!(MetaComponent) components;	
	static MetaComponents* initialize(IAllocator allocator)
	{
		auto m = allocator.allocate!MetaComponents;
		m.components = GrowingList!(MetaComponent)(allocator, 10);
		return m;
	}

	void add(MetaComponent mcomp)
	{
		import std.algorithm;
		auto idx = components.countUntil!(x => x.hash == mcomp.hash);
		if(idx != -1)
		{
			components[idx] = mcomp;
		}
		else 
		{
			components  ~= mcomp;
		}
	}
}