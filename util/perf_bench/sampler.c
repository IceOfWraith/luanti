// LD_PRELOAD sampling profiler: per-thread CPU-time timers, frame-pointer unwinding.
// Output: SAMPLER_OUT file with lines "tid addr0 addr1 ..." (hex), plus /proc/self/maps copy.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ucontext.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <stdatomic.h>

#define MAXD 24
#define MAXS (4u << 20)
typedef struct { unsigned tid; unsigned n; void *pc[MAXD]; } sample_t;
static sample_t *buf; static atomic_uint nsamp;
static long period_ns = 1000000; // 1 ms CPU

static void handler(int sig, siginfo_t *si, void *uc_) {
	unsigned i = atomic_fetch_add(&nsamp, 1);
	if (i >= MAXS) return;
	ucontext_t *uc = uc_;
	sample_t *s = &buf[i];
	s->tid = (unsigned)syscall(SYS_gettid);
	void **fp = (void **)uc->uc_mcontext.gregs[REG_RBP];
	s->pc[0] = (void *)uc->uc_mcontext.gregs[REG_RIP];
	unsigned n = 1;
	void *sp = (void *)uc->uc_mcontext.gregs[REG_RSP];
	while (n < MAXD && fp && (void *)fp >= sp && (void *)fp < (char *)sp + (8 << 20) && ((unsigned long)fp & 7) == 0) {
		void *ret = fp[1];
		if (!ret) break;
		s->pc[n++] = ret;
		void **nfp = (void **)fp[0];
		if (nfp <= fp) break;
		fp = nfp;
	}
	s->n = n;
}

static void arm_thread(void) {
	timer_t t; struct sigevent sev = {0};
	sev.sigev_notify = SIGEV_THREAD_ID; sev.sigev_signo = SIGPROF;
	sev._sigev_un._tid = syscall(SYS_gettid);
	if (timer_create(CLOCK_THREAD_CPUTIME_ID, &sev, &t)) return;
	struct itimerspec its = {{0, period_ns}, {0, period_ns}};
	timer_settime(t, 0, &its, NULL);
}

typedef struct { void *(*fn)(void *); void *arg; } tramp_t;
static void *tramp(void *a) { tramp_t t = *(tramp_t *)a; free(a); arm_thread(); return t.fn(t.arg); }
int pthread_create(pthread_t *th, const pthread_attr_t *at, void *(*fn)(void *), void *arg) {
	static int (*real)(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *);
	if (!real) real = dlsym(RTLD_NEXT, "pthread_create");
	tramp_t *t = malloc(sizeof *t); t->fn = fn; t->arg = arg;
	return real(th, at, tramp, t);
}

static void dump(void) {
	const char *out = getenv("SAMPLER_OUT"); if (!out) out = "samples.txt";
	struct sigaction sa = {0}; sa.sa_handler = SIG_IGN; sigaction(SIGPROF, &sa, NULL);
	FILE *f = fopen(out, "w"); if (!f) return;
	unsigned n = atomic_load(&nsamp); if (n > MAXS) n = MAXS;
	for (unsigned i = 0; i < n; i++) {
		fprintf(f, "%u", buf[i].tid);
		for (unsigned j = 0; j < buf[i].n; j++) fprintf(f, " %lx", (unsigned long)buf[i].pc[j]);
		fputc('\n', f);
	}
	fclose(f);
	char mp[512]; snprintf(mp, sizeof mp, "%s.maps", out);
	FILE *m = fopen("/proc/self/maps", "r"), *o = fopen(mp, "w"); char line[1024];
	while (m && o && fgets(line, sizeof line, m)) fputs(line, o);
	if (m) fclose(m); if (o) fclose(o);
}

__attribute__((constructor)) static void init(void) {
	buf = calloc(MAXS, sizeof(sample_t));
	struct sigaction sa = {0}; sa.sa_sigaction = handler; sa.sa_flags = SA_SIGINFO | SA_RESTART;
	sigaction(SIGPROF, &sa, NULL);
	arm_thread();
	atexit(dump);
}
