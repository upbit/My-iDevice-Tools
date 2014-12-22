#import <sqlite3.h>
#import <Security/Security.h>

#include <getopt.h>

typedef enum {
    KCCMD_NONE = 0,
    KCCMD_LIST,
    KCCMD_ADD,
    KCCMD_UPDATE,
    KCCMD_DELETE,
} KC_CommandType;

void printToStdOut(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	[[NSFileHandle fileHandleWithStandardOutput] writeData:[formattedString dataUsingEncoding:NSNEXTSTEPStringEncoding]];
}

void printUsage(char* cmd_line)
{
	printf("usage: %s [options]\n", cmd_line);
	printf("  -h --help                       show this help\n");
}

// modify form https://github.com/upbit/Keychain-Dumper/blob/master/main.m#L56, dumpKeychainEntitlements()
void dumpKeychainAccessGroups()
{
	NSString *databasePath = @"/var/Keychains/keychain-2.db";
	const char *dbpath = [databasePath UTF8String];
	sqlite3 *keychainDB;
	sqlite3_stmt *statement;

	printToStdOut(@">> keychain-access-groups:\n");

	if (sqlite3_open(dbpath, &keychainDB) == SQLITE_OK) {
		const char *query_stmt = "SELECT DISTINCT agrp FROM genp UNION SELECT DISTINCT agrp FROM inet";
		if (sqlite3_prepare_v2(keychainDB, query_stmt, -1, &statement, NULL) == SQLITE_OK) {
			while(sqlite3_step(statement) == SQLITE_ROW) {
				NSString *group = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
				printToStdOut(@"  %@\n", group);
			}
			sqlite3_finalize(statement);
		} else {
			printf("[ERROR] Query keychain failed.\n");
		}
		sqlite3_close(keychainDB);
	} else {
		printf("[ERROR] Open keychain failed.\n");
	}
}

void keychain_list_entry(CFTypeRef kSecClassType, NSString *access_group, NSString *service)
{
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	[query setObject:(id)kSecClassType forKey:(id)kSecClass];
	[query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	[query setObject:(id)access_group forKey:(id)kSecAttrAccessGroup];
	if ((service) && (kSecClassType == kSecClassGenericPassword)) {
		[query setObject:(id)service forKey:(id)kSecAttrService];
	}

	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnRef];
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];

	CFTypeRef result = NULL;
	OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
	if (status != errSecSuccess) {
		if (status == errSecItemNotFound) return;
		printf("[ERROR] SecItemCopyMatching() failed! error = %d\n", (int)status);
		return;
	}

	NSArray *keychain_entrys = (NSArray *)result;
	for (int i = 0; i < keychain_entrys.count; i++) {
		NSDictionary *entry = (NSDictionary*)keychain_entrys[i];
		printToStdOut(@"%@\n", entry);

		if ((kSecClassType == kSecClassGenericPassword) || (kSecClassType == kSecClassInternetPassword)) {
			NSData *password_data = [entry objectForKey:(id)kSecValueData];
			printToStdOut(@"  + \"s_data\" = %@\n", [[NSString alloc] initWithData:password_data encoding:NSUTF8StringEncoding]);
		}
	}
	
	if (result != NULL)
		CFRelease(result);
}


void keychain_delete_entry(CFTypeRef kSecClassType, NSString *access_group, NSString *service)
{
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	[query setObject:(id)kSecClassType forKey:(id)kSecClass];
	[query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	[query setObject:(id)access_group forKey:(id)kSecAttrAccessGroup];
	if ((service) && (kSecClassType == kSecClassGenericPassword)) {
		[query setObject:(id)service forKey:(id)kSecAttrService];
	}
	
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnRef];
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];

	CFTypeRef result = NULL;
	OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
	if (status != errSecSuccess) {
		if (status == errSecItemNotFound) return;
		printf("[ERROR] SecItemCopyMatching() failed! error = %d\n", (int)status);
		return;
	}

	NSArray *keychain_entrys = (NSArray *)result;
	for (int i = 0; i < keychain_entrys.count; i++) {
		CFDictionaryRef dictionary = (CFDictionaryRef)keychain_entrys[i];

		OSStatus status = SecItemDelete((CFDictionaryRef)dictionary);
		if (status != errSecSuccess) {
			printf("[ERROR] SecItemDelete() failed! error = %d\n", (int)status);
			return;
		}

		printToStdOut(@">> deleted: %@\n", (NSDictionary*)keychain_entrys[i]);
	}

	if (result != NULL)
		CFRelease(result);
}

int main(int argc, char **argv, char **envp)
{
	id pool = [NSAutoreleasePool new];

	int cmd = KCCMD_NONE;
	NSMutableArray *arraySecClass = [[NSMutableArray alloc] init];

	NSString *access_group = nil;
	NSString *service_name = nil;

	int opt;
	const char *shortopts = "Dl:a:u:d:GNICKs:h";
	const struct option longopts[] = {
		// dump keychain groups
		{"dump", 0, NULL, 'D'},

		// command <Entitlement Group>
		{"list", 1, NULL, 'l'},
		{"add", 1, NULL, 'a'},
		{"update", 1, NULL, 'u'},
		{"delete", 1, NULL, 'd'},

		// SecClass selector
		{"generic-password", 0, NULL, 'G'},							// kSecClassGenericPassword
		{"internet-password", 0, NULL, 'N'},						// kSecClassInternetPassword
		{"identity", 0, NULL, 'I'},									// kSecClassIdentity
		{"certificate", 0, NULL, 'C'},								// kSecClassCertificate
		{"classKey", 0, NULL, 'K'},									// kSecClassKey

		// options
		{"service", 1, NULL, 's'},

		{"help", 0, NULL, 'h'},
		{NULL, 0, NULL, 0}
	};

	while((opt = getopt_long(argc, argv, shortopts, longopts, NULL)) != -1) {
		switch (opt) {
			case 'D':
				dumpKeychainAccessGroups();
				return 0;

			case 'l':
				if (cmd != KCCMD_NONE) {
					printf("[ERROR] More than one {--list, --add, --update, --delete} found, abort.");
					return -1;
				}
				cmd = KCCMD_LIST;
				access_group = [NSString stringWithUTF8String:optarg];
				break;
			case 'a':
				if (cmd != KCCMD_NONE) {
					printf("[ERROR] More than one {--list, --add, --update, --delete} found, abort.");
					return -1;
				}
				cmd = KCCMD_ADD;
				access_group = [NSString stringWithUTF8String:optarg];
				break;
			case 'u':
				if (cmd != KCCMD_NONE) {
					printf("[ERROR] More than one {--list, --add, --update, --delete} found, abort.");
					return -1;
				}
				cmd = KCCMD_UPDATE;
				access_group = [NSString stringWithUTF8String:optarg];
				break;
			case 'd':
				if (cmd != KCCMD_NONE) {
					printf("[ERROR] More than one {--list, --add, --update, --delete} found, abort.");
					return -1;
				}
				cmd = KCCMD_DELETE;
				access_group = [NSString stringWithUTF8String:optarg];
				break;

			case 'G':
				[arraySecClass addObject:(id)kSecClassGenericPassword];
				break;
			case 'N':
				[arraySecClass addObject:(id)kSecClassInternetPassword];
				break;
			case 'I':
				[arraySecClass addObject:(id)kSecClassIdentity];
				break;
			case 'C':
				[arraySecClass addObject:(id)kSecClassCertificate];
				break;
			case 'K':
				[arraySecClass addObject:(id)kSecClassKey];
				break;

			case 's':
				service_name = [NSString stringWithUTF8String:optarg];
				break;

			case 'h':
				printUsage(argv[0]);
				return 0;
			case '?':
				printf("Usage: %s [options]\ntype \"%s -h\" for more help.\n", argv[0], argv[0]);
				return 0;
		}
	}

	if (!access_group) {
		printUsage(argv[0]);
		return -1;
	}

	if (arraySecClass.count == 0) {
		[arraySecClass addObject:(id)kSecClassGenericPassword];		// genp

		if (cmd == KCCMD_LIST) {
			[arraySecClass addObject:(id)kSecClassInternetPassword];	// inet
			[arraySecClass addObject:(id)kSecClassIdentity];			// idnt
			[arraySecClass addObject:(id)kSecClassCertificate];			// cert
			[arraySecClass addObject:(id)kSecClassKey];					// keys
		}
	}

	for (id kSecClassType in (NSArray *)arraySecClass) {
		printToStdOut(@">>> SecClass(%@):\n", kSecClassType);

		switch (cmd) {
			case KCCMD_ADD:
				// TO-DO: KeychainWrapper
				break;
			case KCCMD_UPDATE:
				// TO-DO: KeychainWrapper
				break;
			case KCCMD_DELETE:
				// TO-DO: KeychainWrapper
				keychain_delete_entry(kSecClassType, access_group, service_name);
				break;

			default:	// KCCMD_LIST
				keychain_list_entry(kSecClassType, access_group, service_name);
				break;
		}
	}

	[pool drain];
	return 0;
}

// vim:ft=objc