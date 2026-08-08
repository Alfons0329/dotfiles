# test/Dockerfile - proves install.sh works on a genuinely bare Ubuntu 22.04.
#
# The base image is given exactly two things it would not otherwise have:
#   sudo   - deliberately NOT in packages/apt.txt, so nothing the installer is
#            responsible for is pre-provisioned here
#   a user - a non-root account with passwordless sudo, matching a real build
#            machine rather than a root shell
#
# Everything else - zsh, tmux, neovim, fzf, ag, node, the configs - must be
# installed by install.sh, or the build fails.
#
#   docker build -t dotfiles-test -f test/Dockerfile .
#   docker run --rm -it dotfiles-test

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /bin/bash dev \
 && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
 && chmod 0440 /etc/sudoers.d/dev

USER dev
WORKDIR /home/dev

# Copy the installer and its inputs, but not test/. Keeping the test harness in
# a later layer means editing a check re-runs only the verification step
# instead of the whole install.
COPY --chown=dev:dev install.sh /home/dev/dotfiles/
COPY --chown=dev:dev lib/      /home/dev/dotfiles/lib/
COPY --chown=dev:dev modules/  /home/dev/dotfiles/modules/
COPY --chown=dev:dev packages/ /home/dev/dotfiles/packages/
COPY --chown=dev:dev home/     /home/dev/dotfiles/home/

# Running the installer as a build step means a failure fails the build.
# --minimal skips the macOS-only desktop and ghostty modules; no DISPLAY would
# trigger it automatically anyway, but being explicit documents the intent.
#
# Language servers are on by default in install.sh, and left off here so the
# routine build stays quick. `./test/docker-test.sh --with-lsp` overrides this
# to exercise the path a real machine takes.
ARG INSTALL_FLAGS="--yes --minimal --no-lsp-servers"
RUN /home/dev/dotfiles/install.sh $INSTALL_FLAGS

# Same for verification: this is the pass/fail signal for the whole exercise.
COPY --chown=dev:dev test/ /home/dev/dotfiles/test/
RUN /home/dev/dotfiles/test/verify.sh

# Land in the configured shell, exactly as an SSH login would.
CMD ["/bin/zsh", "-l"]
