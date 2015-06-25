module plugin.tile.data;

import math.vector;
import graphics.color;
import bridge;
import util.hash;

enum TileMapID = "TileMap";

__gshared TileDataCont TileData;
struct TileDataCont
{
	HashID image;
}

enum TileType : ubyte
{
	normal = 1,
	collision = 2
}

import reflection;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.tile.data);