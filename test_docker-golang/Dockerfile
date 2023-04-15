# первая стадия
FROM golang:1.19-alpine AS build
ARG SECRET
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY *.go ./
EXPOSE 8080
RUN go build -ldflags="-w -s -X 'main.secret=$SECRET'" -o /app/gocalc
RUN [ ". /calculator_test.go" ]

# вторая стадия
FROM alpine:3.10.3
COPY --from=build /app/gocalc /app/gocalc
ARG SECRET
RUN echo $SECRET > /opt/secret
CMD ["/app/gocalc"]