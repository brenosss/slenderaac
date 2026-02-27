# Build stage
FROM oven/bun:1-debian AS builder

WORKDIR /app

# Build-time environment variables (PUBLIC_* are embedded at build time in SvelteKit)
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

ENV PUBLIC_BASE_URL=$PUBLIC_BASE_URL
ENV PUBLIC_TITLE=$PUBLIC_TITLE
ENV PUBLIC_DISCORD_URL=$PUBLIC_DISCORD_URL
ENV PUBLIC_WHATSAPP_URL=$PUBLIC_WHATSAPP_URL
ENV PUBLIC_INSTAGRAM_URL=$PUBLIC_INSTAGRAM_URL
ENV PUBLIC_WIKI_URL=$PUBLIC_WIKI_URL
ENV PUBLIC_DOWNLOAD_URL=$PUBLIC_DOWNLOAD_URL
ENV PUBLIC_SUPPORT_EMAIL=$PUBLIC_SUPPORT_EMAIL
ENV PUBLIC_ENABLE_PRONOUNS=$PUBLIC_ENABLE_PRONOUNS
ENV PUBLIC_STRIPE_KEY=$PUBLIC_STRIPE_KEY
ENV PUBLIC_TUTORIAL_ENABLED=$PUBLIC_TUTORIAL_ENABLED
ENV PUBLIC_THEME=$PUBLIC_THEME

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
