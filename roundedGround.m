//
//  roundedGround.m
//  akivalipshitz
//
//  Created by Akiva Lipshitz on 7/14/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//
//TODO: Ideas

/**
 * Variations:
 [1] = CurvedEdges,
 [2] == Straight Edges.
 * Settings
 [1] = individual points,
 [2] = One physicsBody.
 * Types
 [1] = Slingshot - each bezier curve is a  separate slingshot
 [2] = Morph
 [3] = Draggable - morph: (It is draggable, and when it goes near other ground, their curves automatically join
 [4] = Renderer Ground. This means that it renders a texture inside its space; This oculd also just be a method
 *_________ Bugs __________
 * When adding roundedground as an occluder, then it crashes. This is because the physicsbody is nil.

 */


#import "roundedGround.h"
#import "CCPhysics+ObjectiveChipmunk.h"

#import "physicsAction.h"
#import "levelScene.h"
#import "starConnecter.h"
#import <CCDirector_Private.h>
#define kMaxEdgePoints 10000
#define fuzzyEqual(number,extent,comparator) (comparator + extent > number) && (number >  comparator - extent)
#define maxScale 1.7
#define minScale 0.6
#define truColor(unscaled) (unscaled / 255)
#define quadCurveTotal 100.f
/*
 curved,   //0
 straight, //1
 cdBroken, //2
 stBroken, //3
 morpher,  //4
 slingshot,//5
 gravity,  //6
 */

//________________________________________________________________________________________________________________________________________________________
static int pnpoly(int nvert, float *vertx, float *verty, float testx, float testy)
{
    int i, j, c = 0;
    for (i = 0, j = nvert-1; i < nvert; j = i++) {
        if ( ((verty[i]>testy) != (verty[j]>testy)) &&
            (testx < (vertx[j]-vertx[i]) * (testy-verty[i]) / (verty[j]-verty[i]) + vertx[i]) )
            c = !c;
    }
    return c;
}

static BOOL isAllTrue(BOOL *bools, int nmBools) {
    int check = 0;
    for (int i = 0; i < nmBools; i++) {
        if (bools[i]) {
            check++;
        }
    }
    if (check == nmBools) {
        return true;
    }
    return false;
}

float map(float range1_A, float range1_B, float range2_A, float range2_B, float value) {
    CGFloat  inMin = range1_A;
    CGFloat  inMax = range1_B;
    
    CGFloat  outMin = range2_A;
    CGFloat  outMax = range2_B;
    
    CGFloat input = value;
    CGFloat output = outMin + (outMax - outMin) * (input - inMin) / (inMax - inMin);
    
    return output;
}

/**
 * This takes a value, a begin point, an endpoint and a distance from the value, and will return the value warped inside the range. If the value drops below the start, for example, by four, the returned value will be the total minus 4;
 @param begin: the beginning of the range - a portal connected to the end if the value + exent drops below it
 @param end: End of the range. Warps to begin
 @param value: The value being checked
 @param extend: The signed distance from value
 
 */
int warpIntToRange(int begin, int end, float value, int extent) {
    int start = value + extent;
    if (start < begin) {
        start = end +1 - abs(begin - extent);
    }
    if (start >= end) {
        start = begin -1 + abs(begin - extent);
    }
    return start;
}

BOOL isEqualToAnyIn(NSArray *array, id Obj) {
    for (int i = 0; i < [array count]; i++) {
        if (Obj == [array objectAtIndex:i]) {
            return TRUE;
        }
    }
    return FALSE;
}

@implementation groundNodePhysicsBody {
    
}//This is the physicsBody for a roundedGroundNode
@synthesize manager;
@synthesize prevPos;
@synthesize originalPos;
-(void)onEnter {
    
    [super onEnter];
    prevPos = self.position;
    self.userInteractionEnabled = NO;
    originalPos = self.position;
}

-(void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    NSLog(@"touchBegan!");
}

-(void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
    [self.manager touch:touch];
}

@end

//________________________________________________________________________________________________________________________________________________________
@implementation groundEdgeNode //This is an absract spriteclass to represent the original spites used to the create the roundedGround in spritebulder. It is exists soley incase anything specific needs to be done with them in subclasses of roundedGround
@synthesize type;
@end



//________________________________________________________________________________________________________________________________________________________

@implementation roundedGround {
    CCRenderState *groundRenderState;
    CCRenderTexture *renderTexture;
    CCBlendMode *blendMode;
    CCTexture *texture;
    
}
@synthesize groundNode;
@synthesize nodeRef;
@synthesize kindOfGround;
+(void)roundedGroundNodesByArray:(NSMutableArray *)array asChildrenOf:(CCNode *)sender {
    NSMutableDictionary *nodes = [roundedGround dictionaryWithArrayAsKeyValuesWithUniqueName:array];
    
    for (CCNode *node in array) {
        
        [[nodes objectForKey:node.name] addObject:node];
    }
    NSEnumerator *enumerator = [nodes objectEnumerator];
    id value;
    
    while ((value = [enumerator
                     nextObject])) {
        /* code that acts on the dictionary’s values */
        NSMutableArray *source = (NSMutableArray *)value;
        roundedGround *ground = [roundedGround roundedGroundWithArrayOfNodes:source to:sender];
        [sender addChild:ground];
        ground.userInteractionEnabled = YES;
    }
}

+(roundedGround *)roundedGroundWithArrayOfNodes:(NSMutableArray *)array to:(CCNode *)sender{//Must implement settingsa
    return [[roundedGround alloc] initWithArray:array to:sender];
}

+(NSMutableDictionary *)dictionaryWithArrayAsKeyValuesWithUniqueName:(NSArray *)array {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for (int i = 0; i < [array count]; i++) {
        CCNode *object = array[i];
        NSArray *otherArray = [dict objectForKey:((CCNode *)object).name];
        if (otherArray == nil) {
            [dict setObject:[NSMutableArray array] forKey:((CCNode *)object).name];
        }
    }
    return dict;
}

/**
 * Initializes and creates a specific version of roundedground, depending on the parameters put forth in spritebuilder. Of course this could be done programmatically as well.
 * The array must contain groundedgenodes or subclassses thereof, and the first in the array must have its type set to one of the types in types. The code handles instance creation automatically.
 
 * Requires:  - the first in the array must have a type set. If not, then type defaults to straight-contig.
 * @param array: an array of groundEdgeNodes
 * @param types: 0: curved, 1: straight, 2: cdBroken, 3: stBroken, 4: morph, 5: slingshot, 6: gravity
 * @return a newly instantiated roundedGround, of the type specified by the user
 */

-(roundedGround *)initWithArray:(NSArray *)array to:(CCNode *)node{//TODO:Calculating physicsbody with array of points seen below;
    if (self == [super init]) {
        
        int type = (((groundEdgeNode *)array[0]).type);
        
        switch (type) {
            case 0: //curved
                [self classicInit:array to:node ofType:type];
                [self setupWithArrayCurved:array ofType:type]; //CHECK
                break;
            case 1: //straight
                [self classicInit:array to:node ofType:type];
                [self setupWithArrayStraight:array ofType:type]; //CHECK
                
                break;
            case 2:
                //                cdBroken
                break;
            case 3:
                //               stBroken
                break;
            case 4:
                //Morphable
                self = [[morph alloc] initWithArray:array to:node ofType:type] ;
                
                break;
            case 5:
                //                slingshot
                self = [[spring alloc] initWithArray:array to:node ofType:type];
                break;
            case 6:
                //                gravity
                self = [[gravityGround alloc] initWithArray:array to:node ofType:type];
                break;
                
            default:
                [self setupWithArrayStraight:array ofType:type];
                break;
        }
        
        self.position = [roundedGround findMidpointFromArray:[roundedGround cgValueFromNodes:array]];
        
        self.anchorPoint = ccp(0.5, 0.5);
        self.userInteractionEnabled = YES;
    }
    
    return self;
}


/**
 * Is the de - facto basic init method for every roundedground. It allocates and instantiates the arrays, sorts the grounds array, creates the drawNodes, and sets up the pill physicsBod sensor.
 *
 * @param array An array of groundEdgeNodes, either sent programmatically or sent via spritebuilder
 * @param to The destination of the node - where to add all of the internal variables and nodes to.
 *
 * @return		a basic roundedGround, without any setup physics bodies, but for the sensorPill. A roundedground with setup ivars, etc.
 */


-(roundedGround *)classicInit:(NSArray *)array to:(CCNode *)node ofType:(types)type{
    self.kindOfGround = type;
    color = [self groundDrawingDataWithType:type];
    
    drawNode = [[CCDrawNode alloc] init];
    [node addChild:drawNode];
    
    grounds  = [[NSMutableArray alloc] init];
    linePoints = [[NSMutableArray alloc] init];
    extendedBoundaries = [[NSMutableArray alloc] init];
    smallBoundaries = [[NSMutableArray alloc] init];
    physicsBodies = [[NSMutableArray alloc] init];
    
    NSMutableArray *NSValpoints = [[NSMutableArray alloc] init];
    for (CCNode *node in array) {
        [grounds addObject:node];
        NSValue *pointVal = [NSValue valueWithCGPoint:node.position];
        [NSValpoints addObject:pointVal];
        node.visible = NO;
    }
    
    midPoint = [roundedGround findMidpointFromArray:NSValpoints];
    self.position = midPoint;
    grounds = (NSMutableArray *)[self sortNodesClockwise:grounds fromCenterPoint:midPoint];
    
    CGFloat xMin = [roundedGround minCGPointWithNSValueArray:NSValpoints forX:YES];
    CGFloat xMax = [roundedGround maxCGPointWithNSValueArray:NSValpoints forX:YES];
    CGFloat yMax = [roundedGround maxCGPointWithNSValueArray:NSValpoints forX:NO];
    //    [drawNode drawSegmentFrom:self.boundingBox.origin to:ccp(self.boundingBox.origin.x + xMax, self.boundingBox.origin.y) radius:5 color:[CCColor orangeColor]];
    //
    //    [drawNode drawSegmentFrom:self.boundingBox.origin to:ccp(self.boundingBox.origin.x, self.boundingBox.origin.y + yMax) radius:5 color:[CCColor yellowColor]];
    CGPoint p1 = ccp(xMin + 20,midPoint.y);
    CGPoint p2 = ccp(xMax - 20, midPoint.y);
    [drawNode drawDot:p1 radius:5 color:[CCColor redColor]];
    [drawNode drawDot:p2
               radius:5 color:[CCColor redColor]];
    
    sensorPill = [groundNodePhysicsBody node];
    CCPhysicsBody *body = [[CCPhysicsBody alloc] init];
    body = [CCPhysicsBody bodyWithPillFrom:ccpSub(p1,midPoint) to:ccpSub(p2, midPoint) cornerRadius:90];
    
    sensorPill.physicsBody = body;
    sensorPill.physicsBody.type = CCPhysicsBodyTypeStatic;
    sensorPill.physicsBody.sensor = YES;
    sensorPill.manager = self;
    sensorPill.position = midPoint;
    sensorPill.physicsBody.sensor = YES;
    [node addChild:sensorPill];
    alreadyEntered = YES;
    gravityEnabled = YES;
    nodeContact = NO;
    return self;
}

-(void)setupRenderer{
    blendMode = [CCBlendMode blendModeWithOptions:@{
                                                    CCBlendFuncSrcAlpha: @(GL_SRC_COLOR),
                                                    CCBlendFuncDstColor:@(GL_SRC_COLOR),
                                                    }];
    CCNodeColor *nodeColor = [CCNodeColor nodeWithColor:[CCColor whiteColor] width:60 height:90];
    CCTexture *testTexture = [CCTexture textureWithFile:@"Untitled/LightAttentuation.psd"];
    groundRenderState = [CCRenderState renderStateWithBlendMode:blendMode shader:[CCShader positionColorShader] mainTexture:testTexture];
    
    CGRect viewport = [CCDirector sharedDirector].viewportRect;
    
    renderTexture = [CCRenderTexture renderTextureWithWidth:[CCDirector sharedDirector].viewSize.width height:[CCDirector sharedDirector].viewSize.height];
    renderTexture.position = viewport.origin;
    NSUInteger z = self.zOrder -1;
    CCSprite *rtSprite = renderTexture.sprite;
	rtSprite.anchorPoint = CGPointZero;
	rtSprite.blendMode = [CCBlendMode blendModeWithOptions:@{
                                                             CCBlendFuncSrcColor: @(GL_SRC_COLOR),
                                                             CCBlendFuncDstColor: @(GL_SRC_COLOR),
                                                             }];
    
    
    [self.parent addChild:renderTexture z:NSIntegerMax];
}

//
-(GroundVertex)groundDrawingDataWithType:(types)type {
    GroundVertex data;
    Color hue;
    hue.a = 1;
    switch (type) {
        case curved:
            hue.r = 255.f;
            hue.g = 230.f;
            hue.b = 98.f;
            data.lnRadius = 8;
            break;
        case stBroken:
            hue.r = 3.f;
            hue.g = 0.f;
            hue.b = 80.f;
            data.lnRadius = 2;
            break;
        case morpher:
            hue.r = 50.f;
            hue.g = 203.f;
            hue.b = 91.f;
            data.lnRadius = 7;
            break;
        case slingshot:
            hue.r = 255.f;
            hue.g = 151.f;
            hue.b = 47.f;
            hue.a = 0;
            data.lnRadius = 5.f;
            break;
        case gravity:
            hue.r = 47;
            hue.g = 158;
            hue.b = 255;
            data.lnRadius = 5;
            break;
        default:
            data.lnRadius = 1;
            hue.r = 255;
            hue.g = 255;
            hue.b = 255;
            break;
    }
    hue.r = hue.r / 255;
    hue.g = hue.g / 255;
    hue.b = hue.b / 255;
    
    Color lineCol;
    lineCol.r = 195.f;
    lineCol.g = 195.f;
    lineCol.b = 195.f;
    lineCol.a = 1;
    
    lineCol.r = lineCol.r / 255.f;
    lineCol.g = lineCol.g / 255.f;
    lineCol.b = lineCol.b / 255.f;
    
    data.color = hue;
    data.lnColor = lineCol;
    
    return data;
}
-(void)touch:(UITouch *)touch {
    NSLog(@"Touch registered in manager;");
}
/**
 * Sets up roundedGround instance with curved shapes and draws a physicsbody for the curved shape. By default the max scale is 1.7, and the min scale is 0.6
 *
 * @param array an array of groundEdgeNodes
 *
 * @return void. It does though set up the curved physicsbody
 */
-(void)setupWithArrayCurved:(NSArray *)array ofType:(types)type {
    linePoints = (NSMutableArray *)[self applyBezierCurvesCubic:[roundedGround cgValueFromNodes:grounds] numberExtraPointsPerSegment:5];
    [self calculateVerticesFromArray:[roundedGround cgValueFromNodes:grounds] draw:YES physicsBody:YES];
    CGFloat avgDist = [roundedGround avgDist:linePoints midPoint:midPoint];
    extendedBoundaries = (NSMutableArray *)[roundedGround extendedBoundaryWithNSValArray:linePoints scale:1.7 fromMid:midPoint];
    smallBoundaries = (NSMutableArray *)[roundedGround extendedBoundaryWithNSValArray:linePoints scale:0.6 fromMid:midPoint];
}

/**
 * Sets up roundedGround instance with straight shapes and draws a physicsbody for the straight shape.
 *
 * @param array an array of groundEdgeNodes
 *
 * @return void. It does though set up the straight physicsbody
 */

-(void)setupWithArrayStraight:(NSArray *)array ofType:(types)type {
    [self calculateVerticesFromArray:[roundedGround cgValueFromNodes:grounds] draw:YES physicsBody:YES];
    
}
/**
 * This one is a bit more complicated. It sets up the current roundedGround instance with groundEdgeNodes and their physicsBodies along its perimeter.
 * @param array an array of groundEdgeNodes setup in code or in spritebuilder, which it uses to extrapolate a bezier curve, and then create groundEdgeNodes along its perimeter
 * @param YON "Yes or no" whether or not the perimeter nodes should have touch-enabled
 * @return void. It does though set up the curved and broken physicsbody
 */


-(void)setupBroken:(NSArray *)array interaction:(BOOL)YON ofType:(types)type{
    linePoints = [linePoints init];
    [physicsBodies removeAllObjects];
    linePoints = (NSMutableArray *)[self applyBezierCurvesCubic:[roundedGround cgValueFromNodes:array] numberExtraPointsPerSegment:10];
    for (NSValue *val in linePoints) {
        CGPoint point = [val CGPointValue];
        groundNodePhysicsBody *edgeNode = [groundNodePhysicsBody node];
        edgeNode.physicsBody = [CCPhysicsBody bodyWithCircleOfRadius:1 andCenter:ccp(edgeNode.contentSize.width / 2, edgeNode.contentSize.height / 2)];
        edgeNode.physicsBody.collisionType = @"roundedGround";
        edgeNode.manager = self;
        if (YON) {
            edgeNode.userInteractionEnabled = YES;
        }
        [physicsBodies addObject:edgeNode];
        [[gameData sharedData].GamePlayNode.level addChild:edgeNode];
        edgeNode.physicsBody.type = CCPhysicsBodyTypeStatic;
        edgeNode.position = point;
        
    }
    extendedBoundaries = (NSMutableArray *)[roundedGround extendedBoundaryWithNSValArray:linePoints scale:maxScale fromMid:midPoint];
    smallBoundaries = (NSMutableArray *)[roundedGround extendedBoundaryWithNSValArray:linePoints scale:minScale fromMid:midPoint];
    
}

+(NSArray *)extendedBoundaryWithNSValArray:(NSArray *)array scale:(CGFloat)scaleVal fromMid:(CGPoint )midPoint{
    NSMutableArray *extendedArray = [[NSMutableArray alloc] init];
    CGAffineTransform scaleMatrix = CGAffineTransformScale(CGAffineTransformIdentity, scaleVal, scaleVal);
    for (int i = 0; i < [array count]; i++) {// Main loop - running through entire array
        CGPoint scaled = CGPointApplyAffineTransform([array[i] CGPointValue], scaleMatrix);
        CGPoint dist = ccpMult(midPoint, 1 - scaleVal);
        CGPoint final = ccpAdd(dist, scaled);
        NSValue *valPoint = [NSValue valueWithCGPoint:final];
        [extendedArray addObject:valPoint];
    }
    return extendedArray;
}

+(NSArray *)extendedBoundaryWithNSValArray:(NSArray *)array distance:(CGFloat )dist fromMid:(CGPoint )midPoint {
    NSMutableArray *extendedArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < [array count]; i++) {// Main loop - running through entire array
        int j = i +1;
        int q = i -1;
        j = j > [array count] -1 ? 0 : j;
        q = q < 0 ? (int)[array count] -1 : q;
        
        CGPoint vecti = ccpSub([array[i] CGPointValue], [array[j] CGPointValue]);
        CGPoint vectq = ccpSub([array[q] CGPointValue], [array[i] CGPointValue]); // This may need to be reveresed
        
        CGPoint perpi = ccpPerp(vecti);
        CGPoint perpq = ccpPerp(vectq);
        vecti = ccpMult(ccpNormalize(perpi), dist);
        vectq = ccpMult(ccpNormalize(perpq), dist);
        CGPoint final = ccpMult(ccpAdd(perpi, perpq), 0.5);
        final = ccpNormalize(final);
        final = ccpMult(final, dist);
        final = ccpAdd(final, [array[i] CGPointValue]);
        NSValue *valPoint = [NSValue valueWithCGPoint:final];
        [extendedArray addObject:valPoint];
        
    }
    return extendedArray;
}
/* It doesn't work at all yet
 -(NSArray *)trianglesWithArray:(NSArray *)points andMidpoint:(CGPoint )mid {
 CGFloat avgDist = [roundedGround avgDist:points midPoint:mid];
 for (CGFloat i = 0; i < 360; i++) {
 
 CGPoint endPoint;
 endPoint.x = (sinf(CC_DEGREES_TO_RADIANS(i)) * avgDist * 2) + mid.x;
 endPoint.y = (cosf(CC_DEGREES_TO_RADIANS(i)) * avgDist * 2) + mid.y;
 CGPoint nearest = [roundedGround calculateNearestPoint:endPoint withArray:points];
 for (int l = 0; l < [points count]; l++) {
 
 }
 int j = i;
 int x = i + 1==[points count] ? 0 : i +1;
 }
 
 }
 */

+(CGFloat )avgDist:(NSArray *)nsValPoints midPoint:(CGPoint )mid{
    CGFloat dividend = [nsValPoints count];
    CGFloat totalDist;
    for (NSValue *val in nsValPoints) {
        totalDist = totalDist + ccpDistance([val CGPointValue], mid);
    }
    return totalDist / dividend;
}

-(void)doOccluderEntryWithNode:(CCNode *)node {
    // Ooof
    ChipmunkPolyShape *poly = self.physicsBody.body.shapes[0];
    _occluderVertexCount = poly.count;
    _occluderVertexes = realloc(_occluderVertexes, _occluderVertexCount*sizeof(*_occluderVertexes));
    
    for(int i=0; i<_occluderVertexCount; i++){
        cpVect v = [poly getVertex:i];
        const GLKVector2 zero2 = {{0, 0}};
        const GLKVector4 zero4 = {{0, 0, 0, 0}};
        
        _occluderVertexes[i] = (CCVertex){GLKVector4Make(v.x, v.y, 0.0f, 1.0f), zero2, zero2, zero4};
    }
}

-(BOOL)isWithinBounds:(CGPoint )point pointsArray:(NSArray *)points {
    int count = (int)[points count];
    CGPoint *outf = [self calculateVerticesFromArray:points draw:NO physicsBody:NO]; //should be small boundaries;
    float *xPsOut = calloc(count, sizeof(CGFloat));;
    float *yPsOut = calloc(count, sizeof(CGPoint));
    for (int i = 0; i < count; i++) {
        xPsOut[i] = outf[i].x;
        yPsOut[i] = outf[i].y;
    }
    BOOL inside = pnpoly(count,xPsOut, yPsOut,point.x, point.y);
    if (inside) {
        return true;
    } else {
        return false;
    }
}

-(void)onEnter
{
    if (!alreadyEntered) {
        [super onEnter];
        grounds  = [[NSMutableArray alloc] init];
        NSMutableArray *NSValpoints = [[NSMutableArray alloc] init];
        for (CCNode *node in self.children) {
            [grounds addObject:node];
            NSValue *pointVal = [NSValue valueWithCGPoint:node.position];
            [NSValpoints addObject:pointVal];
        }
        CGPoint midpoint = [roundedGround findMidpointFromArray:NSValpoints];
        [[gameData sharedData].GamePlayNode.drawNode drawDot:ccpAdd(midpoint, self.position) radius:4 color:[CCColor blackColor]];
    }
}

#pragma mark bezierCurve

/**
 * Parametrically calculates a Point on a Bezier-curve defined by two endpoints, two control points, and the parameter t
 * (see Wikipedia: http://bit.ly/19izHuG).
 *
 * Requires: 0 <= t <= 1
 *
 * @param p0	the first endpoint
 * @param p1	the second endpoint
 * @param cp0	the first control point
 * @param cp1	the second control point
 * @param t		used parametrically to get a point on the curve which is t-percent between p0 and p1
 *
 * @return		a point on the bezier curve parametrized by t
 */
CGPoint calculateBezierCubic(CGPoint p0, CGPoint p1, CGPoint cp0, CGPoint cp1, float t)
{
    int x = (int) ((1 - t) * (1 - t) * (1 - t) * p0.x + 3 * (1 - t) * (1 - t) * t * cp0.x + 3 * (1 - t) * t * t * cp1.x + + t * t * t * p1.x);
    int y = (int) ((1 - t) * (1 - t) * (1 - t) * p0.y + 3 * (1 - t) * (1 - t) * t * cp0.y + 3 * (1 - t) * t * t * cp1.y + + t * t * t * p1.y);
    return  ccp(x, y);
}

/**
 * "Smooths" a list of originalPoints by adding extra interpolated points between them
 * such that points form a C2-continuous bezier curve.
 *
 *
 * Requires: numberExtraPointsPerSegment >= 1
 * @param originalPoints					the list of raw points to be used to
 * @param numberExtraPointsPerSegment
 *
 * @return a new list of points starting with originalPoints(0), ending with originalPoints(originalPoints.size()-1),
 * 		   and filled with a number of additional points including every element of originalPoints as well as a number
 * 		   of interpolated points residing on bezier curves such that the list of points forms a C2-continous curve.
 *         I got this from Ben Reynolds at MGWU. Thanks Ben!
 */

-(NSArray *)applyBezierCurvesCubic:(NSArray *)originalNSValPoints numberExtraPointsPerSegment:(int)number { //number is unused
    if([originalNSValPoints count] <= 2)
    {
        NSLog(@"[originalNSValPoints count] < 2\n. Not enough points to calculate curve");
        return originalNSValPoints;
    }
    
    NSMutableArray* modifiedPoints = [NSMutableArray arrayWithArray:originalNSValPoints];
    [modifiedPoints insertObject:[originalNSValPoints firstObject] atIndex:0];
    [modifiedPoints addObject: [originalNSValPoints firstObject]];
    [modifiedPoints addObject: [originalNSValPoints firstObject]];
    
    NSMutableArray *finalPoints = [NSMutableArray array];
    
    //add first point
    [finalPoints addObject:modifiedPoints[0]];
    for(int i = 1; i < [modifiedPoints count] - 2; i++)
    {
        
        CGPoint point0 = [modifiedPoints[i] CGPointValue];
        CGPoint point1 = [modifiedPoints[i + 1] CGPointValue];
        CGPoint previousPoint = [modifiedPoints[i -1] CGPointValue];
        CGPoint nextPoint = [modifiedPoints[i + 2] CGPointValue];
        
        CGPoint midpointPrevTo0 = ccpMidpoint(previousPoint, point0);
        CGPoint midpoint0To1 = ccpMidpoint(point0, point1);
        CGPoint midpoint1ToNext = ccpMidpoint(point1, nextPoint);
        
        CGPoint midpoint0 = ccpMidpoint(midpointPrevTo0, midpoint0To1);
        CGPoint midpoint1 = ccpMidpoint(midpoint0To1, midpoint1ToNext);
        
        int controlPoint0_x = point0.x + (midpoint0To1.x - midpoint0.x);
        int controlPoint0_y = point0.y + (midpoint0To1.y - midpoint0.y);
        
        int controlPoint1_x = point1.x + (midpoint0To1.x - midpoint1.x);
        int controlPoint1_y = point1.y + (midpoint0To1.y - midpoint1.y);
        
        CGPoint controlPoint0 = ccp(controlPoint0_x, controlPoint0_y);
        CGPoint controlPoint1 = ccp(controlPoint1_x, controlPoint1_y);
        
        int extraPoints = floor(ccpDistance(point0, point1)) * 0.8;
        for( int j = 0; j < number; j++)
        {
            //            float t = (float)j / (float)extraPoints;
            float dividend;
            if (number == 0) {  dividend = extraPoints; }
            else { dividend = number; }
            
            float t = (float)j / dividend;
            
            CGPoint bezierPoint = calculateBezierCubic(point0, point1, controlPoint0, controlPoint1, t);
            NSValue *cgPointVal = [NSValue valueWithCGPoint:bezierPoint];
            [finalPoints addObject:cgPointVal];
        }
    }
    //add last point
    [finalPoints addObject:[modifiedPoints objectAtIndex:[modifiedPoints count]-1]];
    
    return finalPoints;
}

int getPt( int n1 , int n2 , float perc )
{
    int diff = n2 - n1;
    
    return n1 + ( diff * perc );
    
}

-(CGPoint *)applyBezierCurveQuadtratic:(pairOfPoints)pair control:(CGPoint)control {
    CGPoint *quadCurve = calloc(100, sizeof(CGPoint));
    int j = 0;
    
    for( float i = 0; i < 1; i += 0.01) { // First Point
        CGFloat x1 = pair.p1.x;
        CGFloat y1 = pair.p1.y;
        // Control Point
        CGFloat x2 = control.x;
        CGFloat y2 = control.y;
        //   Second point
        CGFloat x3 = pair.p2.x;
        CGFloat y3 = pair.p2.y;
        
        // The Green Line
        float xa = getPt( x1 , x2 , i );
        float ya = getPt( y1 , y2 , i );
        float xb = getPt( x2 , x3 , i );
        float yb = getPt( y2 , y3 , i );
        // The Black Dot
        CGFloat x = getPt( xa , xb , i );
        CGFloat y = getPt( ya , yb , i );
        [drawNode drawDot:ccp(x, ya) radius:4 color:[CCColor orangeColor]];
        
        quadCurve[j] = ccp(x,y);
    }
    
    return quadCurve;
}

+(NSArray *)lineSegmentWith:(CGPoint )one and:(CGPoint)two andExtent:(CGFloat)ext {
    
    CGFloat slope = ((one.y - two.y) / (one.x - two.x)) * ext;
    
    CGFloat yInt = one.y - (one.x * slope);
    NSMutableArray *segPoints = [[NSMutableArray alloc] init];
    CGFloat addend = one.x < two.x ? ext : -1 * ext;
    int comparator = one.x < two.x ? 1 : -1;
    
    CGFloat x = one.x;
    BOOL condition;
    while (x!=two.x) {
        condition =  comparator == 1? x < two.x : x > two.x;
        CGFloat signedX = x * addend;
        CGPoint newPoint = ccp(signedX, ((slope * x) + yInt));
        NSValue *valPoint = [NSValue valueWithCGPoint:newPoint];
        [segPoints addObject:valPoint];
        if (!condition) {
            return segPoints;
        }
        x = x + addend;
    }
    
    return segPoints;
}

+(NSArray *)weightedAveragePoints:(pairOfPoints)pair resolution:(CGFloat)res{
    NSAssert(res < 1, @"Resolution must be less than 1");
    NSMutableArray *ptsArray = [NSMutableArray array];
    
    for (CGFloat i = 0; i < 1; i += res) {
        CGPoint one = ccpMult( pair.p1, 1 - i);
        CGPoint two = ccpMult(pair.p2, i);
        CGPoint inBetween = ccpAdd(one, two);
        [ptsArray addObject:[NSValue valueWithCGPoint:inBetween]];
    }
    return (NSArray *)ptsArray;
}

#pragma mark Utils
#define until 4
-(NSArray *)sortNodesClockwise:(NSArray *)nodes fromCenterPoint:(CGPoint )center{
    NSMutableArray *quadrants = [[NSMutableArray alloc] init];
    NSMutableArray *sortedArray = [[NSMutableArray alloc] init];
    //    int ensure = 4;
    for (int i = 0; i < until; i++) {
        NSMutableArray *quadrant = [[NSMutableArray alloc] init];
        [quadrants addObject:quadrant];
        BOOL condition;
        for (CCNode *node in nodes) {
            switch (i) {
                case 0:
                    condition = node.position.x > center.x && node.position.y > center.y;
                    break;
                case 1:
                    condition = node.position.x < center.x && node.position.y > center.y;
                    
                    break;
                case 2:
                    condition = node.position.x < center.x && node.position.y < center.y;
                    
                    break;
                case 3:
                    condition = node.position.x > center.x && node.position.y < center.y;
                    
                    break;
                default:
                    break;
            }
            
            NSLog(@"The current quadrant is %d. Node condition:%d",i, condition);
            if (condition) {
                [quadrants[i] addObject:node];
                NSLog(@"I is in quadrant: %d", i);
            }
        }
        
        nodes = [nodes sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            CGFloat angleA = atan2f(((CCNode *)obj1).position.y - center.y,((CCNode *)obj1).position.x - center.x);
            CGFloat angleB = atan2f(((CCNode *)obj2).position.y - center.y,((CCNode *)obj2).position.x - center.x);
            
            if (angleA < angleB) {
                return NSOrderedAscending;
            } else if (angleA > angleB) {
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];
    }
    for (int i = 0; i < until; i++) {
        for (NSValue *value in quadrants[i]) {
            [sortedArray addObject:value];
        }
    }
    return nodes;
    
}


+(CGFloat)calculateFarthestPoint:(NSArray *)ofPoints from:(CGPoint)start {
    CGFloat distFloat = 0;
    for (CCNode *node in ofPoints) {
        if ([node isKindOfClass:[CCNode class]]) {// You must use the ccDist to find the farthest point;
            CGFloat distance = ccpDistance(node.position, start);
            distFloat = distance < distFloat ? distFloat : distance;
        } else { NSLog( @"The given array:%@ does not contain CCNodes", ofPoints); }
    }
    return distFloat;
}

+(CGFloat)minCGPointWithNSValueArray:(NSArray *)array forX:(BOOL)yesForX_NoForY{ //TODO: I need a better way of doing things. What if the person using this code gives it an array of ndoes, and not CGpoints wrapped as NSValue's - then it backfires. A better way of doing things would be to have a specific method depending on what type of array you are sorting, and make that autonomous. If it is not autonomous, then Assert that your type of array is not supported - please contact us to add it.
    CGFloat currentMin = [roundedGround maxCGPointWithNSValueArray:array forX:yesForX_NoForY];
    for (NSValue *value in array) {
        CGFloat point = yesForX_NoForY == YES ? [value CGPointValue].x : [value CGPointValue].y;
        currentMin = MIN(point, currentMin);
    }
    return currentMin;
}

+(CGFloat)maxCGPointWithNSValueArray:(NSArray *)array forX:(BOOL)yesForX_NoForY{
    CGFloat currentMax = 0;
    for (NSValue *value in array) {
        CGFloat point = yesForX_NoForY == YES ? [value CGPointValue].x : [value CGPointValue].y;
        currentMax = MAX(point, currentMax);
    }
    return currentMax;
}

+(CGPoint)findMidpointFromArray:(NSArray *)points {
    
    CGPoint min = ccp([roundedGround minCGPointWithNSValueArray:points forX:YES],[roundedGround minCGPointWithNSValueArray:points forX:NO]) ;
    CGPoint max =  ccp([roundedGround maxCGPointWithNSValueArray:points forX:YES], [roundedGround maxCGPointWithNSValueArray:points forX:NO]);
    
    CGFloat midX = ccpMidpoint(min, max).x;
    CGFloat midY = ccpMidpoint(min, max).y;
    CGPoint mid = ccp(midX, midY);
    
    return mid;
}

+(NSArray *)cgValueFromNodes:(NSArray *)nodes {
    NSMutableArray *cgValues = [[NSMutableArray alloc] init];
    for (CCNode *node in nodes) {
        NSValue *cgPointVal = [NSValue valueWithCGPoint:node.position];
        [cgValues addObject:cgPointVal];
    }
    return cgValues;
}

#pragma mark Dynamics

/** Returns a C-Array of CGpoints from a given NSArray of CGpoints wrapped as NSValues.
 * @param Array an array of CGPoints wrapped in NSValues
 * @param yesOrNo whether or not to to draw the shape. This is mroe efficient than calling the method and then running another loop to draw. Defaults to No
 *
 * @param physics Another efficiency ploy - whether or not to draw a physicsBody with the array;
 *
 * @return CGPoint* C-Array of CGPoints
 *
 */

-(CGPoint *)calculateVerticesFromArray:(NSArray *)array draw:(BOOL)yesOrNo physicsBody:(BOOL)physics{
    CGPoint *point = calloc([array count], sizeof(CGPoint));
    
    for (int i = 0; i < [array count]; i++) {
        CGPoint pos = [[array objectAtIndex:i] CGPointValue];
        
        
        point[i] = pos;
    }
    if (yesOrNo) {
        GroundVertex data = color;
        CCColor *lnColor = [CCColor colorWithRed:data.lnColor.r green:data.lnColor.g blue:data.lnColor.b alpha:1];
        CCColor *filColor = [CCColor colorWithRed:data.color.r green:data.color.g blue:data.color.b alpha:data.color.a];
        CGFloat lnRad = data.lnRadius;
        [drawNode drawPolyWithVerts:point count:[array count] fillColor:filColor borderWidth:lnRad borderColor:lnColor];
    }
    if(physics) {
        groundNodePhysicsBody *node = [groundNodePhysicsBody node];
        node.position = midPoint;
        CCPhysicsBody *physicsPoly = [[CCPhysicsBody alloc]init];
        physicsPoly = [CCPhysicsBody bodyWithPolygonFromPoints:point count:[array count] cornerRadius:2];
        node.physicsBody = physicsPoly;
        node.physicsBody.type = CCPhysicsBodyTypeStatic;
        node.position = ccpSub(midPoint, midPoint) ;
        node.manager = self;
        node.physicsBody.sensor = NO;
        [self doOccluderEntryWithNode:node];
        [[[gameData sharedData].GamePlayNode level] addChild:node];
        self.groundNode = node;
        node.physicsBody.collisionType = @"roundedGround";
        
        
    }
    return point;
}
-(void)advancedDraw:(CCDrawNode *)drawer drawingData:(GroundVertex)data  points:(NSArray *)ofPoints {
    CGPoint *cPoints = [self calculateVerticesFromArray:ofPoints draw:NO physicsBody:NO];
    CCColor *col = [CCColor colorWithRed:data.color.r green:data.color.g blue:data.color.b alpha:data.color.a];
    CCColor *lnCol = [CCColor colorWithRed:data.lnColor.r green:data.lnColor.g blue:data.lnColor.b alpha:data.lnColor.a];
    [drawer drawPolyWithVerts:cPoints count:[ofPoints count] fillColor:[CCColor clearColor] borderWidth:data.lnRadius borderColor:lnCol];
}

-(void)drawEdgeWithGradients:(int)numOfLayers withArray:(NSArray *)array {
    NSArray *drawPoints;
    CGFloat scaleFactor = 0.02;
    for (int i = 1; i < numOfLayers +1; i++) {
        CGFloat actualScale = 1 - (i * scaleFactor);
        //        float newAlpha = (255 - (255 / i)) / 255;
        
        GroundVertex newVert;
        
        newVert.color = color.color;
        newVert.lnRadius = color.lnRadius - i;
        newVert.lnColor = color.lnColor;
        newVert.lnColor.a = color.lnColor.a;
        
        drawPoints = [roundedGround extendedBoundaryWithNSValArray:array scale:actualScale fromMid:midPoint];
        [self advancedDraw:drawNode drawingData:newVert points:drawPoints];
    }
}

-(void)drawPath:(CGPoint *)points count:(int)numOfPoints{
    for (int i = 0; i < numOfPoints; i++) {
        int x = i+1;
        if (x == numOfPoints) {
            x = i;
        }
        float radius = color.lnRadius;
        CCColor *col = [CCColor colorWithRed:color.lnColor.r green:color.lnColor.g blue:color.lnColor.b alpha:color.lnColor.a];
        [drawNode drawSegmentFrom:points[1] to:points[x] radius:radius color:[CCColor blueColor]];
    }
}
//-(void)fixedUpdate:(CCTime)delta {
//    BOOL posChange = groundNode.prevPos.x != groundNode.position.x || groundNode.prevPos.y != groundNode.prevPos.y;
//    if (posChange) {
////        [drawNode clear];
//        groundNode.physicsBody = nil;
//        [[[gameData sharedData].GamePlayNode level] removeChild:groundNode];
//        [self calculateVerticesFromArray:linePoints draw:YES physicsBody:YES];
//    }
//    groundNode.prevPos = posChange ? groundNode.position : groundNode.prevPos;
//}

+(CGPoint)calculateNearestPoint:(CGPoint)searchpoint withArray:(NSArray *)points{
    float closestDist = INFINITY;
    CGPoint closestPt = ccp(INFINITY, INFINITY);
    for (NSValue *point in points) {
        CGPoint cgPoint = [point CGPointValue];
        //        float dist = sqrt(pow( (cgPoint.x - searchpoint.x), 2) + pow( (cgPoint.y - searchpoint.y), 2));
        CGFloat dist = ccpDistance(cgPoint, searchpoint);
        if (dist < closestDist) {
            closestDist = dist;
            closestPt = cgPoint;
        }
    }
    
    return closestPt;
}
-(CCNode *)getNearestNodeFrom:(CGPoint)begin with:(NSArray *)nodes {
    CGPoint nearestPoint = [roundedGround calculateNearestPoint:begin withArray:[roundedGround cgValueFromNodes:nodes]];
    CCNode *nearest;
    for (groundEdgeNode *edgeN in nodes) {
        BOOL isEqual = edgeN.position.x == nearestPoint.x && edgeN.position.y == nearestPoint.y;
        if (isEqual) {
            nearest = edgeN;
        }
    }
    return nearest;
}
-(void)collisionWithNode:(CCNode *)nodeOne andNode:(groundNodePhysicsBody *)node {
    NSLog(@"Collision with node
    . Override Me");
}

#pragma mark occluder Methodse
-(void)onExitr2
{
	[[gameData sharedData].GamePlayNode.lightingLayer removeOccluder:self];
	
	[super onExit];
}

-(CCVertex *)occluderVertexes
{
	return _occluderVertexes;
}

-(int)occluderVertexCount
{
	return _occluderVertexCount;
}

-(void)dealloc
{
    free(_occluderVertexes);
}
@end

#pragma mark Specific grounds

@implementation gravityGround

-(gravityGround *)initWithArray:(NSArray *)array to:(CCNode *)node ofType:(types)type{
    if (self == [super classicInit:array to:node ofType:type]) {
        [self setupWithArrayCurved:array ofType:type];
        sensorPill.physicsBody.collisionType = @"roundedGround";
        sensorPill.manager = self;
        self.groundNode.physicsBody.collisionType = @"";
        
        CGPoint *extended =[self calculateVerticesFromArray:extendedBoundaries draw:NO physicsBody:NO];
        [drawNode drawPolyWithVerts:extended count:[extendedBoundaries count] fillColor:[CCColor colorWithRed:truColor(198)  green:truColor(20) blue:truColor(94) alpha:0.5] borderWidth:3 borderColor:[CCColor colorWithRed:truColor(198) green:truColor(82) blue:truColor(96) alpha:1]];
    }
    return self;
}

-(void)collisionWithNode:(CCNode*)nodeOne andNode:(groundNodePhysicsBody *)node{ // This is almost it for the rounded ground. I know right, not a lot
    if (gravityEnabled == YES) {
        self.nodeRef = nodeOne;
        nodeOne.userInteractionEnabled = NO;
        [drawNode drawDot:midPoint radius:4 color:[CCColor redColor]];
        self.groundNode.physicsBody.friction = 0.79;
        CGPoint vectPos;
        vectPos = ccpSub(midPoint, nodeOne.position);
        CGPoint nodeGoToVect = ccpSub(vectPos,self.groundNode.parent.position);
        //        endPoint = ccpSub(ccpAdd(self.parent.position, endPoint), nodeRef.position);
        [self.nodeRef.physicsBody applyForce:ccpMult(nodeGoToVect, 40) ];//ccp(nodeOne.position.x, nodeGoToVect.y), 20)
        
    } else {
        nodeOne.userInteractionEnabled = NO;
        nodeOne.physicsBody.affectedByGravity = YES;
        
    }
}

-(void)touchMoved:(UITouch *)touch {
    CGPoint touchVel = ccpSub(touch.locationInWorld, self.nodeRef.position);
    BOOL within = [self isWithinBounds:touch.locationInWorld pointsArray:extendedBoundaries];
    BOOL without = [self isWithinBounds:touch.locationInWorld pointsArray:linePoints];
    BOOL nodeIn = [self isWithinBounds:self.nodeRef.position pointsArray:extendedBoundaries];
    
    if (within && !without && nodeIn && gravityEnabled) {
        [self.nodeRef.physicsBody applyImpulse:ccpMult(touchVel, 2)];
        [self.nodeRef.physicsBody applyTorque:15];
    }
}
-(void)touch:(UITouch *)touch {
    BOOL insideGround = [self isWithinBounds:touch.locationInWorld pointsArray:linePoints];
    if (insideGround) {
        gravityEnabled = !gravityEnabled;
        if (gravityEnabled) {
            Color touchedColor;
            touchedColor.r = 1;
            touchedColor.g = 1;
            touchedColor.b = truColor(51);
            color.lnColor = touchedColor;
        }  else {
            Color touchedColor;
            touchedColor.r = color.color.r;
            touchedColor.g = color.color.g;
            touchedColor.b = color.color.a;
            color.lnColor = touchedColor;
        }
        //Saves time by not drawing anew every frame.
        [drawNode clear];
        [self calculateVerticesFromArray:[roundedGround cgValueFromNodes:grounds] draw:YES physicsBody:NO];
        CGPoint *extended =[self calculateVerticesFromArray:extendedBoundaries draw:NO physicsBody:NO];
        
        [drawNode drawPolyWithVerts:extended count:[extendedBoundaries count] fillColor:[CCColor colorWithRed:truColor(198)  green:truColor(20) blue:truColor(94) alpha:0.5] borderWidth:3 borderColor:[CCColor colorWithRed:truColor(198) green:truColor(82) blue:truColor(96) alpha:1]];
        
    }
    
}
@end

@implementation morph {
    CGPoint *point;
    BOOL alreadCollided;
    __weak groundNodePhysicsBody *currentGround;
    CCPhysicsJoint *joint;
    NSMutableArray *nearestNodeWithNeighbors;
    NSMutableArray *moveables;
}
@synthesize isBeingMoved;
-(morph *)initWithArray:(NSArray *)array to:(CCNode *)node ofType:(types)type{
    if (self == [super classicInit:array to:node ofType:type]) {
        moveables = [NSMutableArray array];
        color.lnColor.a = 1;
        color.lnColor.b = 1;
        color.lnColor.g = 1;
        color.lnColor.r = 1;
        [self setupBroken:array interaction:NO ofType:type];
        [self calculateVerticesFromArray:linePoints draw:YES physicsBody:NO];
        originalPoints = [linePoints copy];
        //        [self calculateVerticesFromArray:originalPoints
        //                                    draw:YES
        //                             physicsBody:NO];
        self.groundNode.physicsBody.sensor = YES;
        CGFloat minX = [roundedGround minCGPointWithNSValueArray:linePoints forX:YES];
        CGFloat minY = [roundedGround maxCGPointWithNSValueArray:linePoints forX:NO];
        CGFloat maxX = [roundedGround minCGPointWithNSValueArray:linePoints forX:YES];
        CGFloat maxY = [roundedGround maxCGPointWithNSValueArray:linePoints forX:NO];
        CGFloat rangeX = maxX - minX;
        CGFloat rangeY = maxY - minY;
        self.groundNode.contentSize = CGSizeMake(rangeX, rangeY);
        self.userInteractionEnabled = YES;
        NSLog(@"%@",originalPoints);
        NSLog(@"%@",smallBoundaries);
        NSLog(@"%@",extendedBoundaries);
        [self recalculate];
        
    }
    return self;
}
-(NSArray *)getNeigborsOfObj:(id)object extentOf:(int)extent inArray:(NSArray *)array bothDirections:(BOOL)both{
    NSMutableArray *neighborsOf = [NSMutableArray array];
    int timesLoopRuns = !both ? extent +1: extent * 2 +1;
    if ([array containsObject:object]) {
        int stIndx = warpIntToRange(0, [array count], [array indexOfObject:object], extent);
        for (int i = stIndx; i < stIndx + timesLoopRuns; i++) {
            int x = i;
            if (x >= [array count]) {
                x = 0;
            }
            [neighborsOf addObject:[array objectAtIndex:x]];
        }
    }
    return neighborsOf;
}
-(CCNode *)getNodeInArray:(NSArray *)array start:(int)startIndex withDistanceOf:(CGFloat)dist {
    CGFloat extent = 0.0;
    int i = startIndex;
    int totalLoops = 0;
    while (((!fuzzyEqual(dist, 10, extent)) || (extent <= dist)) && (totalLoops  <= [array count])) {
        int x = warpIntToRange(0, [array count], i, 1);
        extent += ccpDistance([(CCNode *)array[x] position], [(CCNode *)array[x] position]);
        i = warpIntToRange(0, [array count], i, 1);
        totalLoops++;
    }
    return [array objectAtIndex:i];
}

-(void)collisionWithNode:(CCNode *)nodeOne andNode:(groundNodePhysicsBody *)node{
    groundNodePhysicsBody *nodeWithDistance = (groundNodePhysicsBody *)[self getNodeInArray:physicsBodies start:[physicsBodies indexOfObject:node] withDistanceOf:100];
    nearestNodeWithNeighbors = [NSMutableArray arrayWithArray:[self getNeigborsOfObj:node extentOf:40 inArray:physicsBodies bothDirections:YES]]; //abs([physicsBodies indexOfObject:node] - [physicsBodies indexOfObject:nodeWithDistance])
    
    if ([nearestNodeWithNeighbors containsObject:node]) {
        if (isBeingMoved && joint == nil) {
            joint = [CCPhysicsJoint connectedDistanceJointWithBodyA:nodeOne.physicsBody bodyB:node.physicsBody anchorA:ccp(0, 0) anchorB:ccp(0, 0)];
            alreadCollided = YES;
        }
    }

-(void)touch:(UITouch *)touch {
    groundEdgeNode *nearestNode;
    isBeingMoved = YES;
    currentGround = (groundNodePhysicsBody *)[self getNearestNodeFrom:touch.locationInWorld with:physicsBodies];
    BOOL within = [self isWithinBounds:touch.locationInWorld pointsArray:extendedBoundaries];
    BOOL without = ![self isWithinBounds:touch.locationInWorld pointsArray:smallBoundaries];
    if (within && without) {
        CGPoint nearestPoint = [roundedGround calculateNearestPoint:touch.locationInWorld withArray:[roundedGround cgValueFromNodes:grounds]];
        for (groundEdgeNode *edgeN in grounds) {
            BOOL isEqual = edgeN.position.x == nearestPoint.x && edgeN.position.y == nearestPoint.y;
            if (isEqual) {
                nearestNode = edgeN;
            }
        }
        NSMutableArray *wthOutNearest = [NSMutableArray arrayWithArray:[grounds copy]];
        [wthOutNearest removeObject:nearestNode];
        CGPoint notNearOthers = [roundedGround calculateNearestPoint:touch.locationInWorld withArray:[roundedGround cgValueFromNodes:wthOutNearest]];
        CGPoint dist = [roundedGround calculateNearestPoint:nearestNode.position withArray:originalPoints];
        //If the distance between the touch and the ground's original location is less than
        if (ccpDistance(notNearOthers, nearestNode.position) > 5) {
            nearestNode.position = touch.locationInWorld;
            
        }
    }
    [self recalculate];

    
}

-(void)recalculate {
    [moveables removeAllObjects];
    grounds = (NSMutableArray *) [self sortNodesClockwise:grounds fromCenterPoint:midPoint];
    [linePoints removeAllObjects];
    linePoints = (NSMutableArray *)[self applyBezierCurvesCubic:[roundedGround cgValueFromNodes:grounds] numberExtraPointsPerSegment:10];
    
    for (int i = 0; i < [linePoints count]; i++) {
        groundNodePhysicsBody *body = [physicsBodies objectAtIndex:i];
//        if (!ccpFuzzyEqual(body.position, [[linePoints objectAtIndex:i] CGPointValue], 50)) {
//            [moveables addObject:body];
//        }
        body.position = [[linePoints objectAtIndex:i] CGPointValue];
    }
    [drawNode clear];
    [self drawEdgeWithGradients:6 withArray:linePoints];
    //    self.groundNode.physicsBody = [CCPhysicsBody bodyWithPolygonFromPoints:bthPt count:[linePoints count] cornerRadius:90];
}
-(void)touchEnd:(UITouch *)touch {
    isBeingMoved = NO;
    [joint invalidate];
    joint = nil;
}
@end

#define dampingValue 100.f
#define stiffnessValue 1000.f
#define restLengthValue 10.f
#define kMaxSprings 4

@implementation spring {
    NSMutableArray *segments;
    NSMutableArray *touchables;
    NSMutableArray *draggables;
    groundNodePhysicsBody *currentDraggable;
    NSMutableArray *currentSprings;
    NSMutableArray *quadSegments;
    NSTimer *timer;
    quadCurve *quadCurveData;
}
-(spring *)initWithArray:(NSArray *)array to:(CCNode *)node ofType:(types)type{
    
    if (self == [super classicInit:array to:node ofType:type]) {
        [sensorPill removeFromParent];
        linePoints = (NSMutableArray *)[self applyBezierCurvesCubic:[roundedGround cgValueFromNodes:grounds] numberExtraPointsPerSegment:10];
        //This is for management. It could be less with optimization and better logic, but I dont feel like it. There are sooooo many things I need to work on.
        quadCurveData = calloc([grounds count], sizeof(quadCurve)); //One set of data per each segment inbetween
        segments = [[NSMutableArray alloc] init];
        touchables = [[NSMutableArray alloc] init];
        draggables = [NSMutableArray array];
        currentSprings = [[NSMutableArray alloc] init];
        quadSegments = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < [grounds count] ; i++) {
            quadCurve newCurve;
            NSMutableArray *segment = [[NSMutableArray alloc] init];
            int l = i - 1;
            if (l < 0)
            { l = [grounds count]-1; }
            groundEdgeNode *edge1 = [grounds objectAtIndex:l];
            
            groundEdgeNode *edge2 = [grounds objectAtIndex:i];
            pairOfPoints pair;
            pair.p1 = edge1.position;
            pair.p2 = edge2.position;
            float range2Max = ccpDistance(pair.p1, pair.p2);
            NSArray *tempPoints = [roundedGround weightedAveragePoints:pair resolution:0.1 ];
            //Regular bodies along the edges
            for (int j = 0; j < [tempPoints count]; j++) { // Creating nodes
                
                groundNodePhysicsBody *newNode = [groundNodePhysicsBody node];
                newNode.position = [tempPoints[j] CGPointValue];
                newNode.manager = self;
                CCPhysicsBody *newBody = [CCPhysicsBody bodyWithCircleOfRadius:6 andCenter:ccp(0, 0)];
                newBody.mass = 2;
                newNode.physicsBody = newBody;
                newNode.physicsBody.type = CCPhysicsBodyTypeDynamic;
                newNode.physicsBody.friction = 0.5;
                [node addChild:newNode];
                
                [segment addObject:newNode];
                //If it is the last one in the array, then it is static - so that the shape doesn't just fall.
                if (j ==0) {
                    newBody.type = CCPhysicsBodyTypeStatic;
                    //Getting the first two points of the curvedata - the beginning and endpoints;
                    newCurve.pair.p1 = ((CCNode *)grounds[i]).position;
                    int l = i +1;
                    if (l == [grounds count]) {
                        l = 0;
                    }
                    newCurve.pair.p2 = ((CCNode *)grounds[l]).position;
                }
                //Draggables
                if (j == [tempPoints count] / 2) {
                    //The centerpoint is the control;
                    
                    
                    [touchables addObject:newNode];
                    groundNodePhysicsBody *newNode = [groundNodePhysicsBody node];
                    newNode.position = [tempPoints[j] CGPointValue];
                    //                newNode.position = [val CGPointValue];
                    newNode.manager = self;
                    CCPhysicsBody *newBody = [CCPhysicsBody bodyWithCircleOfRadius:5 andCenter:ccp(0, 0)];
                    newBody.mass = 15;
                    newNode.physicsBody = newBody;
                    newNode.physicsBody.type = CCPhysicsBodyTypeStatic;
                    newNode.physicsBody.sensor = YES;
                    newCurve.control = [tempPoints[j] CGPointValue];
                    
                    //And adding the curvePoint to the array;
                    quadCurveData[i] = newCurve;
                    [node addChild:newNode];
                    [draggables addObject:newNode];
                }
                
            }
            // Ignoring the first one, actualy creating the ropes for this "Segment"
            for (int j = 1; j < [segment count]; j++) {
                CGFloat maxDist = totalDistanceWith([roundedGround cgValueFromNodes:segment], NO) / (CGFloat)[segment count];
                int nxInd = j - 1;
                if (nxInd < 0) {
                    nxInd = [segment count] - 1;
                }
                if (j == 1) {
                    __unused CCPhysicsJoint *joint =[CCPhysicsJoint connectedSpringJointWithBodyA:((groundNodePhysicsBody *)segment[j]).physicsBody bodyB:((groundNodePhysicsBody *)segment[nxInd]).physicsBody anchorA:ccp(0, 0) anchorB:ccp(0, 0) restLength:restLengthValue stiffness:stiffnessValue damping:dampingValue]; // Dont want the max to be the exact distance, or there is almost no room to move;
                } else {
                    __unused CCPhysicsJoint *joint =[CCPhysicsJoint connectedDistanceJointWithBodyA:((groundNodePhysicsBody *)segment[j]).physicsBody bodyB:((groundNodePhysicsBody *)segment[nxInd]).physicsBody anchorA:ccp(0, 0) anchorB:ccp(0, 0) minDistance:maxDist - 5  maxDistance:maxDist]; // Dont want the max to be the exact distance, or there is almost no room to move;
                    
                    
                }
                
            }
            [segments addObject:segment];
        }
        //Connecting the ropes to the static grounds
        for (int i = 0; i < [segments count]; i++) {
            int j = i - 1;
            if (j < 0) {
                j = [segments count] -1;
            }
            int twoIndx = [segments[j] count] -1;
            groundNodePhysicsBody *one = (groundNodePhysicsBody *)segments[i][0];
            groundNodePhysicsBody *two = (groundNodePhysicsBody *)segments[j][twoIndx];
            __unused CCPhysicsJoint *joint = [CCPhysicsJoint connectedSpringJointWithBodyA:one.physicsBody bodyB:two.physicsBody anchorA:ccp(0, 0) anchorB:ccp(0, 0) restLength:restLengthValue stiffness:stiffnessValue damping:dampingValue];
            
        }
    }
    extendedBoundaries = (NSMutableArray *)[roundedGround extendedBoundaryWithNSValArray:linePoints scale:1.7
                                                                                 fromMid:midPoint];
    smallBoundaries = (NSMutableArray *)[roundedGround extendedBoundaryWithNSValArray:linePoints scale:0.5 fromMid:midPoint];
    timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(recalculate) userInfo:nil repeats:YES];
    return self;
}
-(void)touch:(UITouch *)touch {
    groundNodePhysicsBody *nearestNode;
    groundNodePhysicsBody *nearestDraggable;
    BOOL within = [self isWithinBounds:touch.locationInWorld pointsArray:extendedBoundaries];
    //    BOOL without = ![self isWithinBounds:touch.locationInWorld pointsArray:originalPoints];
    if (within) { // && without
        CGPoint nearestPoint1 = [roundedGround calculateNearestPoint:touch.locationInWorld withArray:[roundedGround cgValueFromNodes:touchables]];
        for (groundNodePhysicsBody *edgeN in touchables) {
            BOOL isEqual = edgeN.position.x == nearestPoint1.x && edgeN.position.y == nearestPoint1.y;
            if (isEqual) {
                
                nearestNode = edgeN;
            }
        }
        CGPoint nearestPoint2 = [roundedGround calculateNearestPoint:touch.locationInWorld withArray:[roundedGround cgValueFromNodes:draggables]];
        for (groundNodePhysicsBody *edgeN in draggables) {
            //          BOOL isEqual = edgeN.position.x == nearestPoint2.x && edgeN.position.y == nearestPoint2.y;
            if (ccpFuzzyEqual(edgeN.position, nearestPoint2, 10)) {
                edgeN.physicsBody.sensor = NO;
                edgeN.position = touch.locationInWorld;
                
                currentDraggable = edgeN;
                nearestDraggable = edgeN;
            }
        }
        
    }
    NSArray *all = [self oneArrayWith3dArray:segments];
    //Creating the springs. It puts the nearestnode in the middle (-kmaxsprings / 2), and goes forward until it is ahead of the index of the nearestnode by 1 half of the maximum springs.
    int i = [all indexOfObject:nearestNode] - (kMaxSprings / 2);
    if ([self isAllNilWithArray:currentSprings]) {
        for (int x = 0; x < kMaxSprings + 1; x++) {
            int trueIndx = i + x; //i is where it starts
            CGFloat maxDist = ccpDistance(touch.locationInWorld, nearestNode.position);
            CCPhysicsJoint *newJoint = [CCPhysicsJoint connectedDistanceJointWithBodyA:((CCNode *)[all objectAtIndex:trueIndx]).physicsBody bodyB:nearestDraggable.physicsBody anchorA:ccp(0, 0) anchorB:ccp(0, 0) minDistance:maxDist - 5 maxDistance:maxDist * 0.7];
            [currentSprings addObject:newJoint];
        }
        
    }
}
-(BOOL)isAllNilWithArray:(NSArray *)array {
    int x = [array count];
    int j = 0;
    for (id d in array) {
        if (d == nil) {
            j++;
        }
    }
    if (j == x) {
        return TRUE;
    } return FALSE;
}
-(void)touchEnd:(UITouch *)touch{
    currentDraggable.physicsBody.sensor = YES;
    currentDraggable.position = currentDraggable.originalPos;
    for (int i = [currentSprings count] -1; i >= 0; i--) {
        [(CCPhysicsJoint *)currentSprings[i] invalidate];
        [currentSprings removeObject:(CCPhysicsJoint *)currentSprings[i]];
    }
}

-(void)recalculate {
    // If you want to draw tha actual shape of the ground, then use this, but it would look nice;
    NSArray *newPoints = [roundedGround cgValueFromNodes:[self oneArrayWith3dArray:segments]];
    [drawNode clear];
    __unused CGPoint *drawPoints = [self calculateVerticesFromArray:newPoints draw:YES physicsBody:NO];
    
    /*
     for (int i = 0; i < [grounds count]; i++) {
     //    NSLog(@"pair1:(%f,%f)/n, pair2: (%f,%f)/n, control: (%f,%f)/n)",quadCurveData[i].pair.p1.x, quadCurveData[i].pair.p1.y, quadCurveData[i].pair.p2.x, quadCurveData[i].pair.p2.y, quadCurveData[i].control.x, quadCurveData[i].control.y);
     }
     
     [drawNode clear];
     for (int i = 0; i < [grounds count]; i++) {
     int l = i+1;
     if (l == [grounds count]) {
     l = 0;
     }
     
     CGPoint *drawPath = [self applyBezierCurveQuadtratic:quadCurveData[i].pair control:ccp(quadCurveData[i].control.x, quadCurveData[i].control.y) ];
   
     
     pairOfPoints p;
     p.p1 = ((CCNode*)grounds[i]).position;
     p.p2 = ((CCNode*)grounds[l]).position;
     
     NSArray *pts = [roundedGround weightedAveragePoints:p resolution:0.1];
     //        CGPoint *drawPath = [self calculateVerticesFromArray:pts draw:NO physicsBody:NO];
     //        [self drawPath:drawPath count:10];
     }
     */
}
-(NSArray *)oneArrayWith3dArray:(NSMutableArray *)array {
    NSMutableArray *all = [NSMutableArray array];
    for (NSArray *tempArray in array) {
        for (int i = 0; i < [tempArray count]; i++) {
            id newObj = tempArray[i];
            [all addObject:newObj];
        }
    }
    return all;
}
@end

/*
 - (void) draw
 
 {
 
 // Here's an example which draws a red textured square.
 // Don't actually load a texture every frame! This is just to simplify things.
 // N.B. Even if you're not on the iPhone, using kCCResolutioniPhone is fine.
 
 UIImage *image = [UIImage imageWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"wumpus" ofType: @"png"]];
 
 CCTexture *tex = [[CCTexture alloc] initWithCGImage: [image CGImage] resolutionType: ];
 
 CGPoint vertices[] = { ccp(0, 0), ccp(50, 0), ccp(50, 50), ccp(0, 50) };
 CGPoint texCoords[] = { ccp(0, 0), ccp(1, 0), ccp(1, 1), ccp(0, 1) };
 
 ccColor4F colors[4];
 colors[0].r = colors[1].r = colors[2].r = colors[3].r = 1;
 colors[0].g = colors[1].g = colors[2].g = colors[3].g = 0;
 colors[0].b = colors[1].b = colors[2].b = colors[3].b = 0;
 colors[0].a = colors[1].a = colors[2].a = colors[3].a = 1;
 
 DrawTexturedPolygon(vertices, texCoords, colors, 4, tex);
 
 }
 
 
 void DrawTexturedPolygon(const CGPoint *vertices, const CGPoint *texCoords, const ccColor4F *colors, NSUInteger vertexCount, CCTexture *texture)
 
 {
 
 CCGLProgram *program = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionTextureColor];
 
 [program use];
 
 [program setUniformForModelViewProjectionMatrix];
 
 ccGLEnableVertexAttribs( kCCVertexAttribFlag_PosColorTex );
 
 ccGLBindTexture2D( texture.name );
 
 // XXX: Mac OpenGL error. arrays can't go out of scope before draw is executed
 
 ccVertex2F newVertices[vertexCount];
 
 ccTex2F newTexCoords[vertexCount];
 
 // iPhone and 32-bit machines optimization
 
 if( sizeof(CGPoint) == sizeof(ccVertex2F) )
 
 glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, vertices);
 
 else
 {
 
 // Mac on 64-bit
 
 for( NSUInteger i=0; i<vertexCount;i++)
 
 newVertices[i] = (ccVertex2F) { vertices[i].x, vertices[i].y };
 
 glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, newVertices);
 }
 
 if( sizeof(CGPoint) == sizeof(ccTex2F) )
 
 glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, 0, texCoords);
 
 else
 
 {
 
 // Mac on 64-bit
 
 for( NSUInteger i=0; i<vertexCount;i++)
 
 newTexCoords[i] = (ccTex2F) { texCoords[i].x, texCoords[i].y };
 
 glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, 0, newTexCoords);
 }
 
 glVertexAttribPointer(kCCVertexAttrib_Color, 4, GL_FLOAT, GL_FALSE, 0, colors);
 
 glDrawArrays(GL_TRIANGLE_FAN, 0, (GLsizei) vertexCount);
 }
 li*/


//coolbeats
