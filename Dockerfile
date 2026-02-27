# Build stage
FROM oven/bun:1-debian AS builder

WORKDIR /app

# Build-time environment variables (embedded at build time in SvelteKit)
# PUBLIC vars
ARG PUBLIC_BASE_URL="http://localhost:5173"
ARG PUBLIC_TITLE="OTServBR-Global"
ARG PUBLIC_DISCORD_URL=""
ARG PUBLIC_WHATSAPP_URL=""
ARG PUBLIC_INSTAGRAM_URL=""
ARG PUBLIC_WIKI_URL=""
ARG PUBLIC_DOWNLOAD_URL="https://github.com/dudantas/tibia-client/releases"
ARG PUBLIC_SUPPORT_EMAIL=""
ARG PUBLIC_ENABLE_PRONOUNS="false"
ARG PUBLIC_STRIPE_KEY=""
ARG PUBLIC_TUTORIAL_ENABLED="false"
ARG PUBLIC_THEME="legbone"

# Private vars (also needed at build time for static imports)
ARG SERVER_ADDRESS="127.0.0.1"
ARG SERVER_PORT="7172"
ARG SERVER_NAME="OTServBR-Global"
ARG SERVER_LOCATION="BRA"
ARG PVP_TYPE="no-pvp"
ARG GAME_SESSION_EXPIRATION_TIME="24h"
ARG FREE_PREMIUM="true"
ARG ENABLE_STRIPE_CUSTOM="false"
ARG ENABLE_STRIPE_CHECKOUT="false"
ARG SECRET_STRIPE_KEY=""
ARG STRIPE_WEBHOOK_SECRET=""
ARG REQUIRE_EMAIL_CONFIRMATION_TO_LOGIN="false"
ARG ALLOW_LEGACY_SHA1_PASSWORDS="true"
ARG DEPRECATED_USE_SHA1_PASSWORDS="false"
ARG AUTO_ADMIN_EMAIL=""
ARG SERVER_SAVE_TIME="06:00:00"
ARG NO_REPLY_EMAIL=""
ARG SMTP_SERVER=""
ARG SMTP_PORT="587"
ARG SMTP_USER=""
ARG SMTP_PASSWORD=""
ARG EMAIL_BACKGROUND_COLOR="#eee6d9"
ARG EMAIL_BUTTON_COLOR="#0010cd"
ARG EMAIL_BUTTON_TEXT="#f4ca41"

# Set all as ENV
ENV PUBLIC_BASE_URL=$PUBLIC_BASE_URL \
    PUBLIC_TITLE=$PUBLIC_TITLE \
    PUBLIC_DISCORD_URL=$PUBLIC_DISCORD_URL \
    PUBLIC_WHATSAPP_URL=$PUBLIC_WHATSAPP_URL \
    PUBLIC_INSTAGRAM_URL=$PUBLIC_INSTAGRAM_URL \
    PUBLIC_WIKI_URL=$PUBLIC_WIKI_URL \
    PUBLIC_DOWNLOAD_URL=$PUBLIC_DOWNLOAD_URL \
    PUBLIC_SUPPORT_EMAIL=$PUBLIC_SUPPORT_EMAIL \
    PUBLIC_ENABLE_PRONOUNS=$PUBLIC_ENABLE_PRONOUNS \
    PUBLIC_STRIPE_KEY=$PUBLIC_STRIPE_KEY \
    PUBLIC_TUTORIAL_ENABLED=$PUBLIC_TUTORIAL_ENABLED \
    PUBLIC_THEME=$PUBLIC_THEME \
    SERVER_ADDRESS=$SERVER_ADDRESS \
    SERVER_PORT=$SERVER_PORT \
    SERVER_NAME=$SERVER_NAME \
    SERVER_LOCATION=$SERVER_LOCATION \
    PVP_TYPE=$PVP_TYPE \
    GAME_SESSION_EXPIRATION_TIME=$GAME_SESSION_EXPIRATION_TIME \
    FREE_PREMIUM=$FREE_PREMIUM \
    ENABLE_STRIPE_CUSTOM=$ENABLE_STRIPE_CUSTOM \
    ENABLE_STRIPE_CHECKOUT=$ENABLE_STRIPE_CHECKOUT \
    SECRET_STRIPE_KEY=$SECRET_STRIPE_KEY \
    STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET \
    REQUIRE_EMAIL_CONFIRMATION_TO_LOGIN=$REQUIRE_EMAIL_CONFIRMATION_TO_LOGIN \
    ALLOW_LEGACY_SHA1_PASSWORDS=$ALLOW_LEGACY_SHA1_PASSWORDS \
    DEPRECATED_USE_SHA1_PASSWORDS=$DEPRECATED_USE_SHA1_PASSWORDS \
    AUTO_ADMIN_EMAIL=$AUTO_ADMIN_EMAIL \
    SERVER_SAVE_TIME=$SERVER_SAVE_TIME \
    NO_REPLY_EMAIL=$NO_REPLY_EMAIL \
    SMTP_SERVER=$SMTP_SERVER \
    SMTP_PORT=$SMTP_PORT \
    SMTP_USER=$SMTP_USER \
    SMTP_PASSWORD=$SMTP_PASSWORD \
    EMAIL_BACKGROUND_COLOR=$EMAIL_BACKGROUND_COLOR \
    EMAIL_BUTTON_COLOR=$EMAIL_BUTTON_COLOR \
    EMAIL_BUTTON_TEXT=$EMAIL_BUTTON_TEXT

# Install dependencies for native modules (bcrypt, canvas)
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package.json bun.lock ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy prisma schema and generate client
COPY prisma ./prisma
RUN bunx prisma generate

# Copy source code
COPY . .

# Build the application
RUN bun run build

# Production stage
FROM oven/bun:1-debian AS runner

WORKDIR /app

# Install runtime dependencies for native modules
RUN apt-get update && apt-get install -y \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libjpeg62-turbo \
    libgif7 \
    librsvg2-2 \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy package.json for runtime
COPY package.json ./

# Copy node_modules from builder (includes compiled native modules)
COPY --from=builder /app/node_modules ./node_modules

# Copy prisma schema
COPY prisma ./prisma

# Copy built application from builder
COPY --from=builder /app/build ./build

# Copy entrypoint script
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

# Set environment variables
ENV NODE_ENV=production
ENV PORT=5173

EXPOSE 5173

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bun", "run", "build/index.js"]
