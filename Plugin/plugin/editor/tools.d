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
	
	Guid hover;
	void use(ToolContext* context)
	{
		auto entities = context.state.getProperty!(Guid[])(Guid.init, EntitySet);
		if(!entities) return;

		foreach(ref guid; *entities)
		{
			auto entity = context.state.proxy!(Entity)(guid);
			if(Entity.hasComponents!(Transform)(entity.components))
			{
				auto trans = context.state.proxy!(Transform)(guid);
				auto loc = context.camera.screenToWorld(context.mouse.location);
				Rect r   = Rect(trans.position.x - trans.scale.x / 2,
								trans.position.y - trans.scale.y / 2,
								trans.scale.x, trans.scale.y);
				if(r.contains(loc))
				{
					hover = guid;
					if(context.mouse.wasPressed(MouseButton.left))
					{
						if(!context.keyboard.isModifiersDown(KeyModifiers.control))
							SharedData.selected.clear();

						SharedData.selected ~= guid;
					}
					
					return;
				}
			}
		}

		hover = Guid.init;
	}

	void render(RenderContext* context)
	{
		if(hover == Guid.init) return;
		auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
		auto frame = (*atlas)["pixel"];
	
		auto transform = context.state.proxy!(Transform)(hover).get();

		float2 trans = context.camera.worldToScreen(transform.position); 
		float2 min = trans - transform.scale * context.camera.scale / 2;
		float2 max = trans + transform.scale * context.camera.scale / 2;
		context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, Color(0x88888888));
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