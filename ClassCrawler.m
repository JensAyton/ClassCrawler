#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>


NSString *ClassHierarchyGraphVizForBundle(NSBundle *bundle);
NSString *ClassHierarchyGraphVizForClass(Class class);
NSString *ClassHierarchyGraphVizForEverything(void);

static NSString *MakeClassTable(NSBundle *bundle, Class relativesOfClass);
static void CrawlClass(Class object, NSHashTable *seen, NSMutableString *str, NSBundle *bundle, BOOL force, NSUInteger *count);
static NSString *PseudoRandomColor(const char *key, uint8_t max);
static NSString *BundleName(NSBundle *bundle);
static BOOL IsSubclass(Class class, Class superclassCandidate);


int main (int argc, const char * argv[])
{
#if 0
	// Runtime library (Blocks stuff).
	NSString *string = ClassHierarchyGraphVizForBundle([NSBundle bundleForClass:[^{} class]]);
#elif 0
	// Core Foundation.
	NSString *string = ClassHierarchyGraphVizForBundle([NSBundle bundleWithIdentifier:@"com.apple.CoreFoundation"]);
#elif 0
	// Foundation.
	NSString *string = ClassHierarchyGraphVizForBundle([NSBundle bundleWithIdentifier:@"com.apple.Foundation"]);
#elif 0
	// AppKit.
	NSString *string = ClassHierarchyGraphVizForBundle([NSBundle bundleWithIdentifier:@"com.apple.AppKit"]);
#elif 0
	// The tool itself; contains _NSResurrectedObject, for some reason.
	NSString *string = ClassHierarchyGraphVizForBundle([NSBundle mainBundle]);
#elif 1
	// Superclasses and subclasses of a given class.
	NSString *string = ClassHierarchyGraphVizForClass([NSArray class]);
#else
	// Everything.
	NSString *string = ClassHierarchyGraphVizForEverything();
#endif
	
	FILE *outFile = fopen("classcrawl.dot", "w");
	fprintf(outFile, "%s", [string UTF8String]);
	fclose(outFile);
	
    return 0;
}


NSString *ClassHierarchyGraphVizForBundle(NSBundle *bundle)
{
	return MakeClassTable(bundle, Nil);
}


NSString *ClassHierarchyGraphVizForClass(Class class)
{
	return MakeClassTable(nil, class);
}


NSString *ClassHierarchyGraphVizForEverything(void)
{
	return MakeClassTable(nil, Nil);
}


static NSString *MakeClassTable(NSBundle *bundle, Class relativesOfClass)
{
	NSMutableString	*string = [NSMutableString string];
	NSHashTable		*seen = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
	int				i, count;
	NSString		*label;
	NSUInteger		classCount = 0;
	
	count = objc_getClassList(NULL, 0);
	Class classes[count];
	count = objc_getClassList(classes, count);
	
	if (relativesOfClass != Nil)  label = [NSString stringWithFormat:@"Relatives of class %s", class_getName(relativesOfClass)];
	else  if (bundle != nil)  label = [NSString stringWithFormat:@"Classes in %@", BundleName(bundle)];
	else  label = @"All loaded classes";
	
	for (i = 0; i < count; i++)
	{
		if (relativesOfClass != Nil && !IsSubclass(classes[i], relativesOfClass))  continue;
		
		CrawlClass(classes[i], seen, string, bundle, NO, &classCount);
	}
	
	NSString *result = [NSString stringWithFormat:@"digraph classCrawl\n{\n\tgraph[rankdir=LR label=\"%@ (%lu classes)\"]\n\tnode [fontname=Helvetica shape=box]\n\t\n%@}\n", label, classCount, string];
	
	return result;
}


static void CrawlClass(Class class, NSHashTable *seen, NSMutableString *str, NSBundle *bundle, BOOL force, NSUInteger *count)
{
	if (class == Nil)  return;
	if (NSHashGet(seen, class) != nil)  return;
	
	NSBundle *classBundle = [NSBundle bundleForClass:class];
	BOOL outOfBundle = bundle != nil && ![classBundle isEqual:bundle];
	
	if (outOfBundle && !force)  return;
	
	if (!outOfBundle)  (*count)++;
	
	NSHashInsertKnownAbsent(seen, class);
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
