module plugin.editor.renderers;

import util.traits;
import bridge.core;
import bridge.data;
import plugin.attributes;
import pluginshared.components;
import pluginshared.data;

import math.vector;
import graphics.textureatlas;
import rendering.combined;
import rendering.shapes;




//Tile
@WorldRenderer("Tile")
void renderTiles(RenderContext* context)
{
	import plugin.tile.data;
	import util.hash;
	import log;

	auto atlas = Editor.gameAssets.locate!(TextureAtlas)(TileData.atlas);
	if(!atlas) return;

	auto obj = Editor.state.getProperty(Guid.init, TileMapID);
	if(!obj) return;

	auto camera = context.camera;
	auto tm = context.state.proxy!TileMap(obj.get!Guid);
	auto positions = tm.positions.get();
	auto colors	   = tm.tint.get();
	auto types	   = tm.type.get();
	auto images    = tm.tileID.get();


	import log;
	logInfo(tm.length);
	foreach(i; 0 .. tm.length)
	{
		

		auto type = types[i];
		if(type == 0) continue;

		Color c;
		if(type == TileType.normal)
			c = Color.white;
		else if(type == TileType.collision)
			c = Color.blue;

		auto pos   = float2(positions[i]);

		float2 min = camera.worldToScreen(pos); 
		float2 max = camera.worldToScreen(pos + float2.one); 

		if(max.x < camera.viewport.x || 
		   max.y < camera.viewport.y || 
		   min.x > camera.viewport.z ||
		   min.y > camera.viewport.w)
			continue;

		auto frame = (*atlas)[HashID(images[i])];
		context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), frame, c);
	}
}

@WorldRenderer("Grid")
void renderGrid(RenderContext* context)
{
	auto cam   = context.camera;
	auto atlas = Editor.assets.locate!(TextureAtlas)(Atlas);
	auto frame = (*atlas)[Pixel];

	//context.renderer.drawQuad(cam.viewport, 0,frame,Color(0xFF707070));

	float2 size = float2(cam.viewport.z - cam.viewport.x,
						 cam.viewport.w - cam.viewport.y);

	float xOff  = (-cam.position.x * cam.scale + size.x / 2)  % cam.scale;
	float width = cam.viewport.z - cam.viewport.x;
	foreach(i; 0 .. cast(int)(width / cam.scale) + 2)
	{
		float2 s0 = float2(xOff + i * cam.scale + cam.viewport.x, cam.viewport.y);
		float2 e0 = float2(xOff + i * cam.scale + cam.viewport.x, cam.viewport.w);

		context.renderer.drawLine(s0, e0, 1, frame, Color(0xAAAAAAAA));
	}

	float yOff  = (-cam.position.y * cam.scale + size.y / 2)  % cam.scale ;
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
	auto font	 = Editor.assets.locate!(FontAtlas)(Fonts);
	auto consola = (*font)[Consola];
	auto text = text1024("Camera: ", context.camera.position);
	float2 size = consola.measure(text) * consola.size;

	float2 pos = context.camera.viewport.xw - float2(0, size.y);
	context.renderer.drawText(text, pos, float2(consola.size), consola, Color.black, float2(0.25, 0.75));
}


@WorldRenderer("Basic")
void renderBasic(RenderContext* context)
{
	auto entities = Editor.state.proxy!(Guid[], EntitySet)(Guid.init).get;
	foreach(ref guid; entities)
	{	
		auto entity = context.state.proxy!Entity(guid);
		if(Entity.hasComponents!(Transform, Sprite)(guid))
		{
			auto transform = context.state.proxy!(Transform)(guid);
			auto sprite	   = context.state.proxy!(Sprite)(guid);

			auto atlas = Editor.gameAssets.locate!(TextureAtlas)(sprite.texture.atlas);
			if(atlas && atlas.contains(sprite.texture.image))
			{
				auto frame = (*atlas)[sprite.texture.image];

				float2 trans = context.camera.worldToScreen(transform.position); 
				float2 min = trans - transform.scale * context.camera.scale / 2;
				float2 max = trans + transform.scale * context.camera.scale / 2;
				context.renderer.drawQuad(float4(min.x, min.y, max.x, max.y), transform.rotation, frame, sprite.tint);
			}
		}

		if(Entity.hasComponents!(Transform, Text)(guid))
		{
			auto transform = context.state.proxy!(Transform)(guid);
			auto text	   = context.state.proxy!(Text)(guid);

			auto atlas	 = Editor.assets.locate!(FontAtlas)(text.font.atlas);
			if(atlas && atlas.contains(text.font.font))
			{
			    auto font	 = (*atlas)[text.font.font];
			
			    float2 trans = context.camera.worldToScreen(transform.position); 
			    float2 size  = transform.scale * font.size;
			
			    context.renderer.drawText(text.text, trans, size, font, text.color, text.thresh);
			}
		}
	}
}

@WorldRenderer("Selected")
void renderSelected(RenderContext* context)
{
	auto atlas = Editor.assets.locate!(TextureAtlas)(Atlas);
	auto frame = (*atlas)[Pixel];

	foreach(guid; SharedData.selected)
	{
		auto entity = context.state.proxy!Entity(guid);
		if(Entity.hasComponents!(Transform)(guid))
		{
			auto transform	= context.state.proxy!(Transform)(guid).get();
			float2 trans = context.camera.worldToScreen(transform.position); 
			float2 min = trans - transform.scale * context.camera.scale / 2;
			float2 max = trans + transform.scale * context.camera.scale / 2;

			context.renderer.drawQuadOutline(float4(min.x, min.y, max.x, max.y), 1.0f,  frame, Color.black, transform.rotation);
		}
	}
}