FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN yarn

COPY tsconfig*.json ./
COPY src ./src

RUN yarn build


FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN yarn install --production

COPY --from=builder /app/dist ./dist

ENV NODE_ENV=production
ENV LOGSTASH_URL=http://logstash:5044/logs

EXPOSE 3000

CMD [ "node", "dist/main.js" ]