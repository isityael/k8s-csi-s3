ARG GO_BASE=dhi.io/golang:1.26.5-alpine3.24-dev@sha256:1afddcf6d8f4069fe80f66637066878228878ba0c09f52c1dd7969d3a7411998
ARG RUNTIME_BASE=dhi.io/alpine-base:3.24-dev@sha256:74230b37711de2e5cbc42b8fbd0bb019417ce99b05e5792390d75cb6c948a560

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

FROM ${RUNTIME_BASE} AS geesefs

# renovate: datasource=github-releases packageName=yandex-cloud/geesefs
ARG GEESEFS_VERSION=v0.43.8
ARG GEESEFS_SHA256=81dd5a9035669ec4bdecf1f54bf6368ecad66258700e2f99e722770c71e5e7f4

RUN apk add --no-cache ca-certificates=20260611-r0 curl=8.21.0-r0 && \
    curl --fail --location --silent --show-error \
      "https://github.com/yandex-cloud/geesefs/releases/download/${GEESEFS_VERSION}/geesefs-linux-amd64" \
      --output /usr/bin/geesefs && \
    echo "${GEESEFS_SHA256}  /usr/bin/geesefs" | sha256sum -c - && \
    chmod 0755 /usr/bin/geesefs

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

COPY --from=geesefs /usr/bin/geesefs /usr/bin/geesefs
COPY --from=gobuild /out/s3driver /s3driver

ENTRYPOINT ["/s3driver"]
