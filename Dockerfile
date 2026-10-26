# ---------- Etapa 1: build ----------
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B
COPY src ./src
RUN ./mvnw clean package -DskipTests -B

# ---------- Etapa 2: runtime ----------
FROM eclipse-temurin:17-jre-alpine AS runner
LABEL org.opencontainers.image.source="https://github.com/Anthonazo/devsu-devops-test" \
      org.opencontainers.image.description="Devsu demo DevOps - Java"

RUN apk add --no-cache tzdata \
 && addgroup -g 1000 -S appgroup \
 && adduser -u 1000 -S appuser -G appgroup \
 && mkdir -p /app/data && chown -R appuser:appgroup /app

WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/target/*.jar app.jar

ENV PORT=8000 \
    NAME_DB=jdbc:h2:file:/app/data/test \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError"

USER 1000:1000
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:${PORT}/api/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
