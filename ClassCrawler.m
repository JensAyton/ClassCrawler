#import "ClassCrawler.h"
#import <objc/runtime.h>


static NSString *MakeClassTable(NSString *label, NSBundle *bundle, Class relativesOfClass);
static NSString *BundleName(NSBundle *bundle);


NSString *ClassHierarchyGraphVizForBundle(NSBundle *bundle)
{
	return MakeClassTable([NSString stringWithFormat:@"Classes in %@", BundleName(bundle)], bundle, Nil);
}


NSString *ClassHierarchyGraphVizForClass(Class class)
{
	return MakeClassTable([NSString stringWithFormat:@"Relatives of class %s", class_getName(class)], nil, class);
}


NSString *ClassHierarchyGraphVizForEverything(void)
{
	return MakeClassTable(@"All loaded classes", nil, Nil);
}


#pragma mark -
#pragma mark Teh inner gutsingz

static void CrawlClass(Class object, NSMutableSet *seen, NSMutableString *str, NSBundle *bundle, BOOL force, NSUInteger *count);
static NSString *PseudoRandomColor(const char *key, uint8_t max);
static BOOL IsSubclass(Class class, Class superclassCandidate);


static NSString *MakeClassTable(NSString *label, NSBundle *bundle, Class relativesOfClass)
{
	NSMutableString	*string = [NSMutableString string];
	NSMutableSet	*seen = [NSMutableSet new];
	int				i, count;
	NSUInteger		classCount = 0;
	
	count = objc_getClassList(NULL, 0);
	Class classes[count];
	count = objc_getClassList(classes, count);
	
	for (i = 0; i < count; i++)
	{
		if (relativesOfClass != Nil && !IsSubclass(classes[i], relativesOfClass))  continue;
		
		CrawlClass(classes[i], seen, string, bundle, NO, &classCount);
	}
	
	NSString *result = [NSString stringWithFormat:@"digraph classCrawl\n{\n\tgraph[rankdir=LR label=\"%@ (%lu classes)\"]\n\tnode [fontname=Helvetica shape=box]\n\t\n%@}\n", label, (unsigned long)classCount, string];
	
	return result;
}


static void CrawlClass(Class class, NSMutableSet *seen, NSMutableString *str, NSBundle *bundle, BOOL force, NSUInteger *count)
{
	id hashKey = [NSValue valueWithPointer:(__bridge void *)class];

	if (class == Nil)  return;
	if ([seen containsObject:hashKey])  return;
	
	NSBundle *classBundle = [NSBundle bundleForClass:class];
	BOOL outOfBundle = bundle != nil && ![classBundle isEqual:bundle];
	
	if (outOfBundle && !force)  return;
	
	if (!outOfBundle)  (*count)++;

	[seen addObject:hashKey];
	Class superClass = class_getSuperclass(class);
	
	const char *className = class_getName(class);
	
	if (outOfBundle || bundle == nil)
	{
		NSString *extras = @"";
		NSString *bundleName = BundleName(classBundle);
		if (outOfBundle)  extras = @" color=grey fontcolor=grey50";
		if (bundle == nil)
		{
			NSString *color = PseudoRandomColor([bundleName UTF8String], 100);
			extras = [NSString stringWithFormat:@" color=\"%@\" fontcolor=\"%@\"", color, color];
		}
		
		[str appendFormat:@"\t%s [label=\"%s\\n(%@)\"%@]\n", className, className, BundleName(classBundle), extras];
	}
	else
	{
		if (superClass == Nil)
		{
			[str appendFormat:@"\t%s\n", class_getName(class)];
			// If there’s a superclass, the edge is sufficient.
		}
	}
	
	if (superClass != Nil)
	{
		const char *superName = class_getName(superClass);
		NSString *color = PseudoRandomColor(superName, 200);
		if (superClass != Nil)  [str appendFormat:@"\t%s -> %s [color=\"%@\"]\n", superName, className, color];
		
		// Crawl upwards to get superclasses from other bundles.
		CrawlClass(superClass, seen, str, bundle, YES, count);
	}
}


/*
	Generate a stable pseudo-random colour, not too near white, based on a
	hash of a string.
*/
static NSString *PseudoRandomColor(const char *key, uint8_t max)
{
	uint32_t hash = 5387;
	while (*key)
	{
		hash = ((hash << 5) + hash) /* 33 * hash */ ^ *key;
		key++;
	}
	
	uint8_t red = ((hash * 7829) & 0xFF) * max / 255;
	uint8_t green = ((hash * 2663) & 0xFF) * max / 255;
	uint8_t blue = (hash & 0xFF) * max / 255;
	
	return [NSString stringWithFormat:@"#%.2X%.2X%.2X", red, green, blue];
}


static NSString *BundleName(NSBundle *bundle)
{
	NSString *bundleName = bundle.bundleIdentifier;
	if (bundleName == nil)  bundleName = bundle.executablePath;
	if (bundleName == nil)  bundleName = bundle.bundlePath;
	if (bundleName == nil)  bundleName = [NSString stringWithFormat:@"Bundle %p", bundle];
	
	return bundleName;
}


static BOOL IsSubclass(Class class, Class superclassCandidate)
{
	while (class != Nil)
	{
		if (class == superclassCandidate)  return YES;
		class = class_getSuperclass(class);
	}
	
	return NO;
}
