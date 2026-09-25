ARG TEST_GO_BASE=golang:1.27.1-alpine3.24@sha256:cf6fca6641884b8433441b2b0652976f975e1d0fdd26d177eaaf8596087f3125
# MinIO no longer publishes public images; DHI builds it (static binary).
ARG MINIO_IMAGE=dhi.io/minio:0.20251015.172955-debian13@sha256:c3ce1454fa880150e3bd63ef5f4716a3cfe018958914cb83d7a1b4db352ef693

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
