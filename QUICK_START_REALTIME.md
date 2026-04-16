# 🚀 Quick Start Guide - Real-Time ECG Monitoring

## ⚡ 5-Minute Startup

### Step 1: Install Dependencies (2 min)
```bash
cd c:\Users\Dancing\ wolf\Desktop\AP\ecg_flutter_app
flutter pub get
```

### Step 2: Run App (1 min)
```bash
flutter run
```

### Step 3: Start Monitoring (2 min)
1. Wait for "Initializing ECG System..." to complete
2. You'll see the main monitoring screen
3. Click the green **START** button
4. Watch the graph fill with ECG data
5. After ~9 seconds, inference runs automatically
6. Result displays below the graph

---

## 🎯 What You'll See

### Timeline
- **0-50ms**: Graph empty, waiting for data
- **50-9500ms**: Graph fills with ECG waveform (live animation)
- **9500ms**: First inference completes
  - Displays: "NORMAL" (green) or "ARRHYTHMIA" (red)
  - Shows confidence %
  - Adds to history
- **Loop**: Repeats continuously

### Example Output
```
Status: ● Live Monitoring...
Buffer: 100% | Inferences: 12

      [Live Graph Shows ECG Waves]

┌─────────────────────────┐
│      💚 NORMAL          │
│      Confidence: 95.8%  │
└─────────────────────────┘

Recent Predictions:
• NORMAL at 14:32:15
• NORMAL at 14:32:06
• NORMAL at 13:59:54
```

---

## 🎮 Controls

| Button | Action |
|--------|--------|
| **START** | Begin streaming ECG data |
| **STOP** | Pause monitoring |
| **RESET** | Clear all data |
| **🔵 (Bluetooth)** | Info about Bluetooth (demo) |

---

## 📊 Stats Explained

### Total Scans
Number of times the model ran inference

### Buffer Fill %
How full the 187-value buffer is
- 0% = empty
- 100% = ready for inference

### Data Points
Total ECG values loaded from CSV

---

## ⚠️ Arrhythmia Detection

When abnormal heartbeat detected:
1. **Visual Alert**: Popup appears
2. **Waveform**: Graph turns red
3. **History**: "ARRHYTHMIA" shows with confidence

---

## 📱 Access Watch Screen

### In App
```
The watch screen simulates a smartwatch display.
Currently accessible through code navigation.
```

### Manual Navigation (If Available)
- Tap menu or app drawer
- Select "Watch Display"
- See incoming ECG data from main phone

---

## 🔄 Streaming Behavior

- **Speed**: 20 samples/second (50ms apart)
- **Buffer**: 187 values (required by model)
- **Full Cycle Time**: ~9.35 seconds
- **Inference Real-Time**: Happens immediately when buffer fills
- **Continuous**: Loops back to start of data

---

## 🆘 If Graph Doesn't Show

**Problem**: ECG graph appears empty

**Fix** (in this order):
1. Click **START** button
2. Wait 2-3 seconds  
3. Graph should show wavy line
4. If not, restart app and try again

---

## 🆘 If No Inference Runs

**Problem**: Prediction card doesn't appear after 15 seconds

**Fix**:
1. Open phone console: `flutter logs`
2. Look for "Inference complete" message
3. If missing, restart with **RESET** + **START**
4. Watch console output for status

---

## 💡 Key Features to Try

### 1. Watch Buffer Fill in Real-Time
- In Stats section, "Buffer Fill %" increases from 0→100%
- Takes ~9 seconds

### 2. Check Prediction Accuracy
- Look at "Recent Predictions" list
- See if model is predicting correctly
- Note: Model trained on specific ECG patterns

### 3. Monitor Conversion Timing
- Time from buffer full to inference appearance
- Should be < 500ms
- Measures model performance

### 4. View Statistics
- Total Scans: How many inferences
- Data Points: How much ECG data available
- Buffer: Real-time fill status

---

## 🧪 Quick Experiments

### Experiment 1: Pause & Resume
```
1. Click START
2. Wait 5 seconds
3. Click STOP (graph freezes)
4. Click START (graph resumes)
```

### Experiment 2: Multiple Inferences
```
1. Click START
2. Let run for 30 seconds
3. Check Recent Predictions: should see 3-4 entries
```

### Experiment 3: Reset Flow
```
1. Let app run a bit
2. Click RESET
3. All stats return to zero
4. Click START again
```

---

## 📊 Example Session

```
Time: 14:30:00 - User presses START
├─ 14:30:00-14:30:09: Buffer fills (ECG waves appear)
├─ 14:30:09: First inference → "NORMAL (92%)"
├─ 14:30:18: Second inference → "NORMAL (94%)"
├─ 14:30:27: Third inference → "NORMAL (91%)"
│
└─ 14:30:35: User clicks STOP
   All activity pauses until START again
```

---

## ✨ Success Indicators

✅ Graph shows real-time ECG waves
✅ Buffer fills to 100%
✅ Predictions appear with percentages
✅ Different predictions stored in history
✅ No error messages in console
✅ App doesn't freeze during operation

---

## 🎓 What's Happening Behind the Scenes

1. **CSV Loading**: `sample_ecg.csv` loaded with ~5000 ECG values
2. **Normalization**: Values converted to 0-1 range
3. **Streaming**: Every 50ms, one value added to buffer
4. **Buffer Check**: When 187 values collected → ready
5. **Inference**: ML model predicts NORMAL or ARRHYTHMIA
6. **Update UI**: Result shown, added to history
7. **Bluetooth**: Result would send to wearable (if connected)
8. **Repeat**: Buffer clears, process continues

---

## 📱 Mobile-Specific Tips

### Landscape Mode
- Graph expands to fill screen
- Better for detailed ECG viewing

### Dark Mode
- App respects system dark theme
- Eye-friendly at night

### Battery
- Real-time streaming uses CPU
- Consider enabling battery saver if running long sessions

---

## 🔗 Next Steps

After exploring basic functionality:

1. **Read** [REALTIME_SETUP.md](REALTIME_SETUP.md) - Full documentation
2. **Customize** CSV loading for your data
3. **Integrate** with real Bluetooth device
4. **Deploy** to production with proper certificates
5. **Monitor** healthcare metrics like HRV, PR intervals, etc.

---

## 🎯 Common Goals

### "How do I use my own ECG data?"
→ Replace `assets/sample_ecg.csv` with your file
→ Keep format: one numeric value per line

### "How do I connect a real smartwatch?"
→ See Bluetooth Integration section in [REALTIME_SETUP.md](REALTIME_SETUP.md)
→ Configure permissions for Android/iOS

### "Can I change how fast data streams?"
→ Edit `streamInterval` in [lib/services/ecg_streaming_service.dart](lib/services/ecg_streaming_service.dart#L24)
→ Default 50ms = 20 samples/sec

### "How do I save predictions to database?"
→ Add Firebase/REST API calls in `_runInference()`
→ Store label, confidence, timestamp

---

**Ready? Hit START and watch the real-time ECG magic! 💓**

For issues, check [REALTIME_SETUP.md](REALTIME_SETUP.md#troubleshooting) Troubleshooting section.
