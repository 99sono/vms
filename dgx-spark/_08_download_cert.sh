#!/bin/bash
# ==============================================================================
# Shared download-cert implementation — sourced by 08_a_* and 08_b_*.
# Downloads nginx-selfsigned.crt from the Spark node.
# ==============================================================================
REMOTE_DIR="dev/DockerBuildFiles/inference-containers/nginx/nginx-vllm-reverse-proxy-dgx-spark/nginx-proxy/ssl"
REMOTE_FILE="$REMOTE_DIR/nginx-selfsigned.crt"
LOCAL_NAME="${SPARK_HOST}-nginx-selfsigned.crt"

echo "Downloading $SPARK_USER@$SPARK_HOST:$REMOTE_FILE → ./$LOCAL_NAME ..."
scp -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST:$REMOTE_FILE" "./$LOCAL_NAME"

chmod 600 "./$LOCAL_NAME"
echo "Permissions set to 600 on $LOCAL_NAME"
echo ""
echo "To install the certificate system-wide:"
echo "  sudo cp $LOCAL_NAME /usr/local/share/ca-certificates/"
echo "  sudo update-ca-certificates"
