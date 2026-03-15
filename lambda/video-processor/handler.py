import json
import boto3
import os
# import cv2  # Not needed for demo - using mock data
# import numpy as np  # Not needed for demo
from datetime import datetime
from urllib.parse import unquote_plus
import tempfile
import random

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

RESULTS_TABLE = os.environ['RESULTS_TABLE']
HEATMAP_BUCKET = os.environ['HEATMAP_BUCKET']

table = dynamodb.Table(RESULTS_TABLE)

def lambda_handler(event, context):
    """
    Process uploaded video from S3:
    1. Download video
    2. Extract frames
    3. Detect vehicles (simplified YOLO simulation)
    4. Estimate speed
    5. Store results in DynamoDB
    """
    
    try:
        # Get S3 event details
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = unquote_plus(event['Records'][0]['s3']['object']['key'])
        
        print(f"Processing video: {bucket}/{key}")
        
        # Download video to tmp
        tmp_video_path = f"/tmp/{os.path.basename(key)}"
        s3_client.download_file(bucket, key, tmp_video_path)
        
        # Process video
        results = process_video(tmp_video_path, key)
        
        # Store results in DynamoDB
        for result in results:
            table.put_item(Item=result)
        
        print(f"Processed {len(results)} vehicle detections")
        
        # Cleanup
        os.remove(tmp_video_path)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed video: {key}',
                'detections': len(results)
            })
        }
        
    except Exception as e:
        print(f"Error processing video: {str(e)}")
        raise e

def process_video(video_path, video_id):
    """
    Process video and detect vehicles with speed estimation

    NOTE: This is a DEMO version that generates mock data without actually processing video.
    In production, you would use:
    - YOLOv8 for vehicle detection
    - DeepSORT for tracking
    - Camera calibration for accurate speed estimation
    - OpenCV for video processing
    """

    # For demo: Generate mock results without actually processing video
    # Simulating ~50 detections per "video"
    num_detections = random.randint(40, 60)
    results = []

    print(f"Generating {num_detections} mock detections for demo purposes")

    for i in range(num_detections):
        frame_number = i * 30  # Simulate frame numbers

        # Simulate vehicle detection (in production, use YOLO on actual frames)
        detections = simulate_vehicle_detection(None, frame_number)

        # Add to results
        for detection in detections:
            timestamp = int(datetime.now().timestamp() * 1000)

            result = {
                'videoId': video_id,
                'timestamp': timestamp + frame_number,  # Unique timestamp
                'frameNumber': frame_number,
                'vehicleType': detection['type'],
                'speed': detection['speed'],
                'confidence': detection['confidence'],
                'location': 'brno-location-1',  # From dataset
                'boundingBox': detection['bbox'],
                'ttl': int(datetime.now().timestamp()) + (30 * 24 * 60 * 60)  # 30 days TTL
            }

            results.append(result)

    return results

def simulate_vehicle_detection(frame, frame_number):
    """
    Simulate vehicle detection and speed estimation

    In production, this would use:
    - YOLOv8 for detection
    - Object tracking (DeepSORT/ByteTrack)
    - Camera calibration for accurate speed calculation
    """

    # Simulate 0-3 vehicles per frame
    num_vehicles = random.randint(0, 4)

    detections = []
    vehicle_types = ['car', 'truck', 'bus', 'motorcycle']

    for i in range(num_vehicles):
        # Simulate detection
        detection = {
            'type': random.choice(vehicle_types),
            'speed': float(random.randint(30, 120)),  # km/h
            'confidence': round(random.uniform(0.7, 0.99), 2),
            'bbox': {
                'x': random.randint(0, 1920),
                'y': random.randint(0, 1080),
                'width': random.randint(50, 200),
                'height': random.randint(50, 150)
            }
        }

        detections.append(detection)

    return detections
