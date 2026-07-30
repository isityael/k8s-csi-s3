ARG GO_BASE=dhi.io/golang:1.26.5-alpine3.24-dev@sha256:29fe0a7d2a5ab0c236fbde3a7f63801755585ed260b6f2f564e831c92bfa9f34
ARG RUNTIME_BASE=dhi.io/alpine-base:3.24-dev@sha256:bc485a80d08683238c792a82331064d2cccafeb724d65a7b049a623db834b547

FROM ${GO_BASE} AS gobuild

ARG IMAGE_VERSION=dev
ARG VCS_REF=unknown

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY pkg ./pkg
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -a \
      -ldflags "-s -w -extldflags '-static' -X github.com/isityael/k8s-csi-s3/pkg/driver.vendorVersion=${IMAGE_VERSION}" \
      -o /out/s3driver ./cmd/s3driver

FROM ${GO_BASE} AS geesefs

# renovate: datasource=github-releases packageName=yandex-cloud/geesefs
ARG GEESEFS_VERSION=v0.43.8
ARG GEESEFS_SOURCE_SHA256=66383e8a6162e389037135482e93ebe6d04fb0451f98e081d87b089c94fb7ec0
# renovate: datasource=go packageName=golang.org/x/crypto
ARG GEESEFS_X_CRYPTO_VERSION=v0.54.0
# renovate: datasource=go packageName=golang.org/x/net
ARG GEESEFS_X_NET_VERSION=v0.57.0
# renovate: datasource=go packageName=google.golang.org/grpc
ARG GEESEFS_GRPC_VERSION=v1.83.0
# renovate: datasource=go packageName=golang.org/x/text
ARG GEESEFS_X_TEXT_VERSION=v0.40.0

RUN apk add --no-cache ca-certificates=20260611-r0 curl=8.21.0-r0 && \
    curl --fail --location --silent --show-error \
      "https://github.com/yandex-cloud/geesefs/archive/refs/tags/${GEESEFS_VERSION}.tar.gz" \
      --output /tmp/geesefs.tar.gz && \
    echo "${GEESEFS_SOURCE_SHA256}  /tmp/geesefs.tar.gz" | sha256sum -c - && \
    mkdir /src && \
    tar -xzf /tmp/geesefs.tar.gz -C /src --strip-components=1

WORKDIR /src
RUN go mod edit \
      -require=golang.org/x/crypto@${GEESEFS_X_CRYPTO_VERSION} \
      -require=golang.org/x/net@${GEESEFS_X_NET_VERSION} \
      -require=google.golang.org/grpc@${GEESEFS_GRPC_VERSION} \
      -require=golang.org/x/text@${GEESEFS_X_TEXT_VERSION} && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -mod=mod -trimpath \
      -ldflags "-s -w -X main.Version=${GEESEFS_VERSION}-ym2" \
      -o /out/geesefs .

FROM ${RUNTIME_BASE}

ARG IMAGE_VERSION=dev
ARG VCS_REF=unknown
ARG RCLONE_VERSION=1.74.1-r1
ARG S3FS_FUSE_VERSION=1.97-r0

LABEL org.opencontainers.image.title="k8s-csi-s3" \
      org.opencontainers.image.description="GeeseFS-based CSI driver for mounting S3 buckets as PersistentVolumes" \
      org.opencontainers.image.source="https://github.com/isityael/k8s-csi-s3" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="Apache-2.0"

RUN apk add --no-cache \
      --repository=https://dl-cdn.alpinelinux.org/alpine/v3.24/community \
      ca-certificates=20260611-r0 \
      fuse=2.9.9-r7 \
      mailcap=2.1.54-r0 \
      rclone=${RCLONE_VERSION} \
      s3fs-fuse=${S3FS_FUSE_VERSION}

COPY --from=geesefs /out/geesefs /usr/bin/geesefs
COPY --from=gobuild /out/s3driver /s3driver

ENTRYPOINT ["/s3driver"]
