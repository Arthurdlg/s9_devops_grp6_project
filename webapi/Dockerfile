FROM golang:1.21.5

# Make directory for application
WORKDIR /app

# Download Go modules
COPY go.mod ./
RUN go mod download

# Copy the source code
COPY *.go ./

# Build
RUN go build -o main

EXPOSE 8080

# Run
CMD ["./main"]
