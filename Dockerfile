FROM node:lts-alpine as base

ENV TZ Europe/Rome
RUN apk update && \
    apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    apk del tzdata

WORKDIR /app

RUN npm i -g @angular/cli
ENV PATH /app/node_modules/.bin:$PATH
COPY package*.json ./
RUN npm config list
RUN npm ci && \
    npm cache clean --force

FROM base as dev
EXPOSE 4200
CMD ["ng", "serve", "--host", "0.0.0.0" ]

FROM base as build
COPY . .
RUN ng build

FROM build as test
ENV NODE_ENV=testing
RUN eslint --ext .js,.vue --ignore-path .gitignore --fix src && prettier . --write

FROM build AS audit
USER root
RUN npm audit --audit-level critical
COPY --from=aquasec/trivy:latest /usr/local/bin/trivy /usr/local/bin/trivy
RUN trivy filesystem --no-progress /

FROM nginx:stable-alpine as production
ENV NODE_ENV=production
COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=build /etc/localtime /etc/localtime
COPY --from=build /etc/timezone /etc/timezone
COPY nginx.default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=5s --timeout=5s --retries=3 \
    CMD wget http://localhost/ -qO - > /dev/null 2>&1

CMD ["nginx", "-g", "daemon off;"]