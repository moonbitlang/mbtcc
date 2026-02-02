#ifndef MBTCC_SIGNAL_H
#define MBTCC_SIGNAL_H

typedef int sig_atomic_t;
typedef void (*sighandler_t)(int);

sighandler_t signal(int, sighandler_t);
int raise(int);

#define SIGINT 2
#define SIGTERM 15
#define SIGPIPE 13

#endif
