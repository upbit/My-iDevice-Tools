#import <sqlite3.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>

#include <getopt.h>

typedef enum {
    KCCMD_NONE = 0,
    KCCMD_LIST,
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
	printf("  -d --dump                       Dump Keychain AccessGroups\n");
	printf("  -U --update                     UPDATE v_Data with specified value <-g> <-s> <-a> <-v>\n");
	printf("  -D --delete                     DELETE keychain with <-g> (-s) (-a)\n");
	printf("  -g --group <AccessGroup>        kSecAttrAccessGroup\n");
	printf("  -s --service <Service>          kSecAttrService\n");
	printf("  -a --account <Account>          kSecAttrAccount\n");
	printf("  -v --value <v_Data>             (UPDATE only) kSecValueData\n");
	printf("\n");
	printf("  <SecClass selector>\n");
	printf("    -G --generic-password         kSecClassGenericPassword\n");
	printf("    -N --internet-password        kSecClassInternetPassword\n");
	printf("    -I --identity                 kSecClassIdentity\n");
	printf("    -C --certificate              kSecClassCertificate\n");
	printf("    -K --classKey                 kSecClassKey\n");
	printf("\n");
	printf("  -h --help                       Show this help\n");
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

void keychain_list_entry(CFTypeRef kSecClassType, NSString *access_group, NSString *service, NSString *account)
{
	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
	[query setObject:(id)kSecClassType forKey:(id)kSecClass];
	[query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	if (access_group)
		[query setObject:(id)access_group forKey:(id)kSecAttrAccessGroup];
	if ((service) && (kSecClassType == kSecClassGenericPassword))
		[query setObject:(id)service forKey:(id)kSecAttrService];
	if ((account) && (kSecClassType == kSecClassGenericPassword))
		[query setObject:(id)account forKey:(id)kSecAttrAccount];

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
		NSMutableDictionary *mutable_entry = [NSMutableDictionary dictionaryWithDictionary:entry];
		
		if ((kSecClassType == kSecClassGenericPassword) || (kSecClassType == kSecClassInternetPassword)) {
			NSData *password_data = [mutable_entry objectForKey:(id)kSecValueData];
			NSString *password_string = [[NSString alloc] initWithData:password_data encoding:NSUTF8StringEncoding];
			if (password_string)
				[mutable_entry setObject:password_string forKey:(id)kSecValueData];
		}

		printToStdOut(@"<AccessGroup:%@, Service:%@, Account:%@>\n", [mutable_entry objectForKey:(id)kSecAttrAccessGroup], [mutable_entry objectForKey:(id)kSecAttrService], [mutable_entry objectForKey:(id)kSecAttrAccount]);
		printToStdOut(@"%@\n", mutable_entry);
	}

	if (result != NULL)
		CFRelease(result);
}

void keychain_update_entry(CFTypeRef kSecClassType, NSString *access_group, NSString *service, NSString *account, NSString *value)
{
	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
	[query setObject:(id)kSecClassType forKey:(id)kSecClass];
	[query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	if (!access_group) {
		printf("[ERROR] --group kSecAttrAccessGroup missed.\n");
		return;
	} else {
		[query setObject:(id)access_group forKey:(id)kSecAttrAccessGroup];
	}
	if ((!service) || (kSecClassType != kSecClassGenericPassword)) {
		printf("[ERROR] --service kSecAttrService missed or SecClass!=kSecClassGenericPassword\n");
		return;
	} else {
		[query setObject:(id)service forKey:(id)kSecAttrService];
	}
	if ((!account) || (kSecClassType != kSecClassGenericPassword)) {
		printf("[ERROR] --account kSecAttrAccount missed or SecClass!=kSecClassGenericPassword\n");
		return;
	} else {
		[query setObject:(id)account forKey:(id)kSecAttrAccount];
	}

	if (!value) {
		printf("[ERROR] --value missed.\n");
		return;
	}

	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	//[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnRef];
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
		NSMutableDictionary *mutable_entry = [NSMutableDictionary dictionaryWithDictionary:entry];
		NSMutableDictionary *update_item = [NSMutableDictionary dictionaryWithDictionary:entry];
		[mutable_entry setObject:(id)kSecClassType forKey:(id)kSecClass];

		printToStdOut(@"  Origin: %@\n", update_item);

		[update_item removeObjectForKey:@"accc"];
		[update_item removeObjectForKey:(id)kSecAttrAccessGroup];

		[update_item setObject:[value dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecValueData];
		
		OSStatus status = SecItemUpdate((CFDictionaryRef)mutable_entry, (CFDictionaryRef)update_item);
		if (status != errSecSuccess) {
			if (status == errSecItemNotFound) return;
			printf("[ERROR] SecItemUpdate() failed! error = %d\n", (int)status);
			printToStdOut(@"  error entry: %@\n", update_item);
			return;
		}

		printToStdOut(@">> Update v_Data to: %@\n", [value dataUsingEncoding:NSUTF8StringEncoding]);
	}

	if (result != NULL)
		CFRelease(result);
}

void keychain_delete_entry(CFTypeRef kSecClassType, NSString *access_group, NSString *service, NSString *account)
{
	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
	[query setObject:(id)kSecClassType forKey:(id)kSecClass];
	[query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	if (!access_group) {
		printf("[ERROR] --group kSecAttrAccessGroup missed.\n");
		return;
	} else {
		[query setObject:(id)access_group forKey:(id)kSecAttrAccessGroup];
	}
	if ((service) && (kSecClassType == kSecClassGenericPassword))
		[query setObject:(id)service forKey:(id)kSecAttrService];
	if ((account) && (kSecClassType == kSecClassGenericPassword))
		[query setObject:(id)account forKey:(id)kSecAttrAccount];

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

	int cmd = KCCMD_LIST;
	NSMutableArray *arraySecClass = [[NSMutableArray alloc] init];

	NSString *access_group = nil;
	NSString *service_name = nil;
	NSString *account_name = nil;
	NSString *value_data = nil;

	int opt;
	const char *shortopts = "dg:s:a:v:GNICKUDh";
	const struct option longopts[] = {
		// dump keychain groups
		{"dump", 0, NULL, 'd'},
		{"group", 1, NULL, 'g'},
		{"service", 1, NULL, 's'},
		{"account", 1, NULL, 'a'},
		{"value", 1, NULL, 'v'},

		// SecClass selector
		{"generic-password", 0, NULL, 'G'},							// kSecClassGenericPassword
		{"internet-password", 0, NULL, 'N'},						// kSecClassInternetPassword
		{"identity", 0, NULL, 'I'},									// kSecClassIdentity
		{"certificate", 0, NULL, 'C'},								// kSecClassCertificate
		{"classKey", 0, NULL, 'K'},									// kSecClassKey

		// options
		{"update", 0, NULL, 'U'},
		{"delete", 0, NULL, 'D'},

		{"help", 0, NULL, 'h'},
		{NULL, 0, NULL, 0}
	};

	while((opt = getopt_long(argc, argv, shortopts, longopts, NULL)) != -1) {
		switch (opt) {
			case 'd':
				dumpKeychainAccessGroups();
				return 0;

			case 'g':
				access_group = [NSString stringWithUTF8String:optarg];
				break;
			case 's':
				service_name = [NSString stringWithUTF8String:optarg];
				break;
			case 'a':
				account_name = [NSString stringWithUTF8String:optarg];
				break;
			case 'v':
				value_data = [NSString stringWithUTF8String:optarg];
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

			case 'U':
				cmd = KCCMD_UPDATE;
				break;
			case 'D':
				cmd = KCCMD_DELETE;
				break;

			case 'h':
				printUsage(argv[0]);
				return 0;
			case '?':
				printf("Usage: %s [options]\ntype \"%s -h\" for more help.\n", argv[0], argv[0]);
				return 0;
		}
	}

	if (arraySecClass.count == 0) {
		[arraySecClass addObject:(id)kSecClassGenericPassword];			// genp
		/*if (cmd == KCCMD_LIST) {
			[arraySecClass addObject:(id)kSecClassInternetPassword];	// inet
			[arraySecClass addObject:(id)kSecClassIdentity];			// idnt
			[arraySecClass addObject:(id)kSecClassCertificate];			// cert
			[arraySecClass addObject:(id)kSecClassKey];					// keys
		}*/
	}

	for (id kSecClassType in (NSArray *)arraySecClass) {
		//printToStdOut(@">>> SecClass(%@):\n", kSecClassType);
		switch (cmd) {
			case KCCMD_UPDATE:
				keychain_update_entry(kSecClassType, access_group, service_name, account_name, value_data);
				break;
			case KCCMD_DELETE:
				keychain_delete_entry(kSecClassType, access_group, service_name, account_name);
				break;

			case KCCMD_LIST:
			default:
				keychain_list_entry(kSecClassType, access_group, service_name, account_name);
				break;
		}
	}

	[pool drain];
	return 0;
}

// vim:ft=objc