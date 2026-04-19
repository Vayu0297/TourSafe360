import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class DashboardTab extends StatefulWidget {
  final List<PatrolTourist> tourists; final List<SOSAlert> alerts;
  final String name, badge, zone; final bool connected; final void Function(int) onNav;
  const DashboardTab({super.key, required this.tourists, required this.alerts,
    required this.name, required this.badge, required this.zone, required this.connected, required this.onNav});
  @override State<DashboardTab> createState() => _DT();
}
class _DT extends State<DashboardTab> {
  Position? _pos;
  @override void initState() { super.initState(); LocationService.getPosition().then((p) { if (mounted) setState(() => _pos = p); }); }
  static const acc=Color(0xFF00B4FF), crd=Color(0xFF0C1630), bdr=Color(0x1F00B4FF), dim=Color(0xFF7B8AB3);
  static const red=Color(0xFFFF3D3D), amb=Color(0xFFFFB300), grn=Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    final act = widget.alerts.where((a) => a.status=='active').length;
    final wrn = widget.tourists.where((t) => t.status=='warning').length;
    final sos = widget.tourists.where((t) => t.status=='sos').length;
    return ListView(padding: const EdgeInsets.fromLTRB(16,16,16,90), children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFF0D1A3A),crd]), borderRadius: BorderRadius.circular(16), border: Border.all(color: bdr)),
        child: Row(children: [
          Container(width:52,height:52,decoration: const BoxDecoration(gradient: LinearGradient(colors:[acc,Color(0xFF7B61FF)]),shape:BoxShape.circle),
            child: const Center(child:Text('🚔',style:TextStyle(fontSize:26)))),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(widget.name,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16)),
            Text(widget.badge,style: const TextStyle(color:acc,fontSize:12,fontWeight:FontWeight.w600)),
            Text(widget.zone,style: const TextStyle(color:dim,fontSize:11)),
            if (_pos!=null) Text('${_pos!.latitude.toStringAsFixed(4)}N ${_pos!.longitude.toStringAsFixed(4)}E',style: const TextStyle(color:dim,fontSize:10,fontFamily:'monospace')),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:5),
            decoration: BoxDecoration(color:widget.connected?const Color(0x2000E676):const Color(0x20FF3D3D),
              borderRadius:BorderRadius.circular(20),border:Border.all(color:widget.connected?grn:red)),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              Container(width:6,height:6,decoration:BoxDecoration(color:widget.connected?grn:red,shape:BoxShape.circle)),
              const SizedBox(width:5),
              Text(widget.connected?'LIVE':'OFFLINE',style:TextStyle(color:widget.connected?grn:red,fontSize:10,fontWeight:FontWeight.bold)),
            ])),
        ])),
      const SizedBox(height:14),
      Row(children:[
        _stat('${widget.tourists.length}','TOURISTS',Icons.people_rounded,acc),
        const SizedBox(width:10),
        _stat('$act','ACTIVE SOS',Icons.sos_rounded,red),
        const SizedBox(width:10),
        _stat('$wrn','WARNING',Icons.warning_rounded,amb),
      ]),
      const SizedBox(height:16),
      if (act>0)...[_lbl('ACTIVE ALERTS',red), ...widget.alerts.where((a)=>a.status=='active').map((a)=>_aCard(a)), const SizedBox(height:14)],
      if (sos+wrn>0)...[_lbl('NEEDS ATTENTION',amb), ...widget.tourists.where((t)=>t.status!='safe').map((t)=>_tCard(t)), const SizedBox(height:14)],
      _lbl('PATROL ZONE',acc),
      Container(padding: const EdgeInsets.all(14),decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(12),border:Border.all(color:bdr)),
        child:Row(children:[
          const Icon(Icons.location_on_rounded,color:acc,size:18), const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(widget.zone,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13)),
            Text('${widget.tourists.length} tourists · ${act>0?"$act SOS active":"All clear"}',style:TextStyle(color:act>0?red:grn,fontSize:11)),
          ])),
        ])),
    ]);
  }
  Widget _stat(String v,String l,IconData i,Color c)=>Expanded(child:Container(
    padding: const EdgeInsets.symmetric(vertical:14,horizontal:8),
    decoration:BoxDecoration(color:Color(0xFF0C1630),borderRadius:BorderRadius.circular(12),border:Border.all(color:Color(0x1F00B4FF))),
    child:Column(children:[Icon(i,color:c,size:20),const SizedBox(height:6),Text(v,style:TextStyle(color:c,fontSize:24,fontWeight:FontWeight.w900)),
      Text(l,style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:8,fontWeight:FontWeight.w600),textAlign:TextAlign.center)])));
  Widget _lbl(String t,Color c)=>Padding(padding: const EdgeInsets.only(bottom:10),child:Text(t,style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.bold,letterSpacing:1.5)));
  Widget _aCard(SOSAlert a)=>GestureDetector(onTap:()=>widget.onNav(3),child:Container(margin: const EdgeInsets.only(bottom:8),padding: const EdgeInsets.all(12),
    decoration:BoxDecoration(color: const Color(0x1AFF3D3D),borderRadius:BorderRadius.circular(12),border:Border.all(color: const Color(0x66FF3D3D))),
    child:Row(children:[const Icon(Icons.sos_rounded,color:Color(0xFFFF3D3D),size:20),const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(a.touristName,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:13)),
        Text('${a.type} · ${a.locationName}',style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11))])),
      const Icon(Icons.chevron_right,color:Color(0xFFFF3D3D),size:18)])));
  Widget _tCard(PatrolTourist t){final c=t.status=='sos'?red:amb;return Container(margin: const EdgeInsets.only(bottom:8),padding: const EdgeInsets.all(12),
    decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(10),border:Border.all(color:c.withOpacity(0.4))),
    child:Row(children:[Text(t.flag,style: const TextStyle(fontSize:24)),const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t.name,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13)),
        Text('${t.location} · Battery ${t.batteryPct}%',style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11))])),
      Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),
        decoration:BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(20),border:Border.all(color:c.withOpacity(0.5))),
        child:Text(t.status.toUpperCase(),style:TextStyle(color:c,fontSize:9,fontWeight:FontWeight.bold)))]));}
}
