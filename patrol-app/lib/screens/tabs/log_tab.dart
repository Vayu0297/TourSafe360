import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class LogTab extends StatefulWidget {
  final String token;
  const LogTab({super.key, required this.token});
  @override State<LogTab> createState() => _LT();
}
class _LT extends State<LogTab> {
  final _n=TextEditingController(); String _type='patrol_check'; bool _busy=false; final List<PatrolLog> _logs=[];
  static const acc=Color(0xFF00B4FF), crd=Color(0xFF0C1630), bdr=Color(0x1F00B4FF), dim=Color(0xFF7B8AB3);
  final _types=[
    {'id':'patrol_check','l':'Patrol Check','i':'check_circle'},
    {'id':'tourist_contact','l':'Tourist Contact','i':'person'},
    {'id':'incident','l':'Incident','i':'warning'},
    {'id':'suspicious','l':'Suspicious','i':'search'},
    {'id':'medical','l':'Medical Assist','i':'medical_services'},
    {'id':'equipment','l':'Equipment Check','i':'backpack'},
    {'id':'other','l':'Other','i':'notes'},
  ];
  Future<void> _sub() async {
    if(_n.text.trim().isEmpty)return;
    setState(()=>_busy=true);
    final pos=await LocationService.getPosition(); final lat=pos?.latitude??0.0,lng=pos?.longitude??0.0;
    final ok=await ApiService.submitLog(widget.token,_type,_n.text.trim(),lat,lng);
    if(ok&&mounted){setState((){_logs.insert(0,PatrolLog(id:'${DateTime.now().millisecondsSinceEpoch}',type:_type,note:_n.text.trim(),timestamp:DateFormat('dd MMM HH:mm').format(DateTime.now()),lat:lat,lng:lng));});
      _n.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Log submitted'),backgroundColor:Color(0xFF00E676)));}
    setState(()=>_busy=false);
  }
  @override
  Widget build(BuildContext context)=>ListView(padding: const EdgeInsets.all(16),children:[
    const Text('PATROL LOG',style:TextStyle(color:Color(0xFF00B4FF),fontSize:11,fontWeight:FontWeight.bold,letterSpacing:1.5)),
    const SizedBox(height:14),
    const Text('Type',style:TextStyle(color:dim,fontSize:11)), const SizedBox(height:8),
    Wrap(spacing:8,runSpacing:8,children:_types.map((t){final on=_type==t['id'];
      return GestureDetector(onTap:()=>setState(()=>_type=t['id'] as String),
        child:Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(color:on?acc.withOpacity(0.15):crd,borderRadius:BorderRadius.circular(10),border:Border.all(color:on?acc:bdr)),
          child:Text(t['l'] as String,style:TextStyle(color:on?acc:dim,fontSize:12,fontWeight:on?FontWeight.bold:FontWeight.normal))));}).toList()),
    const SizedBox(height:16),
    const Text('Notes',style:TextStyle(color:dim,fontSize:11)), const SizedBox(height:8),
    Container(decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(12),border:Border.all(color:bdr)),
      child:TextField(controller:_n,maxLines:4,style: const TextStyle(color:Colors.white,fontSize:13),
        decoration: const InputDecoration(hintText:'Describe observation or incident...',hintStyle:TextStyle(color:dim,fontSize:12),border:InputBorder.none,contentPadding:EdgeInsets.all(14)))),
    const SizedBox(height:14),
    SizedBox(width:double.infinity,height:48,child:ElevatedButton.icon(onPressed:_busy?null:_sub,
      icon:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.send,size:18),
      label:Text(_busy?'Submitting...':'SUBMIT LOG',style: const TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
      style:ElevatedButton.styleFrom(backgroundColor:acc,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))),
    const SizedBox(height:24),
    Text('RECENT (${_logs.length})',style: const TextStyle(color:dim,fontSize:10,fontWeight:FontWeight.bold,letterSpacing:1)),
    const SizedBox(height:10),
    if(_logs.isEmpty) const Text('No logs yet.',style:TextStyle(color:dim,fontSize:12)),
    ..._logs.map((l)=>Container(margin: const EdgeInsets.only(bottom:10),padding: const EdgeInsets.all(12),
      decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(10),border:Border.all(color:bdr)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(l.type.replaceAll('_',' ').toUpperCase(),style: const TextStyle(color:acc,fontSize:10,fontWeight:FontWeight.bold)),
        Text(l.note,style: const TextStyle(color:Colors.white,fontSize:12,height:1.4)),
        const SizedBox(height:4),
        Text(l.timestamp,style: const TextStyle(color:dim,fontSize:10))]))),
    const SizedBox(height:80)]);
}
