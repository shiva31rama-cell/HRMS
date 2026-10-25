import unittest
from fastapi.testclient import TestClient
from app import app, TRAINING_ROWS

client = TestClient(app)

class MLServiceTests(unittest.TestCase):
    def test_dataset_has_expected_labels(self):
        self.assertGreaterEqual(len(TRAINING_ROWS), 50)
        self.assertEqual({row[1] for row in TRAINING_ROWS}, {"Plumbing", "Electrical", "Cleanliness", "Furniture", "Other"})
        self.assertEqual({row[2] for row in TRAINING_ROWS}, {"low", "normal", "high", "urgent"})

    def test_health(self):
        response = client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_prediction_shape(self):
        response = client.post("/predict-maintenance", json={
            "title": "Sparking electrical socket",
            "description": "Burning smell and exposed wire, dangerous"
        })
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn(body["category"], ["Plumbing", "Electrical", "Cleanliness", "Furniture", "Other"])
        self.assertIn(body["priority"], ["low", "normal", "high", "urgent"])
        self.assertGreaterEqual(body["categoryConfidence"], 0)
        self.assertLessEqual(body["categoryConfidence"], 1)
        self.assertEqual(body["trainingExamples"], len(TRAINING_ROWS))

    def test_analytics(self):
        response = client.post("/analytics", json=[
            {"category": "Plumbing", "priority": "high", "status": "resolved",
             "createdAt": "2026-01-01T10:00:00Z", "resolvedAt": "2026-01-01T14:00:00Z"},
            {"category": "Electrical", "priority": "urgent", "status": "open",
             "createdAt": "2026-01-02T10:00:00Z"}
        ])
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["ticketCount"], 2)
        self.assertEqual(body["categoryCounts"]["Plumbing"], 1)
        self.assertEqual(body["averageResolutionHours"], 4.0)

if __name__ == "__main__":
    unittest.main()
