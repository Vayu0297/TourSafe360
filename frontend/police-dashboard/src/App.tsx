import React, { useEffect, useState, useRef, useCallback } from "react";
import axios from "axios";
import { io, Socket } from "socket.io-client";
import {
  MapContainer, TileLayer, Marker, Popup, Circle, Polyline, useMap, useMapEvents,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// ─── FIX LEAFLET DEFAULT ICONS ────────────────────────────────
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

const makeIcon = (color: "red" | "blue" | "green" | "orange" | "grey") =>
  new L.Icon({
    iconUrl: `https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-${color}.png`,
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
  });

// ─── CONFIG ───────────────────────────────────────────────────
// Update this IP each session via: hostname -I | awk '{print $1}'
const API = process.env.REACT_APP_API_URL || "http://10.90.88.240:8000";
const WS  = API.replace("http", "ws");

// ─── TYPES ────────────────────────────────────────────────────
interface Tourist {
  id: string;
  name: string;
  email: string;
  phone: string;
  nationality: string;
  current_lat: number;
  current_lng: number;
  current_location_name: string;
  last_seen: string;
  status: "safe" | "warning" | "sos" | "offline";
  battery_pct: number;
  emergency_contact: string;
  joined: string;
}

interface SOSAlert {
  id: string;
  tourist_id: string;
  tourist_name: string;
  type: string;
  severity: "critical" | "high" | "medium" | "low";
  status: "active" | "responding" | "resolved" | "false_alarm" | "monitoring";
  lat: number;
  lng: number;
  location_name: string;
  description: string;
  responder?: string;
  created_at: string;
  equipment?: string[];
}

interface Geofence {
  id: string;
  name: string;
  state: string;
  lat: number;
  lng: number;
  radius_m: number;
  risk_level: "low" | "medium" | "high";
  max_capacity: number;
  current_count: number;
  entry_point: string;
  alert_rules: string[];
}

// ─── THEME ────────────────────────────────────────────────────
const C = {
  bg0: "#050c18", bg1: "#080f22", bg2: "#0c1630",
  border: "rgba(0,180,255,0.12)", borderHot: "rgba(0,180,255,0.35)",
  accent: "#00b4ff", accentGlow: "rgba(0,180,255,0.15)",
  teal: "#00e5cc", green: "#00e676", amber: "#ffb300",
  red: "#ff3d3d", pink: "#ff4d9d",
  textPrimary: "#e8f4fd", textSecondary: "rgba(200,230,255,0.55)",
  textDim: "rgba(150,190,230,0.3)",
};

// ─── MOCK FALLBACK DATA (used when backend offline) ───────────
const MOCK_TOURISTS: Tourist[] = [
  { id:"T001", name:"James Mitchell", email:"james@example.com", phone:"+1-555-0142", nationality:"USA", current_lat:26.67, current_lng:93.37, current_location_name:"Kaziranga National Park", last_seen:"2 min ago", status:"safe", battery_pct:82, emergency_contact:"+1-555-0199", joined:"2026-04-15" },
  { id:"T002", name:"Akiko Tanaka",   email:"akiko@example.com", phone:"+81-90-1234-5678", nationality:"Japan", current_lat:25.57, current_lng:91.88, current_location_name:"Shillong Peak", last_seen:"5 min ago", status:"safe", battery_pct:64, emergency_contact:"+81-80-5678", joined:"2026-04-14" },
  { id:"T003", name:"Hans Weber",     email:"hans@example.com", phone:"+49-151-2345-6789", nationality:"Germany", current_lat:25.56, current_lng:93.99, current_location_name:"Dzukou Valley", last_seen:"18 min ago", status:"warning", battery_pct:21, emergency_contact:"+49-170-6789", joined:"2026-04-13" },
  { id:"T004", name:"Sophie Laurent", email:"sophie@example.com", phone:"+33-6-12345678", nationality:"France", current_lat:24.53, current_lng:93.77, current_location_name:"Loktak Lake", last_seen:"1 min ago", status:"sos", battery_pct:45, emergency_contact:"+33-6-99887766", joined:"2026-04-15" },
  { id:"T005", name:"Raj Patel",       email:"raj@example.com", phone:"+91-98765-43210", nationality:"India", current_lat:27.58, current_lng:91.86, current_location_name:"Tawang Monastery", last_seen:"9 min ago", status:"safe", battery_pct:91, emergency_contact:"+91-94321-00000", joined:"2026-04-12" },
  { id:"T006", name:"Emma Thompson",  email:"emma@example.com", phone:"+44-7911-123456", nationality:"UK", current_lat:27.00, current_lng:94.22, current_location_name:"Majuli Island", last_seen:"3 min ago", status:"safe", battery_pct:77, emergency_contact:"+44-7999-654321", joined:"2026-04-16" },
  { id:"T007", name:"Yuki Shimada",   email:"yuki@example.com", phone:"+81-80-9876-5432", nationality:"Japan", current_lat:25.58, current_lng:94.01, current_location_name:"Dzukou Valley", last_seen:"94 min ago", status:"offline", battery_pct:3, emergency_contact:"+81-70-1111-2222", joined:"2026-04-11" },
];

const MOCK_SOS: SOSAlert[] = [
  { id:"SOS-001", tourist_id:"T004", tourist_name:"Sophie Laurent", type:"Medical Emergency", severity:"critical", status:"active", lat:24.53, lng:93.77, location_name:"Loktak Lake, Manipur", description:"Sudden chest pain reported. Tourist stationary 22 mins. Fall detection NOT triggered.", created_at:"14:32", equipment:["First aid kit","Oxygen cylinder","Stretcher","Defibrillator","Satellite phone"] },
  { id:"SOS-002", tourist_id:"T003", tourist_name:"Hans Weber", type:"Lost / Navigation", severity:"high", status:"responding", lat:25.56, lng:93.99, location_name:"Dzukou Valley, Nagaland", description:"Deviated 3.2km off registered trail. Battery 21%. No mobile signal in 600m radius.", responder:"Officer Rahul Nath", created_at:"13:15", equipment:["GPS device","Rope 50m","Torch","Emergency blanket","Water supply"] },
  { id:"SOS-003", tourist_id:"T007", tourist_name:"Yuki Shimada", type:"No Signal / Offline", severity:"medium", status:"monitoring", lat:25.58, lng:94.01, location_name:"Dzukou Valley Floor", description:"Device offline 94 min. Last position: valley floor. Fog weather. Companion confirms separate entry.", responder:"Officer Priya Devi", created_at:"06:54", equipment:["Satellite communicator","Rope","Emergency rations","Thermal blanket"] },
];

const MOCK_GEOFENCES: Geofence[] = [
  { id:"GF1", name:"Kaziranga National Park", state:"Assam", lat:26.67, lng:93.37, radius_m:5000, risk_level:"low", max_capacity:200, current_count:47, entry_point:"Kohra Gate", alert_rules:["Exit boundary → SMS alert","Stationary >30min → wellness ping","Battery <15% → low battery alert"] },
  { id:"GF2", name:"Tawang Monastery", state:"Arunachal Pradesh", lat:27.58, lng:91.86, radius_m:3000, risk_level:"medium", max_capacity:50, current_count:23, entry_point:"Tawang Town", alert_rules:["Exit boundary → SMS alert","Offline >60min → dispatcher ping"] },
  { id:"GF3", name:"Shillong Peak", state:"Meghalaya", lat:25.57, lng:91.88, radius_m:2500, risk_level:"low", max_capacity:100, current_count:31, entry_point:"Shillong City", alert_rules:["Exit boundary → SMS alert","Stationary >45min → wellness ping"] },
  { id:"GF4", name:"Dzukou Valley", state:"Nagaland", lat:25.56, lng:93.99, radius_m:4000, risk_level:"high", max_capacity:30, current_count:8, entry_point:"Viswema Village", alert_rules:["Exit boundary → IMMEDIATE alert","Offline >30min → dispatcher ping","Fall >3.8g → ambulance dispatch","Low signal zone — GPS every 5min"] },
  { id:"GF5", name:"Loktak Lake", state:"Manipur", lat:24.53, lng:93.77, radius_m:6000, risk_level:"medium", max_capacity:100, current_count:19, entry_point:"Moirang", alert_rules:["Exit boundary → SMS alert","Water proximity alert active","Battery <20% → alert"] },
  { id:"GF6", name:"Majuli Island", state:"Assam", lat:27.00, lng:94.22, radius_m:4500, risk_level:"low", max_capacity:150, current_count:56, entry_point:"Nimati Ghat Ferry", alert_rules:["Ferry schedule alerts active","Exit boundary → SMS alert"] },
];

// ─── TINY SHARED COMPONENTS ───────────────────────────────────
const Badge: React.FC<{ label: string }> = ({ label }) => {
  const colors: Record<string, string> = {
    safe:"#00e676", warning:"#ffb300", sos:"#ff3d3d", offline:"#888",
    critical:"#ff3d3d", high:"#ff8c00", medium:"#ffb300", low:"#00e676",
    active:"#ff3d3d", responding:"#ffb300", monitoring:"#00b4ff",
    resolved:"#00e676", false_alarm:"#888",
  };
  const c = colors[label] || "#888";
  return (
    <span style={{ padding:"2px 8px", borderRadius:4, fontSize:10, fontWeight:700,
      letterSpacing:0.8, border:`1px solid ${c}44`, color:c, background:`${c}15`,
      textTransform:"uppercase", whiteSpace:"nowrap" }}>
      {label}
    </span>
  );
};

const StatCard: React.FC<{ label:string; value:string|number; sub?:string; accent?:string }> = ({ label,value,sub,accent=C.accent }) => (
  <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:10, padding:"14px 16px", position:"relative", overflow:"hidden" }}>
    <div style={{ position:"absolute", top:0, left:0, width:3, height:"100%", background:accent, borderRadius:"10px 0 0 10px" }}/>
    <div style={{ fontSize:10, color:C.textSecondary, marginBottom:4, letterSpacing:0.8 }}>{label}</div>
    <div style={{ fontSize:22, fontWeight:800, color:C.textPrimary, lineHeight:1 }}>{value}</div>
    {sub && <div style={{ fontSize:10, color:C.textDim, marginTop:3 }}>{sub}</div>}
  </div>
);

const SectionTitle: React.FC<{ title:string; sub?:string }> = ({ title, sub }) => (
  <div style={{ marginBottom:14 }}>
    <div style={{ fontSize:11, fontWeight:700, letterSpacing:1.5, textTransform:"uppercase", color:C.accent }}>{title}</div>
    {sub && <div style={{ fontSize:10, color:C.textSecondary, marginTop:2 }}>{sub}</div>}
  </div>
);

// ─── MAP FLY-TO HELPER ────────────────────────────────────────
const FlyTo: React.FC<{ lat:number; lng:number; zoom?:number }> = ({ lat, lng, zoom=13 }) => {
  const map = useMap();
  useEffect(() => { map.flyTo([lat, lng], zoom, { duration:1.2 }); }, [lat, lng, zoom, map]);
  return null;
};

// ─── TAB: LIVE MAP ────────────────────────────────────────────
const TabMap: React.FC<{
  tourists: Tourist[];
  sosList: SOSAlert[];
  geofences: Geofence[];
  onSelectTourist: (t:Tourist) => void;
  onResolve: (id:string) => void;
  onDispatch: (sosId:string) => void;
}> = ({ tourists, sosList, geofences, onSelectTourist, onResolve, onDispatch }) => {
  const [flyTarget, setFlyTarget] = useState<{lat:number;lng:number;zoom:number}|null>(null);
  const [filter, setFilter] = useState<"all"|"sos"|"warning"|"offline">("all");
  const [showGeofences, setShowGeofences] = useState(true);

  const riskColors: Record<string,string> = { low:"#00e676", medium:"#ffb300", high:"#ff3d3d" };
  const statusIcon: Record<string,any> = {
    safe: makeIcon("blue"), warning: makeIcon("orange"),
    sos: makeIcon("red"), offline: makeIcon("grey"),
  };

  const filteredTourists = tourists.filter(t =>
    filter === "all" ? true : t.status === filter
  );

  return (
    <div style={{ display:"flex", flexDirection:"column", gap:12, height:"100%" }}>
      {/* Controls */}
      <div style={{ display:"flex", gap:8, flexWrap:"wrap", alignItems:"center" }}>
        {(["all","sos","warning","offline"] as const).map(f => (
          <button key={f} onClick={() => setFilter(f)} style={{
            background: filter===f ? C.accentGlow : "transparent",
            border: `1px solid ${filter===f ? C.accent : C.border}`,
            borderRadius:6, padding:"5px 12px", color: filter===f ? C.accent : C.textSecondary,
            fontSize:11, cursor:"pointer", textTransform:"capitalize"
          }}>{f} {f==="all"?`(${tourists.length})`:f==="sos"?`(${tourists.filter(t=>t.status==="sos").length})`:f==="warning"?`(${tourists.filter(t=>t.status==="warning").length})`:`(${tourists.filter(t=>t.status==="offline").length})`}</button>
        ))}
        <button onClick={() => setShowGeofences(v => !v)} style={{
          background: showGeofences ? "rgba(0,229,204,0.1)" : "transparent",
          border: `1px solid ${showGeofences ? C.teal : C.border}`,
          borderRadius:6, padding:"5px 12px", color: showGeofences ? C.teal : C.textSecondary,
          fontSize:11, cursor:"pointer", marginLeft:"auto"
        }}>⬡ Geofences {showGeofences?"ON":"OFF"}</button>
      </div>

      {/* Quick jump to SOS */}
      {sosList.filter(s => s.status === "active").length > 0 && (
        <div style={{ display:"flex", gap:6, flexWrap:"wrap" }}>
          {sosList.filter(s => s.status === "active").map(s => (
            <button key={s.id} onClick={() => setFlyTarget({ lat:s.lat, lng:s.lng, zoom:14 })}
              style={{ background:"rgba(255,61,61,0.1)", border:"1px solid rgba(255,61,61,0.4)", borderRadius:6, padding:"4px 10px", color:C.red, fontSize:11, cursor:"pointer" }}>
              🔴 Jump to {s.tourist_name.split(" ")[0]}
            </button>
          ))}
        </div>
      )}

      {/* Leaflet Map */}
      <div style={{ flex:1, borderRadius:12, overflow:"hidden", border:`1px solid ${C.border}`, minHeight:480 }}>
        <MapContainer
          center={[26.2, 92.5]}
          zoom={7}
          style={{ height:"100%", width:"100%", background:"#060c18" }}
          zoomControl={true}
        >
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            attribution='&copy; <a href="https://carto.com/">CARTO</a>'
          />

          {flyTarget && <FlyTo lat={flyTarget.lat} lng={flyTarget.lng} zoom={flyTarget.zoom} />}

          {/* Geofence circles */}
          {showGeofences && geofences.map(gf => (
            <React.Fragment key={gf.id}>
              <Circle
                center={[gf.lat, gf.lng]}
                radius={gf.radius_m}
                pathOptions={{
                  color: riskColors[gf.risk_level],
                  fillColor: riskColors[gf.risk_level],
                  fillOpacity: 0.06,
                  weight: 1.5,
                  dashArray: "6 4",
                }}
              >
                <Popup>
                  <div style={{ minWidth:200, fontFamily:"monospace", fontSize:12 }}>
                    <div style={{ fontWeight:700, marginBottom:6 }}>{gf.name}</div>
                    <div>State: {gf.state}</div>
                    <div>Risk: <strong style={{ color: riskColors[gf.risk_level] }}>{gf.risk_level.toUpperCase()}</strong></div>
                    <div>Tourists: {gf.current_count} / {gf.max_capacity}</div>
                    <div>Radius: {(gf.radius_m/1000).toFixed(1)} km</div>
                    <div style={{ marginTop:6, fontSize:11, color:"#888" }}>Entry: {gf.entry_point}</div>
                  </div>
                </Popup>
              </Circle>
            </React.Fragment>
          ))}

          {/* Tourist markers */}
          {filteredTourists.map(t => (
            <Marker
              key={t.id}
              position={[t.current_lat, t.current_lng]}
              icon={statusIcon[t.status] || makeIcon("blue")}
            >
              <Popup minWidth={240}>
                <div style={{ fontFamily:"monospace", fontSize:12 }}>
                  <div style={{ fontWeight:700, fontSize:14, marginBottom:6 }}>{t.name}</div>
                  <div style={{ marginBottom:3 }}>🌍 {t.nationality} &nbsp;|&nbsp; ID: {t.id}</div>
                  <div style={{ marginBottom:3 }}>📍 {t.current_location_name}</div>
                  <div style={{ marginBottom:3 }}>⏱ Last seen: {t.last_seen}</div>
                  <div style={{ marginBottom:6 }}>🔋 Battery: {t.battery_pct}%</div>
                  <div style={{ display:"flex", gap:6, marginTop:8 }}>
                    <button onClick={() => { onSelectTourist(t); }}
                      style={{ flex:1, background:"#003399", border:"none", borderRadius:4, padding:"5px 8px", color:"#fff", fontSize:11, cursor:"pointer" }}>
                      View Profile
                    </button>
                    <button onClick={() => setFlyTarget({ lat:t.current_lat, lng:t.current_lng, zoom:15 })}
                      style={{ flex:1, background:"#004422", border:"none", borderRadius:4, padding:"5px 8px", color:"#00e676", fontSize:11, cursor:"pointer" }}>
                      Center Map
                    </button>
                  </div>
                  {t.status === "sos" && (
                    <button onClick={() => {
                      const s = sosList.find(s => s.tourist_id === t.id);
                      if (s) onDispatch(s.id);
                    }} style={{ width:"100%", marginTop:6, background:"#660000", border:"none", borderRadius:4, padding:"6px 8px", color:"#ffaaaa", fontSize:11, cursor:"pointer", fontWeight:700 }}>
                      🚔 Dispatch Unit Now
                    </button>
                  )}
                </div>
              </Popup>
            </Marker>
          ))}

          {/* SOS alert markers with pulsing circle */}
          {sosList.filter(s => s.status === "active").map(s => (
            <Circle key={`sos-pulse-${s.id}`}
              center={[s.lat, s.lng]}
              radius={800}
              pathOptions={{ color:"#ff3d3d", fillColor:"#ff3d3d", fillOpacity:0.08, weight:2 }}
            />
          ))}
        </MapContainer>
      </div>

      {/* Legend */}
      <div style={{ display:"flex", gap:16, flexWrap:"wrap", fontSize:11, color:C.textSecondary }}>
        {[["🔵","Safe tourist"],["🟠","Warning (low battery/lost)"],["🔴","Active SOS"],["⚫","Offline device"]].map(([icon, label]) => (
          <span key={label as string}>{icon} {label as string}</span>
        ))}
        <span style={{ marginLeft:"auto", color:C.textDim }}>Dark tile: © CARTO · Basemaps under Leaflet</span>
      </div>
    </div>
  );
};

// ─── TAB: TOURISTS ────────────────────────────────────────────
const TabTourists: React.FC<{
  tourists: Tourist[];
  selected: Tourist | null;
  onSelect: (t:Tourist|null) => void;
  onFlyTo: (t:Tourist) => void;
}> = ({ tourists, selected, onSelect, onFlyTo }) => {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");

  const filtered = tourists.filter(t => {
    const q = search.toLowerCase();
    const matchQ = t.name.toLowerCase().includes(q) || t.nationality.toLowerCase().includes(q) || t.id.toLowerCase().includes(q);
    const matchS = statusFilter === "all" || t.status === statusFilter;
    return matchQ && matchS;
  });

  if (selected) return (
    <div>
      <button onClick={() => onSelect(null)} style={{ background:"transparent", border:`1px solid ${C.border}`, borderRadius:6, padding:"6px 12px", color:C.textSecondary, fontSize:12, cursor:"pointer", marginBottom:20 }}>
        ← Back to List
      </button>
      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:16 }}>
        <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:20 }}>
          <div style={{ display:"flex", gap:12, alignItems:"center", marginBottom:20 }}>
            <div style={{ width:56, height:56, borderRadius:"50%", background:C.bg0, border:`2px solid ${C.accent}`, display:"flex", alignItems:"center", justifyContent:"center", fontSize:26, flexShrink:0 }}>
              {selected.nationality==="USA"?"🇺🇸":selected.nationality==="Japan"?"🇯🇵":selected.nationality==="Germany"?"🇩🇪":selected.nationality==="France"?"🇫🇷":selected.nationality==="UK"?"🇬🇧":selected.nationality==="India"?"🇮🇳":"🌍"}
            </div>
            <div>
              <div style={{ fontSize:18, fontWeight:800, color:C.textPrimary }}>{selected.name}</div>
              <div style={{ fontSize:12, color:C.textSecondary, marginBottom:4 }}>{selected.id} · {selected.nationality}</div>
              <Badge label={selected.status}/>
            </div>
          </div>
          {[
            ["Email", selected.email],
            ["Phone", selected.phone],
            ["Emergency Contact", selected.emergency_contact],
            ["Current Location", selected.current_location_name],
            ["Last Seen", selected.last_seen],
            ["Battery", `${selected.battery_pct}%`],
            ["GPS", `${selected.current_lat.toFixed(5)}°N, ${selected.current_lng.toFixed(5)}°E`],
            ["Registered", selected.joined],
          ].map(([k,v]) => (
            <div key={k} style={{ display:"flex", justifyContent:"space-between", borderBottom:`1px solid ${C.border}`, padding:"8px 0", fontSize:12 }}>
              <span style={{ color:C.textSecondary }}>{k}</span>
              <span style={{ color:C.textPrimary, fontWeight:500 }}>{v}</span>
            </div>
          ))}
        </div>
        <div style={{ display:"flex", flexDirection:"column", gap:12 }}>
          <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:16 }}>
            <SectionTitle title="Quick Actions"/>
            {[
              { label:"📞 Call Tourist", color:C.accent },
              { label:"📢 Send Safety Alert SMS", color:C.amber },
              { label:"🚔 Dispatch Officer to Location", color:C.red },
              { label:"🗺️ Center Map on Tourist", color:C.teal, action:() => onFlyTo(selected) },
              { label:"🚁 Request Helicopter Rescue", color:C.pink },
            ].map(a => (
              <button key={a.label} onClick={a.action}
                style={{ width:"100%", background:`${a.color}12`, border:`1px solid ${a.color}44`, borderRadius:8, padding:"10px 14px", color:a.color, fontSize:12, fontWeight:600, cursor:"pointer", marginBottom:8, textAlign:"left" }}>
                {a.label}
              </button>
            ))}
          </div>
          {selected.battery_pct < 25 && (
            <div style={{ background:"rgba(255,179,0,0.08)", border:"1px solid rgba(255,179,0,0.3)", borderRadius:10, padding:"12px 14px" }}>
              <div style={{ fontSize:12, fontWeight:700, color:C.amber, marginBottom:4 }}>⚠ Low Battery Warning</div>
              <div style={{ fontSize:11, color:C.textSecondary }}>Tourist device at {selected.battery_pct}%. Connection may drop soon. Consider sending an alert.</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );

  return (
    <div>
      <div style={{ display:"flex", gap:8, marginBottom:14, flexWrap:"wrap" }}>
        <input value={search} onChange={e => setSearch(e.target.value)}
          placeholder="Search name, nationality, ID..."
          style={{ flex:1, background:C.bg2, border:`1px solid ${C.border}`, borderRadius:8, padding:"8px 12px", color:C.textPrimary, fontSize:12, outline:"none", minWidth:160 }}/>
        {["all","safe","warning","sos","offline"].map(s => (
          <button key={s} onClick={() => setStatusFilter(s)}
            style={{ background:statusFilter===s?C.accentGlow:"transparent", border:`1px solid ${statusFilter===s?C.accent:C.border}`, borderRadius:6, padding:"6px 12px", color:statusFilter===s?C.accent:C.textSecondary, fontSize:11, cursor:"pointer", textTransform:"capitalize" }}>
            {s}
          </button>
        ))}
      </div>
      <div style={{ fontSize:11, color:C.textDim, marginBottom:10 }}>{filtered.length} tourist{filtered.length!==1?"s":""}</div>
      <div style={{ display:"grid", gridTemplateColumns:"repeat(auto-fill,minmax(260px,1fr))", gap:10 }}>
        {filtered.map(t => (
          <div key={t.id} onClick={() => onSelect(t)}
            style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:10, padding:"12px 14px", cursor:"pointer", transition:"all 0.15s" }}
            onMouseEnter={e => { (e.currentTarget as HTMLElement).style.borderColor=C.borderHot; (e.currentTarget as HTMLElement).style.transform="translateY(-1px)"; }}
            onMouseLeave={e => { (e.currentTarget as HTMLElement).style.borderColor=C.border; (e.currentTarget as HTMLElement).style.transform="none"; }}>
            <div style={{ display:"flex", gap:10, alignItems:"center", marginBottom:8 }}>
              <div style={{ fontSize:22 }}>
                {t.nationality==="USA"?"🇺🇸":t.nationality==="Japan"?"🇯🇵":t.nationality==="Germany"?"🇩🇪":t.nationality==="France"?"🇫🇷":t.nationality==="UK"?"🇬🇧":t.nationality==="India"?"🇮🇳":"🌍"}
              </div>
              <div style={{ flex:1 }}>
                <div style={{ fontSize:13, fontWeight:700, color:C.textPrimary }}>{t.name}</div>
                <div style={{ fontSize:11, color:C.textSecondary }}>{t.id} · {t.nationality}</div>
              </div>
              <Badge label={t.status}/>
            </div>
            <div style={{ fontSize:11, color:C.textSecondary, marginBottom:4 }}>📍 {t.current_location_name}</div>
            <div style={{ display:"flex", justifyContent:"space-between", fontSize:11, color:C.textDim }}>
              <span>🔋 {t.battery_pct}%</span>
              <span>⏱ {t.last_seen}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ─── TAB: SOS ALERTS ─────────────────────────────────────────
const TabSOS: React.FC<{
  sosList: SOSAlert[];
  preselected: SOSAlert | null;
  onResolve: (id:string) => void;
  onDispatch: (id:string) => void;
  onFlyTo: (lat:number, lng:number) => void;
}> = ({ sosList, preselected, onResolve, onDispatch, onFlyTo }) => {
  const [selected, setSelected] = useState<SOSAlert|null>(preselected || sosList[0] || null);
  const [flash, setFlash] = useState(true);

  useEffect(() => { if (preselected) setSelected(preselected); }, [preselected]);
  useEffect(() => { const t = setInterval(() => setFlash(f => !f), 900); return () => clearInterval(t); }, []);

  const severityColor: Record<string,string> = { critical:C.red, high:C.amber, medium:C.teal, low:C.green };

  return (
    <div style={{ display:"grid", gridTemplateColumns:"300px 1fr", gap:16, height:"100%" }}>
      <div>
        <SectionTitle title="SOS Queue" sub={`${sosList.filter(s=>s.status!=="resolved").length} open`}/>
        {sosList.length === 0 && (
          <div style={{ color:C.green, fontSize:12, padding:"12px 0" }}>✓ No active SOS alerts</div>
        )}
        {sosList.map(s => (
          <div key={s.id} onClick={() => setSelected(s)}
            style={{ background:selected?.id===s.id?`${severityColor[s.severity]}12`:C.bg2, border:`1px solid ${selected?.id===s.id?severityColor[s.severity]:C.border}`, borderRadius:10, padding:"12px 14px", marginBottom:8, cursor:"pointer", transition:"all 0.15s" }}>
            <div style={{ display:"flex", justifyContent:"space-between", marginBottom:5 }}>
              <div style={{ display:"flex", gap:6, alignItems:"center" }}>
                <div style={{ width:8, height:8, borderRadius:"50%", background:s.status==="active"?C.red:s.status==="responding"?C.amber:"#555", flexShrink:0, boxShadow:s.status==="active"&&flash?`0 0 10px ${C.red}`:"none", transition:"box-shadow 0.3s" }}/>
                <span style={{ fontSize:11, fontWeight:700, color:C.textPrimary }}>{s.id}</span>
              </div>
              <Badge label={s.severity}/>
            </div>
            <div style={{ fontSize:13, fontWeight:600, color:C.textPrimary, marginBottom:3 }}>{s.tourist_name}</div>
            <div style={{ fontSize:11, color:C.textSecondary, marginBottom:5 }}>{s.type}</div>
            <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center" }}>
              <Badge label={s.status}/>
              <span style={{ fontSize:10, color:C.textDim }}>{s.created_at}</span>
            </div>
          </div>
        ))}
      </div>

      {selected ? (
        <div style={{ overflow:"auto" }}>
          <div style={{ background:C.bg2, border:`1px solid ${severityColor[selected.severity]}44`, borderRadius:12, padding:20, marginBottom:12 }}>
            <div style={{ display:"flex", justifyContent:"space-between", marginBottom:16 }}>
              <div>
                <div style={{ fontSize:18, fontWeight:800, color:C.textPrimary, marginBottom:4 }}>{selected.id}</div>
                <div style={{ fontSize:13, color:C.textSecondary }}>{selected.tourist_name} · {selected.location_name}</div>
              </div>
              <div style={{ display:"flex", flexDirection:"column", gap:6, alignItems:"flex-end" }}>
                <Badge label={selected.severity}/>
                <Badge label={selected.status}/>
              </div>
            </div>

            {/* Type + time */}
            <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr 1fr", gap:10, marginBottom:16 }}>
              <StatCard label="INCIDENT TYPE" value={selected.type.split(" ").slice(0,2).join(" ")} accent={severityColor[selected.severity]}/>
              <StatCard label="GPS" value={`${selected.lat.toFixed(3)}, ${selected.lng.toFixed(3)}`} accent={C.teal}/>
              <StatCard label="RESPONDER" value={selected.responder || "Unassigned"} accent={C.amber}/>
            </div>

            {/* AI assessment */}
            <div style={{ background:C.bg0, borderRadius:8, padding:"12px 14px", marginBottom:16, borderLeft:`3px solid ${severityColor[selected.severity]}` }}>
              <div style={{ fontSize:10, color:C.textDim, marginBottom:5, letterSpacing:0.8 }}>AI SITUATION ASSESSMENT</div>
              <div style={{ fontSize:12, color:C.textPrimary, lineHeight:1.7 }}>{selected.description}</div>
            </div>

            {/* Equipment */}
            {selected.equipment && selected.equipment.length > 0 && (
              <>
                <SectionTitle title="Recommended Equipment"/>
                <div style={{ display:"flex", flexWrap:"wrap", gap:6, marginBottom:16 }}>
                  {selected.equipment.map(e => (
                    <span key={e} style={{ background:C.bg0, border:`1px solid ${C.border}`, borderRadius:6, padding:"4px 10px", fontSize:11, color:C.textSecondary }}>✓ {e}</span>
                  ))}
                </div>
              </>
            )}

            {/* Actions */}
            <SectionTitle title="Response Actions"/>
            <div style={{ display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:8 }}>
              {[
                { label:"🚔 Dispatch Police", color:C.accent, action:() => onDispatch(selected.id) },
                { label:"🚑 Dispatch Ambulance", color:C.red, action:() => {} },
                { label:"📞 Call Tourist", color:C.green, action:() => {} },
                { label:"🗺️ Show on Map", color:C.teal, action:() => onFlyTo(selected.lat, selected.lng) },
                { label:"✅ Mark Resolved", color:C.teal, action:() => onResolve(selected.id) },
                { label:"⚠ Escalate to HQ", color:C.pink, action:() => {} },
              ].map(a => (
                <button key={a.label} onClick={a.action}
                  style={{ background:`${a.color}12`, border:`1px solid ${a.color}44`, borderRadius:8, padding:"10px 12px", color:a.color, fontSize:11, fontWeight:600, cursor:"pointer", textAlign:"left" }}>
                  {a.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : (
        <div style={{ display:"flex", alignItems:"center", justifyContent:"center", color:C.textDim, fontSize:13 }}>
          Select an alert to view details
        </div>
      )}
    </div>
  );
};

// ─── TAB: GEOFENCES ───────────────────────────────────────────
const MapClickCapture: React.FC<{onMapClick:(lat:number,lng:number)=>void}> = ({onMapClick}) => {
  useMapEvents({ click(e) { onMapClick(e.latlng.lat, e.latlng.lng); } });
  return null;
};

const TabGeofences: React.FC<{
  geofences: Geofence[];
  onFlyTo: (lat:number, lng:number) => void;
  apiUrl: string;
  onRefresh: () => void;
}> = ({ geofences, onFlyTo, apiUrl, onRefresh }) => {
  const [selected, setSelected] = useState<Geofence|null>(geofences[0]||null);
  const [createMode, setCreateMode] = useState(false);
  const [placing, setPlacing] = useState(false);
  const [creating, setCreating] = useState(false);
  const [createMsg, setCreateMsg] = useState("");
  const [newZone, setNewZone] = useState({
    name:"", zone_type:"green", state:"Assam",
    center_lat:26.2006, center_lng:92.9376,
    radius_meters:5000, description:""
  });

  const riskColor: Record<string,string> = { low:C.green, medium:C.amber, high:C.red };
  const zoneColor: Record<string,string> = {
    green:C.green, amber:C.amber, red:C.red, restricted:"#a855f7", low:C.green, medium:C.amber, high:C.red
  };
  const NE_STATES = ["Assam","Meghalaya","Manipur","Mizoram","Nagaland","Tripura","Arunachal Pradesh","Sikkim"];
  const ZONE_TYPES = [
    {value:"green",label:"Safe",color:C.green},
    {value:"amber",label:"Caution",color:C.amber},
    {value:"red",label:"Danger",color:C.red},
    {value:"restricted",label:"Restricted",color:"#a855f7"},
  ];

  const handleMapClick = (lat: number, lng: number) => {
    if (!placing) return;
    setNewZone(p => ({...p, center_lat:parseFloat(lat.toFixed(5)), center_lng:parseFloat(lng.toFixed(5))}));
    setPlacing(false);
    setCreateMsg(`📍 Center set: ${lat.toFixed(4)}, ${lng.toFixed(4)}`);
  };

  const handleCreate = async () => {
    if (!newZone.name) { setCreateMsg("❌ Please enter a zone name"); return; }
    setCreating(true);
    try {
      await axios.post(`${apiUrl}/api/geofence/`, {
        name: newZone.name, zone_type: newZone.zone_type, state: newZone.state,
        center_lat: newZone.center_lat, center_lng: newZone.center_lng,
        radius_meters: newZone.radius_meters, description: newZone.description,
      });
      setCreateMsg("✅ Zone created!");
      setNewZone({name:"",zone_type:"green",state:"Assam",center_lat:26.2006,center_lng:92.9376,radius_meters:5000,description:""});
      onRefresh();
      setTimeout(() => { setCreateMode(false); setCreateMsg(""); }, 1500);
    } catch(e) { setCreateMsg("❌ Failed to create zone"); }
    setCreating(false);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm("Delete this zone?")) return;
    try { await axios.delete(`${apiUrl}/api/geofence/${id}`); onRefresh(); } catch(e) {}
  };

  const activeColor = zoneColor[newZone.zone_type] || C.green;

  return (
    <div style={{ display:"grid", gridTemplateColumns:"280px 1fr", gap:16, height:"calc(100vh - 120px)" }}>

      {/* Left panel */}
      <div style={{ overflowY:"auto", display:"flex", flexDirection:"column", gap:10 }}>

        {/* Toggle buttons */}
        <div style={{ display:"flex", gap:6 }}>
          <button onClick={() => { setCreateMode(false); setPlacing(false); }}
            style={{ flex:1, padding:"8px", borderRadius:6, border:`1px solid ${!createMode?C.accent:C.border}`,
                     background:!createMode?C.accentGlow:"transparent",
                     color:!createMode?C.accent:C.textSecondary, fontSize:11, cursor:"pointer", fontWeight:!createMode?700:400 }}>
            ⬡ View Zones ({geofences.length})
          </button>
          <button onClick={() => setCreateMode(true)}
            style={{ flex:1, padding:"8px", borderRadius:6, border:`1px solid ${createMode?C.teal:C.border}`,
                     background:createMode?"rgba(0,229,204,0.1)":"transparent",
                     color:createMode?C.teal:C.textSecondary, fontSize:11, cursor:"pointer", fontWeight:createMode?700:400 }}>
            + Create Zone
          </button>
        </div>

        {/* CREATE FORM */}
        {createMode && (
          <div style={{ background:C.bg2, border:`1px solid ${C.teal}44`, borderRadius:10, padding:14 }}>
            <div style={{ fontSize:11, fontWeight:700, color:C.teal, marginBottom:10, letterSpacing:1 }}>NEW GEOFENCE ZONE</div>

            <div style={{ marginBottom:8 }}>
              <div style={{ fontSize:10, color:C.textSecondary, marginBottom:3 }}>Zone Name *</div>
              <input value={newZone.name} onChange={e => setNewZone(p=>({...p,name:e.target.value}))}
                placeholder="e.g. Kaziranga Buffer Zone"
                style={{ width:"100%", background:C.bg0, border:`1px solid ${C.border}`,
                         borderRadius:6, padding:"7px 8px", color:C.textPrimary,
                         fontSize:11, outline:"none", boxSizing:"border-box" as any }}/>
            </div>

            <div style={{ marginBottom:8 }}>
              <div style={{ fontSize:10, color:C.textSecondary, marginBottom:3 }}>Zone Type</div>
              <div style={{ display:"flex", gap:4 }}>
                {ZONE_TYPES.map(t => (
                  <button key={t.value} onClick={() => setNewZone(p=>({...p,zone_type:t.value}))}
                    style={{ flex:1, padding:"6px 4px", borderRadius:6,
                             border:`1px solid ${newZone.zone_type===t.value?t.color:C.border}`,
                             background:newZone.zone_type===t.value?`${t.color}22`:"transparent",
                             color:newZone.zone_type===t.value?t.color:C.textSecondary,
                             fontSize:10, cursor:"pointer", fontWeight:700 }}>
                    {t.label}
                  </button>
                ))}
              </div>
            </div>

            <div style={{ marginBottom:8 }}>
              <div style={{ fontSize:10, color:C.textSecondary, marginBottom:3 }}>State</div>
              <select value={newZone.state} onChange={e => setNewZone(p=>({...p,state:e.target.value}))}
                style={{ width:"100%", background:C.bg0, border:`1px solid ${C.border}`,
                         borderRadius:6, padding:"7px 8px", color:C.textPrimary, fontSize:11, outline:"none" }}>
                {NE_STATES.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>

            {/* Click map to place */}
            <div style={{ marginBottom:8 }}>
              <div style={{ fontSize:10, color:C.textSecondary, marginBottom:3 }}>Center Location</div>
              <div style={{ display:"flex", gap:6, marginBottom:6 }}>
                <input value={newZone.center_lat} onChange={e => setNewZone(p=>({...p,center_lat:parseFloat(e.target.value)||0}))}
                  style={{ flex:1, background:C.bg0, border:`1px solid ${C.border}`, borderRadius:6,
                           padding:"6px 8px", color:C.textPrimary, fontSize:10, outline:"none" }}/>
                <input value={newZone.center_lng} onChange={e => setNewZone(p=>({...p,center_lng:parseFloat(e.target.value)||0}))}
                  style={{ flex:1, background:C.bg0, border:`1px solid ${C.border}`, borderRadius:6,
                           padding:"6px 8px", color:C.textPrimary, fontSize:10, outline:"none" }}/>
              </div>
              <button onClick={() => setPlacing(p => !p)}
                style={{ width:"100%", padding:"8px", borderRadius:6,
                         border:`2px dashed ${placing?C.teal:C.border}`,
                         background:placing?"rgba(0,229,204,0.1)":"transparent",
                         color:placing?C.teal:C.textSecondary, fontSize:11, cursor:"pointer", fontWeight:700 }}>
                {placing ? "🎯 Click map to place center..." : "📍 Click Map to Place Center"}
              </button>
            </div>

            <div style={{ marginBottom:8 }}>
              <div style={{ fontSize:10, color:C.textSecondary, marginBottom:3 }}>
                Radius: {newZone.radius_meters >= 1000 ? (newZone.radius_meters/1000).toFixed(1)+"km" : newZone.radius_meters+"m"}
              </div>
              <input type="range" min={500} max={50000} step={500} value={newZone.radius_meters}
                onChange={e => setNewZone(p=>({...p,radius_meters:parseInt(e.target.value)}))}
                style={{ width:"100%", accentColor:activeColor }}/>
              <div style={{ display:"flex", justifyContent:"space-between", fontSize:9, color:C.textDim }}>
                <span>500m</span><span>50km</span>
              </div>
            </div>

            <div style={{ marginBottom:10 }}>
              <div style={{ fontSize:10, color:C.textSecondary, marginBottom:3 }}>Description</div>
              <input value={newZone.description} onChange={e => setNewZone(p=>({...p,description:e.target.value}))}
                placeholder="Optional notes..."
                style={{ width:"100%", background:C.bg0, border:`1px solid ${C.border}`,
                         borderRadius:6, padding:"7px 8px", color:C.textPrimary,
                         fontSize:11, outline:"none", boxSizing:"border-box" as any }}/>
            </div>

            {/* Preview */}
            <div style={{ background:C.bg0, borderRadius:8, padding:"8px 10px", marginBottom:10,
                          border:`1px solid ${activeColor}44` }}>
              <div style={{ fontSize:10, color:C.textDim, marginBottom:4 }}>PREVIEW</div>
              <div style={{ display:"flex", alignItems:"center", gap:8 }}>
                <div style={{ width:12, height:12, borderRadius:"50%", background:activeColor, opacity:0.7 }}/>
                <span style={{ fontSize:12, color:C.textPrimary, fontWeight:600 }}>{newZone.name||"Unnamed zone"}</span>
                <span style={{ fontSize:10, color:C.textDim }}>• {newZone.radius_meters>=1000?(newZone.radius_meters/1000).toFixed(1)+"km":newZone.radius_meters+"m"}</span>
              </div>
            </div>

            {createMsg && (
              <div style={{ fontSize:11, color:createMsg.includes("✅")?C.green:createMsg.includes("📍")?C.teal:C.red,
                           marginBottom:8, padding:"6px 8px", background:C.bg0, borderRadius:6 }}>
                {createMsg}
              </div>
            )}

            <button onClick={handleCreate} disabled={creating}
              style={{ width:"100%", background:`${activeColor}22`, border:`1px solid ${activeColor}`,
                       borderRadius:6, padding:"10px", color:activeColor,
                       fontSize:12, fontWeight:700, cursor:"pointer" }}>
              {creating ? "Creating..." : "✅ Create Geofence Zone"}
            </button>
          </div>
        )}

        {/* ZONE LIST */}
        {!createMode && (
          <>
            <div style={{ display:"flex", gap:6, flexWrap:"wrap" }}>
              {["green","amber","red","restricted"].map(type => {
                const count = geofences.filter(g=>g.risk_level===(type==="green"?"low":type==="amber"?"medium":"high")).length;
                return (
                  <div key={type} style={{ fontSize:10, padding:"2px 8px", borderRadius:20,
                                           background:`${zoneColor[type]}22`, color:zoneColor[type],
                                           border:`1px solid ${zoneColor[type]}44` }}>
                    {count} {type}
                  </div>
                );
              })}
            </div>
            {geofences.map(gf => (
              <div key={gf.id} onClick={() => setSelected(gf)}
                style={{ background:selected?.id===gf.id?C.accentGlow:C.bg2,
                         border:`1px solid ${selected?.id===gf.id?C.accent:C.border}`,
                         borderRadius:8, padding:"10px 12px", cursor:"pointer", transition:"all 0.15s" }}>
                <div style={{ display:"flex", justifyContent:"space-between", marginBottom:4 }}>
                  <span style={{ fontSize:12, fontWeight:600, color:C.textPrimary }}>{gf.name.split(" ").slice(0,3).join(" ")}</span>
                  <div style={{ display:"flex", gap:5, alignItems:"center" }}>
                    <Badge label={gf.risk_level}/>
                    <button onClick={e=>{e.stopPropagation();handleDelete(gf.id);}}
                      style={{ background:"rgba(255,61,61,0.1)", border:"1px solid rgba(255,61,61,0.3)",
                               borderRadius:4, padding:"1px 6px", color:C.red, fontSize:10, cursor:"pointer" }}>
                      ✕
                    </button>
                  </div>
                </div>
                <div style={{ fontSize:11, color:C.textSecondary }}>{gf.state}</div>
                <div style={{ fontSize:10, color:C.textDim, marginTop:2 }}>
                  {(gf.radius_m/1000).toFixed(1)}km radius
                </div>
              </div>
            ))}
          </>
        )}
      </div>

      {/* RIGHT: Interactive Map */}
      <div style={{ display:"flex", flexDirection:"column", gap:10 }}>
        {placing && (
          <div style={{ background:"rgba(0,229,204,0.1)", border:"1px solid rgba(0,229,204,0.4)",
                        borderRadius:8, padding:"8px 14px", fontSize:12, color:C.teal, fontWeight:700 }}>
            🎯 Click anywhere on the map to set the zone center
          </div>
        )}

        <div style={{ flex:1, borderRadius:12, overflow:"hidden", border:`1px solid ${C.border}`, minHeight:500 }}>
          <MapContainer center={[26.2, 92.5]} zoom={7}
            style={{ height:"100%", width:"100%", minHeight:500 }}>
            <TileLayer url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
              attribution='&copy; CARTO'/>

            <MapClickCapture onMapClick={handleMapClick}/>

            {/* Existing zones */}
            {geofences.map(gf => (
              <React.Fragment key={gf.id}>
                <Circle center={[gf.lat, gf.lng]} radius={gf.radius_m}
                  pathOptions={{
                    color: zoneColor[gf.risk_level] || C.accent,
                    fillColor: zoneColor[gf.risk_level] || C.accent,
                    fillOpacity: selected?.id===gf.id ? 0.2 : 0.06,
                    weight: selected?.id===gf.id ? 3 : 1.5,
                    dashArray: "6 4",
                  }}>
                  <Popup>
                    <div style={{ fontFamily:"monospace", fontSize:12, minWidth:180 }}>
                      <div style={{ fontWeight:700, fontSize:14, marginBottom:6 }}>{gf.name}</div>
                      <div>State: {gf.state}</div>
                      <div>Risk: <b style={{color:zoneColor[gf.risk_level]}}>{gf.risk_level.toUpperCase()}</b></div>
                      <div>Radius: {(gf.radius_m/1000).toFixed(1)} km</div>
                      <div>Tourists: {gf.current_count}/{gf.max_capacity}</div>
                      <div style={{ marginTop:6, fontSize:11, color:"#888" }}>Entry: {gf.entry_point}</div>
                      <button onClick={() => handleDelete(gf.id)}
                        style={{ marginTop:8, width:"100%", background:"#660000", border:"none",
                                 borderRadius:4, padding:"5px", color:"#ffaaaa", fontSize:11, cursor:"pointer" }}>
                        Delete Zone
                      </button>
                    </div>
                  </Popup>
                </Circle>
                <Marker position={[gf.lat, gf.lng]} icon={makeIcon(
                  gf.risk_level==="high"?"red":gf.risk_level==="medium"?"orange":"blue"
                )}>
                  <Popup><b>{gf.name}</b><br/>{gf.state}</Popup>
                </Marker>
              </React.Fragment>
            ))}

            {/* Preview new zone while creating */}
            {createMode && (
              <>
                <Circle center={[newZone.center_lat, newZone.center_lng]}
                  radius={newZone.radius_meters}
                  pathOptions={{
                    color: activeColor, fillColor: activeColor,
                    fillOpacity: 0.2, weight: 2.5, dashArray: "8 6"
                  }}/>
                <Marker position={[newZone.center_lat, newZone.center_lng]}
                  icon={makeIcon("green")}>
                  <Popup><b>New: {newZone.name||"Unnamed"}</b><br/>
                    {newZone.zone_type.toUpperCase()} zone<br/>
                    Radius: {(newZone.radius_meters/1000).toFixed(1)}km
                  </Popup>
                </Marker>
              </>
            )}
          </MapContainer>
        </div>

        {/* Zone detail panel */}
        {!createMode && selected && (
          <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:10, padding:14 }}>
            <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:10 }}>
              <div style={{ fontSize:14, fontWeight:700, color:C.textPrimary }}>{selected.name}</div>
              <div style={{ display:"flex", gap:8 }}>
                <button onClick={() => onFlyTo(selected.lat, selected.lng)}
                  style={{ background:C.accentGlow, border:`1px solid ${C.accent}`,
                           borderRadius:6, padding:"4px 10px", color:C.accent, fontSize:11, cursor:"pointer" }}>
                  🗺️ Zoom
                </button>
                <button onClick={() => handleDelete(selected.id)}
                  style={{ background:"rgba(255,61,61,0.1)", border:"1px solid rgba(255,61,61,0.3)",
                           borderRadius:6, padding:"4px 10px", color:C.red, fontSize:11, cursor:"pointer" }}>
                  🗑️ Delete
                </button>
              </div>
            </div>
            <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:8 }}>
              <StatCard label="TOURISTS" value={`${selected.current_count}/${selected.max_capacity}`} accent={C.accent}/>
              <StatCard label="RADIUS" value={`${(selected.radius_m/1000).toFixed(1)}km`} accent={C.teal}/>
              <StatCard label="RISK" value={selected.risk_level.toUpperCase()} accent={riskColor[selected.risk_level]}/>
              <StatCard label="STATE" value={selected.state.split(" ")[0]} accent={C.amber}/>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};


const TabAnalytics: React.FC<{ tourists:Tourist[]; sosList:SOSAlert[]; geofences:Geofence[] }> = ({ tourists, sosList, geofences }) => {
  const byStatus = ["safe","warning","sos","offline"].map(s => ({
    label: s, count: tourists.filter(t => t.status === s).length,
    color: s==="safe"?C.green:s==="warning"?C.amber:s==="sos"?C.red:C.textDim
  }));

  const weeklyData = [
    { day:"Mon", tourists:38, sos:1 },
    { day:"Tue", tourists:44, sos:0 },
    { day:"Wed", tourists:52, sos:2 },
    { day:"Thu", tourists:61, sos:1 },
    { day:"Fri", tourists:74, sos:3 },
    { day:"Sat", tourists:89, sos:2 },
    { day:"Sun", tourists:tourists.length, sos:sosList.length },
  ];
  const maxWeekly = Math.max(...weeklyData.map(d => d.tourists));

  const natData = tourists.reduce((acc, t) => {
    acc[t.nationality] = (acc[t.nationality] || 0) + 1; return acc;
  }, {} as Record<string,number>);

  return (
    <div>
      <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:12, marginBottom:24 }}>
        <StatCard label="TOTAL TOURISTS" value={tourists.length} sub="Currently tracked" accent={C.accent}/>
        <StatCard label="OPEN SOS" value={sosList.filter(s=>s.status!=="resolved").length} sub={`${sosList.filter(s=>s.status==="active").length} critical`} accent={C.red}/>
        <StatCard label="ZONES MONITORED" value={geofences.length} sub={`${geofences.filter(g=>g.risk_level==="high").length} high risk`} accent={C.amber}/>
        <StatCard label="RESOLUTION RATE" value="76%" sub="Avg response 8 min" accent={C.green}/>
      </div>

      <div style={{ display:"grid", gridTemplateColumns:"2fr 1fr", gap:16, marginBottom:16 }}>
        {/* Weekly bar chart */}
        <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:"16px 14px" }}>
          <SectionTitle title="Daily Tourist Traffic — This Week"/>
          <div style={{ display:"flex", gap:5, alignItems:"flex-end", height:140 }}>
            {weeklyData.map(d => (
              <div key={d.day} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:4 }}>
                <span style={{ fontSize:10, color:C.textSecondary }}>{d.tourists}</span>
                <div style={{ width:"100%", position:"relative", height:110 }}>
                  <div style={{ position:"absolute", bottom:0, width:"100%", background:`${C.accent}88`, borderRadius:"3px 3px 0 0", height:`${(d.tourists/maxWeekly)*100}%`, transition:"height 1s ease" }}/>
                  {d.sos > 0 && <div style={{ position:"absolute", bottom:0, width:"100%", background:C.red, borderRadius:2, height:d.sos*5 }}/>}
                </div>
                <span style={{ fontSize:10, color:C.textDim }}>{d.day}</span>
              </div>
            ))}
          </div>
          <div style={{ display:"flex", gap:12, marginTop:10, fontSize:10, color:C.textDim }}>
            <span><span style={{ display:"inline-block", width:8, height:8, background:C.accent, borderRadius:2, marginRight:4 }}/>Tourists</span>
            <span><span style={{ display:"inline-block", width:8, height:8, background:C.red, borderRadius:2, marginRight:4 }}/>SOS</span>
          </div>
        </div>

        {/* Status pie */}
        <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:16 }}>
          <SectionTitle title="Tourist Status"/>
          {byStatus.map(s => (
            <div key={s.label} style={{ marginBottom:10 }}>
              <div style={{ display:"flex", justifyContent:"space-between", fontSize:11, color:C.textSecondary, marginBottom:4 }}>
                <span style={{ textTransform:"capitalize" }}>{s.label}</span>
                <span style={{ color:s.color }}>{s.count}</span>
              </div>
              <div style={{ height:6, background:"rgba(255,255,255,0.06)", borderRadius:3 }}>
                <div style={{ width:`${tourists.length>0?(s.count/tourists.length)*100:0}%`, height:"100%", background:s.color, borderRadius:3, transition:"width 1s ease" }}/>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Nationality + Zone load */}
      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:16 }}>
        <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:16 }}>
          <SectionTitle title="Nationality Distribution"/>
          {Object.entries(natData).sort((a,b)=>b[1]-a[1]).map(([nat, count]) => (
            <div key={nat} style={{ marginBottom:9 }}>
              <div style={{ display:"flex", justifyContent:"space-between", fontSize:11, color:C.textSecondary, marginBottom:4 }}>
                <span>{nat}</span><span>{count}</span>
              </div>
              <div style={{ height:4, background:"rgba(255,255,255,0.06)", borderRadius:3 }}>
                <div style={{ width:`${(count/tourists.length)*100}%`, height:"100%", background:C.accent, borderRadius:3, opacity:0.7 }}/>
              </div>
            </div>
          ))}
        </div>
        <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:16 }}>
          <SectionTitle title="Zone Occupancy"/>
          {geofences.sort((a,b)=>b.current_count-a.current_count).map(gf => {
            const pct = (gf.current_count / gf.max_capacity) * 100;
            const col = pct > 80 ? C.red : pct > 50 ? C.amber : C.green;
            return (
              <div key={gf.id} style={{ marginBottom:9 }}>
                <div style={{ display:"flex", justifyContent:"space-between", fontSize:11, color:C.textSecondary, marginBottom:4 }}>
                  <span>{gf.name.split(" ").slice(0,2).join(" ")}</span>
                  <span style={{ color:col }}>{gf.current_count}/{gf.max_capacity}</span>
                </div>
                <div style={{ height:4, background:"rgba(255,255,255,0.06)", borderRadius:3 }}>
                  <div style={{ width:`${pct}%`, height:"100%", background:col, borderRadius:3 }}/>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

// ─── TAB: SETTINGS ────────────────────────────────────────────
const TabSettings: React.FC<{ apiUrl:string; setApiUrl:(v:string)=>void }> = ({ apiUrl, setApiUrl }) => {
  const [localApi, setLocalApi] = useState(apiUrl);
  const [saved, setSaved] = useState(false);
  const [thresholds, setThresholds] = useState({ fall:3.8, battery:15, offline:60 });
  const [notifs, setNotifs] = useState({ sos:true, offline:true, geofence:true, battery:false });

  const save = () => {
    setApiUrl(localApi);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  };

  return (
    <div style={{ maxWidth:680 }}>
      <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:20, marginBottom:16 }}>
        <SectionTitle title="Backend Connection"/>
        <div style={{ marginBottom:12 }}>
          <div style={{ fontSize:11, color:C.textSecondary, marginBottom:6 }}>FastAPI Base URL — update each session with: <code style={{ color:C.accent }}>{"hostname -I | awk '{print $1}'"}</code></div>
          <input value={localApi} onChange={e => setLocalApi(e.target.value)}
            style={{ width:"100%", background:C.bg0, border:`1px solid ${C.border}`, borderRadius:8, padding:"9px 12px", color:C.textPrimary, fontSize:13, outline:"none", fontFamily:"monospace", boxSizing:"border-box" }}/>
        </div>
        <div style={{ display:"flex", gap:10, alignItems:"center" }}>
          <button onClick={save} style={{ background:saved?"rgba(0,230,118,0.1)":C.accentGlow, border:`1px solid ${saved?C.green:C.accent}`, borderRadius:6, padding:"7px 16px", color:saved?C.green:C.accent, fontSize:12, cursor:"pointer", fontWeight:600, transition:"all 0.3s" }}>
            {saved ? "✓ Saved" : "Save & Apply"}
          </button>
          <div style={{ fontSize:11, color:C.green, display:"flex", alignItems:"center", gap:5 }}>
            <div style={{ width:6, height:6, borderRadius:"50%", background:C.green }}/>Connected (live data)
          </div>
        </div>
      </div>

      <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:20, marginBottom:16 }}>
        <SectionTitle title="Alert Thresholds"/>
        {[
          { key:"fall" as const, label:"Fall Detection (g-force)", min:2, max:5, step:0.1 },
          { key:"battery" as const, label:"Low Battery Alert (%)", min:5, max:30, step:1 },
          { key:"offline" as const, label:"Offline Trigger (minutes)", min:15, max:180, step:5 },
        ].map(f => (
          <div key={f.key} style={{ marginBottom:14 }}>
            <div style={{ display:"flex", justifyContent:"space-between", fontSize:12, color:C.textSecondary, marginBottom:6 }}>
              <span>{f.label}</span>
              <span style={{ color:C.accent, fontFamily:"monospace" }}>{thresholds[f.key]}</span>
            </div>
            <input type="range" min={f.min} max={f.max} step={f.step} value={thresholds[f.key]}
              onChange={e => setThresholds(p => ({ ...p, [f.key]: parseFloat(e.target.value) }))}
              style={{ width:"100%", accentColor:C.accent }}/>
          </div>
        ))}
      </div>

      <div style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:12, padding:20, marginBottom:16 }}>
        <SectionTitle title="Notifications"/>
        {[
          { key:"sos" as const, label:"SOS Alerts", desc:"Immediate notification for all SOS" },
          { key:"offline" as const, label:"Device Offline", desc:"When tourist goes offline" },
          { key:"geofence" as const, label:"Geofence Violations", desc:"Zone entry/exit alerts" },
          { key:"battery" as const, label:"Low Battery", desc:"Tourist device below threshold" },
        ].map(n => (
          <div key={n.key} style={{ display:"flex", justifyContent:"space-between", alignItems:"center", padding:"10px 0", borderBottom:`1px solid ${C.border}` }}>
            <div>
              <div style={{ fontSize:13, color:C.textPrimary }}>{n.label}</div>
              <div style={{ fontSize:11, color:C.textDim }}>{n.desc}</div>
            </div>
            <div onClick={() => setNotifs(p => ({ ...p, [n.key]: !p[n.key] }))}
              style={{ width:40, height:22, borderRadius:11, background:notifs[n.key]?C.accent:"#333", cursor:"pointer", position:"relative", transition:"background 0.2s", flexShrink:0 }}>
              <div style={{ width:16, height:16, borderRadius:"50%", background:"#fff", position:"absolute", top:3, left:notifs[n.key]?21:3, transition:"left 0.2s" }}/>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ─── MAIN APP ─────────────────────────────────────────────────
const TABS = [
  { id:"dashboard", label:"Command Center", icon:"⊞" },
  { id:"map",       label:"Live Map",       icon:"◎" },
  { id:"tourists",  label:"Tourists",       icon:"⊕" },
  { id:"geofences", label:"Geofences",      icon:"⬡" },
  { id:"sos",       label:"SOS Alerts",     icon:"△" },
  { id:"analytics", label:"Analytics",      icon:"⊿" },
  { id:"settings",  label:"Settings",       icon:"⚙" },
];

export default function App() {
  const [tab, setTab] = useState("dashboard");
  const [tourists, setTourists] = useState<Tourist[]>(MOCK_TOURISTS);
  const [sosList, setSosList] = useState<SOSAlert[]>(MOCK_SOS);
  const [geofences, setGeofences] = useState<Geofence[]>(MOCK_GEOFENCES);
  const [apiUrl, setApiUrl] = useState(API);
  const [selectedTourist, setSelectedTourist] = useState<Tourist|null>(null);
  const [selectedSOS, setSelectedSOS] = useState<SOSAlert|null>(null);
  const [mapFlyTarget, setMapFlyTarget] = useState<{lat:number;lng:number}|null>(null);
  const [time, setTime] = useState(new Date());
  const [flash, setFlash] = useState(true);
  const wsRef = useRef<Socket|null>(null);

  // Clock
  useEffect(() => { const t = setInterval(() => setTime(new Date()), 1000); return () => clearInterval(t); }, []);
  useEffect(() => { const t = setInterval(() => setFlash(f=>!f), 900); return () => clearInterval(t); }, []);

  // Auto-login to get token
  useEffect(() => {
    const autoLogin = async () => {
      try {
        if (!localStorage.getItem("v2_token")) {
          const res = await axios.post(`${apiUrl}/api/auth/login`, {
            email: "ai@test.com", password: "Test@123"
          });
          if (res.data?.token) {
            localStorage.setItem("v2_token", res.data.token);
            console.log("Auto-logged in!");
          }
        }
      } catch(e) { console.log("Auto-login failed", e); }
    };
    autoLogin();
  }, [apiUrl]);

  // Fetch from backend (falls back to mock silently)
  const fetchData = useCallback(async () => {
    try {
      // Auto-login if no token
      let token = localStorage.getItem("v2_token") || "";
      if (!token) {
        try {
          const loginRes = await axios.post(`${apiUrl}/api/auth/login`,
            { email: "ai@test.com", password: "Test@123" },
            { timeout: 5000 }
          );
          token = loginRes.data?.token || "";
          if (token) localStorage.setItem("v2_token", token);
        } catch(e) { console.log("Auto-login failed"); }
      }
      const headers = token ? { Authorization: `Bearer ${token}` } : {};
      const [tRes, sRes, gRes] = await Promise.all([
        axios.get(`${apiUrl}/api/tourists/active`, { timeout:10000, headers }),
        axios.get(`${apiUrl}/api/sos/all`, { timeout:10000, headers }),
        axios.get(`${apiUrl}/api/geofence/`, { timeout:10000, headers }),
      ]);
      if (tRes.data?.length) {
        const mapped = tRes.data.map((t: any) => ({
          id: t.id,
          name: t.name || "Unknown",
          email: t.email || "",
          phone: t.phone || t.emergency_contact || "",
          nationality: t.nationality || "Unknown",
          current_lat: t.current_lat || 26.2,
          current_lng: t.current_lng || 92.9,
          current_location_name: t.location_name || `${(t.current_lat||26.2).toFixed(4)}, ${(t.current_lng||92.9).toFixed(4)}`,
          last_seen: t.last_seen ? new Date(t.last_seen).toLocaleTimeString() : "Unknown",
          status: t.current_lat ? "safe" : "offline",
          battery_pct: t.battery_pct || 100,
          emergency_contact: t.emergency_contact || "Not set",
          joined: t.created_at ? new Date(t.created_at).toLocaleDateString() : "",
        }));
        setTourists(mapped);
      }
      if (sRes.data?.length) {
        const mappedSOS = sRes.data.map((s: any) => ({
          id: s.id,
          tourist_id: s.tourist_id || "",
          tourist_name: s.tourist_name || "Unknown",
          type: s.alert_type || "SOS",
          severity: s.severity || "high",
          status: s.status || "active",
          lat: s.latitude || 26.2,
          lng: s.longitude || 92.9,
          location_name: s.location_name || "Unknown location",
          description: s.ai_triage?.triage_summary || s.message || "Emergency alert",
          responder: s.assigned_to || undefined,
          created_at: s.created_at ? new Date(s.created_at).toLocaleTimeString() : "",
          equipment: s.ai_triage?.equipment_recommendations?.map((e: any) => e.equipment || e) || [],
        }));
        setSosList(mappedSOS);
      }
      if (gRes.data?.length) {
        const mappedGF = gRes.data.map((g: any) => ({
          id: g.id,
          name: g.name,
          state: g.state || "NE India",
          lat: g.center_lat || 26.2,
          lng: g.center_lng || 92.9,
          radius_m: g.radius_meters || 5000,
          risk_level: g.zone_type === "red" ? "high" : g.zone_type === "amber" ? "medium" : "low",
          max_capacity: g.max_capacity || 100,
          current_count: g.current_count || 0,
          entry_point: g.description || "Main entrance",
          alert_rules: [`${g.zone_type?.toUpperCase()} zone — alerts active`],
        }));
        setGeofences(mappedGF);
      }
    } catch {
      // Backend offline — mock data stays
    }
  }, [apiUrl]);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 15000);
    return () => clearInterval(interval);
  }, [fetchData]);

  // WebSocket for live updates
  useEffect(() => {
    try {
      const socket = io(apiUrl, { transports:["websocket"], timeout:10000, reconnection:true });
      wsRef.current = socket;
      socket.on("sos_alert", (data: SOSAlert) => {
        setSosList(prev => [data, ...prev.filter(s => s.id !== data.id)]);
      });
      socket.on("tourist_update", (data: Tourist) => {
        setTourists(prev => prev.map(t => t.id === data.id ? data : t));
      });
      return () => { socket.disconnect(); };
    } catch { /* mock mode */ }
  }, [apiUrl]);

  // Actions
  const handleResolve = async (sosId: string) => {
    try {
      await axios.put(`${apiUrl}/api/sos/${sosId}/resolve`, { status: "resolved", assigned_to: "Officer Dispatched" });
    } catch {}
    setSosList(prev => prev.map(s => s.id === sosId ? { ...s, status:"resolved" } : s));
  };

  const handleDispatch = async (sosId: string) => {
    try {
      await axios.put(`${apiUrl}/api/sos/${sosId}/resolve`, { status: "responding", assigned_to: "Officer Dispatched" });
    } catch {}
    setSosList(prev => prev.map(s => s.id === sosId ? { ...s, status:"responding", responder:"Officer Dispatched" } : s));
  };

  const navigateTo = (newTab: string, ctx?: { tourist?:Tourist; sos?:SOSAlert; fly?:{lat:number;lng:number} }) => {
    if (ctx?.tourist) setSelectedTourist(ctx.tourist);
    if (ctx?.sos) setSelectedSOS(ctx.sos);
    if (ctx?.fly) setMapFlyTarget(ctx.fly);
    setTab(newTab);
  };

  const activeSos = sosList.filter(s => s.status === "active").length;

  // ─── DASHBOARD TAB ──────────────────────────────────────────
  const renderDashboard = () => (
    <div>
      {activeSos > 0 && (
        <div onClick={() => setTab("sos")}
          style={{ background:"rgba(255,61,61,0.07)", border:"1px solid rgba(255,61,61,0.35)", borderRadius:10, padding:"11px 16px", marginBottom:20, display:"flex", alignItems:"center", justifyContent:"space-between", cursor:"pointer" }}>
          <div style={{ display:"flex", alignItems:"center", gap:10 }}>
            <div style={{ width:9, height:9, borderRadius:"50%", background:C.red, boxShadow:flash?`0 0 12px ${C.red}`:"none", transition:"box-shadow 0.3s" }}/>
            <span style={{ color:C.red, fontWeight:700, fontSize:13, letterSpacing:0.4 }}>
              ACTIVE EMERGENCY — {activeSos} SOS ALERT{activeSos>1?"S":""} NEED ATTENTION
            </span>
          </div>
          <span style={{ color:C.red, fontSize:11, opacity:0.7 }}>View SOS →</span>
        </div>
      )}

      <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:12, marginBottom:22 }}>
        <StatCard label="ACTIVE TOURISTS" value={tourists.length} sub="Across 6 zones" accent={C.accent}/>
        <StatCard label="SOS ALERTS" value={sosList.filter(s=>s.status!=="resolved").length} sub={`${activeSos} critical`} accent={C.red}/>
        <StatCard label="OFFLINE DEVICES" value={tourists.filter(t=>t.status==="offline").length} sub="Last 90+ min" accent={C.amber}/>
        <StatCard label="HIGH RISK ZONES" value={geofences.filter(g=>g.risk_level==="high").length} sub="Needs monitoring" accent={C.pink}/>
      </div>

      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:16 }}>
        {/* Zones */}
        <div>
          <SectionTitle title="Zone Status"/>
          {geofences.map(gf => (
            <div key={gf.id} onClick={() => navigateTo("geofences")}
              style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:8, padding:"10px 12px", marginBottom:7, cursor:"pointer", display:"flex", justifyContent:"space-between", alignItems:"center" }}
              onMouseEnter={e => (e.currentTarget as HTMLElement).style.borderColor=C.borderHot}
              onMouseLeave={e => (e.currentTarget as HTMLElement).style.borderColor=C.border}>
              <div>
                <div style={{ fontSize:12, fontWeight:600, color:C.textPrimary }}>{gf.name}</div>
                <div style={{ fontSize:11, color:C.textSecondary }}>{gf.state} · {gf.current_count} tourists</div>
              </div>
              <Badge label={gf.risk_level}/>
            </div>
          ))}
        </div>

        {/* Recent SOS */}
        <div>
          <SectionTitle title="Recent SOS Events"/>
          {sosList.length === 0 && <div style={{ color:C.green, fontSize:12 }}>✓ No active alerts</div>}
          {sosList.map(s => (
            <div key={s.id} onClick={() => navigateTo("sos", { sos:s })}
              style={{ background:C.bg2, border:`1px solid ${s.severity==="critical"?"rgba(255,61,61,0.3)":C.border}`, borderRadius:8, padding:"10px 12px", marginBottom:7, cursor:"pointer", display:"flex", gap:10, alignItems:"flex-start" }}
              onMouseEnter={e => (e.currentTarget as HTMLElement).style.borderColor=C.borderHot}
              onMouseLeave={e => (e.currentTarget as HTMLElement).style.borderColor=s.severity==="critical"?"rgba(255,61,61,0.3)":C.border}>
              <div style={{ width:8, height:8, borderRadius:"50%", background:s.status==="active"?C.red:s.status==="responding"?C.amber:"#555", marginTop:4, flexShrink:0, boxShadow:s.status==="active"&&flash?`0 0 8px ${C.red}`:"none" }}/>
              <div style={{ flex:1 }}>
                <div style={{ fontSize:12, fontWeight:600, color:C.textPrimary }}>{s.tourist_name}</div>
                <div style={{ fontSize:11, color:C.textSecondary }}>{s.type} · {s.location_name}</div>
              </div>
              <div style={{ display:"flex", flexDirection:"column", gap:4, alignItems:"flex-end" }}>
                <Badge label={s.status}/>
                <span style={{ fontSize:10, color:C.textDim }}>{s.created_at}</span>
              </div>
            </div>
          ))}

          <SectionTitle title="Tourists Needing Attention" sub=""/>
          {tourists.filter(t => t.status !== "safe").map(t => (
            <div key={t.id} onClick={() => navigateTo("tourists", { tourist:t })}
              style={{ background:C.bg2, border:`1px solid ${C.border}`, borderRadius:8, padding:"9px 12px", marginBottom:6, cursor:"pointer", display:"flex", gap:10, alignItems:"center" }}
              onMouseEnter={e => (e.currentTarget as HTMLElement).style.borderColor=C.borderHot}
              onMouseLeave={e => (e.currentTarget as HTMLElement).style.borderColor=C.border}>
              <div style={{ fontSize:20 }}>{t.nationality==="USA"?"🇺🇸":t.nationality==="Japan"?"🇯🇵":t.nationality==="Germany"?"🇩🇪":t.nationality==="France"?"🇫🇷":t.nationality==="UK"?"🇬🇧":t.nationality==="India"?"🇮🇳":"🌍"}</div>
              <div style={{ flex:1 }}>
                <div style={{ fontSize:12, fontWeight:600, color:C.textPrimary }}>{t.name}</div>
                <div style={{ fontSize:11, color:C.textSecondary }}>{t.current_location_name} · 🔋{t.battery_pct}%</div>
              </div>
              <Badge label={t.status}/>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const renderTab = () => {
    switch (tab) {
      case "dashboard": return renderDashboard();
      case "map": return (
        <TabMap
          tourists={tourists}
          sosList={sosList}
          geofences={geofences}
          onSelectTourist={t => navigateTo("tourists", { tourist:t })}
          onResolve={handleResolve}
          onDispatch={handleDispatch}
        />
      );
      case "tourists": return (
        <TabTourists
          tourists={tourists}
          selected={selectedTourist}
          onSelect={setSelectedTourist}
          onFlyTo={t => navigateTo("map", { fly:{ lat:t.current_lat, lng:t.current_lng } })}
        />
      );
      case "geofences": return <TabGeofences geofences={geofences} onFlyTo={(lat,lng) => navigateTo("map", { fly:{lat,lng} })} apiUrl={apiUrl} onRefresh={fetchData}/>;
      case "sos": return (
        <TabSOS
          sosList={sosList}
          preselected={selectedSOS}
          onResolve={handleResolve}
          onDispatch={handleDispatch}
          onFlyTo={(lat,lng) => navigateTo("map", { fly:{lat,lng} })}
        />
      );
      case "analytics": return <TabAnalytics tourists={tourists} sosList={sosList} geofences={geofences}/>;
      case "settings": return <TabSettings apiUrl={apiUrl} setApiUrl={setApiUrl}/>;
      default: return null;
    }
  };

  return (
    <div style={{ display:"flex", height:"100vh", background:C.bg0, color:C.textPrimary, fontFamily:"'JetBrains Mono','Courier New',monospace", overflow:"hidden" }}>
      {/* Sidebar */}
      <div style={{ width:196, background:C.bg1, borderRight:`1px solid ${C.border}`, display:"flex", flexDirection:"column", flexShrink:0 }}>
        <div style={{ padding:"16px 14px", borderBottom:`1px solid ${C.border}` }}>
          <div style={{ fontSize:12, fontWeight:900, color:C.accent, letterSpacing:1.2 }}>TOURSAFE360</div>
          <div style={{ fontSize:8, color:C.textDim, letterSpacing:1.5, marginTop:2 }}>NE INDIA COMMAND v2</div>
        </div>
        <div style={{ padding:"10px 12px", borderBottom:`1px solid ${C.border}` }}>
          <div style={{ fontSize:17, fontWeight:700, color:C.textPrimary, fontFamily:"monospace" }}>{time.toLocaleTimeString()}</div>
          <div style={{ fontSize:9, color:C.textDim }}>{time.toLocaleDateString("en-IN",{day:"2-digit",month:"short",year:"numeric"})}</div>
          <div style={{ display:"flex", alignItems:"center", gap:5, marginTop:5 }}>
            <div style={{ width:5, height:5, borderRadius:"50%", background:C.green, boxShadow:`0 0 5px ${C.green}` }}/>
            <span style={{ fontSize:9, color:C.green }}>System Online</span>
          </div>
        </div>
        <nav style={{ flex:1, padding:"10px 8px", overflowY:"auto" }}>
          {TABS.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)}
              style={{ width:"100%", background:tab===t.id?`${C.accent}18`:"transparent", border:`1px solid ${tab===t.id?C.accent:C.border}`, borderRadius:7, padding:"8px 10px", color:tab===t.id?C.accent:C.textSecondary, fontSize:11, fontWeight:tab===t.id?700:400, cursor:"pointer", textAlign:"left", marginBottom:3, display:"flex", alignItems:"center", gap:8, transition:"all 0.12s", position:"relative" }}>
              <span>{t.icon}</span>{t.label}
              {t.id==="sos" && activeSos>0 && (
                <span style={{ position:"absolute", right:8, background:C.red, color:"#fff", fontSize:9, fontWeight:800, borderRadius:"50%", width:15, height:15, display:"flex", alignItems:"center", justifyContent:"center", boxShadow:flash?`0 0 6px ${C.red}`:"none" }}>{activeSos}</span>
              )}
            </button>
          ))}
        </nav>
        <div style={{ padding:"10px 14px", borderTop:`1px solid ${C.border}` }}>
          <div style={{ fontSize:11, color:C.textPrimary, fontWeight:600 }}>Officer PL-2847</div>
          <div style={{ fontSize:9, color:C.textDim }}>District Control Center</div>
        </div>
      </div>

      {/* Main */}
      <div style={{ flex:1, display:"flex", flexDirection:"column", overflow:"hidden" }}>
        <div style={{ padding:"12px 22px", borderBottom:`1px solid ${C.border}`, background:C.bg1, display:"flex", justifyContent:"space-between", alignItems:"center", flexShrink:0 }}>
          <div>
            <div style={{ fontSize:14, fontWeight:700, color:C.textPrimary }}>{TABS.find(t=>t.id===tab)?.label}</div>
            <div style={{ fontSize:9, color:C.textDim }}>TourSafe360 · Northeast India Tourism Safety Platform</div>
          </div>
          <div style={{ display:"flex", gap:10, alignItems:"center" }}>
            {activeSos > 0 && (
              <div onClick={() => setTab("sos")} style={{ background:"rgba(255,61,61,0.1)", border:"1px solid rgba(255,61,61,0.3)", borderRadius:6, padding:"4px 10px", fontSize:11, color:C.red, cursor:"pointer", display:"flex", alignItems:"center", gap:5 }}>
                <div style={{ width:5, height:5, borderRadius:"50%", background:C.red, boxShadow:flash?`0 0 6px ${C.red}`:"none" }}/>
                {activeSos} ACTIVE SOS
              </div>
            )}
            <span style={{ fontSize:10, color:C.textDim }}>{tourists.length} tourists tracked</span>
          </div>
        </div>
        <div style={{ flex:1, overflowY:"auto", padding:"18px 22px" }}>
          {renderTab()}
        </div>
      </div>
    </div>
  );
}
