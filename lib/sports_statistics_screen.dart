import 'package:flutter/material.dart';
import 'sports_api_service.dart';

const Color _statsBg=Color(0xFF030814);
const Color _statsPanel=Color(0xFF071326);
const Color _statsLine=Color(0xFF123D65);
const Color _statsCyan=Color(0xFF00E5FF);
const Color _statsBlue=Color(0xFF087BFF);
const Color _statsMuted=Color(0xFFA9BDD6);

class SportsStatisticsScreen extends StatefulWidget {
  const SportsStatisticsScreen({super.key});
  @override
  State<SportsStatisticsScreen> createState()=>_SportsStatisticsScreenState();
}

class _SportsStatisticsScreenState extends State<SportsStatisticsScreen> {
  static const List<String> _sports=<String>[
    'Fútbol','Básquet','NBA','Béisbol','Fútbol americano',
    'Hockey sobre hielo','Balonmano','Rugby','Vóley','Fútbol australiano',
  ];
  final SportsApiService _service=SportsApiService();
  final TextEditingController _searchController=TextEditingController();
  String _sport='Fútbol';
  String? _selectedLeagueId;
  String _selectedLeagueName='';
  String _season=DateTime.now().year.toString();
  List<String> _seasons=<String>[];
  List<Map<String,dynamic>> _leagues=<Map<String,dynamic>>[];
  List<Map<String,dynamic>> _standingRows=<Map<String,dynamic>>[];
  bool _searching=false;
  bool _loadingStandings=false;
  String? _error;

  @override
  void dispose(){_searchController.dispose();super.dispose();}

  Map<String,dynamic> _asMap(dynamic value)=>value is Map?Map<String,dynamic>.from(value):<String,dynamic>{};

  String _text(dynamic value){
    if(value==null)return '';
    if(value is Map){final map=_asMap(value);return (map['name']??map['title']??map['shortName']??'').toString().trim();}
    return value.toString().trim();
  }

  String _leagueId(Map<String,dynamic> row){
    final league=_asMap(row['league']);
    return (league['id']??row['id']??'').toString().trim();
  }

  String _leagueName(Map<String,dynamic> row){
    final league=_asMap(row['league']);
    return _text(league['name']??row['name']??row['competition']);
  }

  List<String> _leagueSeasons(Map<String,dynamic> row){
    final values=row['seasons'];
    if(values is! List)return <String>[];
    final seasons=<String>[];
    for(final value in values){
      final item=_asMap(value);
      final year=(item['year']??value).toString().trim();
      if(RegExp(r'^\d{4}(?:-\d{4})?$').hasMatch(year)&&!seasons.contains(year))seasons.add(year);
    }
    seasons.sort((a,b)=>b.compareTo(a));
    return seasons;
  }

  Future<void> _searchLeagues() async {
    if(_searchController.text.trim().isEmpty){
      setState(()=>_error='Escribe el nombre de una liga para buscarla.');
      return;
    }
    setState((){
      _searching=true;_error=null;_leagues=<Map<String,dynamic>>[];
      _standingRows=<Map<String,dynamic>>[];_selectedLeagueId=null;_selectedLeagueName='';
    });
    try{
      final rows=await _service.fetchLeagues(sport:_sport,search:_searchController.text);
      if(!mounted)return;
      setState((){
        _leagues=rows;_searching=false;
        if(rows.isEmpty)_error='No se encontraron ligas con ese nombre.';
      });
    }catch(error){
      if(!mounted)return;
      setState(()=>_searching=false);
      setState(()=>_error=error.toString());
    }
  }

  void _selectLeague(Map<String,dynamic> row){
    final id=_leagueId(row);
    if(id.isEmpty){setState(()=>_error='La liga seleccionada no tiene identificador.');return;}
    final seasons=_leagueSeasons(row);
    String? currentSeason;
    final rawSeasons=row['seasons'];
    if(rawSeasons is List){
      for(final value in rawSeasons){
        final item=_asMap(value);
        if(item['current']==true&&item['year']!=null){currentSeason=item['year'].toString();break;}
      }
    }
    setState((){
      _selectedLeagueId=id;_selectedLeagueName=_leagueName(row);_seasons=seasons;
      _season=currentSeason??(seasons.isEmpty?DateTime.now().year.toString():seasons.first);
      _standingRows=<Map<String,dynamic>>[];_error=null;
    });
  }

  List<Map<String,dynamic>> _extractStandingRows(List<Map<String,dynamic>> roots){
    final rows=<Map<String,dynamic>>[];
    final seen=<String>{};
    void visit(dynamic node){
      if(node is List){for(final item in node){visit(item);}return;}
      if(node is! Map)return;
      final map=Map<String,dynamic>.from(node);
      final team=map['team']??map['competitor']??map['participant'];
      final hasPosition=map.containsKey('rank')||map.containsKey('position')||map.containsKey('place');
      if(hasPosition&&(team!=null||map.containsKey('points')||map.containsKey('name'))){
        final identity=(map['rank']??map['position']??map['place']).toString()+':'+(_text(team).isEmpty?_text(map['name']):_text(team));
        if(seen.add(identity))rows.add(map);
        return;
      }
      for(final value in map.values){visit(value);}
    }
    for(final root in roots){visit(root);}
    rows.sort((a,b){
      final ar=int.tryParse((a['rank']??a['position']??a['place']??9999).toString())??9999;
      final br=int.tryParse((b['rank']??b['position']??b['place']??9999).toString())??9999;
      return ar.compareTo(br);
    });
    return rows;
  }

  Future<void> _loadStandings() async {
    final id=_selectedLeagueId;
    if(id==null){setState(()=>_error='Primero selecciona una liga.');return;}
    setState((){
      _loadingStandings=true;_error=null;_standingRows=<Map<String,dynamic>>[];
    });
    try{
      final result=await _service.fetchStandings(sport:_sport,leagueId:id,season:_season);
      final rows=_extractStandingRows(result);
      if(!mounted)return;
      setState((){
        _loadingStandings=false;_standingRows=rows;
        if(rows.isEmpty)_error='El proveedor no devolvió una tabla para esa liga y temporada.';
      });
    }catch(error){
      if(!mounted)return;
      setState((){
        _loadingStandings=false;_error=error.toString();
      });
    }
  }

  String _rowName(Map<String,dynamic> row){
    final team=row['team']??row['competitor']??row['participant'];
    if(_text(team).isNotEmpty)return _text(team);
    return _text(row['name']??row['player']??row['driver']);
  }

  String _rowSubtitle(Map<String,dynamic> row){
    final all=_asMap(row['all']??row['games']??row['statistics']);
    final fields=<String>[];
    final played=all['played']??all['games']??row['played'];
    final won=all['win']??all['wins']??row['wins'];
    final drawn=all['draw']??all['draws'];
    final lost=all['lose']??all['losses']??row['losses'];
    final goals=_asMap(all['goals'])['for']??all['points']??row['goals'];
    if(played!=null)fields.add('PJ '+played.toString());
    if(won!=null)fields.add('G '+won.toString());
    if(drawn!=null)fields.add('E '+drawn.toString());
    if(lost!=null)fields.add('P '+lost.toString());
    if(goals!=null)fields.add('GF '+goals.toString());
    return fields.join('  ·  ');
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor:_statsBg,
      appBar:AppBar(
        backgroundColor:_statsBg,
        title:const Text('ESTADÍSTICAS Y CLASIFICACIONES',
          style:TextStyle(color:_statsCyan,fontSize:13,fontWeight:FontWeight.w900)),
      ),
      body:ListView(
        padding:const EdgeInsets.fromLTRB(14,10,14,24),
        children:<Widget>[
          const Text('Consulta ligas y tablas oficiales a través del servidor deportivo.',
            style:TextStyle(color:_statsMuted,fontSize:12,height:1.45)),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            value:_sport,
            decoration:const InputDecoration(labelText:'Deporte',filled:true,fillColor:_statsPanel),
            dropdownColor:_statsPanel,
            items:_sports.map((sport)=>DropdownMenuItem<String>(value:sport,child:Text(sport))).toList(),
            onChanged:(value){
              if(value==null)return;
              setState((){
                _sport=value;_leagues=<Map<String,dynamic>>[];_standingRows=<Map<String,dynamic>>[];
                _selectedLeagueId=null;_selectedLeagueName='';_seasons=<String>[];_error=null;
              });
            },
          ),
          const SizedBox(height:10),
          TextField(
            controller:_searchController,
            textInputAction:TextInputAction.search,
            onSubmitted:(_)=>_searchLeagues(),
            style:const TextStyle(color:Colors.white),
            decoration:InputDecoration(
              labelText:'Buscar liga o competición',hintText:'Ej.: Premier League',
              filled:true,fillColor:_statsPanel,
              suffixIcon:IconButton(
                tooltip:'Buscar ligas',onPressed:_searching?null:_searchLeagues,
                icon:const Icon(Icons.search_rounded,color:_statsCyan),
              ),
            ),
          ),
          const SizedBox(height:9),
          SizedBox(
            width:double.infinity,
            child:OutlinedButton.icon(
              onPressed:_searching?null:_searchLeagues,
              icon:_searching?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.manage_search_rounded),
              label:Text(_searching?'BUSCANDO LIGAS…':'BUSCAR LIGAS'),
              style:OutlinedButton.styleFrom(foregroundColor:_statsCyan,side:const BorderSide(color:_statsCyan)),
            ),
          ),
          if(_leagues.isNotEmpty)...<Widget>[
            const SizedBox(height:16),
            const Text('RESULTADOS DE LIGAS',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
            const SizedBox(height:7),
            ..._leagues.take(12).map((row){
              final id=_leagueId(row);
              final selected=id==_selectedLeagueId;
              final country=_asMap(row['country'])['name'];
              return Card(
                color:selected?const Color(0xFF102746):_statsPanel,
                shape:RoundedRectangleBorder(
                  side:BorderSide(color:selected?_statsCyan:_statsLine),
                  borderRadius:BorderRadius.circular(11),
                ),
                child:ListTile(
                  dense:true,
                  leading:CircleAvatar(
                    backgroundColor:_statsBlue.withAlpha(45),
                    child:const Icon(Icons.emoji_events_rounded,color:_statsCyan,size:20),
                  ),
                  title:Text(_leagueName(row).isEmpty?'Liga '+id:_leagueName(row),
                    style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12)),
                  subtitle:Text('ID '+id+(country==null?'':'  ·  '+country.toString()),
                    style:const TextStyle(color:_statsMuted,fontSize:10)),
                  trailing:Icon(selected?Icons.check_circle:Icons.chevron_right,color:_statsCyan),
                  onTap:()=>_selectLeague(row),
                ),
              );
            }),
          ],
          if(_selectedLeagueId!=null)...<Widget>[
            const SizedBox(height:16),
            Container(
              padding:const EdgeInsets.all(13),
              decoration:BoxDecoration(
                color:_statsPanel,border:Border.all(color:_statsCyan.withAlpha(150)),
                borderRadius:BorderRadius.circular(12),
              ),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:<Widget>[
                  Text(_selectedLeagueName.isEmpty?'Liga '+_selectedLeagueId!:_selectedLeagueName,
                    style:const TextStyle(color:_statsCyan,fontWeight:FontWeight.w900)),
                  const SizedBox(height:9),
                  DropdownButtonFormField<String>(
                    value:_season,
                    decoration:const InputDecoration(labelText:'Temporada',filled:true,fillColor:Color(0xFF0B1B31)),
                    dropdownColor:_statsPanel,
                    items:(_seasons.isEmpty?<String>[_season]:_seasons)
                        .map((season)=>DropdownMenuItem<String>(value:season,child:Text(season))).toList(),
                    onChanged:(value){if(value!=null)setState(()=>_season=value);},
                  ),
                  const SizedBox(height:10),
                  FilledButton.icon(
                    onPressed:_loadingStandings?null:_loadStandings,
                    icon:_loadingStandings
                        ?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:_statsBg))
                        :const Icon(Icons.leaderboard_rounded),
                    label:Text(_loadingStandings?'CARGANDO TABLA…':'VER CLASIFICACIÓN'),
                    style:FilledButton.styleFrom(backgroundColor:_statsCyan,foregroundColor:_statsBg),
                  ),
                ],
              ),
            ),
          ],
          if(_error!=null)...<Widget>[
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(
                color:const Color(0xFF2A1424),border:Border.all(color:const Color(0xFFFF28CF)),
                borderRadius:BorderRadius.circular(11),
              ),
              child:Text(_error!,style:const TextStyle(color:Colors.white,fontSize:12)),
            ),
          ],
          if(_loadingStandings)...<Widget>[
            const SizedBox(height:20),
            const Center(child:CircularProgressIndicator(color:_statsCyan)),
          ],
          if(_standingRows.isNotEmpty)...<Widget>[
            const SizedBox(height:18),
            Text('TABLA • '+_selectedLeagueName+' • '+_season,
              style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:12)),
            const SizedBox(height:7),
            ..._standingRows.asMap().entries.map((entry){
              final index=entry.key;
              final row=entry.value;
              final rank=row['rank']??row['position']??row['place']??index+1;
              final points=row['points']??row['point']??row['score'];
              final name=_rowName(row);
              final subtitle=_rowSubtitle(row);
              return Container(
                margin:const EdgeInsets.only(bottom:7),
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                decoration:BoxDecoration(
                  color:_statsPanel,borderRadius:BorderRadius.circular(11),
                  border:Border.all(color:_statsLine),
                ),
                child:Row(
                  children:<Widget>[
                    SizedBox(width:30,child:Text(rank.toString(),textAlign:TextAlign.center,
                      style:const TextStyle(color:_statsCyan,fontWeight:FontWeight.w900,fontSize:15))),
                    const SizedBox(width:8),
                    Expanded(
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:<Widget>[
                          Text(name.isEmpty?'Equipo / participante':name,maxLines:2,overflow:TextOverflow.ellipsis,
                            style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12)),
                          if(subtitle.isNotEmpty)...<Widget>[
                            const SizedBox(height:3),
                            Text(subtitle,style:const TextStyle(color:_statsMuted,fontSize:10)),
                          ],
                        ],
                      ),
                    ),
                    if(points!=null)...<Widget>[
                      const SizedBox(width:8),
                      Column(
                        children:<Widget>[
                          Text(points.toString(),style:const TextStyle(color:_statsCyan,fontWeight:FontWeight.w900,fontSize:17)),
                          const Text('PTS',style:TextStyle(color:_statsMuted,fontSize:8)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height:12),
          const Text('Los datos dependen de la cobertura y del plan de tu proveedor API-Sports. La aplicación no inventa clasificaciones cuando la fuente no devuelve información.',
            textAlign:TextAlign.center,style:TextStyle(color:_statsMuted,fontSize:10,height:1.4)),
        ],
      ),
    );
  }
}
