FROM alpine
LABEL description="otus linux professional subject:Docker"
RUN apk --no-cache update && apk --no-cache add nginx && apk --no-cache add bash
COPY ./templates/nginx.default.conf /etc/nginx/http.d/default.conf
COPY ./templates/index.html /var/lib/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

