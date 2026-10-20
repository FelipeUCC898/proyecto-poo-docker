# FORENSIC REPORT - hotelspringboot

**Estudiante:** Felipe Narvaez Gomez
**ID:** 908404
**Fecha:** 20/10/2026

## 1. Tabla de Identidad

| Item | Comando | Salida |
|---|---|---|
| Hash de la imagen | `docker inspect --format="{{.Id}}" hotelspringboot:1.0.0` | `sha256:d54de4174cfa4840e470533741896e237ffe313b76e78c08b8cf7a314dd2e416` |
| Variable inyectada | `docker exec hotelspringboot_active env \| findstr OPERATOR_ID` | `OPERATOR_ID=908404` |
| Consumo final calibrado | `docker stats --no-stream hotelspringboot_active` | Ver salida completa abajo |

```text
CONTAINER ID   NAME                     CPU %   MEM USAGE / LIMIT    MEM %   NET I/O           BLOCK I/O    PIDS
e3ebe3660c49   hotelspringboot_active   0.19%  163.9MiB / 256MiB    64.02%  28.5kB / 33.3kB   0B / 262kB   32
```

## 2. Reto 1 - Construccion

Comando usado desde `taller-docker-semana13` (usa el Dockerfile de la carpeta del proyecto):
```powershell
docker build --build-arg STUDENT_ID="908404" -t hotelspringboot:1.0.0 -f ..\Dockerfile ..
```

La imagen se construyo correctamente y existe localmente con el ID indicado en la tabla de identidad. La salida completa del build no se conservo, por lo que no se agregan lineas de consola no verificadas.

## 3. Reto 2 - Auditoria forense

### 3.1 Historial de capas
```text
docker history --human --format "table {{.Size}}\t{{.CreatedBy}}" hotelspringboot:1.0.0
SIZE      CREATED BY
0B        ENTRYPOINT ["sh" "-c" "exec java $JAVA_OPTS …]
0B        USER sensor_user
0B        EXPOSE [8080/tcp]
0B        ENV JAVA_OPTS=-XX:+UseContainerSupport -XX:M…
0B        ENV OPERATOR_ID=908404
47.7MB    RUN |1 STUDENT_ID=908404 /bin/sh -c chown -R…
47.7MB    COPY /build/target/*.jar /app/app.jar # buil…
8.19kB    WORKDIR /app
41kB      RUN |1 STUDENT_ID=908404 /bin/sh -c addgroup…
0B        ARG STUDENT_ID=908404
0B        ENTRYPOINT ["/__cacert_entrypoint.sh"]
12.3kB    COPY --chmod=755 entrypoint.sh /__cacert_ent…
12.3kB    RUN /bin/sh -c set -eux;     echo "Verifying…
141MB     RUN /bin/sh -c set -eux;     ARCH="$(apk --p…
0B        ENV JAVA_VERSION=jdk-17.0.20.1+1
44MB      RUN /bin/sh -c set -eux;     apk add --no-ca…
0B        ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_AL…
0B        ENV PATH=/opt/java/openjdk/bin:/usr/local/sb…
0B        ENV JAVA_HOME=/opt/java/openjdk
0B        CMD ["/bin/sh"]
9.08MB    ADD alpine-minirootfs-3.24.2-x86_64.tar.gz /…
```

Nota: Docker acorto la columna `CREATED BY` en la salida. El historial muestra las capas del JRE y el `.jar`; Maven y el codigo fuente quedan fuera de la imagen final, en la etapa `builder`.

### 3.2 Aislamiento de privilegios
```text
docker top hotelspringboot_active -o pid,user,comm
PID                 USER                COMMAND
1654                10001               java

docker exec hotelspringboot_active id
uid=10001(sensor_user) gid=10001(sensorgroup) groups=10001(sensorgroup)
```

El proceso `java` corre bajo `sensor_user` (UID 10001), no como `root`.

### 3.3 Inmutabilidad de runtime
```text
docker exec hotelspringboot_active touch /etc/crontab_fake
touch: cannot touch '/etc/crontab_fake': Permission denied
```

La cuenta `sensor_user` no puede escribir en `/etc`.

### 3.4 Artefactos de desarrollo
```text
docker exec hotelspringboot_active sh -c "command -v mvn"
Sin salida (codigo de salida 1; Maven no esta instalado).

docker exec hotelspringboot_active sh -c "find / -name '*.java' 2>/dev/null"
Sin salida (no se encontraron archivos `.java`).
```

La imagen final no contiene Maven ni codigo fuente, lo que reduce su tamano y superficie de ataque.

## 4. Reto 3 - cgroups

### 4.1 OOMKilled con 48 MB
```text
docker inspect hotelspringboot_crash --format="Status: {{.State.Status}} | ExitCode: {{.State.ExitCode}} | OOMKilled: {{.State.OOMKilled}}"
Status: exited | ExitCode: 137 | OOMKilled: true
```

El contenedor fue terminado por superar el limite de memoria de 48 MB. El codigo 137 corresponde a la terminacion por SIGKILL.

### 4.2 Calibracion

| Limite -m | Inicio OK | Tiempo de arranque (logs) | Observaciones |
|---|---|---|---|
| 48m | No | No inicio; termino con OOMKilled | `ExitCode: 137` |
| 256m | Si | 22.617 segundos | Sigue corriendo; puerto host 8081 |
| 384m | No probado | No probado | — |
| 512m | No probado | No probado | — |

Umbral minimo probado con inicio exitoso: **256 MB**. Los limites de 384 MB y 512 MB no se probaron, y 256 MB es el minimo exitoso entre los limites ensayados.

Logs:
```text
docker logs --timestamps hotelspringboot_active | findstr "Started HotelApplication"
2026-10-20T22:12:16.346340031Z 2026-10-20T22:12:16.345Z  INFO 1 --- [hotel-reservas-app] [           main]
com.hotel.Hotel.HotelApplication : Started HotelApplication in 22.617 seconds (process running for 25.844)
```

Docker stats:

| CPU % | MEM USAGE / LIMIT | MEM % |
|---|---|---|
| 0.19% | 163.9MiB / 256MiB | 64.02% |

```text
CONTAINER ID   NAME                     CPU %   MEM USAGE / LIMIT    MEM %   NET I/O           BLOCK I/O    PIDS
e3ebe3660c49   hotelspringboot_active   0.19%  163.9MiB / 256MiB    64.02%  28.5kB / 33.3kB   0B / 262kB   32
```
