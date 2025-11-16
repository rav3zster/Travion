# Quick Setup Guide - RAG Feature

## 🚀 Getting Started with AI Route Finder

### Step 1: Get Your Free Gemini API Key

1. Visit: https://makersuite.google.com/app/apikey
2. Sign in with Google account
3. Click "Create API Key"
4. Copy the generated key (starts with `AIza...`)

### Step 2: Configure the App

Open the file: `lib/services/rag_service.dart`

Find this line (around line 11):
```dart
static const String _defaultApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

Replace with your actual key:
```dart
static const String _defaultApiKey = 'AIzaSy...your_actual_key_here';
```

### Step 3: Install Dependencies

Run in terminal:
```bash
flutter pub get
```

### Step 4: Run the App

```bash
flutter run -d emulator-5554
```

## 🎯 How to Use

### Option 1: From Home Screen
1. Open app
2. Tap **"AI Route Finder"** (purple button with ✨ icon)
3. Type your query
4. Tap "Find Routes"

### Option 2: Example Queries

Try these example queries (just tap the chips):
- "Mangalore to NMAMIT"
- "Route to Nitte"
- "Surathkal stops"
- "Udupi buses"

Or ask naturally:
- "How do I get to NMAMIT college?"
- "Bus route from Mangalore to engineering college"
- "Take me to Nitte"
- "Stops near Surathkal"

## 📱 Features You'll Get

✅ **Natural Language Search** - Ask in plain English
✅ **AI-Generated Responses** - Smart, helpful answers
✅ **Route Matching** - See similarity scores
✅ **Bus Stop Details** - Complete list with sequence
✅ **One-Click Load** - Add stops to tracking instantly
✅ **Offline Fallback** - Works without internet (basic mode)

## 💡 Pro Tips

1. **Be Specific**: "Mangalore to Nitte" works better than just "Nitte"
2. **Use Landmarks**: "Bus to NITK" or "Route to engineering college"
3. **Check Match Score**: Green = >50% confidence, good match
4. **Load Stops**: Tap "Load These Stops" to add to your tracking
5. **Expand Cards**: Tap route cards to see full details

## 🔧 Troubleshooting

**Problem**: "API Key Error"
- Solution: Make sure you set a valid Gemini API key

**Problem**: "No routes found"
- Solution: Try different keywords or check pre-loaded routes

**Problem**: App is slow
- Solution: First search takes longer (generating embeddings), then it's fast

**Problem**: Want offline mode?
- Solution: It works! Just has simpler responses without API

## 🆓 Free Tier Limits

Google Gemini Free Tier:
- **15 requests/minute**
- **1,500 requests/day**
- **1 million tokens/month**

This is more than enough for personal use!

## 📚 What's Included

### Pre-loaded Routes:
1. **Mangalore → NMAMIT Nitte** (7 stops)
   - Via Hampankatta, Kottara, Surathkal, Katipalla
   
2. **Mangalore → Udupi** (5 stops)
   - Via Surathkal, Katipalla, Kaup Beach

### Smart Features:
- Semantic search (understands context)
- Keyword matching
- Landmark recognition
- Typo tolerance

## 🎓 Example Interaction

**You**: "How do I reach NMAMIT?"

**AI Response**: 
```
Found route: Mangalore to NMAMIT College Nitte

Main route from Mangalore city to NMAM Institute 
of Technology in Nitte via NH66

Key stops: Mangalore Central → Hampankatta → 
Kottara → Surathkal → Katipalla → Nitte

This route passes through: Hampankatta, NITK 
Surathkal, KMC Hospital.
```

**Result**: 
- 95% match score ✓
- 7 bus stops listed
- Load button to add to tracking

## 🌟 Next Steps

1. Try the AI Route Finder feature
2. Ask different questions
3. Load stops to your tracking
4. Start tracking with bus stop alerts enabled!

---

Need help? Check `RAG_IMPLEMENTATION.md` for technical details.
