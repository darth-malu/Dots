#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
  unsigned long long user, nice, system, idle, iowait, irq, softirq, steal,
      guest, guest_nice;
  unsigned long long total_sum;
  unsigned long long idle_all;
} cpu_stats;

void get_stats(cpu_stats *s) {
  FILE *fp = fopen("/proc/stat", "r");
  /* if (!fp) { */
  /*   perror("Could not open /proc/stat"); */
  /*   exit(1); */
  /* } */

  char label[16];
  // Read the first line (aggregate cpu)
  fscanf(fp, "%s %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu", label,
         &s->user, &s->nice, &s->system, &s->idle, &s->iowait, &s->irq,
         &s->softirq, &s->steal, &s->guest, &s->guest_nice);
  fclose(fp);

  // Summing based on the same logic as btop/htop
  // idle_all includes idle and iowait
  s->idle_all = s->idle + s->iowait;
  s->total_sum = s->user + s->nice + s->system + s->idle + s->iowait + s->irq +
                 s->softirq + s->steal;
}

int main() {
  cpu_stats prev, curr;

  // Initial read
  get_stats(&prev);

  while (1) {
    sleep(1);
    get_stats(&curr);

    unsigned long long total_delta = curr.total_sum - prev.total_sum;
    unsigned long long idle_delta = curr.idle_all - prev.idle_all;

    if (total_delta > 0) {
      // Calculate percentage using double for precision
      double used_delta = (double)(total_delta - idle_delta);
      double utilization = (used_delta / (double)total_delta) * 100.0;
      printf("CPU Usage: %.2f%%\n", utilization);
    }

    prev = curr;
  }

  return 0;
}
