module gameplay;

import allocation;
import framework;
import graphics;
import renderer;
import content;
import math;

import std.algorithm, std.random;

struct Sprite
{
	float2 position;
	Color  color;
	GFrame textureID;
}

struct GFrame
{
	Texture2D texture;
	short4    coords;
}

final class MainScreen : Screen
{
	Renderer renderer;
	AtlasHandle	 atlas; //Should load several of these!

	Sprite[] sprites;
	this() 
	{
		super(false, false); 
	}

	override void initialize() 
	{
		renderer = Renderer(Mallocator.it, 0xffff);

		auto loader = app.locate!(AsyncContentLoader);
		atlas = loader.load!(TextureAtlas)("Atlas");

		sprites = Mallocator.it.allocate!(Sprite[])(0xffff);
		import std.random;
		foreach(i; 0 .. 0xffff)
		{
			Sprite s;
			s.position  = float2(uniform(0, 1920), uniform(0, 1080));
			s.color     = Color(uniform(0, 0xFFFF_FFFF) | 0xFF000000);
			s.textureID = GFrame(atlas.texture, atlas.rects[uniform(0, atlas.asset.length)].source);

			sprites.ptr[i] = s;
		}
	}

	override void update(Time time)
	{
		sprites.randomShuffle();
	}	

	override void render(Time time)
	{
		import util.bench;
		import window.window;

		auto w = app.locate!Window;
		renderer.viewport(float2(w.size));
		gl.viewport(0,0, cast(int)w.size.x, cast(int)w.size.y);
		foreach(ref sprite; sprites)
		{
			float2 size = float2(uniform(35, 70),uniform(35, 70));
			renderer.drawQuad(sprite.position, size, sprite.textureID, sprite.color);
		}

		renderer.draw();
	}
}