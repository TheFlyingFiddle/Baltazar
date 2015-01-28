module mainscreen;

import common;
import content;
import graphics;
import systems;
import components;
import window.gamepad;
import allocation;
import particle_system;
import bindings;
import box2Dintegration;



void createFromArch(ref World world, Transform t, ref EntityArchetype arch)
{
	auto entity = world.entities.create(arch);
	entity.addComp(t);

	world.addEntity(*entity);
}
