module bridge.contexts;

import ui.base : Gui;
import math.rect;
import reflection;

//@DontReflect
//struct Camera
//{
//    float4 viewport;
//
//    float2 offset;
//    float  scale;
//
//    float2 screenToWorld(float2 screenPos)
//    {
//        screenPos = (screenPos + offset * scale) - viewport.xy;
//        return screenPos / scale;
//    }
//
//    float2 worldToScreen(float2 world)
//    {
//        world = (world - offset) * scale;
//        return world + viewport.xy;
//    }
//}


@DontReflect
struct PanelContext
{
	Gui* gui;
	Rect area;
}