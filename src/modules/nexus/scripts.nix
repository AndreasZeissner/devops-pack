{ name, hostPort, initialAdminPassword, host ? "localhost"
, image ? "sonatype/nexus3" }:

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
    sleep 60
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
  '';
  nexus-docker-pull = ''
    docker pull ${image}
  '';
  nexus-down = ''
    docker stop ${name}
    docker rm ${name}
    docker volume rm ${name}-data
  '';
  nexus-up = ''
    docker volume create --name ${name}-data
    docker run -d -p ${
      builtins.toString hostPort
    }:8081 --name ${name} -v ${name}-data:/nexus-data ${image}
  '';
}
