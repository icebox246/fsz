# fsz

[![check](https://github.com/icebox246/fsz/actions/workflows/check.yml/badge.svg)](https://github.com/icebox246/fsz/actions/workflows/check.yml)

[![deploy](https://github.com/icebox246/fsz/actions/workflows/deploy.yml/badge.svg)](https://github.com/icebox246/fsz/actions/workflows/deploy.yml)

Simple remote file browser written in [Zig](https://ziglang.org/).

Demo available at: [fsz-demo.glitch.me](https://fsz-demo.glitch.me/).

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

## GitHub Actions setup

Provide secrets:

- `GLITCH_PROJECT` - name of you target glitch project
- `GLITCH_TOKEN` - token from your glitch git url

The can be found in `Tools > Import/Export > Your project's Git URL`, where git
url is in format: `https://GLITCH_TOKEN@api.glitch.com/git/GLITCH_PROJECT`.
