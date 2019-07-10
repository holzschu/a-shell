//
//  ios_system.h
//  ios_system
//
//  Created by Nicolas Holzschuch on 04/12/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

//! Project version number for ios_system.
FOUNDATION_EXPORT double ios_systemVersionNumber;

//! Project version string for ios_system.
FOUNDATION_EXPORT const unsigned char ios_systemVersionString[];

// Thread-local input and output streams
extern __thread FILE* thread_stdin;
extern __thread FILE* thread_stdout;
extern __thread FILE* thread_stderr;
extern __thread void* thread_context;
// set to true to have more commands available, more debugging information.
extern bool sideLoading;

extern int ios_executable(const char* inputCmd); // does this command exist? (executable file or builtin command)
extern int ios_system(const char* inputCmd); // execute this command (executable file or builtin command)
extern FILE *ios_popen(const char *command, const char *type); // Execute this command and pipe the result
extern int ios_kill(void); // kill the current running command
extern int ios_isatty(int fd); // test whether a file descriptor refers to a terminal
extern pthread_t ios_getLastThreadId(void);
extern pthread_t ios_getThreadId(pid_t pid);
extern void ios_storeThreadId(pthread_t thread);
extern void ios_releaseThread(pthread_t thread);
extern void ios_releaseThreadId(pid_t pid);
extern pid_t ios_currentPid(void);
extern int ios_getCommandStatus(void);
extern const char* ios_progname(void);
extern pid_t ios_fork(void);
extern void ios_waitpid(pid_t pid);

extern NSString* commandsAsString(void);
extern NSArray* commandsAsArray(void);      // set of all commands, in an NSArrays
extern NSString* getoptString(NSString* command);
extern NSString* operatesOn(NSString* command);
extern void initializeEnvironment(void);
extern int ios_setMiniRoot(NSString*);  // restricts operations to a certain hierarchy
extern int ios_setMiniRootURL(NSURL*);  // restricts operations to a certain hierarchy
extern int ios_setAllowedPaths(NSArray<NSString *> *paths);  // restricts operations to a certain hierarchy
extern void ios_switchSession(const void* sessionid);
extern void ios_closeSession(const void* sessionid);
extern void ios_setStreams(FILE* _stdin, FILE* _stdout, FILE* _stderr);
extern void ios_setContext(void *context);
extern void ios_setDirectoryURL(NSURL* workingDirectoryURL);
extern void replaceCommand(NSString* commandName, NSString* functionName, bool allOccurences);
extern NSError* addCommandList(NSString* fileLocation);
