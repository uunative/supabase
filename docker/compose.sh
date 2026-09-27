#!/bin/sh
# Wrapper for `docker compose` in this directory.
#
# This machine has a JWT_SECRET environment variable persisted at the Windows
# User/Machine level (unrelated to this project - some other tool set it).
# Docker Compose gives real shell/OS environment variables precedence over
# .env file values during ${VAR} interpolation, so every `docker compose`
# command run directly here would silently pick up that unrelated value
# instead of the actual project secret in .env, breaking JWT verification
# across every Supabase service (auth, rest, realtime, etc).
#
# This wrapper overrides just that one variable from .env before invoking
# docker compose, so `sh compose.sh up -d` (etc.) always uses the right secret.
# Verify anytime with: sh compose.sh config | grep JWT_SECRET

set -e
cd "$(dirname "$0")"
JWT_SECRET=$(grep '^JWT_SECRET=' .env | cut -d= -f2-)
export JWT_SECRET
exec docker compose "$@"
