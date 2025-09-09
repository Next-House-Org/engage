# Stage 1: Base image for common dependencies
FROM node:22.17.0-alpine AS common-deps

WORKDIR /app

# Copy necessary files for dependency resolution
COPY ./package.json ./yarn.lock ./.yarnrc.yml ./tsconfig.base.json ./nx.json /app/
COPY ./.yarn/releases /app/.yarn/releases
COPY ./.prettierrc /app/
COPY ./packages/twenty-emails/package.json /app/packages/twenty-emails/
COPY ./packages/twenty-server/package.json /app/packages/twenty-server/
COPY ./packages/twenty-server/patches /app/packages/twenty-server/patches
COPY ./packages/twenty-ui/package.json /app/packages/twenty-ui/
COPY ./packages/twenty-shared/package.json /app/packages/twenty-shared/
COPY ./packages/twenty-front/package.json /app/packages/twenty-front/

# Clear the Yarn cache before installing dependencies
RUN yarn cache clean

# Install dependencies
RUN yarn install

# Stage 2: Build the backend
FROM common-deps AS twenty-server-build

WORKDIR /app

# Copy source code after installing dependencies to leverage Docker layer caching
COPY ./packages/twenty-emails /app/packages/twenty-emails
COPY ./packages/twenty-shared /app/packages/twenty-shared
COPY ./packages/twenty-server/src /app/packages/twenty-server/src
COPY ./packages/twenty-server/tsconfig.json /app/packages/twenty-server/tsconfig.json
COPY ./packages/twenty-server/package.json /app/packages/twenty-server/package.json
COPY ./packages/twenty-server/patches /app/packages/twenty-server/patches

# Build the backend application
RUN npx nx run twenty-server:build

# Verify build output
RUN ls -la /app/packages/twenty-server/dist/src/database/clickHouse/

# Move and manage build artifacts
RUN mv /app/packages/twenty-server/dist /app/packages/twenty-server/build
RUN npx nx run twenty-server:build:packageJson
RUN mv /app/packages/twenty-server/dist/package.json /app/packages/twenty-server/package.json
RUN rm -rf /app/packages/twenty-server/dist
RUN mv /app/packages/twenty-server/build /app/packages/twenty-server/dist

# Optimize dependencies for production
RUN yarn workspaces focus --production twenty-emails twenty-shared twenty-server

# Stage 3: Build the frontend
FROM common-deps AS twenty-front-build

WORKDIR /app

# Set build-time environment variables
ARG REACT_APP_SERVER_BASE_URL

# Copy source code for the frontend
COPY ./packages/twenty-front /app/packages/twenty-front
COPY ./packages/twenty-ui /app/packages/twenty-ui
COPY ./packages/twenty-shared /app/packages/twenty-shared

# Remove hidden files and non-UTF-8 files
RUN find /app -name "._*" -delete && \
    find /app -name ".DS_Store" -delete && \
    find /app -name "*.ts" -type f -exec file {} \; | grep -v "UTF-8" | cut -d: -f1 | xargs -I {} rm -f {}

# Build the frontend application
RUN npx nx build twenty-front

# Stage 4: Final stage to run the application
FROM node:18.17.1-alpine AS twenty

# Install necessary tools for health checks and database interactions
RUN apk add --no-cache curl jq postgresql-client

# Install tsx globally for TypeScript execution
RUN npm install -g tsx

WORKDIR /app

# Copy the entrypoint script and make it executable
COPY --from=twenty-front-build /app/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

WORKDIR /app/packages/twenty-server

# Set environment variables
ARG REACT_APP_SERVER_BASE_URL
ENV REACT_APP_SERVER_BASE_URL=$REACT_APP_SERVER_BASE_URL

ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION

# Copy built applications from previous stages
COPY --chown=1000 --from=twenty-server-build /app /app
COPY --chown=1000 --from=twenty-server-build /app/packages/twenty-server /app/packages/twenty-server
COPY --chown=1000 --from=twenty-front-build /app/packages/twenty-front/dist /app/packages/twenty-server/dist/front

# Create necessary directories and set permissions
RUN mkdir -p /app/.local-storage && chown -R 1000 /app

# Use a non-root user for security best practices
USER 1000

# Set the command to run the application
CMD ["node", "dist/src/main"]
ENTRYPOINT ["/app/entrypoint.sh"]

