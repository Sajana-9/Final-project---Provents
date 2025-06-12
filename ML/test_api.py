import requests
import json

# Sample test data
test_tasks = [
    {
        "task_id": "T1",
        "completed": True,
        "complexity": 3,
        "deadline": "2025-05-15",
        "dependencies": "T2,T3"
    },
    {
        "task_id": "T2",
        "completed": False,
        "complexity": 2,
        "deadline": "2025-05-20",
        "dependencies": ""
    },
    {
        "task_id": "T3",
        "completed": False,
        "complexity": 4,
        "deadline": "2025-05-10",
        "dependencies": ""
    }
]

# Test local endpoint
response = requests.post(
    'http://localhost:5000/prioritize',
    json={'tasks': test_tasks},
    headers={'Content-Type': 'application/json'}
)

print("Status Code:", response.status_code)
print("Response:")
print(json.dumps(response.json(), indent=2))