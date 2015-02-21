module particles.examples;

//Example sdl file of a particle system.
//--------------------------------------
//emitRate = 1000
//generators = [ |boxPosGen|,
//|coneVelGen|, 
//|basicColorGen|, 
//|basicTimeGen| 
//]
//
//updators   = [ |eulerUpdater| , |colorUpdater| , |timeUpdater| ]
//
//variables  = 
//{
//    boxPosOffset    = { x = 1 y = 0.1 }
//    coneSpeed	    = { min = 1 max = 2 }
//    coneAngle		= { min = 1 max = 3.14 }
//    startColor	= { min = 0xEEFF0000 max = 0xEEFF0000 }
//    endColor		= { min = 0x00000000 max = 0x00000000 }
//    lifeTime	 	= { min = 3 max = 10 }
//}
//
//particles = 
//{
//    alive	 = 0
//        capacity = 1024
//        variables =
//    [
//        |position|,
//        |velocity|,			
//        |color|, 		
//        |startColor|,   
//        |endColor|,   
//        |lifeTime|		   
//    ]	
//}
//--------------------------------------