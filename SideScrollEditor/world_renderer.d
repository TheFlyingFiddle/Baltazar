module world_renderer;

import state;
import ui;

struct WorldRenderer
{
	EditorState* state;
	Renderer2D* renderer;

	void renderWorld(ref Gui gui)
	{
		import graphics;
		import derelict.opengl3.gl3;
		auto area = gui.area;

		renderer = gui.renderer;
		renderer.end();

		gl.enable(GL_SCISSOR_TEST);
		gl.scissor(cast(int)area.x, cast(int)area.y,  cast(int)area.w, cast(int)area.h);

		renderer.begin();
		
		import common.components;
		foreach(i, ref item; state.items)
		{
		    if(item.hasComp!(Sprite) && item.hasComp!(Transform))
		    {
		        auto sprite		= item.getComp!Sprite;
		        auto transform  = item.getComp!Transform;

				import std.algorithm;
				auto names = state.variables.images.get!(List!string);
				auto idx   = names.countUntil!(x => x == sprite.name);
				if(idx == -1) continue;

				auto frame = state.images[idx];
				mat3 t = mat3.CreateTransform(transform.position, transform.scale, transform.rotation);
		        
		        float2 trans = transform.position + float2(200, 5) + state.camera.offset; 
		        float2 min = trans - transform.scale;
		        float2 max = trans + transform.scale;
		        
		        renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, *frame, sprite.tint);
		
				if(i == state.selected)
					renderer.drawQuadOutline(float4(min.x, min.y, max.x, max.y), 1, gui.atlas["pixel"], Color(0xFFAAAA00),
											 transform.rotation);
		    }
		}

		renderer.end();	

		gl.disable(GL_SCISSOR_TEST);
		renderer.begin();
	}
}
