//
//  ThemeManager.m
//  Writer
//
//  Created by Hendrik Noeller on 04.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "ThemeManager.h"
#import "Theme.h"

@interface ThemeManager ()
@property (strong, nonatomic) NSMutableArray* themes;
@property (nonatomic) NSUInteger selectedTheme;
@property (nonatomic) NSDictionary* plistContents;

@property (strong, nonatomic) Theme* fallbackTheme;
@end

@implementation ThemeManager

#define VERSION_KEY @"version"
#define SELECTED_THEME_KEY @"selectedTheme"
#define THEMES_KEY @"themes"

#pragma mark File Loading

+ (ThemeManager*)sharedManager
{
    static ThemeManager* sharedManager;
    if (!sharedManager) {
        sharedManager = [[ThemeManager alloc] init];
    }
    return sharedManager;
}

- (ThemeManager*)init
{
    self = [super init];
    if (self) {
        //Get path to the plist in the applicationSupportFolder
        NSString* themePlistPath = [self plistFilePath];
        NSString* bundleThemePlistPath = [[NSBundle mainBundle] pathForResource:@"Themes"
                                                                         ofType:@"plist"];
        
        //If the file doesn't exist, copy the default file from the bundle
        NSFileManager* fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:themePlistPath]) {
            [fileManager copyItemAtPath:bundleThemePlistPath
                                 toPath:themePlistPath error:nil];
            _plistContents = [NSDictionary dictionaryWithContentsOfFile:themePlistPath];
        } else {
            NSDictionary *bundlePlistContent = [NSDictionary dictionaryWithContentsOfFile:bundleThemePlistPath];
            _plistContents = [NSDictionary dictionaryWithContentsOfFile:themePlistPath];
            NSUInteger installedVersion = [[_plistContents objectForKey:VERSION_KEY] integerValue];
            NSUInteger bundleVersion = [[bundlePlistContent objectForKey:VERSION_KEY] integerValue];
            
            if (installedVersion < bundleVersion) {
                [fileManager copyItemAtPath:bundleThemePlistPath
                                     toPath:themePlistPath error:nil];
                _plistContents = bundlePlistContent;
            }
        }
        //Extract Data
        
        //Get the selected Theme
        self.selectedTheme = [[_plistContents objectForKey:SELECTED_THEME_KEY] integerValue];
        
        //Get the raw themes
        NSArray* rawThemes = [_plistContents objectForKey:THEMES_KEY];
        self.themes = [[NSMutableArray alloc] initWithCapacity:[rawThemes count]];
        for (NSDictionary* dict in rawThemes) {
            [self.themes addObject:[self themeFromDictionary:dict]];
        }
    }
    return self;
}

- (NSString*)plistFilePath
{
    NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                          NSUserDomainMask,
                                                                          YES);
    NSString* applicationSupportDir = searchPaths[0];
    NSString* appName = @"Writer";
    NSString* writerAppSupportDir = [applicationSupportDir stringByAppendingPathComponent:appName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:writerAppSupportDir]) {
        [fileManager createDirectoryAtPath:writerAppSupportDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return [writerAppSupportDir stringByAppendingPathComponent:@"Themes.plist"];
}

- (Theme*)themeFromDictionary:(NSDictionary*)dict
{
    Theme* theme = [[Theme alloc] init];
    theme.name = [dict objectForKey:@"Name"];
    NSArray* backgroundValues = [dict objectForKey:@"Background"];
    NSArray* textValues = [dict objectForKey:@"Text"];
    NSArray* invisibleTextValues = [dict objectForKey:@"InvisibleText"];
    NSArray* caretValues = [dict objectForKey:@"Caret"];
    NSArray* commentValues = [dict objectForKey:@"Comment"];
    
    theme.backgroundColor = [self colorFromArray:backgroundValues];
    theme.textColor = [self colorFromArray:textValues];
    theme.invisibleTextColor = [self colorFromArray:invisibleTextValues];
    theme.caretColor = [self colorFromArray:caretValues];
    theme.commentColor = [self colorFromArray:commentValues];
    
    return theme;
}

- (NSColor*)colorFromArray:(NSArray*)array
{
    if ([array count] != 3) {
        return nil;
    }
    NSNumber* redValue = array[0];
    NSNumber* greenValue = array[1];
    NSNumber* blueValue = array[2];
    
    double red = redValue.doubleValue / 255.0;
    double green = greenValue.doubleValue / 255.0;
    double blue = blueValue.doubleValue / 255.0;
    return [NSColor colorWithRed:red green:green blue:blue alpha:1.0];
}

#pragma mark Value Access

- (NSColor*)currentBackgroundColor
{
    return [self currentTheme].backgroundColor;
}

- (NSColor*) currentTextColor
{
    return [self currentTheme].textColor;
}

- (NSColor*) currentInvisibleTextColor
{
    return [self currentTheme].invisibleTextColor;
}

- (NSColor*) currentCaretColor
{
    return [self currentTheme].caretColor;
}

- (NSColor*) currentCommentColor
{
    return [self currentTheme].commentColor;
}

- (Theme*)currentTheme {
    if (self.selectedTheme >= [self numberOfThemes]) {
        return self.fallbackTheme;
    }
    return self.themes[self.selectedTheme];
}

- (Theme *)fallbackTheme
{
    if (!_fallbackTheme) {
        _fallbackTheme = [[Theme alloc] init];
        _fallbackTheme.backgroundColor = [NSColor colorWithWhite:0.0 alpha:1.0];
        _fallbackTheme.textColor = [NSColor colorWithWhite:1.0 alpha:1.0];
        _fallbackTheme.invisibleTextColor = [NSColor colorWithWhite:0.7 alpha:1.0];
        _fallbackTheme.caretColor = [NSColor colorWithWhite:0.1 alpha:1.0];
        _fallbackTheme.commentColor = [NSColor colorWithWhite:0.5 alpha:1.0];
    }
    return _fallbackTheme;
}



#pragma mark Selection management

- (NSUInteger)numberOfThemes
{
    return [self.themes count];
}

- (NSString*)nameForThemeAtIndex:(NSUInteger)index
{
    if (index >= [self numberOfThemes]) {
        return @"";
    }
    Theme* theme = self.themes[index];
    return theme.name;
}

- (NSUInteger)selectedTheme
{
    return _selectedTheme;
}

- (void)selectThemeWithName:(NSString *)name
{
    for (int i = 0; i < [self numberOfThemes]; i++) {
        Theme *theme = self.themes[i];
        if ([theme.name isEqualToString:name]) {
            self.selectedTheme = i;
            [self.plistContents setValue:@(i) forKey:SELECTED_THEME_KEY];
            NSString* plistFilePath = [self plistFilePath];
            [self.plistContents writeToFile:plistFilePath atomically:YES];
            return;
        }
    }
}

@end
