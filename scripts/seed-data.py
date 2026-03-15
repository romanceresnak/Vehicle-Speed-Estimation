#!/usr/bin/env python3

"""
Seed demo data into DynamoDB for Traffic Speed Analyzer
This script generates realistic traffic data for demonstration purposes
"""

import boto3
import random
import time
from datetime import datetime, timedelta
from decimal import Decimal

def generate_demo_data(num_records=200):
    """Generate realistic demo traffic data"""

    vehicle_types = ['car', 'truck', 'bus', 'motorcycle']
    locations = ['brno-location-1', 'brno-location-2', 'brno-location-3']
    video_ids = ['session-001.mp4', 'session-002.mp4', 'session-003.mp4']

    records = []
    base_time = int((datetime.now() - timedelta(hours=2)).timestamp() * 1000)

    for i in range(num_records):
        # Distribute across different scenarios
        if i < num_records * 0.7:  # 70% normal traffic
            speed = random.randint(50, 80)
        elif i < num_records * 0.85:  # 15% slower traffic
            speed = random.randint(30, 50)
        else:  # 15% speeding violations
            speed = random.randint(81, 130)

        # Random vehicle type with realistic distribution
        type_rand = random.random()
        if type_rand < 0.65:  # 65% cars
            vehicle_type = 'car'
        elif type_rand < 0.85:  # 20% trucks
            vehicle_type = 'truck'
        elif type_rand < 0.95:  # 10% buses
            vehicle_type = 'bus'
        else:  # 5% motorcycles
            vehicle_type = 'motorcycle'

        record = {
            'videoId': random.choice(video_ids),
            'timestamp': base_time + (i * 1000) + random.randint(0, 500),
            'frameNumber': i * 30 + random.randint(0, 30),
            'vehicleType': vehicle_type,
            'speed': Decimal(str(speed)),
            'confidence': Decimal(str(round(random.uniform(0.75, 0.99), 2))),
            'location': random.choice(locations),
            'boundingBox': {
                'x': random.randint(100, 1700),
                'y': random.randint(100, 900),
                'width': random.randint(80, 250),
                'height': random.randint(60, 180)
            },
            'ttl': int((datetime.now() + timedelta(days=30)).timestamp())
        }

        records.append(record)

    return records

def upload_to_dynamodb(table_name, records):
    """Upload records to DynamoDB table"""

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    print(f"Uploading {len(records)} demo records to {table_name}...")

    # Batch write for efficiency
    with table.batch_writer() as batch:
        for i, record in enumerate(records):
            batch.put_item(Item=record)

            # Progress indicator
            if (i + 1) % 50 == 0:
                print(f"  Uploaded {i + 1}/{len(records)} records...")

    print(f"✓ Successfully uploaded {len(records)} records!")

def main():
    import sys

    if len(sys.argv) < 2:
        print("Usage: python seed-data.py <table-name> [num-records]")
        print("Example: python seed-data.py traffic-speed-analyzer-results-dev 200")
        sys.exit(1)

    table_name = sys.argv[1]
    num_records = int(sys.argv[2]) if len(sys.argv) > 2 else 200

    print("========================================")
    print("Seeding Demo Data to DynamoDB")
    print("========================================")
    print(f"Table: {table_name}")
    print(f"Records: {num_records}")
    print("")

    # Generate data
    print("Generating demo data...")
    records = generate_demo_data(num_records)
    print(f"✓ Generated {len(records)} records")
    print("")

    # Upload to DynamoDB
    try:
        upload_to_dynamodb(table_name, records)
        print("")
        print("✓ Demo data seeded successfully!")
        print("")
        print("Summary:")
        print(f"  - Total vehicles: {len(records)}")

        speeds = [float(r['speed']) for r in records]
        print(f"  - Average speed: {sum(speeds)/len(speeds):.1f} km/h")
        print(f"  - Max speed: {max(speeds):.0f} km/h")
        print(f"  - Violations (>80 km/h): {sum(1 for s in speeds if s > 80)}")

        types = {}
        for r in records:
            types[r['vehicleType']] = types.get(r['vehicleType'], 0) + 1
        print(f"  - Vehicle types: {dict(types)}")

    except Exception as e:
        print(f"Error uploading data: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
