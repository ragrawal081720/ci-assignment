FROM node:20-alpine

WORKDIR /app

# Accept build argument for API URL
ARG VITE_API_BASE_URL=http://localhost:8000/api
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

EXPOSE 5173

# Run in dev mode with host access
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]
