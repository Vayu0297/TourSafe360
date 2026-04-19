import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class MapTab extends StatefulWidget {
  final List<PatrolTourist> tourists; final List<SOSAlert> alerts;
  const MapTab({super.key, required this.tourists, required this.alerts});
  @override State<MapTab> createState() => _MT();
}
class _MT extends State<MapTab> {
  final _mc = MapController(); Position? _pos; PatrolTourist? _st; SOSAlert? _sa;
  @override void initState() { super.initState(); LocationService.getPosition().then((p){if(mounted&&p!=null){setState(()=>_pos=p);_mc.move(LatLng(p.latitude,p.longitude),10);}}); }
  Color _tc(String s)=>s=='sos'?const Color(0xFFFF3D3D):s=='warning'?const Color(0xFFFFB300):s=='offline'?const Color(0xFF888888):const Color(0xFF00E676);
  @override
  Widget build(BuildContext c)=>Stack(children:[
    FlutterMap(mapController:_mc,
      options:MapOptions(initialCenter: const LatLng(26.2,92.5),initialZoom:7,onTap:(_, __)=>setState(()=>_st=_sa=null)),
      children:[
        TileLayer(urlTemplate:'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',subdomains: const ['a','b','c']),
        MarkerLayer(markers:[
          if(_pos!=null)Marker(point:LatLng(_pos!.latitude,_pos!.longitude),width:40,height:40,
            child:Container(decoration:BoxDecoration(color: const Color(0xFF00B4FF),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:2),
              boxShadow: const [BoxShadow(color:Color(0x8800B4FF),blurRadius:12)]),child: const Icon(Icons.navigation_rounded,color:Colors.white,size:18))),
          ...widget.tourists.map((t)=>Marker(point:LatLng(t.lat,t.lng),width:38,height:38,
            child:GestureDetector(onTap:()=>setState(()=>{_st=t,_sa=null}),
              child:Container(decoration:BoxDecoration(color:_tc(t.status),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:1.5),
                boxShadow:[BoxShadow(color:_tc(t.status).withOpacity(0.6),blurRadius:8)]),
                child:Center(child:Text(t.flag,style: const TextStyle(fontSize:18))))))),
          ...widget.alerts.where((a)=>a.status=='active').map((a)=>Marker(point:LatLng(a.lat,a.lng),width:44,height:44,
            child:GestureDetector(onTap:()=>setState(()=>{_sa=a,_st=null}),
              child:Container(decoration: const BoxDecoration(color:Color(0xFFFF3D3D),shape:BoxShape.circle,
                boxShadow:[BoxShadow(color:Color(0xAAFF3D3D),blurRadius:16)]),
                child: const Icon(Icons.sos_rounded,color:Colors.white,size:22))))),
        ]),
      ]),
    Positioned(top:16,right:16,child:Column(children:[
      _mb(Icons.my_location,()async{final p=await LocationService.getPosition();if(p!=null)_mc.move(LatLng(p.latitude,p.longitude),13);}),
      const SizedBox(height:8),
      _mb(Icons.add,()=>_mc.move(_mc.camera.center,_mc.camera.zoom+1)),
      const SizedBox(height:8),
      _mb(Icons.remove,()=>_mc.move(_mc.camera.center,_mc.camera.zoom-1)),
      const SizedBox(height:8),
      _mb(Icons.fit_screen,()=>_mc.move(const LatLng(26.2,92.5),7)),
    ])),
    if(widget.alerts.any((a)=>a.status=='active'))
      Positioned(top:16,left:12,child:Column(children:widget.alerts.where((a)=>a.status=='active').map((a)=>GestureDetector(
        onTap:(){_mc.move(LatLng(a.lat,a.lng),13);setState(()=>{_sa=a,_st=null});},
        child:Container(margin: const EdgeInsets.only(bottom:6),padding: const EdgeInsets.symmetric(horizontal:10,vertical:6),
          decoration:BoxDecoration(color: const Color(0xCC0C1630),borderRadius:BorderRadius.circular(20),border:Border.all(color: const Color(0x66FF3D3D))),
          child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.sos_rounded,color:Color(0xFFFF3D3D),size:14),const SizedBox(width:4),
            Text(a.touristName.split(' ')[0],style: const TextStyle(color:Color(0xFFFF3D3D),fontSize:11,fontWeight:FontWeight.bold))])))).toList())),
    if(_st!=null)Positioned(bottom:16,left:12,right:12,child:_tc2(_st!)),
    if(_sa!=null)Positioned(bottom:16,left:12,right:12,child:_ac(_sa!)),
  ]);
  Widget _mb(IconData i,VoidCallback f)=>GestureDetector(onTap:f,child:Container(width:40,height:40,
    decoration:BoxDecoration(color: const Color(0xDD0C1630),borderRadius:BorderRadius.circular(10),border:Border.all(color: const Color(0x1F00B4FF))),
    child:Icon(i,color: const Color(0xFF00B4FF),size:20)));
  Widget _tc2(PatrolTourist t)=>Container(padding: const EdgeInsets.all(14),
    decoration:BoxDecoration(color: const Color(0xEE0C1630),borderRadius:BorderRadius.circular(14),border:Border.all(color:_tc(t.status).withOpacity(0.4))),
    child:Row(children:[Text(t.flag,style: const TextStyle(fontSize:28)),const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t.name,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:14)),
        Text(t.location,style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11)),
        Text('Battery ${t.batteryPct}%  Last seen ${t.lastSeen}m',style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11))])),
      GestureDetector(onTap:()=>_mc.move(LatLng(t.lat,t.lng),14),
        child:Container(padding: const EdgeInsets.all(8),decoration:BoxDecoration(color: const Color(0x2200B4FF),borderRadius:BorderRadius.circular(8)),
          child: const Icon(Icons.center_focus_strong,color:Color(0xFF00B4FF),size:20)))]));
  Widget _ac(SOSAlert a)=>Container(padding: const EdgeInsets.all(14),
    decoration:BoxDecoration(color: const Color(0xEE150505),borderRadius:BorderRadius.circular(14),border:Border.all(color: const Color(0x66FF3D3D))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.sos_rounded,color:Color(0xFFFF3D3D),size:20),const SizedBox(width:8),
        Expanded(child:Text(a.touristName,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
        Text(a.severity.toUpperCase(),style: const TextStyle(color:Color(0xFFFF3D3D),fontSize:10,fontWeight:FontWeight.bold))]),
      const SizedBox(height:4),
      Text(a.type,style: const TextStyle(color:Color(0xFFFF3D3D),fontSize:12)),
      Text(a.locationName,style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11)),
    ]));
}
