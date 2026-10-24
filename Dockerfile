# ==========================================
# ETAPA 1: Build y compilación (Maven + JDK 17)
# ==========================================
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

COPY src ./src
RUN ./mvnw clean package -DskipTests -B

# ==========================================
# ETAPA 2: Runtime ligero y seguro (JRE 17)
# ==========================================
FROM eclipse-temurin:17-jre-alpine AS runner

RUN apk add --no-cache curl tzdata

# Crear grupo y usuario con UID y GID 1000 coincidentes con Kubernetes
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

WORKDIR /app

# Asignar permisos completos al usuario 1000 sobre /app para permitir escribir test.mv.db
RUN mkdir -p /app && chown -R appuser:appgroup /app && chmod -R 775 /app

COPY --from=builder --chown=appuser:appgroup /app/target/*.jar app.jar

ENV SERVER_PORT=8000 \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"

USER 1000:1000

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:${SERVER_PORT}/api/swagger-ui.html || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dserver.port=${SERVER_PORT} -jar app.jar"]