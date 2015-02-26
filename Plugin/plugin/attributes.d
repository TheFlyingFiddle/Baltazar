module plugin.attributes;
import plugin.editor.data;
import reflection;

@DontReflect
struct RenderContext
{
	import rendering.combined;

	WorldData*  world;
	Camera*     camera;
	Renderer2D* renderer;
}

struct WorldRenderer 
{
	string name;
}