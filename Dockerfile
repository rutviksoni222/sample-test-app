FROM nginx:alpine
COPY ./index.html /index.html
COPY . /usr/share/nginx/html

