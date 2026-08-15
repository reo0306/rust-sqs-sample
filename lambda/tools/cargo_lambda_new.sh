#!/bin/sh

# 新規プロジェクト名を末尾引数から取得
DIR_NAME="$(eval echo \$$#)"

# Cargoプロジェクト作成
cargo lambda new "$@"
cd "${DIR_NAME}" || exit 1
# Makefile.tomlを作成
cat <<'EOF' > Makefile.toml

[config]
skip_core_tasks = true

[tasks.build]
script = "cargo lambda build --arm64 --release --output-format zip"

[tasks.s3push.env]
STAGE = {script = ["echo ${STAGE:?}"]}
BUCKET = "${STAGE}-lambda-deploy-rust"
NAME = {script = ["basename `pwd`"]}

[tasks.s3push]
script = '''
    aws s3api put-object \
    --bucket ${BUCKET} \
    --key ${NAME}/bootstrap.zip \
    --body target/lambda/${NAME}/bootstrap.zip \
    -checksum-algorithm sha256
'''
dependencies = ["build"]

