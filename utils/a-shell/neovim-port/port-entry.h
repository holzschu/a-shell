#pragma once
#include <stdio.h>

typedef int (*nvim_port_run_fn)(int argc, char **argv, FILE **streams, const char *runtime);
int nvim_port_run(int argc, char **argv, FILE **streams, const char *runtime);
