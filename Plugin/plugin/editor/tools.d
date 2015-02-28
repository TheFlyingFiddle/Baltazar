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
	int hover;
	void use(WorldToolContext* context)
	{
		hover = -1;
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
		if(hover != -1)
		{
			auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
			auto frame = (*atlas)["pixel"];

			auto transform = context.world.items[hover].peek!(Transform);
			float2 trans = context.camera.worldToScreen(transform.position); 
			float2 min = trans - transform.scale * context.camera.scale / 2;
			float2 max = trans + transform.scale * context.camera.scale / 2;

			context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, Color(0x88888888));
		}
	}
}


import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.tools);

/*
@EditorTool
struct Grab
{
	bool isMoving = false;
	void use(ToolContext* context)
	{
		if(context.mouse.isDown(MouseButton.left))
		{
			float2 offset = context.mouse.moveDelta / context.state.camera.scale;
			context.state.camera.offset -= offset;
		}
	}
}

*/