{ name, hostPort, initialAdminPassword, host ? "localhost"
, image ? "sonatype/nexus3", persist ? false, extraDockerConfig ? "" }:

rec {
  nexus-clean = ''
    function nexus_clean {
      ${nexus-down}
    }
    trap nexus_clean EXIT
  '';
  nexus-health-cmd = ''
    curl http://${host}:${builtins.toString hostPort}/service/rest/v1/status
  '';
  nexus-health = ''
    while true
    do 
      ${nexus-health-cmd}
      sleep 10
    done
  '';
  nexus-bootstrap = ''
    set +e
    ADMIN_PASSWORD=$(docker exec -i ${name} cat /nexus-data/admin.password)

    curl \
      --retry 10 \
      --retry-all-errors \
      -H 'accept: application/json' \
      -H 'Content-Type: text/plain' \
      -u admin:$ADMIN_PASSWORD \
      -d ${initialAdminPassword} \
      -X 'PUT' \
      http://${host}:${
        builtins.toString hostPort
      }/service/rest/v1/security/users/admin/change-password

    curl \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -u admin:${initialAdminPassword} \
      -d '{"enabled": true}' \
      -X 'PUT' \
      http://${host}:${
        builtins.toString hostPort
      }/service/rest/v1/security/anonymous
    set -e
  '';
  nexus-docker-pull = ''
    docker pull ${image}
  '';
  nexus-down = ''
    docker stop ${name}
    docker rm ${name}
    ${
      if persist then ''
        echo "skipping to delete local persistence $(git rev-parse --show-toplevel)/${name}-data"
      '' else ''
        docker volume rm ${name}-data
      ''
    } 
  '';
  nexus-up = ''
    ${if persist then ''
      mkdir -p $(git rev-parse --show-toplevel)/${name}-data
      mkdir -p $(git rev-parse --show-toplevel)/${name}-data
      # chown -R 200 $(git rev-parse --show-toplevel)/${name}-data
    '' else
      ""}

    docker volume create --name ${name}-data
    docker run ${if persist then "-d" else ""} \
    -p ${builtins.toString hostPort}:8081 \
    ${extraDockerConfig} \
    --name ${name} \
    ${
      if persist then
        "-v $(git rev-parse --show-toplevel)/${name}-data:/nexus-data"
      else
        "-v ${name}-data:/nexus-data"
    } \
    ${image}
  '';
  nexus-definition = ''
    echo "${nexus-up}"
  '';
  nexus-process = ''
    set -e
    ${nexus-clean}
    ${nexus-docker-pull}
    ${nexus-up}
    sleep 60
    ${nexus-bootstrap}

    ${if persist then ''
      ${nexus-health}
    '' else
      ""}
  '';
}
