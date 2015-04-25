module plugin.editor.tools;

import math;
import bridge.core;
import window.mouse;
import window.keyboard;
import common.components;
import plugin.attributes;
import graphics.textureatlas;
import rendering.shapes;
import util.traits;
import plugin.core.data;

alias Tools = Classes!(plugin.editor.tools);

interface ITool
{
	string name();
	bool usable(ToolContext* contex);
	void use(ToolContext* context);
	void render(RenderContext* context);
}

class Select : ITool
{
	string name() { return "Select"; }
	bool usable(ToolContext* contex) 
	{
		return  SharedData.mode == Mode.entity;
	}
	
	float2 start, end;
	void use(ToolContext* context)
	{
		if(context.mouse.wasPressed(MouseButton.left))
		{
			start = context.camera.screenToWorld(context.mouse.location);
			end   = start;
		}
		else if(context.mouse.isDown(MouseButton.left))
		{
			end   = context.camera.screenToWorld(context.mouse.location);
		}
		else if(context.mouse.wasReleased(MouseButton.left))
		{
			end	  = context.camera.screenToWorld(context.mouse.location);
			selectEntities(context);
		}
		else 
		{
			start = end = float2.zero;
		}
	}

	void selectEntities(ToolContext* context)
	{
		SharedData.selected.clear();
		Rect bounds = Rect(start, end);

		auto entities = context.state.getProperty!(Guid[])(Guid.init, EntitySet);
		if(!entities) return;

		foreach(ref guid; *entities)
		{
		    auto entity = context.state.proxy!(Entity)(guid);
		    if(Entity.hasComponents!(Transform)(entity.components))
		    {
		        auto trans = context.state.proxy!(Transform)(guid);
		        Rect r   = Rect(trans.position.x - trans.scale.x / 2,
		                        trans.position.y - trans.scale.y / 2,
		                        trans.scale.x, trans.scale.y);
		        if(r.intersects(bounds))
		        {
			        SharedData.selected ~= guid;
		        }
		    }
		}
	}

	void render(RenderContext* context)
	{
		if(start == end) return;

		auto entities = context.state.getProperty!(Guid[])(Guid.init, EntitySet);
		if(!entities) return;

		auto atlas = Editor.assets.locate!(TextureAtlas)(Atlas);
		auto pixel = (*atlas)[Pixel];

		Rect bounds = Rect(start, end);
		foreach(ref guid; *entities)
		{
			auto entity = context.state.proxy!(Entity)(guid);
		    if(Entity.hasComponents!(Transform)(entity.components))
		    {
		        auto trans = context.state.proxy!(Transform)(guid);
				Rect r   = Rect(trans.position.x - trans.scale.x / 2,
		                        trans.position.y - trans.scale.y / 2,
		                        trans.scale.x, trans.scale.y);
		        if(r.intersects(bounds))
		        {
					float2 pos = context.camera.worldToScreen(trans.position); 
					float2 min = pos - trans.scale * context.camera.scale / 2;
					float2 max = pos + trans.scale * context.camera.scale / 2;
					context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), trans.rotation, pixel, Color(0x88888888));
		        }
		    }
		}

		Rect screenBounds = Rect(context.camera.worldToScreen(float2(bounds.xy)),
								 context.camera.worldToScreen(float2(bounds.zw)));

		context.renderer.drawQuad(screenBounds.toFloat4, 0, pixel, Color(0x44444444));
		context.renderer.drawQuadOutline(screenBounds.toFloat4, 1.0f, pixel, Color(0xff000000));
	}
}

class Grab  : ITool
{
	string name() { return "Grab"; }
	bool usable(ToolContext* contex) 
	{
		return true;
	}

	void use(ToolContext* context)
	{
		Rect area = Rect(context.camera.viewport);
		if(area.contains(context.mouse.location))
		{
			if(context.mouse.isDown(MouseButton.left))
			{
				auto downLoc = context.mouse.state(MouseButton.left).lastDown;
				if(area.contains(downLoc))
				{
					float2 offset = context.mouse.moveDelta / context.camera.scale;
					context.camera.position -= offset;
				}
			}
		}
	}

	void render(RenderContext* context) { }
}

class Move  : ITool
{
	string name() { return "Move"; }

	bool usable(ToolContext* context) 
	{
		return SharedData.mode == Mode.entity;
	}

	float2 lastLocation;
	bool moving = false;
	void use(ToolContext* context)
	{
		if(moving) 
		{
			if(context.mouse.wasReleased(MouseButton.left)) 
			{
				moving = false;
				return;
			}
			else
			{
				auto newLocation = context.camera.screenToWorld(context.mouse.location);
				auto delta		 = newLocation - lastLocation;
				lastLocation	 = newLocation;

				foreach(ref guid; SharedData.selected)
				{
					auto entity = context.state.proxy!(Entity)(guid);
					if(Entity.hasComponents!(Transform)(entity.components))
					{
						auto trans = context.state.proxy!(Transform)(guid);
						trans.position = trans.position + delta;
					}
				}
			}
		} 
		else
		{
			if(context.mouse.wasPressed(MouseButton.left)) 
			{
				moving = true;
				lastLocation = context.camera.screenToWorld(context.mouse.location);
			}
		}
	}

	void render(RenderContext* context) { }
}



//TILE MODE
import plugin.tile.data;
class TilePaiter  : ITool
{
	string name() { return "Tiler"; }

	bool usable(ToolContext* context) 
	{
		return SharedData.mode == Mode.tile;
	}

	void createMap()
	{
		auto obj = Editor.state.createObject;
		Editor.state.setProperty(Guid.init, TileMapID, obj);

		//Should move this somewhere!
		auto tm = Editor.state.proxy!TileMap(obj);
		tm.capacity = 10;
		tm.positions.initialize(10);
		tm.type.initialize(10);
		tm.tint.initialize(10);
		tm.tileID.initialize(10);
	}

	import log;
	void growMap()
	{	
		Editor.state.setRestorePoint();

		auto oldObj = Editor.state.getProperty!Guid(Guid.init, TileMapID);
		auto tmOld   = Editor.state.proxy!TileMap(*oldObj);
		auto nCap    = tmOld.capacity * 2;


		auto pos    = tmOld.positions.get();
		auto type   = tmOld.type.get();
		auto tint   = tmOld.tint.get();
		auto tileID = tmOld.tileID.get();


		Editor.state.destroy(*oldObj);
		auto obj = Editor.state.createObject();
		Editor.state.setProperty(Guid.init, TileMapID, obj);

		auto tm = Editor.state.proxy!(TileMap)(obj);

		tm.capacity = nCap;
		tm.positions.initialize(nCap);
		tm.type.initialize(nCap);
		tm.tint.initialize(nCap);
		tm.tileID.initialize(nCap);

		auto nPos    = tm.positions.get();
		auto ntype   = tm.type.get();
		auto ntint   = tm.tint.get();
		auto ntileID = tm.tileID.get(); 

		nPos[0 .. nCap / 2] = pos;
		ntype[0 .. nCap / 2] = type;
		ntint[0 .. nCap / 2] = tint;
		ntileID[0 .. nCap / 2] = tileID;
	}

	auto getMap()
	{
		auto obj = Editor.state.getProperty!Guid(Guid.init, TileMapID);
		if(!obj)
		{
			createMap();
			obj = Editor.state.getProperty!Guid(Guid.init, TileMapID);
		}
		return Editor.state.proxy!TileMap(*obj);
	}

	//Add support of controll click adding.
	int counter = 0;
	void use(ToolContext* context)	
	{
		auto m = context.mouse;
		if(m.isDown(MouseButton.left))
		{
			auto loc  = context.camera.screenToWorld(m.location);
			int2 iloc = int2(loc);
			
			if(loc.x < -0.5) iloc.x--;
			if(loc.y < -0.5) iloc.y--;

			auto tm   = getMap();
			auto type = tm.type.get();
			auto pos  = tm.positions.get();
			auto img  = tm.tileID.get();

			int free  = -1;
			int taken = -1;
			int cap	  = tm.capacity;
			foreach(i; 0 .. tm.capacity)
			{
				if(pos[i] == iloc && type[i] != 0 &&
				   img[i] == TileData.image.value) 
				{
					taken = i;
					break;
				}

				if(type[i] == 0 || (pos[i] == iloc && img[i] != TileData.image.value)) {
					free = i;
					break;
				}

			}

			if(taken != -1) return;
			
			if(free == -1) {
				growMap();
				auto tmn = getMap();
				tmn.positions[cap] = iloc;
				tmn.type[cap]	   = cast(ubyte)TileType.normal;
				tmn.tileID[cap]	   = TileData.image.value;
			}
			else 
			{
				tm.positions[free] = iloc;
				tm.type[free]	   = cast(ubyte)TileType.normal;
				tm.tileID[free]	   = TileData.image.value;
			}
			counter++;
		
		}

		if(m.wasReleased(MouseButton.left))
		{
			if(counter > 0)
				context.state.setRestorePoint();
			
			counter = 0;
		}
	}

	void render(RenderContext* context) { }
}

class TileEraser : ITool
{
	string name() { return "Eraser"; }

	bool usable(ToolContext* context) 
	{
		return SharedData.mode == Mode.tile;
	}


	auto getMap()
	{
		auto obj = Editor.state.getProperty!Guid(Guid.init, TileMapID);
		return Editor.state.proxy!TileMap(*obj);
	}

	int counter = 0;
	void use(ToolContext* context)	
	{
		if(!Editor.state.exists(Guid.init, TileMapID)) return;

		auto m = context.mouse;
		if(m.isDown(MouseButton.left))
		{
			auto loc  = context.camera.screenToWorld(m.location);
			int2 iloc = int2(loc);

			if(loc.x < -0.5) iloc.x--;
			if(loc.y < -0.5) iloc.y--;

			auto tm   = getMap();
			auto type = tm.type.get();
			auto pos  = tm.positions.get();

			int taken = -1;
			foreach(i; 0 .. tm.capacity)
			{
				if(pos[i] == iloc && type[i] != 0) 
				{
					taken = i;
					break;
				}
			}

			if(taken == -1) return;
			
			tm.positions[taken] = int2.zero;
			tm.type[taken]		= 0;
			tm.tileID[taken]	= 0;
			counter++;

		}

		if(m.wasReleased(MouseButton.left))
		{
			if(counter > 0)
				context.state.setRestorePoint();

			counter = 0;
		}
	}


	void render(RenderContext* context) { }
}		