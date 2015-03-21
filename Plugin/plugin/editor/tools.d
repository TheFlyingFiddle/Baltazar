module plugin.editor.tools;

import math;
import bridge.core;
import window.mouse;
import window.keyboard;
import common.components;
import plugin.attributes;
import graphics.textureatlas;
import rendering.shapes;


@WorldTool("Selection")
struct Select
{
	bool usable(WorldToolContext* context) { return true; }

	int hover;
	void use(WorldToolContext* context)
	{
		this.hover = -1;
		foreach(i, ref item; context.world.items)
		{
			auto trans = item.peek!(Transform);
			if(trans)
			{
				auto loc = context.camera.screenToWorld(context.mouse.location);
				Rect r   = Rect(trans.position.x - trans.scale.x / 2,
								trans.position.y - trans.scale.y / 2,
								trans.scale.x, trans.scale.y);
				if(r.contains(loc))
				{
					hover = i;

					if(context.mouse.wasPressed(MouseButton.left))
					{
						import log;
						logInfo("I selected a new item!");
						context.world.selectedItem = i;
						context.world.select(i, 0);			
					}
					return;
				}
			}
		}
	}

	void render(RenderContext* context)
	{
		if(hover != -1 && hover < context.world.items.length)
		{
			auto item = context.world.items[hover];

			auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
			auto frame = (*atlas)["pixel"];
			auto transform = item.peek!(Transform);
			
			float2 trans = context.camera.worldToScreen(transform.position); 
			float2 min = trans - transform.scale * context.camera.scale / 2;
			float2 max = trans + transform.scale * context.camera.scale / 2;

			context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, Color(0x88888888));
		}
	}
}

@WorldTool("Grab")
struct Grab
{
	bool usable(WorldToolContext* context) { return true; }

	void use(WorldToolContext* context)
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
}

// Moves the selected object
@WorldTool("Move")
struct Move
{
	bool usable(WorldToolContext* context) {
		auto selected = context.world.items[context.world.selectedItem];
		auto trans = selected.peek!Transform;
		return trans != null;
	}

	int hover;
	float2 lastLocation;
	bool moving = false;
	void use(WorldToolContext* context)
	{
		if(moving) {
			if(context.mouse.wasReleased(MouseButton.left)) {
				moving = false;
				return;
			} else {
				auto selected = context.world.items[context.world.selectedItem];
				auto trans = selected.peek!Transform;
				auto newLocation = context.camera.screenToWorld(context.mouse.location);
				trans.position += newLocation - lastLocation;
				lastLocation = newLocation;
			}
		} else {
			if(context.mouse.wasPressed(MouseButton.left)) {
				moving = true;
				lastLocation = context.camera.screenToWorld(context.mouse.location);
			}
		}
	}
}

import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.tools);