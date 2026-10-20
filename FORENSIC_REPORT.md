# FORENSIC REPORT - eco-air-backend

**Estudiante:** Felipe Narvaez Gomez  
**ID:** 908404
**Fecha:** (20/10/2026)

## 1. Tabla de Identidad

| Item | Comando | Salida |
|---|---|---|
| Hash de la imagen | `docker inspect --format="{{.Id}}" eco-air-backend:1.0.0` | `sha256:...` |
| Variable inyectada | `docker exec eco_air_active env \| findstr OPERATOR_ID` | `OPERATOR_ID=...` |
| Consumo final calibrado | `docker stats --no-stream` | (tabla abajo) |

```
PEGAR AQUI LA SALIDA COMPLETA DE docker stats --no-stream
```

## 2. Reto 1 - Construccion

Comando usado:
```
docker build --build-arg STUDENT_ID="TU_ID_AQUI" -t eco-air-backend:1.0.0 .
```
Salida (ultimas lineas):
```
PEGAR AQUI
```

## 3. Reto 2 - Auditoria forense

### 3.1 Historial de capas
```
docker history --human --format "table {{.Size}}\t{{.CreatedBy}}" eco-air-backend:1.0.0
PEGAR SALIDA
```
Explicacion: (la imagen final solo contiene JRE + usuario + .jar; Maven y el codigo fuente quedaron en la etapa builder y no estan en las capas finales).

### 3.2 Aislamiento de privilegios
```
docker top eco_air_active -o pid,user,comm
PEGAR SALIDA
```
Explicacion: el proceso `java` corre bajo `sensor_user` (UID 10001), no como root.

### 3.3 Inmutabilidad de runtime
```
docker exec eco_air_active touch /etc/crontab_fake
PEGAR SALIDA (Permission denied)
```
Explicacion: sensor_user no tiene permisos de escritura sobre /etc (pertenece a root), por lo que un atacante que comprometa la app no puede dejar scripts persistentes.

### 3.4 Artefactos de desarrollo
```
docker exec eco_air_active which mvn
PEGAR SALIDA (vacia / exit code 1)

docker exec eco_air_active sh -c "find / -name '*.java' 2>/dev/null"
PEGAR SALIDA (vacia)
```
Explicacion: ni Maven ni codigo fuente existen en la imagen final, gracias al build multietapa. Menor superficie de ataque y menor tamano.

## 4. Reto 3 - cgroups

### 4.1 OOMKilled con 48 MB
```
docker inspect eco_air_crash --format="Status: {{.State.Status}} | ExitCode: {{.State.ExitCode}} | OOMKilled: {{.State.OOMKilled}}"
PEGAR SALIDA
```
Explicacion: (el kernel mato el proceso con SIGKILL, codigo 137, porque Spring Boot + Hibernate necesitan mas de 48 MB).

### 4.2 Calibracion

| Limite -m | Inicio OK | Tiempo de arranque (logs) | Observaciones |
|---|---|---|---|
| 256m | | | |
| 384m | | | |
| 512m | | | |

Umbral minimo encontrado: **____ MB**

Logs:
```
docker logs --timestamps eco_air_active | findstr "Started EcoAirApplication"
PEGAR SALIDA
```

Docker stats:

| CPU % | MEM USAGE / LIMIT | MEM % |
|---|---|---|
| | | |

```
PEGAR SALIDA COMPLETA
```
