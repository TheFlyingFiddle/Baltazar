module common;

public import common.components;

import util.traits;

alias ComponentTypes = Structs!(common.components);
static string[] ComponentIDs = [staticMap!(id, ComponentTypes) ];
