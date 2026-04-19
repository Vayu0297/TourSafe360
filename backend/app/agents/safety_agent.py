from langgraph.graph import StateGraph, END
from langchain_ollama import OllamaLLM
from typing import TypedDict, Optional
from app.core.config import settings
import json

class SafetyState(TypedDict):
    alert_type: str
    message: str
    latitude: float
    longitude: float
    tourist_name: str
    blood_group: str
    emergency_contact: str
    severity: Optional[str]
    triage_result: Optional[str]
    dispatch_action: Optional[str]
    nearest_police: Optional[str]
    final_response: Optional[str]

llm = OllamaLLM(model=settings.SAFETY_MODEL,
                 base_url=settings.OLLAMA_BASE_URL, temperature=0.1)

def triage_node(state: SafetyState) -> SafetyState:
    prompt = f"""You are an emergency triage AI for tourism safety in North East India.
Analyze this alert and respond ONLY in valid JSON.

Alert: {state['alert_type']} | Message: {state['message']}
Tourist: {state['tourist_name']} | Blood: {state['blood_group']}
Location: {state['latitude']}, {state['longitude']}

JSON format:
{{"severity":"critical/high/medium/low","triage_summary":"brief","immediate_action":"what to do","medical_needed":true/false,"estimated_response_time":"X minutes"}}"""
    try:
        response = llm.invoke(prompt)
        start = response.find('{')
        end = response.rfind('}') + 1
        data = json.loads(response[start:end])
        state['severity'] = data.get('severity', 'high')
        state['triage_result'] = json.dumps(data)
    except Exception:
        state['severity'] = 'high'
        state['triage_result'] = json.dumps({
            "severity": "high",
            "triage_summary": f"{state['alert_type']} alert from {state['tourist_name']}",
            "immediate_action": "Dispatch nearest unit immediately",
            "medical_needed": state['alert_type'] in ['medical', 'accident'],
            "estimated_response_time": "15 minutes"
        })
    return state

def find_police_node(state: SafetyState) -> SafetyState:
    stations = [
        {"name": "Guwahati City Police", "lat": 26.1445, "lng": 91.7362, "contact": "0361-2731030"},
        {"name": "Kaziranga Police Post", "lat": 26.5775, "lng": 93.1711, "contact": "03776-268003"},
        {"name": "Shillong Police Control", "lat": 25.5788, "lng": 91.8933, "contact": "0364-2223232"},
        {"name": "Tawang Police Station", "lat": 27.5861, "lng": 91.8594, "contact": "03794-222233"},
        {"name": "Imphal Police HQ", "lat": 24.8170, "lng": 93.9368, "contact": "0385-2450701"},
    ]
    best = min(stations, key=lambda s: (
        (s['lat'] - state['latitude'])**2 + (s['lng'] - state['longitude'])**2
    ))
    state['nearest_police'] = json.dumps(best)
    return state

def dispatch_node(state: SafetyState) -> SafetyState:
    triage = json.loads(state['triage_result'])
    police = json.loads(state['nearest_police'])
    state['dispatch_action'] = json.dumps({
        "dispatch_to": police['name'],
        "contact": police['contact'],
        "severity": state['severity'],
        "instructions": triage.get('immediate_action'),
        "medical_needed": triage.get('medical_needed', False),
        "tourist_blood_group": state['blood_group'],
        "emergency_contact": state['emergency_contact'],
        "coordinates": f"{state['latitude']},{state['longitude']}",
        "google_maps": f"https://maps.google.com/?q={state['latitude']},{state['longitude']}",
    })
    return state

def response_node(state: SafetyState) -> SafetyState:
    dispatch = json.loads(state['dispatch_action']) if state['dispatch_action'] else {}
    triage = json.loads(state['triage_result'])
    state['final_response'] = (
        f"ALERT: {state['alert_type'].upper()} | Severity: {state['severity'].upper()}\n"
        f"Tourist: {state['tourist_name']} | Blood: {state['blood_group']}\n"
        f"Action: {triage.get('immediate_action')}\n"
        f"Dispatched to: {dispatch.get('dispatch_to')} | {dispatch.get('contact')}"
    )
    return state

def route_severity(state: SafetyState) -> str:
    return 'dispatch' if state.get('severity') in ['critical', 'high'] else 'response'

def build_safety_graph():
    g = StateGraph(SafetyState)
    g.add_node("triage", triage_node)
    g.add_node("find_police", find_police_node)
    g.add_node("dispatch", dispatch_node)
    g.add_node("response", response_node)
    g.set_entry_point("triage")
    g.add_edge("triage", "find_police")
    g.add_conditional_edges("find_police", route_severity,
                            {"dispatch": "dispatch", "response": "response"})
    g.add_edge("dispatch", "response")
    g.add_edge("response", END)
    return g.compile()

safety_graph = build_safety_graph()

async def run_safety_agent(alert_data: dict) -> dict:
    state = SafetyState(
        alert_type=alert_data.get('alert_type', 'sos'),
        message=alert_data.get('message', ''),
        latitude=alert_data.get('latitude', 0.0),
        longitude=alert_data.get('longitude', 0.0),
        tourist_name=alert_data.get('tourist_name', 'Unknown'),
        blood_group=alert_data.get('blood_group', 'Unknown'),
        emergency_contact=alert_data.get('emergency_contact', 'Not provided'),
        severity=None, triage_result=None,
        dispatch_action=None, nearest_police=None, final_response=None
    )
    result = safety_graph.invoke(state)
    return {
        'severity': result['severity'],
        'triage': json.loads(result['triage_result']),
        'dispatch': json.loads(result['dispatch_action']) if result['dispatch_action'] else None,
        'nearest_police': json.loads(result['nearest_police']),
        'summary': result['final_response']
    }
