#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

#define AF_ALG  38
#define EACCES  13

// GPL license required, otherwise the it will fail at runtime with:
//   "cannot call GPL-restricted function from non-GPL compatible program"
char LICENSE[] SEC("license") = "GPL";

// kprobe type required for bpf_override_return
SEC("kprobe/__x64_sys_socket")
int BPF_KPROBE(block_af_alg, struct pt_regs *regs)
{
    // regs is the pt_regs of the syscall: di = first arg = family
    int family = (int)PT_REGS_PARM1_CORE(regs);

    if (family == AF_ALG)
        bpf_override_return(ctx, -EACCES);

    return 0;
}