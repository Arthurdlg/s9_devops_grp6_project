FROM golang:1.21.5

# Make directory for application
WORKDIR /webapi

# Download Go modules
COPY webapi/go.mod ./
RUN go mod download

# Copy the source code
COPY webapi/main.go ./

# Build
RUN go build -o main
EXPOSE 8080
# Run
CMD ["./main"]
