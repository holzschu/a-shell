#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include "HostPane.h"
#include <signal.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>
#include <sys/socket.h>
#include <dlfcn.h>
extern int ios_unsetenv_pid(const char *, int);
extern int numDashCommands;
static _Atomic(void *) liveJob;
static atomic_int spawnEntered, releaseSpawn;
static int beforeSpawn, cooked, startup, sequential;
static atomic_int foreignReady;
static int startupFirst;
int host_foreign_main(int argc,char **argv){atomic_store(&foreignReady,1);sleep(3);return 0;}
int host_churn_main(int argc,char **argv){return 0;}
static atomic_int dashEntered, releaseDash;
static int (*dashMain)(int, char **);
int host_gated_dash_main(int argc, char **argv) {
    if(!startup)return dashMain(argc,argv);
    atomic_store(&dashEntered,1);
    while(!atomic_load(&releaseDash))usleep(1000);
    return dashMain(argc,argv);
}
static atomic_int sessionChanged;
static int releasedFinished=-1,releasedStatus=-1;
int ashell_worker_host_spawn_ex(const char *command,const char *cwd,unsigned cols,unsigned rows,const char *const *env,ashell_pane_options *options,int *fd,void **job) {
    const char *clean[256]; size_t n=0;
    for(size_t i=0;env&&env[i]&&n<255;i++)
        if(strncmp(env[i],"ASHELL_WORKER_PID=",18)&&strncmp(env[i],"ASHELL_WORKER_ROOT_PID=",23)&&strncmp(env[i],"TMPDIR=",7))clean[n++]=env[i];
    clean[n]=NULL;
    // The real broker crosses into an app process without the worker marker.
    unsetenv("ASHELL_WORKER_PID");
    ios_unsetenv_pid("ASHELL_WORKER_PID",0);
    ios_unsetenv("ASHELL_WORKER_PID");
    int result=ashell_host_pane_spawn_ex(command,cwd,cols,rows,clean,options,fd,job);
    if(beforeSpawn || startup) {
        dprintf(1,"SPAWN_ENTERED\n");
        atomic_store(&spawnEntered,1);
        if(beforeSpawn)while(!atomic_load(&releaseSpawn))usleep(1000);
    }
    if(!result)liveJob=*job;
    return result;
}
int ashell_worker_host_poll(void *j,int *s){return ashell_host_pane_poll(j,s);}
int ashell_worker_host_close_stdin(void *j){return ashell_host_pane_close_stdin(j);}
int ashell_worker_host_interrupt(void *j){
    const void *caller=ios_getContext();
    int error=ashell_host_pane_interrupt(j);
    if(ios_getContext()!=caller) { atomic_store(&sessionChanged,1); dprintf(1,"interrupt changed caller session: FAIL\n"); }
    if(startup && !atomic_load(&releaseDash)) { startupFirst=error; dprintf(1,"startup_first_interrupt=%d\n",error); atomic_store(&releaseDash,1); }
    return error;
}
int ashell_worker_host_cancel(void *j){return ashell_host_pane_cancel(j);}
void ashell_worker_host_release(void *j){releasedFinished=ashell_host_pane_poll(j,&releasedStatus);ashell_host_pane_release(j);}
int host_fixture_main(int argc, char **argv) {
    (void)argc; (void)argv;
    if(!cooked)ios_startInteractive();
    sleep(2);
    char bytes[8192]; memset(bytes, 'x', sizeof(bytes));
    for (int i=0;i<256;i++) if (fwrite(bytes,1,sizeof(bytes),thread_stdout)!=sizeof(bytes)) return 8;
    return 7;
}
int main(int argc, char **argv) {@autoreleasepool {
    if(argc<2||argc>3)return 2;
    sequential=argc==3&&!strcmp(argv[2],"sequential-startup");
    startup=argc==3&&!strcmp(argv[2],"startup");
    cooked=sequential||startup||(argc==3&&!strcmp(argv[2],"cooked"));
    beforeSpawn=argc==3&&!strcmp(argv[2],"before-spawn");
    alarm(20);numDashCommands=1;initializeEnvironment();ios_switchSession("host-policy-cancel-consumer");ios_setContext("host-policy-cancel-consumer");
    ios_setenv("ASHELL_WORKER_PID","999",1);ios_setenv("ASHELL_HOST_COMMANDS","sleep",1);
    ios_setenv("PATH",argv[1],1);
    FILE *input=tmpfile(),*output=tmpfile(),*error=tmpfile();void *registration=NULL;
    if(!input||!output||!error||ashell_register_owned_streams(input,output,error,&registration))return 2;
    ios_setStreams(input,output,error);joinMainThread=false;
    replaceCommand(@"sleep", @"host_fixture_main", false);
    if(startup||sequential) {
        NSString *library=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/dash.framework/dash"];
        void *image=dlopen(library.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
        dashMain=image?dlsym(image,"main"):NULL;
        if(!dashMain)return 2;
        replaceCommand(@"dash",@"host_gated_dash_main",false);
    }
    int passed=0;
    for(int iteration=0;iteration<(sequential?2:1);iteration++) {
    FILE *foreignInput=NULL,*foreignOutput=NULL,*foreignError=NULL;void *foreignRegistration=NULL;pid_t foreignPid=0;
    if(sequential&&iteration==1) {
        // Cross a virtual-PID wrap with a foreign session alive during B startup.
        replaceCommand(@"host-churn",@"host_churn_main",false);
        replaceCommand(@"host-foreign",@"host_foreign_main",false);
        ios_switchSession("host-foreign-consumer");ios_setContext("host-foreign-consumer");
        ios_setenv("PATH",argv[1],1);
        foreignInput=tmpfile();foreignOutput=tmpfile();foreignError=tmpfile();
        if(!foreignInput||!foreignOutput||!foreignError||ashell_register_owned_streams(foreignInput,foreignOutput,foreignError,&foreignRegistration))return 2;
        ios_setStreams(foreignInput,foreignOutput,foreignError);
        for(int i=0;i<128;i++){pid_t p=ios_fork();ios_system("host-churn");ios_waitpid(p);}
        foreignPid=ios_fork();ios_system("host-foreign");
        for(int i=0;i<200&&!atomic_load(&foreignReady);i++)usleep(10000);
        if(!atomic_load(&foreignReady))return 2;
        ios_switchSession("host-policy-cancel-consumer");ios_setContext("host-policy-cancel-consumer");ios_setStreams(input,output,error);
        ios_setenv("ASHELL_WORKER_PID","999",1);liveJob=NULL;startup=1;
        atomic_store(&dashEntered,0);atomic_store(&releaseDash,0);atomic_store(&spawnEntered,0);
    }
    pid_t pid=ios_fork();ios_system("sleep 2");
    for(int i=0;i<200&&!(beforeSpawn?atomic_load(&spawnEntered):liveJob!=NULL);i++)usleep(10000);
    if(!(beforeSpawn?atomic_load(&spawnEntered):liveJob!=NULL)){dprintf(1,"host spawn was not reached\n");return 2;}
    if(startup) {
        for(int i=0;i<200&&!atomic_load(&dashEntered);i++)usleep(10000);
        if(!atomic_load(&dashEntered))return 2;
    } else if(!beforeSpawn)usleep(100000);
    dprintf(1,"interrupt before_spawn=%d pid=%d\n",beforeSpawn,pid);
    int killed=ios_interruptpid(pid);
    atomic_store(&releaseSpawn,1);
    ios_waitpid(pid);ashell_wait_owned_streams(registration);
    int expected=cooked?130:7;
    int status=ios_getCommandStatus(),actual=releasedStatus,finished=releasedFinished;
    dprintf(1,"kill=%d command_status=%d host_finished=%d host_status=%d %s\n",killed,status,finished,actual,status==expected&&finished==1&&actual==expected?"PASS":"FAIL");
    passed=status==expected&&finished==1&&actual==expected&&!atomic_load(&sessionChanged);
    if(sequential&&iteration==1)passed=passed&&startupFirst!=0;
    if(!passed)return 1;
    if(sequential&&iteration==1) {
        ios_switchSession("host-foreign-consumer");ios_waitpid(foreignPid);ashell_wait_owned_streams(foreignRegistration);
        int foreignStatus=ios_getCommandStatus();dprintf(1,"foreign_status=%d expected=0 %s\n",foreignStatus,foreignStatus==0?"PASS":"FAIL");
        if(foreignStatus!=0)return 1;
        ashell_unregister_owned_streams(&foreignRegistration);ios_setStreams(stdin,stdout,stderr);
        fclose(foreignInput);fclose(foreignOutput);fclose(foreignError);
        ios_switchSession("host-policy-cancel-consumer");ios_setStreams(input,output,error);
    }
    }
    if(cooked&&passed) {
        cooked=0; startup=0; liveJob=NULL;
        ios_setenv("ASHELL_WORKER_PID","999",1);
        pid_t pid=ios_fork();ios_system("sleep 2");ios_waitpid(pid);
        ashell_wait_owned_streams(registration);
        int next=ios_getCommandStatus();
        passed=next==7&&releasedFinished==1&&releasedStatus==7;
        dprintf(1,"next_host_status=%d host_status=%d %s\n",next,releasedStatus,passed?"PASS":"FAIL");
    }
    ashell_unregister_owned_streams(&registration);ios_setStreams(stdin,stdout,stderr);
    fclose(input);fclose(output);fclose(error);
    return passed?0:1;
}}
