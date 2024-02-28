#multi-stage container build
#first build application using Maven
#then create actual container
FROM maven:3.9.6-ibm-semeru-17-focal as build

WORKDIR /app

COPY resources/ ./resources/
COPY src/ ./src/
COPY pom.xml .

RUN mvn liberty:create
RUN mvn package
RUN mvn liberty:start && \
    mvn liberty:deploy && \
    mvn liberty:stop 

#Latest Open Liberty, UBI-based from IBM Container Registry
FROM icr.io/appcafe/open-liberty:kernel-slim-java17-openj9-ubi

# Add Liberty server configuration including all necessary features
COPY --from=build --chown=1001:0 /app/src/main/liberty/config/server.xml /config/server.xml
COPY --from=build --chown=1001:0 /app/src/main/liberty/config/server.env /config/server.env
COPY --from=build --chown=1001:0 /app/target/liberty/wlp/usr/servers/defaultServer/bootstrap.properties /config/

# This script will add the requested XML snippets to enable Liberty features and grow image to be fit-for-purpose using featureUtility.
# Only available in 'kernel-slim'. The 'full' tag already includes all features for convenience.
RUN features.sh

# Add app
COPY --from=build --chown=1001:0 /app/target/io.openliberty.sample.daytrader9.war /config/apps/

#Derby files
COPY --from=build --chown=1001:0 /app/target/liberty/wlp/usr/shared/resources/DerbyLibs/derby-10.14.2.0.jar /opt/ol/wlp/usr/shared/resources/DerbyLibs/derby-10.14.2.0.jar
COPY --from=build --chown=1001:0 /app/target/liberty/wlp/usr/shared/resources/data /opt/ol/wlp/usr/shared/resources/data

RUN configure.sh
