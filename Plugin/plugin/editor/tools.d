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
	bool usable(ToolContext* contex) { return true; }
	
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

		auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
		auto pixel = (*atlas)["pixel"];

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
	bool usable(ToolContext* contex) { return true; }

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

	void render(RenderContext* context)
	{
	}
}

class Move  : ITool
{
	string name() { return "Move"; }

	bool usable(ToolContext* context) 
	{
		return true;
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