module plugin.editor.renderers;

import bridge.core;
import plugin.attributes;
import plugin.core.data;
import common.components;

import math.vector;
import graphics.textureatlas;
import rendering.combined;
import rendering.shapes;

@WorldRenderer("Grid")
void renderGrid(RenderContext* context)
{
	auto cam   = context.camera;
	auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
	auto frame = (*atlas)["pixel"];

	context.renderer.drawQuad(cam.viewport, 0,frame,Color(0xFF707070));

	float xOff  = (-cam.position.x * cam.scale)  % cam.scale;
	float width = cam.viewport.z - cam.viewport.x;
	foreach(i; 0 .. cast(int)(width / cam.scale) + 2)
	{
		float2 s0 = float2(xOff + i * cam.scale + cam.viewport.x, cam.viewport.y);
		float2 e0 = float2(xOff + i * cam.scale + cam.viewport.x, cam.viewport.w);

		context.renderer.drawLine(s0, e0, 1, frame, Color(0xAAAAAAAA));
	}

	float yOff  = (-cam.position.y * cam.scale)  % cam.scale;
	float height = cam.viewport.w - cam.viewport.y;
	foreach(i; 0 .. cast(int)(height / cam.scale) + 2)
	{
		float2 s0 = float2(cam.viewport.x, yOff + i * cam.scale + cam.viewport.y);
		float2 e0 = float2(cam.viewport.z, yOff + i * cam.scale + cam.viewport.y);

		context.renderer.drawLine(s0, e0, 1, frame, Color(0xAAAAAAAA));
	}
}

@WorldRenderer("Camera Info")
void renderCamera(RenderContext* context)
{
	import util.strings;
	auto font	 = Editor.assets.locate!(FontAtlas)("Fonts");
	auto consola = (*font)["consola"];
	auto text = text1024("Camera: ", context.camera.position);
	float2 size = consola.measure(text) * consola.size;

	float2 pos = context.camera.viewport.xw - float2(0, size.y);
	context.renderer.drawText(text, pos, float2(consola.size), consola, Color.black, float2(0.25, 0.75));
}

@WorldRenderer("Basic")
void renderBasic(RenderContext* context)
{
	foreach(ref item; context.world.items)
	{	
		auto transform = item.peek!(Transform);
		auto sprite    = item.peek!(Sprite);
		auto text      = item.peek!(Text);
		auto door      = item.peek!(Door);
		auto fan	   = item.peek!(Fan);

		if(transform && sprite)
		{
			auto atlas = Editor.assets.locate!(TextureAtlas)(sprite.texture.atlas);
			if(atlas && atlas.contains(sprite.texture.image))
			{
				auto frame = (*atlas)[sprite.texture.image];

				float2 trans = context.camera.worldToScreen(transform.position); 
				float2 min = trans - transform.scale * context.camera.scale / 2;
				float2 max = trans + transform.scale * context.camera.scale / 2;
				context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, sprite.tint);
			}
		}

		if(transform && text)
		{
			auto atlas	 = Editor.assets.locate!(FontAtlas)(text.font.atlas);
			if(atlas && atlas.contains(text.font.font))
			{
				auto font	 = (*atlas)[text.font.font];

				float2 trans = context.camera.worldToScreen(transform.position); 
				float2 size  = transform.scale * font.size;

				context.renderer.drawText(text.text, trans, size, font, text.color, text.thresh);
			}
		}

		if(transform && fan)
		{
			auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
			auto frame = (*atlas)["pixel"];

			float2 trans = context.camera.worldToScreen(transform.position); 
			float2 min = trans + float2(-transform.scale.x, transform.scale.y) * context.camera.scale / 2;
			float2 max = min + float2(transform.scale.x, fan.effect) * context.camera.scale;
			Color crl = fan.active ? Color(0x88008800) : Color(0x88000088);
			context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, crl);
		}
	
		if(transform && door)
		{
			auto used    = door.open ? door.openImage : door.closedImage;
			auto atlas = Editor.assets.locate!(TextureAtlas)(used.atlas);
			if(atlas && atlas.contains(used.image))
			{
				auto frame = (*atlas)[used.image];

				float2 trans = context.camera.worldToScreen(transform.position); 
				float2 min = trans - transform.scale * context.camera.scale / 2;
				float2 max = trans + transform.scale * context.camera.scale / 2;

				context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, Color(0xFFFFFFFF));
			}
		}
	}
}

@WorldRenderer("Selected")
void renderSelected(RenderContext* context)
{
	auto item = context.world.item;
	if(item)
	{
		auto transform = item.peek!Transform;
		if(transform)
		{
			auto atlas = Editor.assets.locate!(TextureAtlas)("Atlas");
			if(atlas)
			{
				auto frame = (*atlas)["pixel"];

				float2 trans = context.camera.worldToScreen(transform.position); 
				float2 min = trans - transform.scale * context.camera.scale / 2;
				float2 max = trans + transform.scale * context.camera.scale / 2;

				context.renderer.drawQuadOutline(float4(min.x, min.y, max.x, max.y), 1.0f,  frame, Color.black, transform.rotation);
			}
		}
	}
}


import reflection;

enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.renderers);