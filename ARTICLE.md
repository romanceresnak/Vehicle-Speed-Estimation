# Serverless AI Traffic Analyzer: Від detekcie vozidiel po real-time dashboard za $0.40/mesiac

Predstavte si systém, ktorý dokáže spracovať video z dopravnej kamery, detekovať vozidlá, odhadnúť ich rýchlosť a zobraziť všetko na modernom dashboarde - a to všetko bez jediného servera. V tomto článku vám ukážem, ako som vytvoril kompletný serverless AI Traffic Speed Analyzer pomocou AWS a Terraformu.

## Motivácia

Keď som hľadal zaujímavý projekt pre demonštráciu AWS serverless architektúry, narazil som na [BrnoCompSpeed dataset](https://github.com/JakubSochor/BrnoCompSpeed) - verejne dostupný dataset pre detekciu vozidiel a estimáciu rýchlosti z dopravných kamier. Perfektná príležitosť spojiť cloud computing s real-world use case.

**Ciele projektu:**
- ✅ Plne serverless architektúra (žiadne EC2, žiadne kontajnery)
- ✅ Infrastructure as Code pomocou Terraformu
- ✅ Automatizované nasadenie jedným príkazom
- ✅ Moderný dashboard s neumorphism dizajnom
- ✅ Minimálne náklady (pod $1/mesiac pre demo)

## Architektúra

Systém je postavený na 6 hlavných AWS službách, ktoré spolu tvoria event-driven pipeline:

### Data Flow

1. **Upload:** Traffic kamery uploadujú MP4 videá do **S3 Videos** bucketu
2. **Processing:** S3 event automaticky triggeruje **Lambda** funkciu
3. **Storage:** Lambda zapisuje výsledky do **DynamoDB** a heatmapy do **S3 Heatmaps**
4. **Distribution:** CloudFront distribuuje heatmapy globálne (CDN)
5. **API Layer:** React aplikácia fetchuje dáta cez **API Gateway** z DynamoDB
6. **Frontend:** Dashboard je distribuovaný cez CloudFront (statické S3 hosting)

### Komponenty

**1. S3 Buckets (3x)**
- `videos` - úložisko pre nahrané MP4 videá (30-day retention)
- `dashboard` - statická React aplikácia (source pre CloudFront)
- `heatmaps` - generované heat mapy (distribuované cez CloudFront)

**2. Lambda Functions (2x)**
- `video-processor` - spracovanie videa, detekcia vozidiel (3008 MB RAM, 15 min timeout)
  - Input: S3 event trigger
  - Output: DynamoDB records + S3 heatmaps
- `api-handler` - REST API pre dashboard (512 MB RAM)
  - Input: API Gateway request
  - Output: JSON response s dátami z DynamoDB

**3. DynamoDB Tables (2x)**
- `results` - detekované vozidlá s rýchlosťou
  - PK: `videoId`, SK: `timestamp`
  - GSI: `LocationIndex` (rýchle query podľa lokality)
  - TTL: automatické mazanie po 30 dňoch
- `heatmaps` - metadata pre heat mapy
  - PK: `location`, SK: `date`

**4. API Gateway**
- REST API s `/results` endpointom
- CORS enabled pre dashboard
- Lambda proxy integration
- Spája React frontend s DynamoDB cez Lambda

**5. CloudFront**
- Global CDN s 2 origin buckety:
  - S3 Dashboard (React aplikácia)
  - S3 Heatmaps (PNG obrázky)
- HTTPS only
- Cache invalidation po deploy

**6. Terraform Modules**
Infraštruktúra je rozdelená do 5 modulov:
```
terraform/modules/
├── s3/           # 3 buckety s lifecycle policies
├── dynamodb/     # 2 tables s GSI a TTL
├── lambda/       # 2 functions s IAM roles a S3 triggers
├── api-gateway/  # REST API s CORS
└── cloudfront/   # CDN distribution s 2 origins
```

## Implementácia

### 1. Lambda Video Processor

Pôvodný zámer bol použiť OpenCV pre skutočnú detekciu vozidiel, ale narazil som na **Lambda deployment limit 70 MB**. OpenCV balík má sám 33 MB, čo spolu s dependencies pretieklo limit.

**Riešenie:** Pre demo účely som odstránil OpenCV a implementoval mock data generation:

```python
# lambda/video-processor/handler.py
import json
import random
from decimal import Decimal
from datetime import datetime

def lambda_handler(event, context):
    # Get video metadata from S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    video_id = key.split('/')[-1]

    # Process video (mock detection for demo)
    results = process_video(f'/tmp/{video_id}', video_id)

    # Batch write to DynamoDB
    table_name = os.environ['RESULTS_TABLE']
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    with table.batch_writer() as batch:
        for result in results:
            batch.put_item(Item=result)

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Processed {len(results)} detections',
            'videoId': video_id
        })
    }

def simulate_vehicle_detection(frame, frame_number):
    """Generate realistic mock vehicle detections"""
    vehicle_types = ['car', 'truck', 'bus', 'motorcycle']

    # 70% normal traffic (50-80 km/h)
    # 15% slow traffic (30-50 km/h)
    # 15% violations (>80 km/h)
    rand = random.random()
    if rand < 0.7:
        speed = random.randint(50, 80)
    elif rand < 0.85:
        speed = random.randint(30, 50)
    else:
        speed = random.randint(81, 130)

    return {
        'vehicleType': random.choice(vehicle_types),
        'speed': Decimal(str(speed)),
        'confidence': Decimal(str(round(random.uniform(0.75, 0.99), 2)))
    }
```

**Terraform konfigurácia:**

```hcl
# terraform/modules/lambda/main.tf
resource "aws_lambda_function" "video_processor" {
  filename      = "${path.module}/../../../lambda/video-processor/deployment.zip"
  function_name = "${var.project_name}-video-processor-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 900
  memory_size   = 3008

  environment {
    variables = {
      RESULTS_TABLE   = var.results_table_name
      HEATMAPS_BUCKET = var.heatmaps_bucket_name
    }
  }
}

# S3 trigger
resource "aws_s3_bucket_notification" "video_upload" {
  bucket = var.videos_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".mp4"
  }
}
```

### 2. DynamoDB Schema

**Results Table:**
```hcl
resource "aws_dynamodb_table" "results" {
  name           = "${var.project_name}-results-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "videoId"
  range_key      = "timestamp"

  attribute {
    name = "videoId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "location"
    type = "S"
  }

  # Global Secondary Index pre query podľa lokality
  global_secondary_index {
    name            = "LocationIndex"
    hash_key        = "location"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # TTL pre automatické mazanie starých záznamov
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
```

**Príklad záznamu:**
```json
{
  "videoId": "session-001.mp4",
  "timestamp": 1710512345000,
  "frameNumber": 150,
  "vehicleType": "car",
  "speed": 78,
  "confidence": 0.92,
  "location": "brno-location-1",
  "ttl": 1713104345
}
```

### 3. API Gateway + Lambda API Handler

```python
# lambda/api-handler/handler.py
def lambda_handler(event, context):
    params = event.get('queryStringParameters', {}) or {}

    # Query DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['RESULTS_TABLE'])

    if params.get('location'):
        # Query using GSI
        response = table.query(
            IndexName='LocationIndex',
            KeyConditionExpression='location = :loc',
            ExpressionAttributeValues={':loc': params['location']},
            Limit=int(params.get('limit', 200))
        )
    else:
        # Scan all
        response = table.scan(Limit=int(params.get('limit', 200)))

    results = response['Items']

    # Calculate statistics
    speeds = [float(r['speed']) for r in results]
    stats = {
        'totalVehicles': len(results),
        'averageSpeed': round(sum(speeds) / len(speeds), 2) if speeds else 0,
        'maxSpeed': max(speeds) if speeds else 0,
        'minSpeed': min(speeds) if speeds else 0,
        'violations': len([s for s in speeds if s > 80]),
        'violationRate': round(len([s for s in speeds if s > 80]) / len(speeds) * 100, 2) if speeds else 0
    }

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'count': len(results),
            'results': results,
            'statistics': stats
        }, cls=DecimalEncoder)
    }
```

### 4. React Dashboard s Neumorphism dizajnom

Pre dashboard som zvolil **neumorphism** dizajn - moderný soft 3D štýl s tieňmi, ktorý vyzerá elegantne a profesionálne.

**Design System:**
```css
:root {
  --bg-primary: #f0f0f3;
  --accent: #0066ff;

  /* Neumorphism shadows */
  --shadow-light: -8px -8px 16px rgba(255, 255, 255, 0.8),
                   8px 8px 16px rgba(0, 0, 0, 0.15);
  --shadow-inset: inset -4px -4px 8px rgba(255, 255, 255, 0.5),
                  inset 4px 4px 8px rgba(0, 0, 0, 0.1);
  --shadow-hover: -12px -12px 20px rgba(255, 255, 255, 0.9),
                  12px 12px 20px rgba(0, 0, 0, 0.2);
}

.stat-card {
  background: var(--bg-primary);
  padding: 2rem;
  border-radius: 1.5rem;
  box-shadow: var(--shadow-light);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.stat-card:hover {
  box-shadow: var(--shadow-hover);
  transform: translateY(-2px);
}
```

**Animated Counter Hook:**
```javascript
function useCountUp(end, duration = 2000) {
  const [count, setCount] = useState(0)

  useEffect(() => {
    if (!end) return
    let startTime
    const animate = (currentTime) => {
      if (!startTime) startTime = currentTime
      const progress = Math.min((currentTime - startTime) / duration, 1)
      setCount(Math.floor(progress * end))
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    requestAnimationFrame(animate)
  }, [end, duration])

  return count
}
```

**StatCard Component s Tooltip:**
```javascript
function StatCard({ label, value, unit, tooltip, isViolation }) {
  const animatedValue = useCountUp(parseFloat(value))

  return (
    <div className={`stat-card ${isViolation ? 'violation' : ''}`}>
      <div className="stat-header">
        <div className="stat-label">{label}</div>
        {tooltip && (
          <div className="tooltip-icon" data-tooltip={tooltip}>?</div>
        )}
      </div>
      <div className="stat-value">
        {animatedValue}{unit && <span className="stat-unit">{unit}</span>}
      </div>
    </div>
  )
}
```

**Features:**
- ✅ Animated counters (0 → konečná hodnota)
- ✅ Tooltips na hover s vysvetleniami
- ✅ Real-time update indicator s pulzujúcou bodkou
- ✅ Space Grotesk font (tech vibe)
- ✅ Minimalistická paleta (čierna/biela/modrá)
- ✅ Responsive dizajn

### 5. Automatizované nasadenie

Celý deployment je automatizovaný jedným skriptom:

```bash
#!/bin/bash
# scripts/deploy-auto.sh

set -e

echo "🚀 Starting automated deployment..."

# Build Lambda functions
echo "📦 Building Lambda functions..."
cd lambda
bash build.sh
cd ..

# Deploy infrastructure
echo "🏗️  Deploying infrastructure with Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

# Get outputs
API_ENDPOINT=$(terraform output -raw api_endpoint)
DASHBOARD_BUCKET=$(terraform output -raw dashboard_bucket_name)
RESULTS_TABLE=$(terraform output -raw results_table_name)
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)

echo "✅ Infrastructure deployed!"
echo "   API Endpoint: $API_ENDPOINT"
echo "   Dashboard Bucket: $DASHBOARD_BUCKET"

# Seed demo data
echo "📊 Seeding demo data..."
cd ..
python3 scripts/seed-data.py "$RESULTS_TABLE" 200
echo "✅ 200 demo records created"

# Build and deploy dashboard
echo "🎨 Building dashboard..."
cd dashboard
npm install --cache /tmp/npm-cache
echo "VITE_API_ENDPOINT=$API_ENDPOINT" > .env
npm run build

echo "📤 Deploying dashboard to S3..."
aws s3 sync build/ s3://$DASHBOARD_BUCKET/ --delete

echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"

echo "✅ Deployment complete!"
echo "🌐 Dashboard will be live at CloudFront URL in 2-3 minutes"
```

**Použitie:**
```bash
bash scripts/deploy-auto.sh
```

Celý deployment trvá **7-10 minút**:
- 2-3 min: Build (Lambda + React)
- 3-5 min: Terraform apply
- 10 sec: Seed data
- 1-2 min: S3 sync
- 2-3 min: CloudFront invalidation

## Demo Data Generation

Pre demonštráciu som vytvoril skript, ktorý generuje realistické dopravné dáta:

```python
# scripts/seed-data.py
def generate_demo_data(num_records=200):
    records = []
    video_ids = ['session-001.mp4', 'session-002.mp4', 'session-003.mp4']
    locations = ['brno-location-1', 'brno-location-2']
    vehicle_types = ['car', 'truck', 'bus', 'motorcycle']

    base_time = int(datetime.now().timestamp() * 1000)

    for i in range(num_records):
        # Speed distribution
        if i < num_records * 0.7:  # 70% normal traffic
            speed = random.randint(50, 80)
        elif i < num_records * 0.85:  # 15% slower
            speed = random.randint(30, 50)
        else:  # 15% violations
            speed = random.randint(81, 130)

        # Vehicle type distribution (based on real traffic)
        rand = random.random()
        if rand < 0.65:
            vehicle_type = 'car'
        elif rand < 0.85:
            vehicle_type = 'truck'
        elif rand < 0.95:
            vehicle_type = 'bus'
        else:
            vehicle_type = 'motorcycle'

        record = {
            'videoId': random.choice(video_ids),
            'timestamp': base_time + (i * 1000),
            'frameNumber': i * 30,
            'vehicleType': vehicle_type,
            'speed': Decimal(str(speed)),
            'confidence': Decimal(str(round(random.uniform(0.75, 0.99), 2))),
            'location': random.choice(locations),
            'ttl': int((datetime.now() + timedelta(days=30)).timestamp())
        }
        records.append(record)

    return records
```

**Distribúcia:**
- 🚗 **Autá:** 65%
- 🚚 **Kamióny:** 20%
- 🚌 **Autobusy:** 10%
- 🏍️ **Motorky:** 5%

**Rýchlosti:**
- ✅ **Normálna doprava (50-80 km/h):** 70%
- 🐌 **Pomalá doprava (30-50 km/h):** 15%
- ⚠️ **Porušenia (>80 km/h):** 15%

## Náklady

### Demo Scale (10 videí/mesiac)

| Služba | Spotreba | Náklady |
|--------|----------|---------|
| **S3 Storage** | 5 GB | $0.12 |
| **S3 Requests** | 10 PUT + 1000 GET | $0.00 |
| **Lambda Compute** | 10 × 30s @ 3008 MB | $0.08 |
| **Lambda Requests** | 10 invocations | $0.00 |
| **DynamoDB** | 200 writes + 10K reads | $0.00 (Free tier) |
| **API Gateway** | 10K requests | $0.00 (Free tier) |
| **CloudFront** | 1 GB transfer | $0.00 (Free tier) |
| **Data Transfer** | 2 GB OUT | $0.18 |
| **TOTAL** | | **$0.38/mesiac** |

### Production Scale (100 videí/mesiac)

| Služba | Náklady |
|--------|---------|
| S3 Storage | $1.15 |
| Lambda Compute | $4.00 |
| Lambda Requests | $0.02 |
| DynamoDB | $2.50 |
| API Gateway | $0.35 |
| CloudFront | $0.85 |
| Data Transfer | $5.40 |
| **TOTAL** | **$14.27/mesiac** |

**Cost Optimization Tips:**
- ✅ S3 Lifecycle policy (30-day retention šetrí storage)
- ✅ DynamoDB TTL (automatické mazanie starých záznamov)
- ✅ Lambda Memory tuning (3008 MB je potrebné len pre OpenCV)
- ✅ CloudFront cache (znižuje Lambda invocations)
- ✅ API Gateway caching (voliteľné pre ešte nižšie náklady)

## Výsledky

Live demo: [Dashboard URL]

**Štatistiky z demo dát (200 záznamov):**
- 🚦 **Celkový počet vozidiel:** 200
- ⚡ **Priemerná rýchlosť:** 66.4 km/h
- 🏎️ **Maximálna rýchlosť:** 128 km/h
- 🐌 **Minimálna rýchlosť:** 32 km/h
- ⚠️ **Porušenia (>80 km/h):** 30 (15%)
- 📊 **Najčastejší typ vozidla:** Auto (65%)

**Dashboard features:**
- 📈 Line chart: Rýchlosť v čase
- 📊 Bar chart: Distribúcia rýchlostí po 10 km/h intervaloch
- 🥧 Pie chart: Rozdelenie typov vozidiel
- 🗺️ Mapa: Leaflet mapa s markerom lokality (Brno)
- 🎯 Real-time stats: 4 animated stat cards s tooltipmi
- 🔍 Filters: Filtrovanie podľa lokality a video ID

## Čo som sa naučil

### 1. Lambda Limits sú reálne
Prvý pokus s OpenCV zlyhal na 70 MB limite. **Learning:** Pre ML workloady v Lambde je lepšie použiť:
- Lambda Container Images (10 GB limit)
- SageMaker Serverless Inference
- Alebo predtrénované modely cez AWS Rekognition/Bedrock

### 2. DynamoDB GSI je game-changer
Bez LocationIndex by som musel scannovať celú tabuľku. GSI umožňuje efektívne query:
```python
# Rýchle query (používa GSI)
table.query(
    IndexName='LocationIndex',
    KeyConditionExpression='location = :loc',
    ExpressionAttributeValues={':loc': 'brno-location-1'}
)

# vs. pomalý scan (skenuje všetky záznamy)
table.scan(
    FilterExpression=Attr('location').eq('brno-location-1')
)
```

### 3. CloudFront cache invalidation je kritická
Po deploy dashboardu používatelia videli starú verziu kvôli cache. **Riešenie:** Automatická invalidation v deploy scripte:
```bash
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"
```

### 4. Neumorphism vyžaduje opatrnosť
Príliš veľké tiene môžu byť overwhelming. **Sweet spot:**
- Light shadow: 8-12px
- Dark shadow: 8-12px
- Border radius: 1-2rem
- Subtle transitions (0.3s)

### 5. Terraform moduly = čistý kód
Rozdelenie do modulov výrazne zlepšilo:
- **Čitateľnosť:** Každý modul má jasné rozhranie
- **Testovateľnosť:** Môžem deployovať len 1 modul
- **Reusability:** S3 modul použijem v iných projektoch
- **Team collaboration:** Iný dev môže pracovať na inom module

## Možné vylepšenia

Pre production-ready systém by som pridal:

**1. Skutočné ML spracovanie**
```python
# Použitie AWS Rekognition
rekognition = boto3.client('rekognition')

response = rekognition.start_label_detection(
    Video={'S3Object': {'Bucket': bucket, 'Name': key}},
    MinConfidence=80,
    NotificationChannel={
        'SNSTopicArn': sns_topic_arn,
        'RoleArn': rekognition_role_arn
    }
)
```

**2. Stream processing s Kinesis**
```hcl
resource "aws_kinesis_stream" "vehicle_detections" {
  name             = "vehicle-detections"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}
```

**3. Real-time notifications cez SNS**
```python
# Pri detekcii porušenia
if speed > 80:
    sns = boto3.client('sns')
    sns.publish(
        TopicArn=os.environ['ALERTS_TOPIC'],
        Subject='Speed Violation Detected',
        Message=f'Vehicle {vehicle_id} exceeded limit: {speed} km/h'
    )
```

**4. Dlhodobé ukladanie do S3 + Athena**
```hcl
resource "aws_glue_catalog_table" "vehicle_detections" {
  database_name = aws_glue_catalog_database.traffic.name
  name          = "detections"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.archive.bucket}/detections/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }
  }
}
```

**5. Monitoring a alarmy**
```hcl
resource "aws_cloudwatch_metric_alarm" "high_violation_rate" {
  alarm_name          = "high-speed-violations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ViolationRate"
  namespace           = "TrafficAnalyzer"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "Alert when violation rate exceeds 20%"

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

**6. Multi-region deployment**
```hcl
# terraform/modules/multi-region/main.tf
provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "europe_deployment" {
  source = "../core"
  providers = {
    aws = aws.eu-west-1
  }
}

module "us_deployment" {
  source = "../core"
  providers = {
    aws = aws.us-east-1
  }
}
```

## Záver

Celý projekt od prvého `terraform init` po live dashboard mi trval asi deň práce. Výsledok? Plne funkčný traffic analyzer, ktorý ma stojí 40 centov mesačne a dokáže automaticky škálovať od 0 do tisícov requestov bez toho, aby som sa musel starať o servery.

Najväčšie prekvapenie? Lambda 70 MB limit, ktorý ma donútil odstániť OpenCV a použiť mock data. V produkčnej verzii by som použil Lambda Container Images (10 GB limit) alebo AWS Rekognition Video.

Terraform moduly sa mi osvedčili - keď som potreboval zmeniť DynamoDB TTL, stačilo upraviť jeden súbor v `modules/dynamodb/` a deploy trval 2 minúty. Deployment automation bol game changer - jeden script, ktorý mi za 10 minút nahodí celú infraštruktúru vrátane demo dát.

Serverless má zmysel hlavne pre event-driven workloady s premenlivým traffikom. Ak máte konzistentne vysoký traffic alebo potrebujete long-running tasks (>15 min), EC2/ECS bude lacnejšie. Pre prototyping a low-traffic projekty je serverless bezkonkurenčný.

---

**Repository:** [https://github.com/romanceresnak/Vehicle-Speed-Estimation](https://github.com/romanceresnak/Vehicle-Speed-Estimation)
**Live Demo:** [CloudFront Dashboard URL]
**Náklady:** $0.38/mesiac (10 videí)

Máte otázky? Napíšte mi na [váš email/kontakt].
