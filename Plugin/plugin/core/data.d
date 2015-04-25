module plugin.core.data;

import allocation;
import bridge.attributes;
import bridge.core;
import reflection;

import collections.list;
import util.variant;
import math.vector;

enum Fonts = "Fonts";
enum Consola = "consola";
enum Atlas = "GuiAtlas";
enum Pixel = "pixel";

enum EntitySet    = "entities";
enum ArchetypeSet = "archetypes";

enum Mode
{
	entity,
	tile
}


struct SharedDataCont
{
	Guid			   archetype;
	GrowingList!(Guid) selected;
	Camera			   camera;
	Mode			   mode;
}

__gshared SharedDataCont SharedData;

__gshared static this()
{
	SharedData.archetype = Guid.init;
	SharedData.selected  = GrowingList!(Guid)(Mallocator.cit, 10);
	SharedData.camera	 = Camera.init;
	SharedData.mode		 = Mode.entity;
}

struct Tmp
{
	Guid[] guids;
}

@DontReflect
struct Entity
{
	string name;
	ulong  components;
	static auto create(IEditorState state, string name, string set)
	{
		auto obj   = state.createObject();
		state.addToSet(Guid.init, set, obj);
		auto proxy = state.proxy!(Entity)(obj);
		proxy.name = name;

		return obj;
	}

	static void destroy(IEditorState state, Guid guid, string set)
	{
		state.removeFromSet(Guid.init, set, guid); 
		state.destroy(guid);
	}

	static bool hasComponents(T...)(ulong components)
	{
		enum mask = componentMask!T;
		return (components & mask) == mask;
	}

	static ulong componentMask(T...)()
	{
		import std.typetuple;
		import common.components;
		ulong mask = 0;
		foreach(i, ct; ComponentTypes)
		{
			static if(staticIndexOf!(ct, T) != -1)
			{
				mask |= (1 << i);
			}
		}
		return mask;
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

enum isTrue(T) = true;
mixin GenerateMetaData!(isTrue, plugin.core.data);