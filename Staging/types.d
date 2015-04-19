module types;

import math.vector;

struct Transform
{
	float2 position = float2.zero;
	float2 scale	= float2.zero;
	float  rotation = 0;
}

struct Problems
{
	Transform test;
	int dummy = 3;
}



import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, types);