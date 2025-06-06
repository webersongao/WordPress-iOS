@import SFHFKeychainUtils;
#import "WPAccount.h"
#ifdef KEYSTONE
#import "Keystone-Swift.h"
#else
#import "WordPress-Swift.h"
#endif

@interface WPAccount ()

@property (nonatomic, strong, readwrite) NSString *cachedToken;

@end

@implementation WPAccount

@dynamic username;
@dynamic blogs;
@dynamic defaultBlog;
@dynamic primaryBlogID;
@dynamic uuid;
@dynamic dateCreated;
@dynamic email;
@dynamic emailVerified;
@dynamic displayName;
@dynamic userID;
@dynamic avatarURL;
@dynamic settings;
@synthesize _private_wordPressComRestApi;
@synthesize cachedToken;

#pragma mark - NSManagedObject subclass methods

- (void)prepareForDeletion
{
    // Only do these deletions in the primary context (no parent)
    if (self.managedObjectContext.concurrencyType != NSMainQueueConcurrencyType) {
        return;
    }

    [_private_wordPressComRestApi invalidateAndCancelTasks];
    _private_wordPressComRestApi = nil;
    self.authToken = nil;
}

- (void)didTurnIntoFault
{
    [super didTurnIntoFault];
    _private_wordPressComRestApi = nil;
    self.cachedToken = nil;
}

+ (NSString *)entityName
{
    return @"Account";
}

#pragma mark - Custom accessors

- (void)setUsername:(NSString *)username
{
    NSString *previousUsername = self.username;

    BOOL usernameChanged = ![previousUsername isEqualToString:username];
    NSString *authToken = nil;

    if (usernameChanged) {
        authToken = self.authToken;
        self.authToken = nil;
    }

    [self willChangeValueForKey:@"username"];
    [self setPrimitiveValue:username forKey:@"username"];
    [self didChangeValueForKey:@"username"];

    if (usernameChanged) {
        self.authToken = authToken;
    }
}

- (NSString *)authToken
{
    if (self.cachedToken != nil) {
        return self.cachedToken;
    }

    NSString *token = [WPAccount tokenForUsername:self.username];
    self.cachedToken = token;
    return token;
}

- (void)setAuthToken:(NSString *)authToken
{
    self.cachedToken = nil;

    if (authToken) {
        NSError *error = nil;
        [SFHFKeychainUtils storeUsername:self.username
                             andPassword:authToken
                          forServiceName:[WPAccount authKeychainServiceName]
                             accessGroup:nil
                          updateExisting:YES
                                   error:&error];

        if (error) {
            DDLogError(@"Error while updating WordPressComOAuthKeychainServiceName token: %@", error);
        }

    } else {
        NSError *error = nil;
        [SFHFKeychainUtils deleteItemForUsername:self.username
                                  andServiceName:[WPAccount authKeychainServiceName]
                                     accessGroup:nil
                                           error:&error];
        if (error) {
            DDLogError(@"Error while deleting WordPressComOAuthKeychainServiceName token: %@", error);
        }
    }

    // Make sure to release any RestAPI alloc'ed, since it might have an invalid token
    _private_wordPressComRestApi = nil;
}

- (BOOL)hasAtomicSite {
    for (Blog *blog in self.blogs) {
        if ([blog isAtomic]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Static methods

+ (NSString *)tokenForUsername:(NSString *)username isJetpack:(BOOL)isJetpack error:(NSError **)outError
{
    if (isJetpack) {
        [WPAccount migrateAuthKeyForUsername:username];
    }

    NSError *error = nil;
    NSString *authToken = [SFHFKeychainUtils getPasswordForUsername:username
                                                     andServiceName:[WPAccount authKeychainServiceName]
                                                        accessGroup:nil
                                                              error:&error];
    if (error) {
        DDLogError(@"Error while retrieving WordPressComOAuthKeychainServiceName token: %@", error);

        if (outError) {
            *outError = error;
        }
        return nil;
    }

    return authToken;
}

+ (void)migrateAuthKeyForUsername:(NSString *)username
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SharedDataIssueSolver *sharedDataIssueSolver = [SharedDataIssueSolver instance];
        [sharedDataIssueSolver migrateAuthKeyFor:username];
    });
}

@end
