#import <Preferences/Preferences.h>

@interface YueyuKeyboardSettingsListController : PSListController
@end

@implementation YueyuKeyboardSettingsListController
- (id)specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end