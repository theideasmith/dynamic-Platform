dynamic-Platform
================

###A Cocos2d V3 API for easily generating  dynamic platforms with different properties - gravity, morphable (Contre-Joure),  pullBack - catapult and counting. 

-I was inspired by the likes of Contre-Jour, Major-Magnet, Cut-the-rope, and Badlands to write an iPhone game in which the character is controlled by the environment, and the player has control over the environment. 

-We began prototyping with different modifiers which effect the characters movement, and eventually came up with the idea of platforms which are interacted with in different ways and have different properties, such as the ability to be morphable, to pull back on the perimeter and launch the character by releasing, to apply a gravitational force on the character. 

-The end result is a nice, clean interface for creating platforms with different properties - all you need is an array of points to draw the initial shape, implement a few methods in your gameplay scene, a CCPhysicsNode to add the rounded ground, and most importantly to specify the type of platform by setting the property of the first object in the array to a number - which corresponds to the type. 

**Anyone interested in making a demo, please do - and download my game, Darklight, when it comes out. If this gains enough traction on github, I will open-sourc'ify' the rest of Darklight. dynamic-Platforms is my first open-source project, and I would really appreciate if the community takes it on. It is pretty cool, and can lead the way for more advanced game creation tools for cocos2d. **

####Here is a breakdown on how to use dynamicPlatforms with your project. 

Take a minute, to clone this repo to your local github. I'll wait. 

First, add this line of code to the top of your Scene class:


    #import "roundedGround.h"


Add this line of code in your onEnter, didLoadFromCCB, or a custom setup method. Replace <code>[self level]</code> with the name of the content-node in your game. 

    className = [NSString stringWithFormat:@"%s",class_getName([groundEdgeNode class])];//Not roundedGround
       NSArray *roundedGrounds = [self nodeWithClass:className withArray:level.children childrenOf:[self level]];
       if ([roundedGrounds count] != 0) {
           [roundedGround roundedGroundNodesByArray:(NSMutableArray *)roundedGrounds asChildrenOf:level];
       }
   


Add this line of code in your touchMoved method in whichever scene you want to create roundedGrounds in. 
    
    NSArray *groundes;
        NSString *className = [NSString stringWithFormat:@"%s",class_getName([morph class])];//Not roundedGround
        groundes = [self nodeWithClass:className withArray:level.children childrenOf:[self <content-node in your      game>]];
        for (roundedGround *managerGround in groundes) {
            [managerGround touch:touch];
    }
    

Ok, now that you have the code setup, it is time learn how to actually use it:
You must first open spritebuilder 


''
  The first method looks through the children of the contentnode, and ever
