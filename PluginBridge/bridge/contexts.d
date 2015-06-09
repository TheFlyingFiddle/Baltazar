module bridge.contexts;
import math.rect;
import reflection;

import ui.base;
@DontReflect
struct PanelContext
{
	Gui* gui;
	Rect area;
}