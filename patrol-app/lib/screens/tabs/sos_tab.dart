import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../models/models.dart';

class SOSTab extends StatelessWidget {
  final List<SOSAlert> alerts; final void Function(String) onRespond, onResolve;
  const SOSTab({super.key, required this.alerts, required this.onRespond, required this.onResolve});
  static const red=Color(0xFFFF3D3D), amb=Color(0xFFFFB300), grn=Color(0xFF00E676), crd=Color(0xFF0C1630), dim=Color(0xFF7B8AB3);
  Color _sc(String s)=>s=='critical'?red:s=='high'?const Color(0xFFFF8C00):s=='medium'?amb:grn;
  @override
  Widget build(BuildContext context){
    final act=alerts.where((a)=>a.status=='active'||a.status=='responding').toList();
    final done=alerts.where((a)=>a.status=='resolved').toList();
    return ListView(padding: const EdgeInsets.all(12),children:[
      if(act.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:50),child:Column(children:[
        Icon(Icons.check_circle_rounded,color:Color(0xFF00E676),size:56), SizedBox(height:14),
        Text('All Clear',style:TextStyle(color:Color(0xFF00E676),fontSize:18,fontWeight:FontWeight.bold)),
        Text('No active SOS alerts',style:TextStyle(color:Color(0xFF7B8AB3),fontSize:13))]))
      else...[Text('ACTIVE ALERTS (${act.length})',style: const TextStyle(color:red,fontSize:11,fontWeight:FontWeight.bold,letterSpacing:1.5)),
        const SizedBox(height:10), ...act.map((a)=>_card(context,a,true))],
      if(done.isNotEmpty)...[const SizedBox(height:20),
        const Text('RESOLVED',style:TextStyle(color:Color(0xFF00E676),fontSize:11,fontWeight:FontWeight.bold,letterSpacing:1.5)),
        const SizedBox(height:10), ...done.map((a)=>_card(context,a,false))],
      const SizedBox(height:80)]);
  }
  Widget _card(BuildContext ctx,SOSAlert a,bool isAct){
    final c=_sc(a.severity);
    return Container(margin: const EdgeInsets.only(bottom:14),
      decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(14),border:Border.all(color:isAct?c.withOpacity(0.5): const Color(0x1F00B4FF))),
      child:Column(children:[
        Container(padding: const EdgeInsets.all(14),decoration:BoxDecoration(color:isAct?c.withOpacity(0.08):Colors.transparent,borderRadius: const BorderRadius.vertical(top:Radius.circular(14))),
          child:Row(children:[Icon(Icons.sos_rounded,color:c,size:22),const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(a.touristName,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:14)),
              Text('${a.type} · ${a.createdAt}',style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w600))])),
            Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(20),border:Border.all(color:c.withOpacity(0.5))),
                child:Text(a.severity.toUpperCase(),style:TextStyle(color:c,fontSize:9,fontWeight:FontWeight.bold))),
              const SizedBox(height:4),
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(20)),
                child:Text(a.status.toUpperCase(),style: const TextStyle(color:Colors.white54,fontSize:9)))])])),
        Padding(padding: const EdgeInsets.fromLTRB(14,0,14,14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Icon(Icons.pin_drop_rounded,color:Color(0xFF7B8AB3),size:14),const SizedBox(width:4),
            Expanded(child:Text(a.locationName,style: const TextStyle(color:dim,fontSize:11)))]),
          if(a.description.isNotEmpty)...[const SizedBox(height:8),
            Container(padding: const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white.withOpacity(0.03),borderRadius:BorderRadius.circular(8),border:Border(left:BorderSide(color:c,width:3))),
              child:Text(a.description,style: const TextStyle(color:dim,fontSize:11,height:1.5)))],
          if(a.equipment.isNotEmpty)...[const SizedBox(height:8),
            const Text('EQUIPMENT:',style:TextStyle(color:Color(0xFFFFB300),fontSize:10,fontWeight:FontWeight.bold)),
            const SizedBox(height:4),
            Wrap(spacing:6,runSpacing:4,children:a.equipment.map((e)=>Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),
              decoration:BoxDecoration(color:Colors.white.withOpacity(0.05),borderRadius:BorderRadius.circular(20),border:Border.all(color: const Color(0x1F00B4FF))),
              child:Text('+ $e',style: const TextStyle(color:dim,fontSize:10)))).toList())],
          if(isAct)...[const SizedBox(height:12),Row(children:[
            Expanded(child:ElevatedButton.icon(onPressed:()async{try{await Vibration.vibrate(pattern:[0,200,100,200]);}catch(_){}onRespond(a.id);},
              icon: const Icon(Icons.directions_run,size:16),label: const Text('RESPOND',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
              style:ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4FF),foregroundColor:Colors.white,padding: const EdgeInsets.symmetric(vertical:10)))),
            const SizedBox(width:8),
            Expanded(child:ElevatedButton.icon(onPressed:()=>onResolve(a.id),
              icon: const Icon(Icons.check_circle,size:16),label: const Text('RESOLVE',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
              style:ElevatedButton.styleFrom(backgroundColor:grn,foregroundColor:Colors.black,padding: const EdgeInsets.symmetric(vertical:10)))),
            const SizedBox(width:8),
            ElevatedButton(onPressed:(){},style:ElevatedButton.styleFrom(backgroundColor: const Color(0x33FF3D3D),padding: const EdgeInsets.all(10),side: const BorderSide(color:red)),
              child: const Icon(Icons.phone,color:red,size:18))])]]))]));}
}
