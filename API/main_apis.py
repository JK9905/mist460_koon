from fastapi import FastAPI
from record_event import record_event

app = FastAPI()

@app.post("/record_event")
def create_record(mcuMacAddress: str, event_type: str):
    return record_event(mcuMacAddress, event_type)
