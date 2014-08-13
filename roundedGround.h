//
//  roundedGround.h
//  akivalipshitz
//
//  Created by Akiva Lipshitz on 7/14/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//





#import "CCNode.h"
typedef struct {
    CGPoint one;
    CGPoint two;
    CGPoint three;
}triVertex;
;typedef struct{
    float r;
    float g;
    float b;
    float a;
}Color;

typedef struct{
    Color color;
    Color lnColor;
    CGFloat lnRadius;
}GroundVertex;
typedef struct {
    pairOfPoints pair;
    CGPoint control;
}quadCurve;
typedef enum {
    curved,   //0
    straight, //1
    cdBroken, //2
    stBroken, //3
    morpher,  //4
    slingshot,//5
    gravity,  //6
}types;
#pragma mark Helper classes

@class roundedGround;
@class Gumli;
@class GamePlay;


@interface groundNodePhysicsBody : CCNode // finalProduct
@property roundedGround *manager;
@property CGPoint prevPos;
@property CGPoint originalPos;

@end

@interface groundEdgeNode : CCSprite // In spriteBuilder
@property int type;
@end

#pragma mark roundedGround.Proper

@interface roundedGround : CCNode  <Occluder> {
    BOOL gumliContact;
    BOOL gravityEnabled;
    CGPoint midPoint;
    CCDrawNode *drawNode;
    groundNodePhysicsBody *sensorPill;
    CCVertex *_occluderVertexes;
	int _occluderVertexCount;
    BOOL vertical;
    NSMutableArray *grounds;
    NSMutableArray *linePoints;
    BOOL alreadyEntered;
    NSMutableArray *physicsBodies;
    NSMutableArray *extendedBoundaries;
    NSArray *smallBoundaries;
    NSArray *originalPoints;
    GroundVertex color;
    NSTimer *timer;
    
}
@property groundNodePhysicsBody *groundNode;
@property (weak )CCNode *characterRef;
@property types kindOfGround;
-(void)collisionWithGumli:(CCNode *)node andNode:(groundNodePhysicsBody *)node;
-(NSArray *)applyBezierCurvesCubic:(NSArray *)originalNSValPoints numberExtraPointsPerSegment:(int)number;
-(CGPoint *)calculateVerticesFromArray:(NSArray *)array draw:(BOOL)yesOrNo physicsBody:(BOOL)physics;
-(void)touch:(UITouch *)touch;
-(void)touchMoved:(UITouch *)touch;
-(void)touchEnd:(UITouch *)touch;

-(void)recalculate;

+(NSMutableDictionary *)dictionaryWithArrayAsKeyValuesWithUniqueName:(NSArray *)array;
+(void)roundedGroundNodesByArray:(NSMutableArray *)array asChildrenOf:(CCNode *)sender;
+(CGFloat)calculateFarthestPoint:(NSArray *)ofPoints from:(CGPoint)start;
+(CGFloat)minCGPointWithNSValueArray:(NSArray *)array forX:(BOOL)yesForX_NoForY;
+(CGFloat)maxCGPointWithNSValueArray:(NSArray *)array forX:(BOOL)yesForX_NoForY;
+(CGPoint)findMidpointFromArray:(NSArray *)points;
+(NSArray *)cgValueFromNodes:(NSArray *)nodes;
+(NSArray *)extendedBoundaryWithNSValArray:(NSArray *)array distance:(CGFloat )dist fromMid:(CGPoint )midPoint;
+(NSArray *)extendedBoundaryWithNSValArray:(NSArray *)array scale:(CGFloat)scaleVal fromMid:(CGPoint )midPoint;

+(CGPoint)calculateNearestPoint:(CGPoint)searchpoint withArray:(NSArray *)points;
+(CGFloat )avgDist:(NSArray *)nsValPoints midPoint:(CGPoint )mid;
-(BOOL)isWithinBounds:(CGPoint )point pointsArray:(NSArray *)points;
+(NSArray *)lineSegmentWith:(CGPoint )one and:(CGPoint)two andExtent:(CGFloat)ext;
+(NSArray *)weightedAveragePoints:(pairOfPoints)pair resolution:(CGFloat)res;

@end

#pragma mark roundedGround.Subclass

@interface gravityGround : roundedGround
-(gravityGround *)initWithArray:(NSArray *)array to:(CCNode *)node ofType:(types)type;
@end

@interface morph : roundedGround
@property BOOL isBeingMoved;
-(morph *)initWithArray:(NSArray *)array to:(CCNode *)node ofType:(types)type;
@end

@interface spring : roundedGround
-(spring *)initWithArray:(NSArray *)array to:(CCNode *)node ofType:(types)type;
@end


