#!/usr/bin/env bash

#### REQUIRES: yq

ARGUMENT=${1}

set -o errexit -o nounset -o pipefail
set -o monitor # Job Control, needed for "fg"

function main() {
  log "Starting presentation" 
  
  INTERNAL=""
  DOCKER_ARGS="-p 8000:8000 -p 35729:35729"
  
  if [[ "${ARGUMENT}" == "internal" ]]; then
      INTERNAL=true
      DOCKER_ARGS=""
  fi
  
  # shellcheck disable=SC2046
  # Quoting leads to '' which in turn leads to failing docker command
  # For dist/theme: Don't mount whole folder to not overwrite other files in folder (fonts, images, etc.)
  CONTAINER_ID=$( docker run --detach \
      $([[ -d docs/slides ]] && echo "-v $(pwd)/docs/slides:/reveal/docs/slides") \
      $([[ -d dist/theme ]] && for f in dist/theme/*.css; do echo "-v $(pwd)/${f}:/reveal/${f}"; done) \
      $([[ -d images ]] && echo "-v $(pwd)/images:/reveal/images") \
      $([[ -d resources ]] && echo "-v $(pwd)/resources:/resources") \
      $([[ -d plugin ]] && for dir in plugin/*/; do echo "-v $(pwd)/${dir}:/reveal/${dir}"; done) \
      -e TITLE="$(yq '.title' config.yaml)" \
      -e THEME_CSS="$(yq '.css_theme' config.yaml)" \
      -e WIDTH="$(yq '.width' config.yaml)" \
      -e HEIGHT="$(yq '.height' config.yaml)" \
      -e MARGIN="$(yq '.margin' config.yaml)" \
      -e MIN_SCALE="$(yq '.min_scale' config.yaml)" \
      -e MAX_SCALE="$(yq '.max_scale' config.yaml)" \
      -e ADDITIONAL_PLUGINS="$(yq '.additional_plugins' config.yaml)" \
      -e ADDITIONAL_SCRIPT="$(yq '.additional_script' config.yaml)" \
      ${DOCKER_ARGS} \
     cloudogu/reveal.js:$(yq '.revealjs_version' config.yaml))
  
  if [ -t 1 ] ; then
    # When running in terminal, print logs in background while waiting for container to come up
    docker logs ${CONTAINER_ID}
    # Running in terminal
    docker attach ${CONTAINER_ID} &
  fi
  
  if [[ "${INTERNAL}" == "true" ]]; then
      REVEAL_HOSTNAME=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID})
  else
      REVEAL_HOSTNAME=localhost
  fi
  
  log "Waiting for presentation to become available on http://${REVEAL_HOSTNAME}:8000"
  
  until $(curl -s -o /dev/null --head --fail ${REVEAL_HOSTNAME}:8000); do sleep 1; done
  
  if [ -t 1 ] ; then
    # Running in terminal
    # Open Browser
    xdg-open http://${REVEAL_HOSTNAME}:8000
    
    # Bring container to foreground, so it can be stopped using ctrl+c. 
    # But don't output "docker attach ${CONTAINER_ID}"
    fg > /dev/null
  else 
    # Headless, e.g. called by printPdf.sh
    # Return container ID to caller
    echo "$CONTAINER_ID"
  fi
}

function log() {
  if [ -t 1 ] ; then
    # Print only when running in terminal, suppress for headless
    echo "$1"
  fi
}

main "$@"