import os
import gzip
from base64 import b64decode
import json
import re

import boto3

DOMAIN = os.environ.get('DOMAIN')
REGION = os.environ.get('REGION')
CLUSTER = os.environ.get('CLUSTER')

if REGION is None or CLUSTER is None or DOMAIN is None:
    raise ValueError("Missing environment variables")


def lambda_handler(event, context):
    """Updates the desired count for a service."""

    event_data = json.loads(gzip.decompress(b64decode(event['awslogs']['data'])).decode())

    services = set()

    domain_escaped = DOMAIN.replace('.', r'\.')
    prog = re.compile(rf'(\S+)\.{domain_escaped}')
    print("pattern: " + prog.pattern)
    for event in event_data['logEvents']:
        print("message: " + event['message'])
        result = prog.search(event['message'])
        if result:
            print(result)
            services.add(result.group(1))

    if not services:
        return

    ecs = boto3.client('ecs', region_name=REGION)
    response = ecs.describe_services(
        cluster=CLUSTER,
        services=[service for service in services],
    )

    for service in response['services']:
        desired = service['desiredCount']

        if desired == 0:
            ecs.update_service(
                cluster=CLUSTER,
                service=service['serviceName'],
                desiredCount=1,
            )
            print(f"Updated {service} desiredCount to 1")
        else:
            print(f"{service} desiredCount already at 1")