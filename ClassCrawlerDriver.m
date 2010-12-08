#import <Cocoa/Cocoa.h>
#import "ClassCrawler.h"


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
	NSString *string = ClassHierarchyGraphVizForClass([NSDictionary class]);
#else
	// Everything.
	NSString *string = ClassHierarchyGraphVizForEverything();
#endif
	
	FILE *outFile = fopen("classcrawl.dot", "w");
	fprintf(outFile, "%s", [string UTF8String]);
	fclose(outFile);
	
    return 0;
}
