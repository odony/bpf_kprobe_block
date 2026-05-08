# af_alg_block

small BPF program that blocks all access to the Linux kernel crypto API
(`AF_ALG` sockets) system-wide without requiring a kernel module or reboot to
enable the `bpf` LSM.

`AF_ALG` (address family 38) is a Linux socket interface that exposes kernel
cryptographic primitives to userspace. 

Inspired by https://github.com/philfry/cve-2026-31431-ftrace which uses an
alternative custom kernel module approach.


## How it works

The program attaches a `kprobe` to `__x64_sys_socket`, the kernel entry point
for the `socket(2)` syscall on x86-64. When any process calls
`socket(AF_ALG, ...)`, the kprobe fires before the syscall executes and
calls `bpf_override_return()` to inject `-EACCES` as the return value.
The real syscall never runs. From userspace the call fails with
`EPERM: Permission denied`, identical to what a kernel LSM policy would
produce.


## Building

Tested on stock Ubuntu 24.04 only, but once compiled, should run on other
Ubuntu releases.

```sh
# install build dependencies
make deps

# fetch and build libbpf 1.3.0 from Ubuntu apt source (once)
# (make sure you have deb-src packages enabled first)
make libbpf

# build the static binary
make
```

The resulting `af_alg_block` binary is statically linked against libbpf and
has no runtime library dependencies beyond the kernel.


## Usage

```sh
# run (blocks AF_ALG until stopped)
sudo ./af_alg_block

# stop (detaches the kprobe, AF_ALG access restored)
^C
```

To run as a persistent systemd service:

```ini
# /etc/systemd/system/af-alg-block.service
[Unit]
Description=Block AF_ALG sockets
After=sysinit.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/af_alg_block
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```sh
sudo cp af_alg_block /usr/local/sbin/
sudo systemctl enable --now af-alg-block
```


# DISCLAIMER

 Not a kernel developer, use at your own risk!