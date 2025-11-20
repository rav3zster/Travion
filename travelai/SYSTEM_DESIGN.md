# 🏗️ Travion System Design

Complete system architecture diagrams for the TravelAI/Travion project.

---

## 📐 1. Overall System Architecture

### Mermaid Diagram (Renders on GitHub)

```mermaid
graph TB
    subgraph "Mobile App (Flutter)"
        UI[User Interface]
        GPS[GPS Service]
        ML[ML Engine]
        DB[(SQLite DB)]
    end
    
    subgraph "Cloud Services (Google)"
        Gemini[Gemini 1.5 Flash<br/>LLM]
        Embed[text-embedding-004<br/>Vector Embeddings]
    end
    
    subgraph "ML Models"
        TFLite[TensorFlow Lite<br/>stop_classifier.tflite<br/>25.89 KB]
    end
    
    subgraph "External APIs"
        Mappls[Mappls SDK<br/>Indian Maps]
    end
    
    UI -->|Location Updates| GPS
    GPS -->|Raw GPS Data| ML
    ML -->|Inference| TFLite
    ML -->|Store Results| DB
    UI -->|Query Routes| Gemini
    Gemini -->|Generate Embeddings| Embed
    UI -->|Display Map| Mappls
    DB -->|Historical Data| ML
    
    style UI fill:#4CAF50,color:#fff
    style GPS fill:#2196F3,color:#fff
    style ML fill:#FF9800,color:#fff
    style TFLite fill:#9C27B0,color:#fff
    style Gemini fill:#F44336,color:#fff
    style Embed fill:#E91E63,color:#fff
```

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRAVION SYSTEM ARCHITECTURE                  │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐           ┌──────────────────────┐
│   Mobile App Layer   │           │   Cloud Services     │
│     (Flutter)        │◄─────────►│    (Google AI)       │
├──────────────────────┤           ├──────────────────────┤
│                      │           │                      │
│  ┌────────────────┐  │           │  ┌────────────────┐ │
│  │ User Interface │  │           │  │ Gemini 1.5     │ │
│  └────────┬───────┘  │           │  │ Flash (LLM)    │ │
│           │          │           │  └────────────────┘ │
│  ┌────────▼───────┐  │           │                      │
│  │  GPS Service   │  │           │  ┌────────────────┐ │
│  └────────┬───────┘  │           │  │ text-embedding │ │
│           │          │           │  │ -004 (Vector)  │ │
│  ┌────────▼───────┐  │           │  └────────────────┘ │
│  │   ML Engine    │◄─┼───────────┼──────────┐          │
│  └────────┬───────┘  │           │          │          │
│           │          │           └──────────┼──────────┘
│  ┌────────▼───────┐  │                      │
│  │  TFLite Model  │  │           ┌──────────▼──────────┐
│  │  (25.89 KB)    │  │           │   Mappls Maps SDK   │
│  └────────┬───────┘  │           │   (Indian Maps)     │
│           │          │           └─────────────────────┘
│  ┌────────▼───────┐  │
│  │  SQLite DB     │  │
│  │ (Local Store)  │  │
│  └────────────────┘  │
└──────────────────────┘
```

---

## 📱 2. Mobile App Architecture

### Mermaid Diagram

```mermaid
graph LR
    subgraph "Presentation Layer"
        Home[Home Page]
        Map[Map View]
        Track[Track Page]
        Alert[Alert Page]
        Stop[Stop Detection]
        Settings[Settings]
    end
    
    subgraph "Business Logic"
        StopSvc[Stop Detection<br/>Service]
        RAG[RAG Service]
        Route[Route Learning<br/>Service]
        Alert2[Alert Service]
        Location[Location Service]
    end
    
    subgraph "Data Layer"
        StopDB[(Stop Detection<br/>Database)]
        Cache[(Offline Cache)]
        Prefs[(Shared Prefs)]
    end
    
    Home --> StopSvc
    Track --> StopSvc
    Stop --> StopSvc
    Map --> Location
    Alert --> Alert2
    
    StopSvc --> StopDB
    RAG --> Cache
    Route --> StopDB
    Alert2 --> Location
    
    StopSvc --> RAG
    RAG --> Route
    
    style Home fill:#4CAF50,color:#fff
    style StopSvc fill:#FF9800,color:#fff
    style StopDB fill:#2196F3,color:#fff
```

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────┐
│               FLUTTER APP ARCHITECTURE (MVVM)               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────── UI Layer ───────────────────┐
│                                                 │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐      │
│  │ Home │  │ Map  │  │Track │  │Alert │      │
│  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘      │
└─────┼─────────┼─────────┼─────────┼───────────┘
      │         │         │         │
┌─────▼─────────▼─────────▼─────────▼───────────┐
│            Business Logic Layer                │
├────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────┐  ┌─────────────────┐     │
│  │ Stop Detection  │  │   RAG Service   │     │
│  │    Service      │◄─┤  (Route Search) │     │
│  └────────┬────────┘  └────────┬────────┘     │
│           │                    │               │
│  ┌────────▼────────┐  ┌────────▼────────┐     │
│  │ Route Learning  │  │ Alert Service   │     │
│  │    Service      │  │  (Proximity)    │     │
│  └────────┬────────┘  └────────┬────────┘     │
└───────────┼────────────────────┼───────────────┘
            │                    │
┌───────────▼────────────────────▼───────────────┐
│              Data Layer                         │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  SQLite  │  │  Cache   │  │  Shared  │     │
│  │    DB    │  │ (Assets) │  │  Prefs   │     │
│  └──────────┘  └──────────┘  └──────────┘     │
└─────────────────────────────────────────────────┘
```

---

## 🤖 3. ML Pipeline Architecture

### Mermaid Diagram

```mermaid
graph TD
    A[GPS Raw Data] -->|Speed, Location, Time| B[Feature Extraction]
    B -->|8 Features| C{Preprocessing}
    
    C -->|Normalize| D[StandardScaler]
    D --> E[Neural Network<br/>128→64→32→5]
    
    E --> F{Classification}
    F -->|Softmax| G[5 Stop Types]
    
    G --> H[Traffic Signal]
    G --> I[Toll Gate]
    G --> J[Regular Stop]
    G --> K[Gas Station]
    G --> L[Rest Area]
    
    H --> M[User Feedback]
    I --> M
    J --> M
    K --> M
    L --> M
    
    M -->|Learning| N[(SQLite DB)]
    N -->|Historical Data| B
    
    style A fill:#4CAF50,color:#fff
    style E fill:#9C27B0,color:#fff
    style F fill:#FF9800,color:#fff
    style M fill:#2196F3,color:#fff
```

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  ML CLASSIFICATION PIPELINE                 │
└─────────────────────────────────────────────────────────────┘

GPS Data ──────┐
               │
┌──────────────▼──────────────┐
│   Feature Extraction        │
│  • dwell_time               │
│  • speed_before             │
│  • heading                  │
│  • visit_count              │
│  • hour                     │
│  • day_of_week              │
│  • latitude                 │
│  • longitude                │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│   StandardScaler            │
│   (Normalization)           │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│   Neural Network            │
│   ┌─────────────────┐       │
│   │ Input: 8        │       │
│   └────────┬────────┘       │
│   ┌────────▼────────┐       │
│   │ Dense: 128      │       │
│   │ Dropout: 0.3    │       │
│   └────────┬────────┘       │
│   ┌────────▼────────┐       │
│   │ Dense: 64       │       │
│   │ Dropout: 0.2    │       │
│   └────────┬────────┘       │
│   ┌────────▼────────┐       │
│   │ Dense: 32       │       │
│   │ Dropout: 0.2    │       │
│   └────────┬────────┘       │
│   ┌────────▼────────┐       │
│   │ Output: 5       │       │
│   │ Softmax         │       │
│   └─────────────────┘       │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│      Classification         │
│  ┌───────────────────────┐  │
│  │ 0: Traffic Signal     │  │
│  │ 1: Toll Gate          │  │
│  │ 2: Regular Stop       │  │
│  │ 3: Gas Station        │  │
│  │ 4: Rest Area          │  │
│  └───────────────────────┘  │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│     User Feedback           │
│   (Crowdsourced Learning)   │
└──────────────┬──────────────┘
               │
        ┌──────▼──────┐
        │  SQLite DB  │
        │  (Learning) │
        └─────────────┘
```

---

## 🔍 4. RAG System Architecture

### Mermaid Diagram

```mermaid
graph LR
    A[User Query:<br/>"Mangalore to Karkala"] --> B[Gemini<br/>text-embedding-004]
    B --> C[384D Vector]
    
    D[(Knowledge Base<br/>Route Entries)] --> E[Pre-computed<br/>Embeddings]
    E --> F[Vector Store]
    
    C --> G{Similarity Search}
    F --> G
    
    G -->|Cosine Similarity<br/>70% weight| H[Top Matches]
    
    A -->|Keywords| I[Keyword Match<br/>30% weight]
    D --> I
    
    H --> J[Combined Score]
    I --> J
    
    J --> K[Best Route]
    K --> L[Gemini 1.5 Flash<br/>Response Generation]
    L --> M[Natural Language<br/>Answer]
    
    style A fill:#4CAF50,color:#fff
    style B fill:#E91E63,color:#fff
    style G fill:#FF9800,color:#fff
    style L fill:#F44336,color:#fff
```

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              RAG (RETRIEVAL-AUGMENTED GENERATION)           │
└─────────────────────────────────────────────────────────────┘

User Query: "Mangalore to Karkala bus"
        │
        ▼
┌───────────────────┐
│ Query Processing  │
└────────┬──────────┘
         │
    ┌────┴─────┐
    │          │
    ▼          ▼
┌─────────┐  ┌──────────────┐
│Embedding│  │Keyword       │
│ (70%)   │  │Extraction    │
└────┬────┘  │(30%)         │
     │       └──────┬───────┘
     │              │
     ▼              ▼
┌─────────────────────────────┐
│   Vector Similarity Search  │
│                             │
│  ┌───────────────────────┐  │
│  │ Knowledge Base        │  │
│  │ ┌─────────────────┐   │  │
│  │ │ Route 1: EMB    │   │  │
│  │ │ Route 2: EMB    │   │  │
│  │ │ Route 3: EMB    │   │  │
│  │ │    ...          │   │  │
│  │ └─────────────────┘   │  │
│  └───────────────────────┘  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────┐
│  Combined Scoring   │
│  • Cosine: 70%      │
│  • Keyword: 30%     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Top 3 Matches     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Gemini 1.5 Flash   │
│  (Answer Generator) │
└──────────┬──────────┘
           │
           ▼
    Natural Language
       Response
```

---

## 🚦 5. Stop Detection Flow

### Mermaid Diagram

```mermaid
sequenceDiagram
    participant User
    participant GPS
    participant Service as Stop Detection Service
    participant ML as TFLite Model
    participant DB as SQLite
    participant UI
    
    User->>GPS: Start Tracking
    GPS->>Service: Location Update
    Service->>Service: Check Speed
    
    alt Speed < 0.5 m/s
        Service->>Service: Start Dwell Timer
        Service->>Service: Wait 10-60s
        Service->>Service: Bus Moves Again
        Service->>ML: Classify Stop
        ML-->>Service: Prediction (5 types)
        Service->>UI: Show Classification Dialog
        UI->>User: "Was this a bus stop?"
        User-->>UI: Feedback
        UI->>Service: User Choice
        Service->>DB: Store with Confidence
        DB-->>Service: Learning Complete
    else Speed >= 0.5 m/s
        Service->>GPS: Continue Monitoring
    end
```

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              STOP DETECTION WORKFLOW                        │
└─────────────────────────────────────────────────────────────┘

    USER STARTS TRACKING
            │
            ▼
    ┌───────────────┐
    │  GPS Service  │
    │  (5m filter)  │
    └───────┬───────┘
            │ Location Update
            ▼
    ┌───────────────────┐
    │  Check Speed      │
    │  Threshold:       │
    │  < 0.5 m/s        │
    └─────────┬─────────┘
              │
        ┌─────┴─────┐
        │           │
    MOVING      STOPPED
        │           │
        │           ▼
        │   ┌───────────────┐
        │   │ Start Dwell   │
        │   │    Timer      │
        │   └───────┬───────┘
        │           │
        │           ▼
        │   ┌───────────────┐
        │   │ Wait 10-60s   │
        │   │ (Min/Max)     │
        │   └───────┬───────┘
        │           │
        │           ▼
        │   ┌───────────────┐
        │   │ Bus Moves?    │
        │   └───────┬───────┘
        │           │ YES
        │           ▼
        │   ┌─────────────────────┐
        │   │  Extract Features   │
        │   │  • dwell_time       │
        │   │  • speed_before     │
        │   │  • location         │
        │   │  • time_of_day      │
        │   └──────────┬──────────┘
        │              │
        │              ▼
        │   ┌─────────────────────┐
        │   │  TFLite Inference   │
        │   │  Neural Network     │
        │   └──────────┬──────────┘
        │              │
        │              ▼
        │   ┌─────────────────────┐
        │   │  Classification     │
        │   │  ┌───────────────┐  │
        │   │  │Traffic Signal │  │
        │   │  │Toll Gate      │  │
        │   │  │Regular Stop   │  │
        │   │  │Gas Station    │  │
        │   │  │Rest Area      │  │
        │   │  └───────────────┘  │
        │   └──────────┬──────────┘
        │              │
        │              ▼
        │   ┌─────────────────────┐
        │   │  Show Dialog to     │
        │   │  User for Feedback  │
        │   └──────────┬──────────┘
        │              │
        │              ▼
        │      ┌──────────────┐
        │      │ User Confirms│
        │      │  Stop Type   │
        │      └──────┬───────┘
        │             │
        │             ▼
        │   ┌──────────────────┐
        │   │  Update SQLite   │
        │   │  • Confidence++  │
        │   │  • Learn Pattern │
        │   └──────────────────┘
        │
        └──► Continue Monitoring
```

---

## 🌐 6. Data Flow Diagram

### Mermaid Diagram

```mermaid
graph TD
    A[User Input] --> B{Action Type}
    
    B -->|Search Route| C[RAG Pipeline]
    B -->|Track Trip| D[GPS Tracking]
    B -->|View History| E[Database Query]
    
    C --> F[Gemini Embeddings]
    F --> G[Vector Search]
    G --> H[Gemini LLM]
    H --> I[Route Result]
    
    D --> J[Location Stream]
    J --> K[Stop Detection]
    K --> L[ML Classification]
    L --> M[User Feedback]
    M --> N[(SQLite Storage)]
    
    E --> N
    N --> O[History Display]
    
    I --> P[Display to User]
    O --> P
    
    style A fill:#4CAF50,color:#fff
    style C fill:#E91E63,color:#fff
    style D fill:#2196F3,color:#fff
    style L fill:#9C27B0,color:#fff
```

---

## 🔧 7. Technology Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    TECHNOLOGY STACK                         │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Frontend       │  │   Backend        │  │   ML/AI          │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ • Flutter 3.x    │  │ • Dart           │  │ • TensorFlow     │
│ • Material UI    │  │ • SQLite         │  │ • TFLite         │
│ • Mappls SDK     │  │ • SharedPrefs    │  │ • Scikit-learn   │
│                  │  │                  │  │ • Pandas/NumPy   │
└──────────────────┘  └──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Cloud Services │  │   Sensors        │  │   Dev Tools      │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ • Gemini 1.5     │  │ • GPS            │  │ • VS Code        │
│ • text-embed-004 │  │ • Accelerometer  │  │ • Git/GitHub     │
│ • Google AI SDK  │  │ • Gyroscope      │  │ • Flutter DevTools│
│                  │  │                  │  │ • Python         │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## 🎨 8. PlantUML Code (use plantuml.com)

```plantuml
@startuml Travion System Architecture

!define RECTANGLE class

skinparam backgroundColor #FEFEFE
skinparam componentStyle rectangle

package "Mobile App (Flutter)" {
    [User Interface] as UI
    [GPS Service] as GPS
    [ML Engine] as ML
    [Stop Detection] as Stop
    [RAG Service] as RAG
    database "SQLite DB" as DB
}

package "Cloud Services" {
    [Gemini 1.5 Flash] as Gemini
    [text-embedding-004] as Embed
    [Mappls Maps SDK] as Maps
}

package "ML Models" {
    [TensorFlow Lite\n25.89 KB] as TFLite
}

UI --> GPS : Location Updates
GPS --> ML : Raw GPS Data
ML --> TFLite : Inference
ML --> Stop : Classify
Stop --> DB : Store Results
UI --> RAG : Query Routes
RAG --> Gemini : Generate Answer
RAG --> Embed : Create Embeddings
UI --> Maps : Display Map
DB --> ML : Historical Data

@enduml
```

```plantuml
@startuml ML Pipeline

!theme plain

actor User
participant "GPS" as GPS
participant "Feature\nExtraction" as FE
participant "Standard\nScaler" as Scale
participant "Neural\nNetwork" as NN
participant "Classification" as Class
participant "User\nFeedback" as FB
database "SQLite" as DB

User -> GPS: Start Tracking
GPS -> FE: Raw GPS Data
FE -> Scale: 8 Features
Scale -> NN: Normalized Data
NN -> Class: Predictions
Class -> FB: 5 Stop Types
FB -> User: Show Dialog
User -> FB: Confirm Type
FB -> DB: Store Learning
DB -> FE: Historical Data

@enduml
```

---

## 🌍 9. Online Diagram Tools

### **Draw.io / diagrams.net** (FREE)
- URL: https://app.diagrams.net/
- Import this XML:

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Travion">
    <mxGraphModel>
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <mxCell id="2" value="Flutter App" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#4CAF50;strokeColor=#2E7D32;fontColor=#FFFFFF;" vertex="1" parent="1">
          <mxGeometry x="40" y="40" width="120" height="60" as="geometry"/>
        </mxCell>
        <mxCell id="3" value="GPS Service" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#2196F3;strokeColor=#1565C0;fontColor=#FFFFFF;" vertex="1" parent="1">
          <mxGeometry x="40" y="140" width="120" height="60" as="geometry"/>
        </mxCell>
        <mxCell id="4" value="ML Engine" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FF9800;strokeColor=#E65100;fontColor=#FFFFFF;" vertex="1" parent="1">
          <mxGeometry x="40" y="240" width="120" height="60" as="geometry"/>
        </mxCell>
        <mxCell id="5" value="Gemini AI" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F44336;strokeColor=#C62828;fontColor=#FFFFFF;" vertex="1" parent="1">
          <mxGeometry x="240" y="140" width="120" height="60" as="geometry"/>
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### **Excalidraw** (FREE)
- URL: https://excalidraw.com/
- Hand-drawn style diagrams
- Export as PNG/SVG

### **Lucidchart** (FREE tier)
- URL: https://www.lucidchart.com/
- Professional diagrams
- Up to 3 docs free

### **Mermaid Live Editor** (FREE)
- URL: https://mermaid.live/
- Paste the Mermaid code from above
- Export as PNG/SVG

---

## 📊 Quick Reference

| Diagram Type | Best For | Tool |
|--------------|----------|------|
| **Mermaid** | GitHub READMEs | Built-in GitHub |
| **PlantUML** | Technical docs | plantuml.com |
| **ASCII** | Simple text docs | Any editor |
| **Draw.io** | Professional presentations | diagrams.net |
| **Excalidraw** | Quick sketches | excalidraw.com |

---

## 🚀 How to Use

### **1. GitHub (Mermaid)**
Just paste the Mermaid code blocks into your `README.md` - GitHub renders them automatically!

### **2. PlantUML Online**
1. Go to http://www.plantuml.com/plantuml/uml/
2. Paste the PlantUML code
3. Download as PNG/SVG

### **3. Draw.io**
1. Go to https://app.diagrams.net/
2. File → Import from → Paste the XML
3. Edit and export

### **4. VS Code Extension**
Install "Markdown Preview Mermaid Support" to preview Mermaid diagrams locally.

---

## 📁 Files Generated

All diagrams are embedded in this file. You can:
- ✅ Copy Mermaid code to GitHub
- ✅ Copy PlantUML to plantuml.com
- ✅ View ASCII diagrams anywhere
- ✅ Use Draw.io XML for editing

---

**Generated for Travion Project - TravelAI Bus Stop Detection System** 🚌
