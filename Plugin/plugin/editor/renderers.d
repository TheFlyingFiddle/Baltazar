module plugin.editor.renderers;

import bridge.attributes;
import bridge.state;
import common.components;

import collections.list;
import std.algorithm;
import math.vector;

import rendering.combined;
import rendering.shapes;

/*

@WorldRenderer("Grid")
void renderGrid(RenderContext* context)
{
	auto cam = context.camera;
	auto frame = context.images.find!(x => x.name == "pixel"); 
	if(frame.empty) return;

	float width = cam.viewport.z - cam.viewport.x;
	foreach(i; 0 .. cast(int)(width / cam.scale) + 1)
	{
		float2 s0 = float2(i * cam.scale + cam.viewport.x, cam.viewport.y);
		float2 e0 = float2(i * cam.scale + cam.viewport.x, cam.viewport.w);

		context.renderer.drawLine(s0, e0, 1, frame[0].val, Color(0xAAAAAAAA));
	}

	float height = cam.viewport.w - cam.viewport.y;
	foreach(i; 0 .. cast(int)(height / cam.scale) + 1)
	{
		float2 s0 = float2(cam.viewport.x, i * cam.scale + cam.viewport.y);
		float2 e0 = float2(cam.viewport.z, i * cam.scale + cam.viewport.y);

		context.renderer.drawLine(s0, e0, 1, frame[0].val, Color(0xAAAAAAAA));
	}
}

@WorldRenderer("Camera Info")
void renderCamera(RenderContext* context)
{
	import util.strings;
	auto font = context.fonts.find!(x => x.name == "consola")[0].val;
	auto text = text1024("Camera: ", context.camera.offset);

	float2 pos = context.camera.viewport.xy + float2(3, 6);
	context.renderer.drawText(text, pos, float2(font.size), *font, Color.black, float2(0.25, 0.75));
}

@ItemRenderer("Sprite")
void renderSprite(RenderContext* context, Transform* transform, Sprite* sprite)
{
	auto frame = context.images.find!(x => x.name == sprite.texture.name);
	if(frame.empty) return;

	float2 trans = context.camera.worldToScreen(transform.position); 
	float2 min = trans - transform.scale * context.camera.scale / 2;
	float2 max = trans + transform.scale * context.camera.scale / 2;

	context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame[0].val, sprite.tint);
}

@ItemRenderer("Text")
void renderText(RenderContext* context, Transform* transform, Text* text)
{
	auto font = context.fonts.find!(x => x.name == text.font.name);
	if(font.empty) return;

	float2 trans = context.camera.worldToScreen(transform.position); 
	float2 size  = transform.scale * font[0].val.size;

	context.renderer.drawText(text.text, trans, size, *(font[0].val), text.color, text.thresh);
}

@ItemRenderer("Fan")
void renderFan(RenderContext* context, Transform* transform, Fan* fan)
{
	auto frame = context.images.find!(x => x.name == "pixel");
	if(frame.empty) return;

	float2 trans = context.camera.worldToScreen(transform.position); 

	float2 min = trans + float2(-transform.scale.x, transform.scale.y) * context.camera.scale / 2;
	float2 max = min + float2(transform.scale.x, fan.effect) * context.camera.scale;

	Color crl = fan.active ? Color(0x88008800) : Color(0x88000088);
	context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame[0].val, crl);
}

@ItemRenderer("Door")
void renderDoor(RenderContext* context, Transform* transform, Door* door)
{
	auto used    = door.open ? door.openImage : door.closedImage;
	auto frame = context.images.find!(x => x.name == used.name);
	if(frame.empty) return;

	float2 trans = context.camera.worldToScreen(transform.position); 
	float2 min = trans - transform.scale * context.camera.scale / 2;
	float2 max = trans + transform.scale * context.camera.scale / 2;

	context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame[0].val, Color(0xFFFFFFFF));
}

*/