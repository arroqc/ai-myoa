import json
import boto3

bedrock = boto3.client("bedrock-runtime")

MODEL_ID = "meta.llama3-70b-instruct-v1:0"


def lambda_handler(event, context):
    body = json.loads(event.get("body", "{}"))
    prompt = body.get("prompt", "").strip()

    if not prompt:
        return _response(400, {"error": "prompt is required"})

    payload = {
        "prompt": prompt,
        "max_gen_len": 512,
        "temperature": 0.7,
        "top_p": 0.9,
    }

    result = bedrock.invoke_model(
        modelId=MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(payload),
    )

    response_body = json.loads(result["body"].read())
    generated_text = response_body["generation"].strip()

    return _response(200, {"text": generated_text})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
