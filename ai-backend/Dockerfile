FROM node:20-bookworm-slim

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .

ENV NODE_ENV=production
ENV PORT=8080
ENV REALTIME_ATTACH_HTTP=true
ENV REQUIRE_AUTH=true
EXPOSE 8080

CMD ["node", "server.js"]
