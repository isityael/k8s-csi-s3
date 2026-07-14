ARG TEST_GO_BASE=golang:1.26.5-alpine3.24@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2
ARG MINIO_IMAGE=quay.io/minio/minio:RELEASE.2025-04-22T22-12-26Z@sha256:a1ea29fa28355559ef137d71fc570e508a214ec84ff8083e39bc5428980b015e

FROM ${MINIO_IMAGE} AS minio

FROM ${TEST_GO_BASE}

# renovate: datasource=github-releases packageName=yandex-cloud/geesefs
ARG GEESEFS_VERSION=v0.43.8
ARG GEESEFS_SHA256=81dd5a9035669ec4bdecf1f54bf6368ecad66258700e2f99e722770c71e5e7f4

RUN apk add --no-cache fuse=2.9.9-r7 && \
    wget -q \
      "https://github.com/yandex-cloud/geesefs/releases/download/${GEESEFS_VERSION}/geesefs-linux-amd64" \
      -O /usr/bin/geesefs && \
    echo "${GEESEFS_SHA256}  /usr/bin/geesefs" | sha256sum -c - && \
    chmod 0755 /usr/bin/geesefs

COPY --from=minio /usr/bin/minio /usr/local/bin/minio

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

ENTRYPOINT ["/build/test/test.sh"]
