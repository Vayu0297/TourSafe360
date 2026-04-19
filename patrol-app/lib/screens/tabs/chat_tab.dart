import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';

class ChatTab extends StatefulWidget {
  final List<ChatMessage> msgs; final List<PatrolTourist> tourists; final void Function(String,String,String) onSend;
  const ChatTab({super.key, required this.msgs, required this.tourists, required this.onSend});
  @override State<ChatTab> createState() => _CT();
}
class _CT extends State<ChatTab> {
  final _c=TextEditingController(), _s=ScrollController();
  String _tid='control_center', _tt='control_center';
  static const acc=Color(0xFF00B4FF), crd=Color(0xFF0C1630), bdr=Color(0x1F00B4FF), dim=Color(0xFF7B8AB3);
  void _send(){final t=_c.text.trim();if(t.isEmpty)return;widget.onSend(_tid,_tt,t);_c.clear();Future.delayed(const Duration(milliseconds:100),(){if(_s.hasClients)_s.animateTo(_s.position.maxScrollExtent,duration: const Duration(milliseconds:300),curve:Curves.easeOut);});}
  @override
  Widget build(BuildContext ctx)=>Column(children:[
    Container(color: const Color(0xFF080F22),padding: const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('SEND TO:',style:TextStyle(color:dim,fontSize:10,fontWeight:FontWeight.bold,letterSpacing:1)),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        _chip('Control Center','control_center','control_center'),
        _chip('All Tourists','broadcast','broadcast'),
        ...widget.tourists.map((t)=>_chip('${t.flag} ${t.name.split(' ')[0]}',t.id,'tourist')),
      ])),
    ])),
    Expanded(child:widget.msgs.isEmpty?const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.chat_bubble_outline,color:dim,size:48),SizedBox(height:12),Text('No messages yet',style:TextStyle(color:dim,fontSize:14))]))
      :ListView.builder(controller:_s,padding: const EdgeInsets.all(12),itemCount:widget.msgs.length,itemBuilder:(_,i){
        final m=widget.msgs[i]; final fmt=DateFormat('HH:mm').format(m.time);
        return Align(alignment:m.isMe?Alignment.centerRight:Alignment.centerLeft,
          child:Container(margin: const EdgeInsets.only(bottom:8),padding: const EdgeInsets.symmetric(horizontal:14,vertical:10),
            constraints:BoxConstraints(maxWidth:MediaQuery.of(ctx).size.width*0.75),
            decoration:BoxDecoration(color:m.isMe?acc.withOpacity(0.18):crd,
              borderRadius:BorderRadius.only(topLeft: const Radius.circular(16),topRight: const Radius.circular(16),
                bottomLeft:Radius.circular(m.isMe?16:4),bottomRight:Radius.circular(m.isMe?4:16)),
              border:Border.all(color:m.isMe? const Color(0x3300B4FF):bdr)),
            child:Column(crossAxisAlignment:m.isMe?CrossAxisAlignment.end:CrossAxisAlignment.start,children:[
              if(!m.isMe)Text(m.sender,style: const TextStyle(color:acc,fontSize:10,fontWeight:FontWeight.bold)),
              Text(m.text,style: const TextStyle(color:Colors.white,fontSize:13,height:1.4)),
              Text(fmt,style: const TextStyle(color:dim,fontSize:9))])));
      })),
    Container(padding: const EdgeInsets.all(12),color: const Color(0xFF080F22),child:Row(children:[
      Expanded(child:Container(decoration:BoxDecoration(color:crd,borderRadius:BorderRadius.circular(24),border:Border.all(color:bdr)),
        child:TextField(controller:_c,style: const TextStyle(color:Colors.white,fontSize:13),maxLines:null,
          decoration: const InputDecoration(hintText:'Message...',hintStyle:TextStyle(color:dim),border:InputBorder.none,contentPadding:EdgeInsets.symmetric(horizontal:16,vertical:10)),
          onSubmitted:(_)=>_send()))),
      const SizedBox(width:8),
      GestureDetector(onTap:_send,child:Container(width:44,height:44,decoration: const BoxDecoration(color:acc,shape:BoxShape.circle),
        child: const Icon(Icons.send_rounded,color:Colors.white,size:20))),
    ])),
  ]);
  Widget _chip(String l,String id,String t){final on=_tid==id;return GestureDetector(onTap:()=>setState(()=>{_tid=id,_tt=t}),
    child:Container(margin: const EdgeInsets.only(right:8),padding: const EdgeInsets.symmetric(horizontal:12,vertical:6),
      decoration:BoxDecoration(color:on?acc.withOpacity(0.18):Colors.transparent,borderRadius:BorderRadius.circular(20),border:Border.all(color:on?acc:bdr)),
      child:Text(l,style:TextStyle(color:on?acc:dim,fontSize:11,fontWeight:FontWeight.w600))));}
}
