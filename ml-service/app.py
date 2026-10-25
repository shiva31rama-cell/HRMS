from collections import Counter
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline

app = FastAPI(
    title="HRMS ML Service",
    description="Maintenance text classification and descriptive data mining for HostelHub.",
    version="1.0.0",
)

# Small hand-labelled examples make the academic demo reproducible. Extend with
# reviewed, de-identified real tickets before making real-world accuracy claims.
TRAINING_ROWS = [
    ("tap leaking water dripping pipe wet bathroom", "Plumbing", "normal"),
    ("toilet flush broken water pipe leaking", "Plumbing", "high"),
    ("washbasin drain blocked water overflowing", "Plumbing", "high"),
    ("no water coming from shower tap", "Plumbing", "normal"),
    ("severe pipe burst flooding room immediately", "Plumbing", "urgent"),
    ("water heater leaking near bathroom", "Plumbing", "high"),
    ("electrical socket sparking burning smell", "Electrical", "urgent"),
    ("fan not working switch broken", "Electrical", "normal"),
    ("lights flickering in room", "Electrical", "low"),
    ("power outage exposed wire danger", "Electrical", "urgent"),
    ("ceiling light stopped working", "Electrical", "normal"),
    ("air conditioner electrical power issue", "Electrical", "high"),
    ("dirty bathroom needs cleaning", "Cleanliness", "normal"),
    ("garbage not collected bad smell corridor", "Cleanliness", "normal"),
    ("pest insects cockroach problem in room", "Cleanliness", "high"),
    ("spilled waste dirty common area", "Cleanliness", "low"),
    ("mold and damp smell in bathroom", "Cleanliness", "high"),
    ("room needs deep cleaning urgently before inspection", "Cleanliness", "high"),
    ("broken bed frame loose screws", "Furniture", "normal"),
    ("cupboard door hinge broken", "Furniture", "low"),
    ("study table chair damaged unusable", "Furniture", "normal"),
    ("window lock broken cannot secure room", "Furniture", "high"),
    ("mattress damaged bed board cracked", "Furniture", "normal"),
    ("door handle came off and door won't close", "Furniture", "high"),
    ("internet wifi connection slow", "Other", "low"),
    ("lost key need help from warden", "Other", "normal"),
    ("urgent safety issue in corridor", "Other", "urgent"),
    ("noise complaint from neighbouring room", "Other", "low"),
    ("water cooler not cooling", "Other", "normal"),
    ("lift stopped between floors people trapped", "Other", "urgent"),
    ("minor dripping tap can wait until tomorrow", "Plumbing", "low"),
    ("socket completely dead no power to desk", "Electrical", "normal"),
    ("overflowing toilet flooding shared bathroom", "Plumbing", "urgent"),
    ("broken chair leg could cause injury", "Furniture", "high"),
    ("trash room overflowing and attracting pests", "Cleanliness", "high"),
    ("small light bulb fused", "Electrical", "low"),
]

texts = [row[0] for row in TRAINING_ROWS]
category_labels = [row[1] for row in TRAINING_ROWS]
priority_labels = [row[2] for row in TRAINING_ROWS]

def make_model(labels: list[str]) -> Pipeline:
    return Pipeline([
        ("tfidf", TfidfVectorizer(lowercase=True, ngram_range=(1, 2), strip_accents="unicode")),
        ("classifier", MultinomialNB(alpha=0.25)),
    ])

category_model = make_model(category_labels).fit(texts, category_labels)
priority_model = make_model(priority_labels).fit(texts, priority_labels)

class PredictionInput(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    description: str = Field(min_length=1, max_length=2000)

class Ticket(BaseModel):
    category: str = "Other"
    priority: str = "normal"
    status: str = "open"
    createdAt: str | None = None
    resolvedAt: str | None = None

def classify(model: Pipeline, text: str) -> tuple[str, float]:
    probabilities = model.predict_proba([text])[0]
    index = int(probabilities.argmax())
    return str(model.classes_[index]), round(float(probabilities[index]), 3)

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "HRMS ML Service", "model": "TF-IDF + Multinomial Naive Bayes"}

@app.post("/predict-maintenance")
def predict_maintenance(payload: PredictionInput) -> dict[str, Any]:
    text = f"{payload.title.strip()} {payload.description.strip()}".strip()
    if len(text) < 4:
        raise HTTPException(status_code=422, detail="Provide a more descriptive maintenance issue.")
    category, category_confidence = classify(category_model, text)
    priority, priority_confidence = classify(priority_model, text)
    return {
        "category": category,
        "priority": priority,
        "categoryConfidence": category_confidence,
        "priorityConfidence": priority_confidence,
        "model": "TF-IDF + Multinomial Naive Bayes",
        "trainingExamples": len(TRAINING_ROWS),
        "disclaimer": "Demo model trained on a small hand-labelled starter dataset. Staff must review suggestions; confidence is not a guarantee of correctness.",
    }

def parse_date(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except (TypeError, ValueError):
        return None

@app.post("/analytics")
def maintenance_analytics(tickets: list[Ticket]) -> dict[str, Any]:
    categories = Counter(ticket.category for ticket in tickets)
    priorities = Counter(ticket.priority for ticket in tickets)
    statuses = Counter(ticket.status for ticket in tickets)
    months: Counter[str] = Counter()
    resolution_hours: list[float] = []

    for ticket in tickets:
        created = parse_date(ticket.createdAt)
        if created:
            months[created.strftime("%Y-%m")] += 1
        resolved = parse_date(ticket.resolvedAt)
        if created and resolved and resolved >= created:
            resolution_hours.append((resolved - created).total_seconds() / 3600)

    return {
        "ticketCount": len(tickets),
        "categoryCounts": dict(categories.most_common()),
        "priorityCounts": dict(priorities.most_common()),
        "statusCounts": dict(statuses.most_common()),
        "monthlyCounts": [{"month": month, "count": count} for month, count in sorted(months.items())],
        "averageResolutionHours": round(sum(resolution_hours) / len(resolution_hours), 2) if resolution_hours else None,
        "resolvedSamples": len(resolution_hours),
        "model": "Descriptive data mining over stored maintenance tickets",
        "dataNote": "Analytics reflect only records supplied by the HRMS API. Small or synthetic demo data is not representative of a real hostel.",
    }
