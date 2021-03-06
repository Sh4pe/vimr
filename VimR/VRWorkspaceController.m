/**
* Tae Won Ha — @hataewon
*
* http://taewon.de
* http://qvacua.com
*
* See LICENSE
*/

#import <MacVimFramework/MacVimFramework.h>
#import <TBCacao/TBCacao.h>
#import "VRWorkspaceController.h"
#import "VRWorkspace.h"
#import "VRUtils.h"
#import "VRWorkspaceFactory.h"
#import "VRUserDefaults.h"
#import "VRDefaultLogSetting.h"


NSString *const qVimArgFileNamesToOpen = @"filenames";
NSString *const qVimArgOpenFilesLayout = @"layout";


@implementation VRWorkspaceController {
  NSMutableArray *_mutableWorkspaces;
  NSMutableDictionary *_pid2Workspace;
}

@autowire(vimManager)
@autowire(workspaceFactory)
@autowire(userDefaults)

#pragma mark Properties
- (NSArray *)workspaces {
  return _mutableWorkspaces;
}

#pragma mark Public
- (void)ensureUrlsAreVisible:(NSArray *)urls {
  NSSet *urlSet = [[NSSet alloc] initWithArray:urls];

  for (VRWorkspace *workspace in _mutableWorkspaces) {
    NSMutableSet *workspaceUrls = [[NSMutableSet alloc] initWithArray:workspace.openedUrls];
    [workspaceUrls intersectSet:urlSet];

    [workspace ensureUrlsAreVisible:workspaceUrls.allObjects];
  }
}

- (void)newWorkspace {
  [self createNewVimControllerWithWorkingDir:[NSURL fileURLWithPath:NSHomeDirectory()] args:nil];
}

- (void)openFilesInNewWorkspace:(NSArray *)fileUrls {
  NSDictionary *args = [self vimArgsFromFileUrls:fileUrls];
  NSURL *commonParentDir = common_parent_url(fileUrls);

  [self createNewVimControllerWithWorkingDir:commonParentDir args:args];
}

- (void)cleanUp {
  [_vimManager terminateAllVimProcesses];
}

- (BOOL)hasDirtyBuffers {
  for (VRWorkspace *workspace in _mutableWorkspaces) {
    if (workspace.hasModifiedBuffer) {
      return YES;
    }
  }

  return NO;
}

#pragma mark NSObject
- (id)init {
  self = [super init];
  RETURN_NIL_WHEN_NOT_SELF

  _mutableWorkspaces = [[NSMutableArray alloc] initWithCapacity:5];
  _pid2Workspace = [[NSMutableDictionary alloc] initWithCapacity:5];

  return self;
}

#pragma mark MMVimManagerDelegateProtocol
- (void)manager:(MMVimManager *)manager vimControllerCreated:(MMVimController *)vimController {
  VRWorkspace *workspace = _pid2Workspace[@(vimController.pid)];

  [workspace setUpWithVimController:vimController];
}

- (void)manager:(MMVimManager *)manager vimControllerRemovedWithControllerId:(unsigned int)controllerId pid:(int)pid {
  VRWorkspace *workspace = _pid2Workspace[@(pid)];

  [_pid2Workspace removeObjectForKey:@(pid)];
  [_mutableWorkspaces removeObject:workspace];

  [workspace cleanUpAndClose];

  [self quitWhenRequested];
}

- (NSMenuItem *)menuItemTemplateForManager:(MMVimManager *)manager {
  return [[NSMenuItem alloc] init]; // dummy menu item
}

#pragma mark Private
- (NSDictionary *)vimArgsFromFileUrls:(NSArray *)fileUrls {
  NSMutableArray *fileNames = [[NSMutableArray alloc] initWithCapacity:4];
  for (NSURL *url in fileUrls) {
    [fileNames addObject:url.path];
  }

  return @{
      qVimArgFileNamesToOpen : fileNames,
      qVimArgOpenFilesLayout : @(MMLayoutTabs),
  };
}
- (void)createNewVimControllerWithWorkingDir:(NSURL *)workingDir args:(id)args {
  int pid = [_vimManager pidOfNewVimControllerWithArgs:args];

  VRWorkspace *workspace = [_workspaceFactory newWorkspaceWithWorkingDir:workingDir];
  [_mutableWorkspaces addObject:workspace];

  _pid2Workspace[@(pid)] = workspace;
}

- (void)quitWhenRequested {
  if (![_userDefaults boolForKey:qDefaultQuitWhenLastWindowCloses]) {
    return;
  }

  if (_pid2Workspace.allValues.count > 0) {
    return;
  }

  DDLogInfo(@"Quitting VimR since the last main window has been closed.");
  [_application terminate:self];
}

@end
