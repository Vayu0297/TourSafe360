import React, { useState, useEffect, useRef } from "react";
import { MapContainer, TileLayer, Circle, Marker, Popup, useMapEvents } from "react-leaflet";
import L from "leaflet";
import axios from "axios";

const ZONE_COLORS: Record<string,string> = {
  green: "#22c55e",
  amber: "#f97316",
  red: "#ef4444",
  restricted: "#7c3aed",
};

const ZONE_LABELS: Record<string,string> = {
  green: "Safe Zone",
  amber: "Caution Zone",
  red: "Danger Zone",
  restricted: "Restricted Zone",
};

const NE_INDIA_STATES = ["Assam","Meghalaya","Manipur","Mizoram","Nagaland","Tripura","Arunachal Pradesh","Sikkim"];

interface Props {
  API: string;
  tourists: any[];
  liveSignals: any[];
  geofences: any[];
  onRefresh: () => void;
}

function MapClickHandler({ onMapClick }: { onMapClick: (lat:number,lng:number)=>void }) {
  useMapEvents({ click(e) { onMapClick(e.latlng.lat, e.latlng.lng); } });
  return null;
}

export default function GeofenceManager({ API, tourists, liveSignals, geofences, onRefresh }: Props) {
  const [mode, setMode] = useState<"view"|"create">("view");
  const [editZone, setEditZone] = useState<any>(null);
  const [form, setForm] = useState({
    name:"", zone_type:"green", state:"Assam",
    center_lat:26.2006, center_lng:92.9376,
    radius_meters:5000, description:""
  });
  const [loading, setLoading] = useState(false);
  const [placing, setPlacing] = useState(false);
  const [msg, setMsg] = useState("");

  const update = (k: string, v: any) => setForm(f=>({...f,[k]:v}));

  const handleMapClick = (lat: number, lng: number) => {
    if (!placing) return;
    update("center_lat", lat);
    update("center_lng", lng);
    setPlacing(false);
    setMsg(`Center set: ${lat.toFixed(5)}, ${lng.toFixed(5)}`);
  };

  const handleCreate = async () => {
    if (!form.name) { setMsg("Please enter a zone name"); return; }
    setLoading(true);
    try {
      await axios.post(`${API}/api/geofence/`, form);
      setMsg("✅ Geofence created!");
      setMode("view");
      setForm({name:"",zone_type:"green",state:"Assam",center_lat:26.2006,center_lng:92.9376,radius_meters:5000,description:""});
      onRefresh();
    } catch(e) {
      setMsg("❌ Failed to create geofence");
    }
    setLoading(false);
  };

  const handleDelete = async (id: string, name: string) => {
    if (!window.confirm(`Delete zone "${name}"?`)) return;
    try {
      await axios.delete(`${API}/api/geofence/${id}`);
      setMsg(`✅ "${name}" deleted`);
      onRefresh();
    } catch(e) {
      setMsg("❌ Delete failed");
    }
  };

  const handleToggle = async (zone: any) => {
    try {
      await axios.put(`${API}/api/geofence/${zone.id}`, { active: !zone.active });
      setMsg(`${!zone.active ? "✅ Activated" : "⏸ Deactivated"}: ${zone.name}`);
      onRefresh();
    } catch(e) {}
  };

  const allZones = [...geofences];

  return (
    <div style={{display:"grid",gridTemplateColumns:"320px 1fr",gap:16,height:"calc(100vh-160px)"}}>

      {/* Left Panel */}
      <div style={{display:"flex",flexDirection:"column",gap:12,overflow:"auto"}}>

        {/* Mode buttons */}
        <div style={{display:"flex",gap:8}}>
          <button onClick={()=>setMode("view")}
            style={{flex:1,padding:"10px 0",borderRadius:12,border:"none",cursor:"pointer",
                    background:mode==="view"?"linear-gradient(135deg,#6c63ff,#a855f7)":"#f0e8ff",
                    color:mode==="view"?"#fff":"#6c63ff",fontWeight:700,fontSize:13}}>
            View Zones
          </button>
          <button onClick={()=>setMode("create")}
            style={{flex:1,padding:"10px 0",borderRadius:12,border:"none",cursor:"pointer",
                    background:mode==="create"?"linear-gradient(135deg,#22c55e,#16a34a)":"#ecfdf5",
                    color:mode==="create"?"#fff":"#059669",fontWeight:700,fontSize:13}}>
            + Create Zone
          </button>
        </div>

        {msg && (
          <div style={{background:msg.includes("✅")?"#ecfdf5":"#fef2f2",borderRadius:10,
                       padding:"8px 12px",fontSize:12,color:msg.includes("✅")?"#059669":"#ef4444"}}>
            {msg}
          </div>
        )}

        {/* CREATE FORM */}
        {mode==="create" && (
          <div style={{background:"#fff",borderRadius:20,padding:18,boxShadow:"0 4px 20px rgba(108,99,255,0.1)"}}>
            <h3 style={{margin:"0 0 14px",color:"#333",fontSize:15}}>Create New Geofence</h3>

            <div style={{marginBottom:10}}>
              <label style={{fontSize:12,color:"#888",display:"block",marginBottom:4}}>Zone Name *</label>
              <input value={form.name} onChange={e=>update("name",e.target.value)}
                placeholder="e.g. Kaziranga Buffer Zone"
                style={{width:"100%",padding:"10px 12px",borderRadius:10,border:"2px solid #e8d5ff",
                        fontSize:13,boxSizing:"border-box",color:"#333"}}/>
            </div>

            <div style={{marginBottom:10}}>
              <label style={{fontSize:12,color:"#888",display:"block",marginBottom:4}}>Zone Type</label>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:6}}>
                {Object.entries(ZONE_LABELS).map(([type,label])=>(
                  <button key={type} onClick={()=>update("zone_type",type)}
                    style={{padding:"8px 6px",borderRadius:10,border:`2px solid ${form.zone_type===type?ZONE_COLORS[type]:"#e8d5ff"}`,
                            background:form.zone_type===type?ZONE_COLORS[type]+"22":"#fff",
                            color:form.zone_type===type?ZONE_COLORS[type]:"#888",
                            cursor:"pointer",fontSize:11,fontWeight:700}}>
                    {type==="green"?"🟢":type==="amber"?"🟡":type==="red"?"🔴":"🟣"} {label}
                  </button>
                ))}
              </div>
            </div>

            <div style={{marginBottom:10}}>
              <label style={{fontSize:12,color:"#888",display:"block",marginBottom:4}}>State</label>
              <select value={form.state} onChange={e=>update("state",e.target.value)}
                style={{width:"100%",padding:"10px 12px",borderRadius:10,border:"2px solid #e8d5ff",fontSize:13,color:"#333"}}>
                {NE_INDIA_STATES.map(s=><option key={s}>{s}</option>)}
              </select>
            </div>

            <div style={{marginBottom:10}}>
              <label style={{fontSize:12,color:"#888",display:"block",marginBottom:4}}>
                Radius: {form.radius_meters >= 1000 ? (form.radius_meters/1000).toFixed(1)+"km" : form.radius_meters+"m"}
              </label>
              <input type="range" min={500} max={50000} step={500} value={form.radius_meters}
                onChange={e=>update("radius_meters",parseInt(e.target.value))}
                style={{width:"100%",accentColor:"#6c63ff"}}/>
              <div style={{display:"flex",justifyContent:"space-between",fontSize:11,color:"#aaa"}}>
                <span>500m</span><span>50km</span>
              </div>
            </div>

            <div style={{marginBottom:10}}>
              <label style={{fontSize:12,color:"#888",display:"block",marginBottom:4}}>Center Location</label>
              <div style={{display:"flex",gap:6,marginBottom:6}}>
                <input value={form.center_lat.toFixed(5)} readOnly
                  style={{flex:1,padding:"8px 10px",borderRadius:8,border:"1px solid #e8d5ff",fontSize:12,color:"#555",background:"#f8f0ff"}}/>
                <input value={form.center_lng.toFixed(5)} readOnly
                  style={{flex:1,padding:"8px 10px",borderRadius:8,border:"1px solid #e8d5ff",fontSize:12,color:"#555",background:"#f8f0ff"}}/>
              </div>
              <button onClick={()=>{setPlacing(true);setMsg("Click on the map to set center");}}
                style={{width:"100%",padding:"9px",borderRadius:10,
                        border:"2px dashed #6c63ff",background:placing?"#f0e8ff":"#fff",
                        color:"#6c63ff",cursor:"pointer",fontSize:12,fontWeight:700}}>
                {placing?"🎯 Click map to place center...":"📍 Click to place on map"}
              </button>
            </div>

            <div style={{marginBottom:14}}>
              <label style={{fontSize:12,color:"#888",display:"block",marginBottom:4}}>Description</label>
              <textarea value={form.description} onChange={e=>update("description",e.target.value)}
                placeholder="Optional notes..."
                style={{width:"100%",padding:"10px 12px",borderRadius:10,border:"2px solid #e8d5ff",
                        fontSize:13,boxSizing:"border-box",color:"#333",resize:"vertical",minHeight:60}}/>
            </div>

            {/* Preview */}
            <div style={{background:"#f8f0ff",borderRadius:10,padding:10,marginBottom:12}}>
              <div style={{fontSize:11,color:"#6c63ff",fontWeight:700,marginBottom:4}}>Preview</div>
              <div style={{display:"flex",gap:8,alignItems:"center"}}>
                <div style={{width:16,height:16,borderRadius:"50%",background:ZONE_COLORS[form.zone_type],opacity:0.6}}/>
                <span style={{fontSize:12,color:"#333",fontWeight:600}}>{form.name||"Unnamed zone"}</span>
                <span style={{fontSize:11,color:"#888"}}>• {(form.radius_meters/1000).toFixed(1)}km</span>
              </div>
            </div>

            <button onClick={handleCreate} disabled={loading}
              style={{width:"100%",padding:14,borderRadius:12,border:"none",cursor:"pointer",
                      background:"linear-gradient(135deg,#6c63ff,#a855f7)",color:"#fff",
                      fontSize:14,fontWeight:700}}>
              {loading?"Creating...":"✅ Create Geofence"}
            </button>
          </div>
        )}

        {/* ZONE LIST */}
        {mode==="view" && (
          <div>
            <div style={{display:"flex",gap:8,marginBottom:10,flexWrap:"wrap"}}>
              {Object.entries(ZONE_LABELS).map(([type,label])=>{
                const count = allZones.filter(z=>z.zone_type===type).length;
                return count > 0 ? (
                  <div key={type} style={{background:ZONE_COLORS[type]+"22",color:ZONE_COLORS[type],
                                         padding:"3px 10px",borderRadius:20,fontSize:11,fontWeight:700}}>
                    {count} {label}
                  </div>
                ) : null;
              })}
            </div>

            {allZones.length===0 && (
              <div style={{background:"#fff",borderRadius:16,padding:30,textAlign:"center"}}>
                <div style={{fontSize:36}}>📍</div>
                <p style={{color:"#888",marginTop:8,fontSize:13}}>No geofences yet. Create your first zone!</p>
              </div>
            )}

            {allZones.map(zone=>(
              <div key={zone.id} style={{background:"#fff",borderRadius:16,padding:14,marginBottom:8,
                                         borderLeft:`4px solid ${ZONE_COLORS[zone.zone_type]||"#888"}`,
                                         boxShadow:"0 4px 20px rgba(108,99,255,0.08)",
                                         opacity:zone.active===false?0.5:1}}>
                <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start"}}>
                  <div style={{flex:1}}>
                    <div style={{fontWeight:700,color:"#333",fontSize:13}}>{zone.name}</div>
                    <div style={{color:"#888",fontSize:11,marginTop:2}}>{zone.state}</div>
                    <div style={{display:"flex",gap:6,marginTop:6,flexWrap:"wrap"}}>
                      <span style={{background:ZONE_COLORS[zone.zone_type]+"22",color:ZONE_COLORS[zone.zone_type],
                                    padding:"2px 8px",borderRadius:20,fontSize:10,fontWeight:700}}>
                        {ZONE_LABELS[zone.zone_type]||zone.zone_type}
                      </span>
                      <span style={{background:"#f0e8ff",color:"#6c63ff",padding:"2px 8px",borderRadius:20,fontSize:10}}>
                        {zone.radius_meters>=1000?(zone.radius_meters/1000).toFixed(1)+"km":zone.radius_meters+"m"}
                      </span>
                    </div>
                    {zone.description&&<div style={{color:"#aaa",fontSize:11,marginTop:4}}>{zone.description}</div>}
                  </div>
                  <div style={{display:"flex",gap:6,flexDirection:"column"}}>
                    <button onClick={()=>handleToggle(zone)}
                      style={{padding:"4px 10px",borderRadius:8,border:"none",cursor:"pointer",
                              background:zone.active!==false?"#ecfdf5":"#fef2f2",
                              color:zone.active!==false?"#059669":"#ef4444",fontSize:11,fontWeight:700}}>
                      {zone.active!==false?"Active":"Inactive"}
                    </button>
                    <button onClick={()=>handleDelete(zone.id, zone.name)}
                      style={{padding:"4px 10px",borderRadius:8,border:"none",cursor:"pointer",
                              background:"#fef2f2",color:"#ef4444",fontSize:11,fontWeight:700}}>
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Map */}
      <div style={{borderRadius:20,overflow:"hidden",boxShadow:"0 4px 20px rgba(108,99,255,0.15)"}}>
        <div style={{background:"linear-gradient(135deg,#6c63ff,#a855f7)",padding:"10px 16px",
                     display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <span style={{color:"#fff",fontWeight:700,fontSize:14}}>🗺️ Interactive Geofence Map</span>
          <div style={{display:"flex",gap:10,fontSize:11,color:"rgba(255,255,255,0.8)"}}>
            <span>🟢 Safe</span><span>🟡 Caution</span><span>🔴 Danger</span><span>🟣 Restricted</span>
          </div>
        </div>

        <MapContainer center={[26.2006,92.9376]} zoom={6}
          style={{height:"calc(100vh - 220px)",width:"100%"}}>
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"/>
          <MapClickHandler onMapClick={handleMapClick}/>

          {/* DB Zones */}
          {allZones.filter(z=>z.active!==false).map((zone:any)=>(
            <Circle key={zone.id}
              center={[zone.center_lat, zone.center_lng]}
              radius={zone.radius_meters}
              color={ZONE_COLORS[zone.zone_type]||"#888"}
              fillOpacity={0.15} weight={2.5}>
              <Popup>
                <div style={{minWidth:180}}>
                  <b style={{color:ZONE_COLORS[zone.zone_type]}}>{zone.name}</b><br/>
                  <span style={{fontSize:12}}>Type: {ZONE_LABELS[zone.zone_type]||zone.zone_type}</span><br/>
                  <span style={{fontSize:12}}>State: {zone.state}</span><br/>
                  <span style={{fontSize:12}}>Radius: {zone.radius_meters>=1000?(zone.radius_meters/1000).toFixed(1)+"km":zone.radius_meters+"m"}</span><br/>
                  {zone.description&&<span style={{fontSize:11,color:"#888"}}>{zone.description}</span>}
                </div>
              </Popup>
            </Circle>
          ))}

          {/* Preview of new zone while creating */}
          {mode==="create" && (
            <>
              <Circle
                center={[form.center_lat, form.center_lng]}
                radius={form.radius_meters}
                color={ZONE_COLORS[form.zone_type]}
                fillOpacity={0.25} weight={3}
                dashArray="10 5"/>
              <Marker position={[form.center_lat, form.center_lng]}>
                <Popup><b>New zone: {form.name||"Unnamed"}</b></Popup>
              </Marker>
            </>
          )}

          {/* Tourist locations */}
          {tourists.filter(t=>t.current_lat&&t.current_lng).map((t:any)=>(
            <Marker key={t.id} position={[t.current_lat,t.current_lng]}>
              <Popup><b>👤 {t.name}</b><br/>{t.nationality}</Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}
