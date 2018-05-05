import boto3
import json
import logging
import os
import sys

from base64 import b64decode
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta
from decimal import *

ENCRYPTED_HOOK_URL = os.environ['kmsEncryptedHookUrl']
SLACK_CHANNEL      = os.environ['slackChannel']
THRESHOLD_DANGER   = Decimal(os.environ['thresholdDanger'])
THRESHOLD_WARNING  = Decimal(os.environ['thresholdWarning'])
COST_TYPE          = os.environ['costType']

HOOK_URL = "https://" + boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED_HOOK_URL))['Plaintext'].decode('utf-8')

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ce = boto3.client('ce')

def lambda_handler(event, context):
    logger.info("Event: %s", str(event))
    
    utc_now = datetime.utcnow()
    start = utc_now.date() - timedelta(days=utc_now.day - 1)
    end   = start + relativedelta(months=1)

    fields = []
    total  = Decimal(0)
    try:
        ce_res = ce.get_cost_and_usage(
            TimePeriod = {
                'Start': str(start),
                'End'  : str(end)
            },
            Granularity = 'MONTHLY',
            Metrics     = ['BlendedCost', 'UnblendedCost'],
            GroupBy     = [{
                'Type': 'DIMENSION',
                'Key' : 'SERVICE'
            }]
        )
        logger.info("CostAndUsage: %s", str(ce_res))

        # It does not correspond to 'NextPageToken'
        rbt = ce_res['ResultsByTime']
        for groups in rbt:
            for group in groups['Groups']:
                fields.append({
                    "title": group["Keys"][0],
                    "value": str(round(Decimal(group["Metrics"][COST_TYPE]["Amount"]), 2)),
                    "short": True
                })
                total += Decimal(group["Metrics"][COST_TYPE]["Amount"])
    except:
        e = sys.exc_info()
        logger.info("ERROR: %s", str(e))

    color = 'good'
    if total > THRESHOLD_DANGER:
        color = 'danger'
    elif total > THRESHOLD_WARNING:
        color = 'warning'
    
    slack_message = {
        'pretext': "Current Service Usage Charge",
        'color'  : color,
        'channel': SLACK_CHANNEL,
        'title'  : "AWS Costs",
        'fields' : fields,
        'text'   : "The total cost of %s is $%s ." % (datetime.strftime(utc_now, '%m %Y'), str(round(total, 2)))
    }

    req = Request(HOOK_URL, json.dumps(slack_message).encode('utf-8'))
    try:
        response = urlopen(req)
        response.read()
        logger.info("Message posted to %s", slack_message['channel'])
    except HTTPError as e:
        logger.error("Request failed: %d %s", e.code, e.reason)
    except URLError as e:
        logger.error("Server connection failed: %s", e.reason)
