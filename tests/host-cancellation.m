#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include "HostPane.h"
#include <signal.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>
#include <sys/socket.h>
extern int ios_unsetenv_pid(const char *, int);
extern int numDashCommands;
static _Atomic(void *) liveJob;
static atomic_int spawnEntered, releaseSpawn;
static int beforeSpawn, cooked;
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
    if(beforeSpawn) {
        dprintf(1,"SPAWN_ENTERED\n");
        atomic_store(&spawnEntered,1);
        while(!atomic_load(&releaseSpawn))usleep(1000);
    }
    if(!result)liveJob=*job;
    return result;
}
int ashell_worker_host_poll(void *j,int *s){return ashell_host_pane_poll(j,s);}
int ashell_worker_host_close_stdin(void *j){return ashell_host_pane_close_stdin(j);}
int ashell_worker_host_interrupt(void *j){
    int error=ashell_host_pane_interrupt(j);
    // The real broker executes this call in a different process.
    ios_switchSession("host-policy-cancel-consumer");
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
    cooked=argc==3&&!strcmp(argv[2],"cooked");
    beforeSpawn=argc==3&&!strcmp(argv[2],"before-spawn");
    alarm(10);numDashCommands=1;initializeEnvironment();ios_switchSession("host-policy-cancel-consumer");
    ios_setenv("ASHELL_WORKER_PID","999",1);ios_setenv("ASHELL_HOST_COMMANDS","sleep",1);
    ios_setenv("PATH",argv[1],1);
    FILE *input=tmpfile(),*output=tmpfile(),*error=tmpfile();void *registration=NULL;
    if(!input||!output||!error||ashell_register_owned_streams(input,output,error,&registration))return 2;
    ios_setStreams(input,output,error);joinMainThread=false;
    replaceCommand(@"sleep", @"host_fixture_main", false);
    pid_t pid=ios_fork();ios_system("sleep 2");
    for(int i=0;i<200&&!(beforeSpawn?atomic_load(&spawnEntered):liveJob!=NULL);i++)usleep(10000);
    if(!(beforeSpawn?atomic_load(&spawnEntered):liveJob!=NULL)){dprintf(1,"host spawn was not reached\n");return 2;}
    if(!beforeSpawn)usleep(100000);
    dprintf(1,"interrupt before_spawn=%d pid=%d\n",beforeSpawn,pid);
    int killed=ios_interruptpid(pid);
    atomic_store(&releaseSpawn,1);
    ios_waitpid(pid);ashell_wait_owned_streams(registration);
    int expected=cooked?130:7;
    int status=ios_getCommandStatus(),actual=releasedStatus,finished=releasedFinished;
    dprintf(1,"kill=%d command_status=%d host_finished=%d host_status=%d %s\n",killed,status,finished,actual,status==expected&&finished==1&&actual==expected?"PASS":"FAIL");
    int passed=status==expected&&finished==1&&actual==expected;
    if(cooked&&passed) {
        cooked=0; liveJob=NULL;
        ios_setenv("ASHELL_WORKER_PID","999",1);
        pid=ios_fork();ios_system("sleep 2");ios_waitpid(pid);
        ashell_wait_owned_streams(registration);
        int next=ios_getCommandStatus();
        passed=next==7&&releasedFinished==1&&releasedStatus==7;
        dprintf(1,"next_host_status=%d host_status=%d %s\n",next,releasedStatus,passed?"PASS":"FAIL");
    }
    ashell_unregister_owned_streams(&registration);ios_setStreams(stdin,stdout,stderr);
    fclose(input);fclose(output);fclose(error);
    return passed?0:1;
}}
