import 'package:flutter/material.dart';
import '../../models/models.dart';

class TouristsTab extends StatefulWidget {
  final List<PatrolTourist> tourists; final void Function(PatrolTourist) onMsg;
  const TouristsTab({super.key, required this.tourists, required this.onMsg});
  @override State<TouristsTab> createState() => _TT();
}
class _TT extends State<TouristsTab> {
  String _q='', _f='all';
  Color _sc(String s)=>s=='sos'?const Color(0xFFFF3D3D):s=='warning'?const Color(0xFFFFB300):s=='offline'?const Color(0xFF888888):const Color(0xFF00E676);
  @override
  Widget build(BuildContext context) {
    final list=widget.tourists.where((t)=>(_q.isEmpty||t.name.toLowerCase().contains(_q.toLowerCase())||t.nationality.toLowerCase().contains(_q.toLowerCase()))&&(_f=='all'||t.status==_f)).toList();
    return Column(children:[
      Container(color: const Color(0xFF080F22),padding: const EdgeInsets.all(12),child:Column(children:[
        TextField(onChanged:(v)=>setState(()=>_q=v),style: const TextStyle(color:Colors.white,fontSize:13),
          decoration: InputDecoration(hintText:'Search tourist...',hintStyle: const TextStyle(color:Color(0xFF7B8AB3)),
            prefixIcon: const Icon(Icons.search,color:Color(0xFF7B8AB3),size:18),filled:true,fillColor: const Color(0xFF0C1630),
            contentPadding: const EdgeInsets.symmetric(vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none))),
        const SizedBox(height:8),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:['all','safe','warning','sos','offline'].map((f){
          final on=_f==f; final c=f=='all'?const Color(0xFF00B4FF):f=='safe'?const Color(0xFF00E676):f=='warning'?const Color(0xFFFFB300):f=='sos'?const Color(0xFFFF3D3D):const Color(0xFF888888);
          return GestureDetector(onTap:()=>setState(()=>_f=f),child:Container(margin: const EdgeInsets.only(right:8),padding: const EdgeInsets.symmetric(horizontal:14,vertical:6),
            decoration:BoxDecoration(color:on?c.withOpacity(0.15):Colors.transparent,borderRadius:BorderRadius.circular(20),border:Border.all(color:on?c: const Color(0x1F00B4FF))),
            child:Text(f.toUpperCase(),style:TextStyle(color:on?c: const Color(0xFF7B8AB3),fontSize:10,fontWeight:FontWeight.bold))));}).toList())),
      ])),
      Expanded(child:list.isEmpty?const Center(child:Text('No tourists found',style:TextStyle(color:Color(0xFF7B8AB3)))):
        ListView.builder(padding: const EdgeInsets.all(12),itemCount:list.length,itemBuilder:(_,i){
          final t=list[i]; final c=_sc(t.status);
          return GestureDetector(onTap:()=>_detail(t),child:Container(margin: const EdgeInsets.only(bottom:10),padding: const EdgeInsets.all(14),
            decoration:BoxDecoration(color: const Color(0xFF0C1630),borderRadius:BorderRadius.circular(12),border:Border.all(color: const Color(0x1F00B4FF))),
            child:Row(children:[Text(t.flag,style: const TextStyle(fontSize:28)),const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(t.name,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:14)),
                Text('${t.nationality} · ${t.id}',style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11)),
                Text('${t.location}  Battery ${t.batteryPct}%  ${t.lastSeen}m ago',style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:11))])),
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),
                decoration:BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(20),border:Border.all(color:c.withOpacity(0.5))),
                child:Text(t.status.toUpperCase(),style:TextStyle(color:c,fontSize:9,fontWeight:FontWeight.bold)))]));
        })),
    ]);
  }
  void _detail(PatrolTourist t){
    final c=_sc(t.status);
    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor: const Color(0xFF0C1630),
      shape: const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))),
      builder:(_)=>DraggableScrollableSheet(expand:false,initialChildSize:0.65,maxChildSize:0.9,
        builder:(_,ctrl)=>SingleChildScrollView(controller:ctrl,padding: const EdgeInsets.all(20),child:Column(children:[
          Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(2))),
          const SizedBox(height:16),
          Row(children:[Text(t.flag,style: const TextStyle(fontSize:40)),const SizedBox(width:14),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(t.name,style: const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold)),
              Text(t.nationality,style:TextStyle(color:c,fontSize:13)),
              Container(margin: const EdgeInsets.only(top:4),padding: const EdgeInsets.symmetric(horizontal:10,vertical:3),
                decoration:BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(20),border:Border.all(color:c.withOpacity(0.5))),
                child:Text(t.status.toUpperCase(),style:TextStyle(color:c,fontSize:10,fontWeight:FontWeight.bold)))]]),
          const SizedBox(height:16),
          ...[['Phone',t.phone],['Emergency',t.emergencyContact],['Location',t.location],
            ['Battery','${t.batteryPct}%'],['Last seen','${t.lastSeen} min ago'],
            ['GPS','${t.lat.toStringAsFixed(5)}N, ${t.lng.toStringAsFixed(5)}E']
          ].map((r)=>Container(padding: const EdgeInsets.symmetric(vertical:10),
            decoration: const BoxDecoration(border:Border(bottom:BorderSide(color:Color(0x1F00B4FF)))),
            child:Row(children:[SizedBox(width:90,child:Text(r[0],style: const TextStyle(color:Color(0xFF7B8AB3),fontSize:12))),
              Expanded(child:Text(r[1],style: const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w500)))]))),
          const SizedBox(height:16),
          Row(children:[
            Expanded(child:ElevatedButton.icon(onPressed:(){},icon: const Icon(Icons.phone,size:16),label: const Text('CALL'),
              style:ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676),foregroundColor:Colors.white))),
            const SizedBox(width:10),
            Expanded(child:ElevatedButton.icon(onPressed:(){Navigator.pop(context);widget.onMsg(t);},icon: const Icon(Icons.chat,size:16),label: const Text('MSG'),
              style:ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4FF),foregroundColor:Colors.white))),
            const SizedBox(width:10),
            Expanded(child:ElevatedButton.icon(onPressed:(){},icon: const Icon(Icons.sos,size:16),label: const Text('SOS'),
              style:ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D3D),foregroundColor:Colors.white))),
          ])]))));
  }
}
