#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
static int fd_count(void) { int count=0; for(int fd=0;fd<1024;fd++) if(fcntl(fd,F_GETFD)!=-1) count++; return count; }
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 3) return 2;
        setenv("TERM", "xterm-256color", 1);
        setenv("TERMINFO", argv[1], 1);
        setenv("COLUMNS", "80", 1);
        setenv("LINES", "24", 1);
        setenv("LANG", "en_US.UTF-8", 1);
        joinMainThread = true;
        static char session[] = "pico-runtime";
        ios_switchSession(session);
        ios_setWindowSize(80, 24, session);
        int before=fd_count();
        int signals[]={SIGHUP,SIGTERM,SIGTSTP,SIGWINCH};
        struct sigaction handlers[4];
        for(int i=0;i<4;i++) if(sigaction(signals[i],NULL,&handlers[i])) return 5;
        for (int pass=0; pass<20; pass++) {
            FILE *input=tmpfile(), *output=tmpfile();
            if (!input || !output) return 3;
            const char *text=pass ? "second editor run Привет 世界\n" : "first editor run\n";
            fwrite(text,1,strlen(text)-1,input); fputs("\017\r\030",input); rewind(input);
            ios_setStreams(input,output,stderr); ios_settty(input);
            thread_stdin=input; thread_stdout=output; thread_stderr=stderr;
            char path[4096], command[8192];
            snprintf(path,sizeof(path),"%s/pico-%d.txt",argv[2],pass);
            snprintf(command,sizeof(command),"pico -dcs UTF-8 -kcs UTF-8 %s",path);
            int result=ios_system(command);
            fflush(output); rewind(output);
            int c; while ((c=fgetc(output)) != EOF) fputc(c,stderr);
            FILE *saved=fopen(path,"rb"); char bytes[256]={0};
            if(saved) { fread(bytes,1,sizeof(bytes)-1,saved); fclose(saved); }
            fprintf(stderr,"\nPICO_RESULT pass=%d status=%d bytes=%zu\n",pass,result,strlen(bytes));
            fclose(input); fclose(output);
            if(result != 0 || strcmp(bytes,text)) return 4;
        }
        int after=fd_count();
        fprintf(stderr,"PICO_FDS before=%d after=%d\n",before,after);
        if(after>before+2) return 6;
        for(int i=0;i<4;i++) { struct sigaction current; if(sigaction(signals[i],NULL,&current)||current.sa_handler!=handlers[i].sa_handler) { fprintf(stderr,"PICO_SIGNAL_CHANGED signal=%d\n",signals[i]); return 7; } }
        fprintf(stderr,"PICO_EDIT_REENTRY_PASSED\n");
        ios_closeSession(session);
        return 0;
    }
}
