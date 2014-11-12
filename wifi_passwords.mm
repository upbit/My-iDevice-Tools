#import <Security/Security.h>

#define KEYCHAIN_SVCE_AIRPORT   "AirPort"
#define KEYCHAIN_ACCT_NAME      "acct"

void keychain_wifi_passwords()
{
    NSMutableArray *acct_name = [NSMutableArray array];
    
    // form KeyChain get AirPort.acct (Wifi Name)
    {
        NSMutableDictionary *query = [NSMutableDictionary dictionary];
        
        [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
        [query setObject:(__bridge id)kSecMatchLimitAll forKey:(__bridge id)kSecMatchLimit];
        [query setObject:(__bridge id)@KEYCHAIN_SVCE_AIRPORT forKey:(__bridge id)kSecAttrService];
        [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
        
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        if (status != errSecSuccess) {
            printf("[ERROR] SecItemCopyMatching() failed! error = %ld\n", status);
            return;
        }
        
        NSArray *wifi_list = (NSArray *)result;
        for (int i = 0; i < wifi_list.count; i++) {
            NSDictionary *wifi = (NSDictionary*)wifi_list[i];
            // get wifi name
            [acct_name addObject:wifi[@KEYCHAIN_ACCT_NAME]];
        }
        
        if (result != NULL) {
            CFRelease(result);
        }
    }
    
    // get password for each AirPort.acct
    {
        for (NSString *acct in acct_name) {
            NSMutableDictionary *query = [NSMutableDictionary dictionary];
            
            [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
            [query setObject:(__bridge id)@KEYCHAIN_SVCE_AIRPORT forKey:(__bridge id)kSecAttrService];
            [query setObject:acct forKey:(__bridge id)kSecAttrAccount];
            [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
            
            CFTypeRef result = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
            if (status != errSecSuccess) {
                printf("[ERROR] SecItemCopyMatching() failed! error = %ld\n", status);
                return;
            }
            
            NSData *password = (NSData *)result;
            NSString *output = [[NSString alloc] initWithData:password encoding:NSASCIIStringEncoding];
            printf("%s: %s\n", [acct cStringUsingEncoding:NSUTF8StringEncoding], [output cStringUsingEncoding:NSUTF8StringEncoding]);
            
            if (result != NULL) {
                CFRelease(result);
            }
        }
    }
}

int main(int argc, char **argv, char **envp)
{
    keychain_wifi_passwords();
	return 0;
}

// vim:ft=objc
