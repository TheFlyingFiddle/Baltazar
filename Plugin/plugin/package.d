module plugin;
import common.components;

template isTest(T...) if(T.length == 1)
{
	enum isTest = true;
}

import reflection;
mixin GenerateMetaData!(isTest,
                        common.components);