# Diagramy pre Článok - Draw.io Špecifikácia

## 1. MAIN ARCHITECTURE DIAGRAM

### Komponenty (zľava doprava, zhora dole):

#### Vrstva 1: Input
- **Traffic Camera Icon** → **S3 Bucket (Videos)**
  - Label: "Upload .mp4"
  - Lifecycle: 30d retention
  - Event trigger ikon

#### Vrstva 2: Processing
- **Lambda Function (Video Processor)**
  - Python 3.11
  - 3008 MB RAM
  - 15 min timeout
  - Trigger: S3 ObjectCreated
  - Mock: Vehicle detection

#### Vrstva 3: Storage
- **DynamoDB Tables** (2 tables)
  - Results Table
    - PK: videoId
    - SK: timestamp
    - GSI: LocationIndex
  - Heatmaps Table
    - PK: location
    - SK: date

- **S3 Bucket (Heatmaps)**
  - Generated images
  - Public read

#### Vrstva 4: API Layer
- **Lambda Function (API Handler)**
  - Python 3.11
  - 512 MB RAM
  - Query DynamoDB

- **API Gateway (REST)**
  - /results endpoint
  - CORS enabled
  - Lambda Proxy integration

#### Vrstva 5: Frontend
- **S3 Bucket (Dashboard)**
  - Static website
  - React build

- **CloudFront Distribution**
  - Global CDN
  - HTTPS only
  - Edge locations

#### Vrstva 6: User
- **React Dashboard**
  - Charts (Recharts)
  - Maps (Leaflet)
  - Neumorphism UI

### Šípky/Connections:
1. Camera → S3 Videos (Upload)
2. S3 Videos → Lambda Video Processor (S3 Event)
3. Lambda Processor → DynamoDB Results (Write)
4. Lambda Processor → S3 Heatmaps (Write)
5. User Browser → CloudFront (HTTPS GET)
6. CloudFront → S3 Dashboard (Origin)
7. Dashboard → API Gateway (GET /results)
8. API Gateway → Lambda API (Invoke)
9. Lambda API → DynamoDB (Query)
10. Lambda API → Dashboard (JSON Response)

### Farby:
- S3: Orange (#FF9900)
- Lambda: Orange (#FF9900)
- DynamoDB: Blue (#4053D6)
- API Gateway: Purple (#A166FF)
- CloudFront: Purple (#8C4FFF)
- User/Browser: Gray

---

## 2. DATA FLOW SEQUENCE DIAGRAM

### Sequence (zhora dole):

**Actors:**
- User
- S3 Videos
- Lambda Video Processor
- DynamoDB
- CloudFront
- React Dashboard
- API Gateway
- Lambda API Handler

**Flow:**
```
1. User → S3 Videos: Upload video.mp4
2. S3 Videos → Lambda Processor: S3 Event trigger
3. Lambda Processor → S3 Videos: Download video
4. Lambda Processor → Lambda Processor: Process video\n(Vehicle detection\nSpeed estimation)
5. Lambda Processor → DynamoDB: Batch write results (200 records)
6. Lambda Processor → S3 Heatmaps: Upload heatmap.png

--- User opens dashboard ---

7. User → CloudFront: GET https://d3ru6yyf5a8cqw.cloudfront.net
8. CloudFront → S3 Dashboard: Fetch index.html + assets
9. S3 Dashboard → CloudFront: Return files
10. CloudFront → User: Render dashboard

--- Dashboard loads data ---

11. Dashboard → API Gateway: GET /results?limit=200
12. API Gateway → Lambda API: Invoke with query params
13. Lambda API → DynamoDB: Query(LocationIndex)
14. DynamoDB → Lambda API: Return 200 items
15. Lambda API → Lambda API: Calculate statistics
16. Lambda API → API Gateway: JSON response
17. API Gateway → Dashboard: Return data
18. Dashboard → Dashboard: Render charts\nAnimate counters
19. Dashboard → User: Display analytics
```

### Farby pre sequence:
- User actions: Green arrows
- AWS internal: Blue arrows
- Data responses: Orange arrows (dotted)

---

## 3. TERRAFORM MODULES STRUCTURE

### Stromová štruktúra:

```
📁 terraform/
├── 📄 main.tf (Root module)
├── 📄 variables.tf
├── 📄 outputs.tf
├── 📄 terraform.tfvars.example
│
├── 📁 modules/
│   ├── 📁 s3/
│   │   ├── 📄 main.tf
│   │   │   ├── aws_s3_bucket.videos
│   │   │   ├── aws_s3_bucket.dashboard
│   │   │   └── aws_s3_bucket.heatmaps
│   │   ├── 📄 variables.tf
│   │   └── 📄 outputs.tf
│   │
│   ├── 📁 dynamodb/
│   │   ├── 📄 main.tf
│   │   │   ├── aws_dynamodb_table.results
│   │   │   └── aws_dynamodb_table.heatmaps
│   │   ├── 📄 variables.tf
│   │   └── 📄 outputs.tf
│   │
│   ├── 📁 lambda/
│   │   ├── 📄 main.tf
│   │   │   ├── aws_iam_role.lambda_role
│   │   │   ├── aws_lambda_function.video_processor
│   │   │   ├── aws_lambda_function.api_handler
│   │   │   └── aws_s3_bucket_notification
│   │   ├── 📄 variables.tf
│   │   └── 📄 outputs.tf
│   │
│   ├── 📁 api-gateway/
│   │   ├── 📄 main.tf
│   │   │   ├── aws_api_gateway_rest_api
│   │   │   ├── aws_api_gateway_resource
│   │   │   └── aws_api_gateway_deployment
│   │   ├── 📄 variables.tf
│   │   └── 📄 outputs.tf
│   │
│   └── 📁 cloudfront/
│       ├── 📄 main.tf
│       │   └── aws_cloudfront_distribution
│       ├── 📄 variables.tf
│       └── 📄 outputs.tf
```

### Module Dependencies (diagram):
```
┌─────────────┐
│   main.tf   │
└──────┬──────┘
       │
       ├─────────────────┬────────────────┬──────────────┬─────────────┐
       │                 │                │              │             │
       ▼                 ▼                ▼              ▼             ▼
   ┌─────┐         ┌──────────┐    ┌──────────┐   ┌────────┐   ┌───────────┐
   │ S3  │────────▶│  Lambda  │───▶│ DynamoDB │   │API GW  │   │CloudFront │
   └─────┘         └──────────┘    └──────────┘   └────────┘   └───────────┘
     │                   │               ▲             │              │
     │                   └───────────────┘             │              │
     └─────────────────────────────────────────────────┘              │
                                                                      │
                                    ┌─────────────────────────────────┘
                                    │
                                    ▼
                              (depends on S3
                               dashboard bucket)
```

---

## 4. DEPLOYMENT FLOW DIAGRAM

### Swimlanes:

**Lane 1: Developer**
```
[Push code to GitHub]
      ↓
[Run deploy-auto.sh]
```

**Lane 2: Build Process**
```
[Build Lambda functions]
- pip install requirements
- Create deployment.zip (1.7KB)
      ↓
[Build React dashboard]
- npm install
- npm run build
- Generate static files
```

**Lane 3: Terraform**
```
[terraform init]
      ↓
[terraform apply]
- Create S3 buckets
- Create DynamoDB tables
- Create Lambda functions
- Create API Gateway
- Create CloudFront
      ↓
[Get outputs]
- API endpoint
- Dashboard URL
- Bucket names
```

**Lane 4: Data Seeding**
```
[Run seed-data.py]
- Generate 200 records
- Batch write to DynamoDB
      ↓
[✓ Demo data ready]
```

**Lane 5: Frontend Deploy**
```
[S3 sync dashboard/build/]
- Upload HTML, CSS, JS
      ↓
[CloudFront invalidate cache]
- Invalidation ID
- Status: InProgress
      ↓
[Wait 2-3 min]
      ↓
[✓ Dashboard live]
```

**Lane 6: Verification**
```
[Open Dashboard URL]
      ↓
[Test API endpoint]
      ↓
[Verify demo data]
      ↓
[✓ Deployment complete]
```

### Timeline:
- Step 1-2: 2-3 min (Build)
- Step 3: 3-5 min (Terraform)
- Step 4: 10 sec (Seed data)
- Step 5: 1-2 min (Frontend)
- Step 6: 2-3 min (CloudFront cache)
**Total: ~7-10 minutes**

---

## 5. COST BREAKDOWN DIAGRAM (Pie Chart alebo Bar Chart)

### Monthly Cost (~10 videos/month):

**Pie Chart Data:**
- S3 Storage: $0.25 (62.5%)
- Lambda Compute: $0.15 (37.5%)
- DynamoDB: $0.00 (Free tier)
- API Gateway: $0.00 (Free tier)
- CloudFront: $0.00 (Free tier)

**Total: $0.40/month**

### Production Scale (100 videos/month):

**Bar Chart:**
```
S3:          ████████ $3.00
Lambda:      ████████████████ $8.00
DynamoDB:    ████ $2.00
API Gateway: ██ $1.00
CloudFront:  $0.00 (Free tier)

Total: $14.00/month
```

---

## 6. DASHBOARD UI COMPONENTS

### Layout Diagram:

```
┌────────────────────────────────────────────────────────┐
│  Header (Neumorphism card)                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Traffic Speed Analyzer                          │  │
│  │  Real-time analytics powered by AWS              │  │
│  │  ● Last updated: 14:32:45                        │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│  Controls (Filters)                                    │
│  [Location ▼] [Video ID] [Filter Button]              │
└────────────────────────────────────────────────────────┘

┌──────────┬──────────┬──────────┬──────────┐
│ Total    │ Avg      │ Max      │ Violations│
│ Vehicles │ Speed    │ Speed    │          │
│  200 ⓘ   │ 66 km/h ⓘ│ 128 km/h│  30 (15%)│
│          │          │          │  ⓘ       │
└──────────┴──────────┴──────────┴──────────┘
     ↑ Animated counters    ↑ Tooltips on hover

┌────────────────────────────────────────────────────────┐
│  Speed Over Time (Line Chart)                         │
│  ┌────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │     📈 Line graph                              │   │
│  │                                                 │   │
│  └────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘

┌──────────────────────────┬──────────────────────────┐
│ Speed Distribution       │ Vehicle Types            │
│ ┌──────────────────────┐ │ ┌──────────────────────┐ │
│ │                      │ │ │                      │ │
│ │   📊 Bar chart      │ │ │   🥧 Pie chart      │ │
│ │                      │ │ │                      │ │
│ └──────────────────────┘ │ └──────────────────────┘ │
└──────────────────────────┴──────────────────────────┘

┌────────────────────────────────────────────────────────┐
│  Traffic Location (Map)                                │
│  ┌────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │     🗺️ Leaflet map with marker                │   │
│  │        (Brno, Czech Republic)                  │   │
│  │                                                 │   │
│  └────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

### Neumorphism Elements:
- **Background:** #f0f0f3 (light gray)
- **Cards:** Box-shadow with light/dark sides
- **Buttons:** Pressed effect on click
- **Inputs:** Inset shadow
- **Typography:** Space Grotesk font

---

## 7. NEUMORPHISM CSS VISUALIZATION

### Card Shadow Diagram:

```
Regular state:
┌─────────────────────────┐
│  ☀️                      │  ← Light shadow
│      Card Content       │     (-8px -8px white)
│                      🌑 │  ← Dark shadow
└─────────────────────────┘     (8px 8px black)

Hover state:
┌─────────────────────────┐
│  ☀️☀️                    │  ← Stronger light
│      Card Content       │     (-12px -12px)
│                    🌑🌑 │  ← Stronger dark
└─────────────────────────┘     (12px 12px)

Button pressed (inset):
┌─────────────────────────┐
│     🌑                  │  ← Inverted shadows
│      Pressed            │     (inset)
│                    ☀️   │
└─────────────────────────┘
```

---

## SCREENSHOT CHECKLIST

Pre článok potrebujete urobiť tieto screenshoty:

### 1. Dashboard Overview
- [ ] Celý dashboard (full page screenshot)
- [ ] Header s real-time indicator
- [ ] Stats cards (všetky 4)

### 2. Interactive Features
- [ ] Tooltip na hover (stat card s info ikon)
- [ ] Animated counter (GIF animácie 0→200)
- [ ] Filter controls

### 3. Charts Detail
- [ ] Speed over time (line chart)
- [ ] Speed distribution (bar chart)
- [ ] Vehicle types (pie chart)
- [ ] Traffic map

### 4. AWS Console
- [ ] Lambda functions list
- [ ] DynamoDB tables
- [ ] S3 buckets
- [ ] API Gateway endpoints
- [ ] CloudFront distribution

### 5. Code Examples
- [ ] Terraform modules štruktúra (VS Code)
- [ ] Lambda handler code
- [ ] React component code

### 6. Terminal Output
- [ ] terraform apply výstup
- [ ] deploy-auto.sh progress
- [ ] Demo data seeding

---

## DRAW.IO TIPS

### Farby AWS ikon:
- **Compute (Lambda):** #FF9900
- **Storage (S3):** #569A31
- **Database (DynamoDB):** #2E73B8
- **Networking (CloudFront):** #8C4FFF
- **Integration (API GW):** #FF4F8B

### Icon Library:
Použite "AWS Architecture Icons" alebo importujte AWS icon set do draw.io

### Layout Tips:
1. **Horizontal flow** pre main architecture
2. **Vertical swimlanes** pre deployment
3. **Tree structure** pre Terraform modules
4. **Sequence** pre data flow

### Export Settings:
- Format: PNG
- DPI: 300 (high quality)
- Background: Transparent alebo white
- Size: Width ~1200px (pre web)

---

Toto je kompletná špecifikácia pre všetky diagramy! Môžete teraz otvoriť draw.io a vytvoriť jednotlivé diagramy podľa týchto špecifikácií.
