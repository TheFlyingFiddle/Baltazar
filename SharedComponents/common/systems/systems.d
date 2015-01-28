module common.systems.systems;
import framework;
import common.components;
import allocation;

class SpriteSystem : System
{
	import rendering.combined, content;
	import rendering.shapes;
	import graphics;

	Renderer2D* renderer;
	AtlasHandle atlas;

	override bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!(Transform) &&
			   e.hasComp!(Sprite);
	}

	override void initialize(IAllocator allocator)
	{
		import content;
		auto loader = world.app.locate!(AsyncContentLoader);
		atlas = loader.load!(TextureAtlas)("Atlas");

		renderer = world.app.locate!(Renderer2D);
	}

	override void postStep(Time time)
	{
		renderer.begin();

		foreach(ref e; entities)
		{
			auto trans  = e.getComp!(Transform);
			auto sprite = e.getComp!(Sprite);
			auto frame  = atlas[sprite.name];

			float2 min = trans.position - trans.scale;
			float2 max = trans.position + trans.scale;

			renderer.drawQuad(float4(min.x, min.y, max.x, max.y), trans.rotation, frame, sprite.tint); 
		}

		renderer.end();
	}
}
