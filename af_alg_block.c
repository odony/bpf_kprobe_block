#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <bpf/libbpf.h>
#include "af_alg_block.bpf.skel.h"

static volatile int running = 1;

static void handle_sig(int sig) {
    (void)sig;
    running = 0;
}

int main(void) {
    struct af_alg_block_bpf *skel;
    int err;

    // load and verify BPF program
    skel = af_alg_block_bpf__open_and_load();
    if (!skel) {
        fprintf(stderr, "failed to load BPF skeleton\n");
        return 1;
    }

    err = af_alg_block_bpf__attach(skel);
    if (err) {
        fprintf(stderr, "failed to attach BPF program: %d\n", err);
        af_alg_block_bpf__destroy(skel);
        return 1;
    }

    printf("af_alg_block: running, AF_ALG sockets are blocked\n");
    printf("              press Ctrl-C to stop\n");

    signal(SIGINT, handle_sig);
    signal(SIGTERM, handle_sig);

    while (running)
        sleep(1);

    printf("\naf_alg_block: detaching\n");
    af_alg_block_bpf__destroy(skel);
    return 0;
}