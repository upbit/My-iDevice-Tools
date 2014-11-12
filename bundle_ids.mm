#import <AppList.h>

int main(int argc, char **argv, char **envp)
{
    // list all the apps
    ALApplicationList *apps = [ALApplicationList sharedApplicationList];
    
    // sort the apps by display name. displayIdentifiers is an autoreleased object.
    NSArray *displayIdentifiers = [[apps.applications allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 caseInsensitiveCompare:obj2];
    }];
    
    NSMutableString *outputs = [NSMutableString new];
    
    for (NSString *key in displayIdentifiers) {
        NSString *name = [apps.applications objectForKey:key];
        [outputs appendString:[NSString stringWithFormat:@"%-48s: %@\n", [key cStringUsingEncoding:NSUTF8StringEncoding], name]];
    }
    
    printf("%s\n", [outputs cStringUsingEncoding:NSUTF8StringEncoding]);
    [outputs release];
	return 0;
}

// vim:ft=objc
