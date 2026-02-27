#!/bin/sh
set -e

echo "Starting SlenderAAC..."

# Wait for database to be ready
echo "Waiting for database connection..."
sleep 3

# Mark the initial canary migration as applied (since base tables already exist)
echo "Marking base migration as applied..."
bunx prisma migrate resolve --applied 000000000000_init_from_canary 2>/dev/null || true

# Run pending migrations
echo "Running database migrations..."
bunx prisma migrate deploy || {
    echo "Migrate deploy failed, trying db push..."
    bunx prisma db push --accept-data-loss
}

echo "Migrations complete, starting application..."

# Execute the main command
exec "$@"
