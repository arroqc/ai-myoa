import json
import base64
import boto3
import os
import uuid
from datetime import datetime

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")

IMAGES_BUCKET = os.environ["IMAGES_BUCKET"]
MODEL_ID = "amazon.titan-image-generator-v1"


def lambda_handler(event, context):
    body = json.loads(event.get("body", "{}"))
    prompt = body.get("prompt", "").strip()
    session_id = body.get("session_id", "unknown")

    if not prompt:
        return _response(400, {"error": "prompt is required"})

    payload = {
        "taskType": "TEXT_IMAGE",
        "textToImageParams": {"text": prompt},
        "imageGenerationConfig": {
            "numberOfImages": 1,
            "width": 512,
            "height": 512,
            "quality": "standard",
        },
    }

    result = bedrock.invoke_model(
        modelId=MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(payload),
    )

    response_body = json.loads(result["body"].read())
    image_data = base64.b64decode(response_body["images"][0])

    image_key = f"sessions/{session_id}/{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:8]}.png"
    s3.put_object(
        Bucket=IMAGES_BUCKET,
        Key=image_key,
        Body=image_data,
        ContentType="image/png",
    )

    image_url = f"https://{IMAGES_BUCKET}.s3.amazonaws.com/{image_key}"
    return _response(200, {"image_url": image_url, "s3_key": image_key})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
