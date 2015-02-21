module plugin.editor.tools;

import math;
import window.mouse;
import window.keyboard;
import bridge.attributes;
import bridge.state;
import common.components;

/*

@EditorTool
struct Select
{
	bool isMoving = false;
	void use(ToolContext* context)
	{

		auto state = context.state;
		auto m	   = context.mouse;

		if(!m.isDown(MouseButton.left))
			isMoving = false;

		if(m.wasPressed(MouseButton.left))
		{
			float2 loc = state.camera.screenToWorld(m.location);
			foreach(i, ref item; state.items)
			{
				auto transform = item.peek!(Transform);
				if(transform)
				{
					float2 min  = float2(transform.position - transform.scale / 2);
					float2 size = transform.scale; 
					Rect r = Rect(min.x, min.y, size.x, size.y);
					if(r.contains(loc))
					{
						isMoving = true;
						state.selected = i;
						break;
					}
				}
			}
		}

		if(isMoving)
		{
			auto item = state.item(state.selected);
			if(item)
			{
				float2 delta      = m.moveDelta;
				float2 worldDelta = delta / state.camera.scale;
				auto transform = item.get!Transform;
				transform.position += worldDelta;
			}
		}
	}
}

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