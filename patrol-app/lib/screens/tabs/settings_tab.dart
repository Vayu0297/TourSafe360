import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsTab extends StatefulWidget {
  final String name, badge, zone, token; final VoidCallback onLogout;
  const SettingsTab({super.key, required this.name, required this.badge, required this.zone, required this.token, required this.onLogout});
  @override State<SettingsTab> createState() => _ST();
}
class _ST extends State<SettingsTab> {
  final _ip=TextEditingController(); bool _v=true,_s=true,_tr=true,_ok=false;
  static const acc=Color(0xFF00B4FF), crd=Color(0xFF0C1630), bdr=Color(0x1F00B4FF), dim=Color(0xFF7B8AB3);
  @override void initState(){super.initState();SharedPreferences.getInstance().then((p){if(mounted)setState((){_ip.text=p.getString('api_url')??'http://192.168.1.100:8000';_v=p.getBool('vibrate')??true;_s=p.getBool('sound')??true;_tr=p.getBool('tracking')??true;});});}
  Future<void> _save() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('api_url',_ip.text.trim()); await p.setBool('vibrate',_v); await p.setBool('sound',_s); await p.setBool('tracking',_tr);
    setState(()=>_ok=true); Future.delayed(const Duration(seconds:2),(){if(mounted)setState(()=>_ok=false);});
  }
  @override
  Widget build(BuildContext context)=>ListView(padding: const EdgeInsets.all(16),children:[
    Container(padding: const EdgeInsets.all(16),decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(16),border:Border.all(color:bdr)),
      child:Row(children:[Container(width:52,height:52,decoration: const BoxDecoration(gradient:LinearGradient(colors:[acc,Color(0xFF7B61FF)]),shape:BoxShape.circle),
        child: const Center(child:Text('🚔',style:TextStyle(fontSize:26)))),const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(widget.name,style: const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16)),
          Text(widget.badge,style: const TextStyle(color:acc,fontSize:12,fontWeight:FontWeight.w600)),
          Text(widget.zone,style: const TextStyle(color:dim,fontSize:11))]))
      ])),
    const SizedBox(height:18),
    Container(padding: const EdgeInsets.all(16),decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(12),border:Border.all(color:bdr)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('SERVER URL',style:TextStyle(color:acc,fontSize:10,fontWeight:FontWeight.bold,letterSpacing:1.5)),
      const SizedBox(height:10),
      const Text('Run: hostname -I | awk \'{print \$1}\'',style:TextStyle(color:dim,fontSize:11,fontFamily:'monospace')),
      const SizedBox(height:8),
      TextField(controller:_ip,style: const TextStyle(color:acc,fontSize:13,fontFamily:'monospace'),
        decoration:InputDecoration(filled:true,fillColor: const Color(0xFF050C18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide: const BorderSide(color:bdr)),
          focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide: const BorderSide(color:acc)),
          contentPadding: const EdgeInsets.symmetric(horizontal:12,vertical:10)))])),
    const SizedBox(height:14),
    Container(padding: const EdgeInsets.all(16),decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(12),border:Border.all(color:bdr)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('ALERTS',style:TextStyle(color:acc,fontSize:10,fontWeight:FontWeight.bold,letterSpacing:1.5)),
      const SizedBox(height:12),
      ...[['SOS Vibration',_v,(v){setState(()=>_v=v as bool);}],['SOS Sound',_s,(v){setState(()=>_s=v as bool);}],['Live GPS Tracking',_tr,(v){setState(()=>_tr=v as bool);}]]
        .map((r)=>Padding(padding: const EdgeInsets.only(bottom:10),child:Row(children:[Expanded(child:Text(r[0] as String,style: const TextStyle(color:Colors.white,fontSize:13))),Switch(value:r[1] as bool,onChanged:r[2] as void Function(bool)?,activeColor:acc)])))
    ])),
    const SizedBox(height:14),
    SizedBox(width:double.infinity,height:48,child:ElevatedButton(onPressed:_save,
      style:ElevatedButton.styleFrom(backgroundColor:_ok? const Color(0xFF00E676):acc,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
      child:Text(_ok?'SAVED':'SAVE SETTINGS',style: const TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)))),
    const SizedBox(height:14),
    Container(padding: const EdgeInsets.all(14),decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(12),border:Border.all(color:bdr)),
      child: const Column(children:[Row(children:[Icon(Icons.info_outline,color:dim,size:16),SizedBox(width:8),Text('TourSafe360 Patrol v2.0',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold))]),SizedBox(height:6),
        Text('NE India Tourism Police Field Unit\nConnects to Control Center & Tourist App\nSocket.IO live · FastAPI backend · flutter_map',style:TextStyle(color:dim,fontSize:11,height:1.6))])),
    const SizedBox(height:14),
    SizedBox(width:double.infinity,height:48,child:OutlinedButton.icon(onPressed:widget.onLogout,
      icon: const Icon(Icons.logout,size:18),label: const Text('SIGN OUT',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
      style:OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3D3D),side: const BorderSide(color:Color(0xFFFF3D3D)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))),
    const SizedBox(height:80)]);
}
