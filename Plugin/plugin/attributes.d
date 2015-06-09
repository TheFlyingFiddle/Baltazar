module plugin.attributes;

import bridge.core, bridge.data;
import pluginshared.data;
import reflection;
import window.keyboard;
import window.mouse;

@DontReflect
struct RenderContext
{
	import rendering.combined;

	IEditorState state;
	Camera*     camera;
	Renderer2D* renderer;
}

@DontReflect
struct ToolContext
{
	IEditorState state;
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