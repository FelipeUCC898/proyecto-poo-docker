# ============ ETAPA 1: builder ============
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder

# ID del estudiante inyectado en tiempo de construccion
ARG 908404

WORKDIR /build

# 1) Solo el pom.xml: la descarga de dependencias queda en cache
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 2) Ahora si el codigo fuente (si cambia src/, no se repite el paso anterior)
COPY src ./src
RUN mvn package -DskipTests -B

# ============ ETAPA 2: runtime ============
FROM eclipse-temurin:17-jre-alpine

# Hay que re-declarar el ARG en esta etapa para poder usarlo en ENV
ARG STUDENT_ID

# Usuario sin privilegios: sensor_user (UID 10001) en el grupo sensorgroup
RUN addgroup -g 10001 sensorgroup && \
    adduser -D -u 10001 -G sensorgroup sensor_user

WORKDIR /app

# Copiar unicamente el .jar resultante
COPY --from=builder /build/target/*.jar /app/app.jar

# Titularidad de /app para sensor_user
RUN chown -R sensor_user:sensorgroup /app

# Variables de entorno
ENV OPERATOR_ID=${908404}
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=70.0 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

# Cambiar a usuario no privilegiado ANTES del ENTRYPOINT
USER sensor_user

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
