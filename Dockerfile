FROM oven/bun:1.3-alpine

# Install gbrain from GitHub (NEVER from npm)
RUN bun install -g github:garrytan/gbrain

# Expose port
EXPOSE 3000

# Startup script handles init + serve
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
