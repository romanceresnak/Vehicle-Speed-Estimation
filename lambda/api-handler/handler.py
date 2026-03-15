import json
import boto3
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
RESULTS_TABLE = os.environ['RESULTS_TABLE']
table = dynamodb.Table(RESULTS_TABLE)

class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert DynamoDB Decimal to float"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    API handler for retrieving traffic analysis results
    
    Query params:
    - videoId: Filter by video ID
    - location: Filter by location
    - limit: Number of results (default 100)
    """
    
    try:
        # CORS headers
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        }
        
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        video_id = params.get('videoId')
        location = params.get('location')
        limit = int(params.get('limit', 100))
        
        # Query DynamoDB
        if video_id:
            # Query by videoId
            response = table.query(
                KeyConditionExpression=Key('videoId').eq(video_id),
                Limit=limit
            )
        elif location:
            # Query by location using GSI
            response = table.query(
                IndexName='LocationIndex',
                KeyConditionExpression=Key('location').eq(location),
                Limit=limit
            )
        else:
            # Scan all results (not recommended for production)
            response = table.scan(Limit=limit)
        
        items = response.get('Items', [])
        
        # Calculate statistics
        stats = calculate_statistics(items)
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'count': len(items),
                'results': items,
                'statistics': stats
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }

def calculate_statistics(items):
    """Calculate traffic statistics from results"""
    
    if not items:
        return {}
    
    speeds = [item['speed'] for item in items]
    
    # Speed statistics
    avg_speed = sum(speeds) / len(speeds)
    max_speed = max(speeds)
    min_speed = min(speeds)
    
    # Speed violations (> 80 km/h)
    violations = sum(1 for speed in speeds if speed > 80)
    violation_rate = (violations / len(speeds)) * 100
    
    # Vehicle type distribution
    vehicle_types = {}
    for item in items:
        vtype = item['vehicleType']
        vehicle_types[vtype] = vehicle_types.get(vtype, 0) + 1
    
    return {
        'totalVehicles': len(items),
        'averageSpeed': round(avg_speed, 2),
        'maxSpeed': round(max_speed, 2),
        'minSpeed': round(min_speed, 2),
        'violations': violations,
        'violationRate': round(violation_rate, 2),
        'vehicleTypes': vehicle_types
    }
