#define _GNU_SOURCE

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
#include <string.h>
#include <err.h>
#include <sched.h>
#include <sys/eventfd.h>
#include <sys/wait.h>

#include <dynamic.h>
#include <reactor.h>
#include <clo.h>

#include "helpers.h"


// Function Declarations
static core_status server_handler(core_event *event);
static int fork_workers();


int main()
{
  int parent_eventfd;
  server s;

  // Ignore the "broken pipe" signal
  signal(SIGPIPE, SIG_IGN);

  // fork_workers() forks a separate child/worker process for each available cpu and returns an eventfd from the parent
  // The eventfd is used to signal the parent. This guarantees the forking order needed for REUSEPORT_CBPF to work well
  parent_eventfd = fork_workers();

  core_construct(NULL);
  server_construct(&s, server_handler, &s);
  server_option_set(&s, SERVER_OPTION_BPF);
  server_open(&s, 0, 8080);

  // Once this worker process is listening on the socket, signal the parent that it can proceed with the next fork
  eventfd_write(parent_eventfd, (eventfd_t) 1);
  close(parent_eventfd);

  core_loop(NULL);
  core_destruct(NULL);
}


static core_status server_handler(core_event *event)
{
  static char hello_string[] = "Hello, World!";
  static char default_string[] = "Hello from libreactor!\n";
  static clo_pair json_pair[] = {{ .string = "message", .value = { .type = CLO_STRING, .string = "Hello, World!" }}};
  static clo json_object[] = {{ .type = CLO_OBJECT, .object = json_pair }};

  server *server = event->state;
  server_context *context = (server_context *) event->data;

  switch (event->type)
    {
    case SERVER_REQUEST:
      if (segment_equal(context->request.target, segment_string("/json"))){
        json(context, json_object);
      }
      else if (segment_equal(context->request.target, segment_string("/plaintext"))){
        plaintext(context, hello_string);
      }
      else{
        plaintext(context, default_string);
      }
      return CORE_OK;
    default:
      warn("error");
      server_destruct(server);
      return CORE_ABORT;
    }
}


static int fork_workers()
{
  int e, efd, worker_count = 0;
  pid_t pid;
  eventfd_t eventfd_value;
  cpu_set_t online_cpus, cpu;

  // Get set of all online CPUs
  CPU_ZERO(&online_cpus);
  sched_getaffinity(0, sizeof(online_cpus), &online_cpus);

  int num_online_cpus = CPU_COUNT(&online_cpus); // Get count of online CPUs
  int rel_to_abs_cpu[num_online_cpus];
  int rel_cpu_index = 0;

  // Create a mapping between the relative cpu id and absolute cpu id for cases where the cpu ids are not contiguous
  // E.g if only cpus 0, 1, 8, and 9 are visible to the app because taskset was used or because some cpus are offline
  // then the mapping is 0 -> 0, 1 -> 1, 2 -> 8, 3 -> 9
  for (int abs_cpu_index = 0; abs_cpu_index < CPU_SETSIZE; abs_cpu_index++) {
    if (CPU_ISSET(abs_cpu_index, &online_cpus)){
      rel_to_abs_cpu[rel_cpu_index] = abs_cpu_index;
      rel_cpu_index++;

      if (rel_cpu_index == num_online_cpus)
        break;
    }
  }

  // fork a new child/worker process for each available cpu
  for (int i = 0; i < num_online_cpus; i++)
  {
    // Create an eventfd to communicate with the forked child process on each iteration
    // This ensures that the order of forking is deterministic which is important when using SO_ATTACH_REUSEPORT_CBPF
    efd = eventfd(0, EFD_SEMAPHORE);
    if (efd == -1)
      err(1, "eventfd");

    pid = fork();
    if (pid == -1)
      err(1, "fork");

    // Parent process. Block the for loop until the child has set cpu affinity AND started listening on its socket
    if (pid > 0)
    {
      // Block waiting for the child process to update the eventfd semaphore as a signal to proceed
      eventfd_read(efd, &eventfd_value);
      close(efd);

      worker_count++;
      (void) fprintf(stderr, "Worker running on CPU %d\n", i);
      continue;
    }

    // Child process. Set cpu affinity and return eventfd
    if (pid == 0)
    {
      CPU_ZERO(&cpu);
      CPU_SET(rel_to_abs_cpu[i], &cpu);
      e = sched_setaffinity(0, sizeof cpu, &cpu);
      if (e == -1)
        err(1, "sched_setaffinity");

      // Break out of the for loop and continue running main. The child will signal the parent once the socket is open
      return efd;
    }
  }

  (void) fprintf(stderr, "libreactor running with %d worker processes\n", worker_count);

  wait(NULL); // wait for children to exit
  (void) fprintf(stderr, "A worker process has exited unexpectedly. Shutting down.\n");
  exit(EXIT_FAILURE);
}