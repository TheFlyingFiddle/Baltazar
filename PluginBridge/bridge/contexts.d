module bridge.contexts;

import ui.base : Gui;
import math.rect;
import reflection;


@DontReflect
struct PanelContext
{
	Gui* gui;
	Rect area;
}