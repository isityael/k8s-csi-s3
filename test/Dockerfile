ARG TEST_GO_BASE=golang:1.27.2-alpine3.24@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d
# MinIO no longer publishes public images; DHI builds it (static binary).
ARG MINIO_IMAGE=dhi.io/minio:0.20251015.172955-debian13@sha256:2156f0e55fbc8003f95b9563b37e854c7b2c88d498f0f033856df7a5fbf61701

FROM ${MINIO_IMAGE} AS minio

FROM ${TEST_GO_BASE}

# renovate: datasource=github-releases packageName=yandex-cloud/geesefs
ARG GEESEFS_VERSION=v0.43.9
ARG GEESEFS_SHA256=8253f0bad8070f504b3ca94a76919d9617252e7ffae04efca9ca54d5cfbaaca8

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
