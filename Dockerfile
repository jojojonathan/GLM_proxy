# glmproxy — zero-dependency ESM, no npm install needed
FROM node:22-alpine

WORKDIR /app

COPY package.json main.js openai.js anthropic.js ./
COPY lib ./lib
COPY bin ./bin

# OpenAI-compatible endpoint (openai.js). Override PORT via docker run -e.
EXPOSE 18791

CMD ["node", "openai.js"]
