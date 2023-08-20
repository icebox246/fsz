# fsz

Simple remote file browser written in [Zig](https://ziglang.org/).

# Building

This project requires `zig` version `0.11.0`.

```shell
# build project
zig build

# build project and run unit tests
zig build test

 build project and run it
zig build run
```

# Deploying

This project is designed to be deployed on [glitch.com](https://glitch.com/)

## glitch.com setup

In a glitch project run commands in terminal:

```shell
git config receive.denyCurrentBranch updateInstead
echo refresh > .git/hooks/post-receive && chmod u+x .git/hooks/post-receive
```