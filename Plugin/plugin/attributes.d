module plugin.attributes;
import plugin.core.data;
import reflection;
import window.keyboard;
import window.mouse;

@DontReflect
struct RenderContext
{
	import rendering.combined;

	WorldData*  world;
	Camera*     camera;
	Renderer2D* renderer;
}

@DontReflect
struct WorldToolContext
{
	WorldData* world;
	Keyboard*  keyboard;
	Mouse*     mouse;
	Camera*    camera;
}

struct WorldTool
{
	string name;
}

struct WorldRenderer 
{
	string name;
}