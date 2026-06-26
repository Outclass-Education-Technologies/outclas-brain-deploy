FROM oven/bun:1.3-alpine

# Ensure bun global bin is in PATH
ENV PATH="/root/.bun/bin:$PATH"

# Remote gbrain sources clone GitHub repos server-side.
RUN apk add --no-cache git

# Install gbrain from GitHub (NEVER from npm)
RUN bun install -g github:garrytan/gbrain && gbrain --version

# Expose port
EXPOSE 3000

# Startup script handles init + serve
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
