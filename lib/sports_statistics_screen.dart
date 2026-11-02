import 'package:flutter/material.dart';
import 'sports_api_service.dart';

const Color _statsBg=Color(0xFF030814);
const Color _statsPanel=Color(0xFF071326);
const Color _statsLine=Color(0xFF123D65);
const Color _statsCyan=Color(0xFF00E5FF);
const Color _statsBlue=Color(0xFF087BFF);
const Color _statsMuted=Color(0xFFA9BDD6);

class SportsStatisticsScreen extends StatefulWidget {
  const SportsStatisticsScreen({super.key, this.initialSport = 'Fútbol', this.onOpenAgenda});
  final String initialSport;
  final VoidCallback? onOpenAgenda;
  @override
  State<SportsStatisticsScreen> createState()=>_SportsStatisticsScreenState();
}

class _SportsStatisticsScreenState extends State<SportsStatisticsScreen> {
  static const List<String> _sports=<String>[
    'Fútbol','Básquet','NBA','Béisbol','Fútbol americano',
    'Hockey sobre hielo','Balonmano','Rugby','Vóley','Fútbol australiano','Fórmula 1','MMA',
  ];
  static const Map<String,String> _sportIds=<String,String>{
    'Fútbol':'football','Básquet':'basketball','NBA':'nba','Béisbol':'baseball',
    'Fútbol americano':'american-football','Hockey sobre hielo':'hockey',
    'Balonmano':'handball','Rugby':'rugby','Vóley':'volleyball',
    'Fútbol australiano':'afl','Fórmula 1':'formula-1','MMA':'mma',
  };
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
  void initState(){
    super.initState();
    if(_sports.contains(widget.initialSport))_sport=widget.initialSport;
  }

  String _t(String es,String en,String pt,String fr){
    switch(Localizations.localeOf(context).languageCode){
      case 'en':return en;
      case 'pt':return pt;
      case 'fr':return fr;
      default:return es;
    }
  }

  String _sportLabel(String sport){
    switch(sport){
      case 'Fútbol':return _t('Fútbol','Football','Futebol','Football');
      case 'Básquet':return _t('Básquet','Basketball','Basquete','Basket-ball');
      case 'Béisbol':return _t('Béisbol','Baseball','Beisebol','Baseball');
      case 'Fútbol americano':return _t('Fútbol americano','American football','Futebol americano','Football américain');
      case 'Hockey sobre hielo':return _t('Hockey sobre hielo','Ice hockey','Hóquei no gelo','Hockey sur glace');
      case 'Balonmano':return _t('Balonmano','Handball','Handebol','Handball');
      case 'Vóley':return _t('Vóley','Volleyball','Vôlei','Volley-ball');
      case 'Fútbol australiano':return _t('Fútbol australiano','Australian football','Futebol australiano','Football australien');
      case 'Fórmula 1':return 'Formula 1';
      case 'MMA':return 'MMA';
      default:return sport;
    }
  }

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
    final id=league['id']??row['id']??(_sport=='MMA'?(row['name']??row['category']):null);
    return (id??'').toString().trim();
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
    if (id.isEmpty || (_sport != 'MMA' && !RegExp(r'^\d+$').hasMatch(id))) {
      setState(() => _error = 'La competición seleccionada no tiene un identificador válido.');
      return;
    }
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
      if(_sport=='MMA'){
        final fighters=map['fighters'] is List ? map['fighters'] as List : const <dynamic>[];
        final firstRaw=map['fighter1']??map['home']??(fighters.isNotEmpty?fighters[0]:null);
        final secondRaw=map['fighter2']??map['away']??(fighters.length>1?fighters[1]:null);
        final first=_asMap(firstRaw);
        final second=_asMap(secondRaw);
        final firstName=_text(first['name']??firstRaw);
        final secondName=_text(second['name']??secondRaw);
        final fightName=[firstName,secondName].where((v)=>v.isNotEmpty).join(' vs ');
        rows.add(<String,dynamic>{'rank':rows.length+1,'name':fightName.isEmpty?'Combate ${map['id']??''}':fightName,'fight':map,'id':map['id']});
        return;
      }
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

  String _rowLogo(Map<String,dynamic> row){
    final fight=_asMap(row['fight']);
    final fighters=fight['fighters'] is List ? fight['fighters'] as List : const <dynamic>[];
    final firstFighter=fight['fighter1']??(fighters.isNotEmpty?fighters[0]:null);
    final team=_asMap(row['team']??row['competitor']??row['participant']??firstFighter);
    final nested=_asMap(team['team']);
    return (team['logo']??team['image']??nested['logo']??row['logo']??'').toString().trim();
  }

  String _rowIdentifier(Map<String,dynamic> row){
    final fight=_asMap(row['fight']);
    final team=_asMap(row['team']??row['competitor']??row['participant']);
    final nested=_asMap(team['team']);
    final id=team['id']??nested['id']??row['id']??fight['id'];
    return id==null?'':'ID $id';
  }

  Widget _badgeImage(String url, IconData fallback){
    if(url.isEmpty){
      return CircleAvatar(backgroundColor:_statsBlue.withAlpha(45),child:Icon(fallback,color:_statsCyan,size:20));
    }
    return CircleAvatar(
      backgroundColor:_statsBlue.withAlpha(45),
      child:ClipOval(child:Image.network(url,width:34,height:34,fit:BoxFit.contain,
        errorBuilder:(_,__,___)=>Icon(fallback,color:_statsCyan,size:20))),
    );
  }

  String _rowName(Map<String,dynamic> row){
    final team=row['team']??row['competitor']??row['participant'];
    if(_text(team).isNotEmpty)return _text(team);
    if(_text(row['name']).isNotEmpty)return _text(row['name']);
    return _text(row['name']??row['player']??row['driver']);
  }

  String _rowSubtitle(Map<String,dynamic> row){
    if(_sport=='MMA'){
      final fight=_asMap(row['fight']);
      final status=_text(fight['status']??fight['result']);
      final category=_text(fight['category']??fight['weight_class']);
      return <String>[category,status].where((v)=>v.isNotEmpty).join('  ·  ');
    }
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
        title:Text(_t('ESTADÍSTICAS','STATISTICS','ESTATÍSTICAS','STATISTIQUES'),
          style:const TextStyle(color:_statsCyan,fontSize:14,fontWeight:FontWeight.w900)),
        actions:<Widget>[
          if(widget.onOpenAgenda!=null)IconButton(
            tooltip:'Abrir agenda de partidos',
            onPressed:widget.onOpenAgenda,
            icon:const Icon(Icons.calendar_month_rounded,color:_statsCyan),
          ),
        ],
      ),
      body:ListView(
        padding:const EdgeInsets.fromLTRB(14,10,14,24),
        children:<Widget>[
          Text(_t('Consulta estadísticas, competiciones y clasificaciones de varios deportes.','Browse statistics, competitions and standings across sports.','Consulte estatísticas, competições e classificações de vários esportes.','Consultez les statistiques, compétitions et classements de plusieurs sports.'),
            style:const TextStyle(color:_statsMuted,fontSize:12,height:1.45)),
          const SizedBox(height:5),
          Text(_t('IDENTIFICADOR DEL DEPORTE:','SPORT ID:','ID DO ESPORTE:','ID DU SPORT:')+' ${_sportIds[_sport]??'—'}',
            style:const TextStyle(color:_statsCyan,fontSize:10,fontWeight:FontWeight.w800)),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            value:_sport,
            decoration:InputDecoration(labelText:_t('Deporte','Sport','Esporte','Sport'),filled:true,fillColor:_statsPanel),
            dropdownColor:_statsPanel,
            items:_sports.map((sport)=>DropdownMenuItem<String>(value:sport,child:Text(_sportLabel(sport)))).toList(),
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
              labelText:_t('Buscar liga o competición','Search league or competition','Buscar liga ou competição','Rechercher une ligue ou compétition'),hintText:_sport=='Fórmula 1'?'Ej.: 2026':_sport=='MMA'?'Ej.: peso ligero':'Ej.: Premier League',
              filled:true,fillColor:_statsPanel,
              suffixIcon:IconButton(
                tooltip:_t('Buscar competiciones','Search competitions','Buscar competições','Rechercher des compétitions'),onPressed:_searching?null:_searchLeagues,
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
              label:Text(_searching?_t('BUSCANDO…','SEARCHING…','BUSCANDO…','RECHERCHE…'):_t('BUSCAR','SEARCH','BUSCAR','RECHERCHER')),
              style:OutlinedButton.styleFrom(foregroundColor:_statsCyan,side:const BorderSide(color:_statsCyan)),
            ),
          ),
          if(_leagues.isNotEmpty)...<Widget>[
            const SizedBox(height:16),
            Text(_t('RESULTADOS DE COMPETICIONES','COMPETITION RESULTS','RESULTADOS DAS COMPETIÇÕES','RÉSULTATS DES COMPÉTITIONS'),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
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
                  leading:_badgeImage(
                    (_asMap(row['league'])['logo']??_asMap(row['country'])['flag']??row['logo']??'').toString(),
                    Icons.emoji_events_rounded,
                  ),
                  title:Text(_leagueName(row).isEmpty?'Liga '+id:_leagueName(row),
                    style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12)),
                  subtitle:Text('ID '+id+(country==null?'':'  ·  '+country.toString())+'  ·  ${_sportIds[_sport]??_sport}',
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
                    decoration:const InputDecoration(labelText:_t('Temporada','Season','Temporada','Saison'),filled:true,fillColor:Color(0xFF0B1B31)),
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
                    label:Text(_loadingStandings?_t('CARGANDO…','LOADING…','CARREGANDO…','CHARGEMENT…'):_t('VER ESTADÍSTICAS','VIEW STATISTICS','VER ESTATÍSTICAS','VOIR LES STATISTIQUES')),
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
            Text(_t('ESTADÍSTICAS • ','STATISTICS • ','ESTATÍSTICAS • ','STATISTIQUES • ')+_selectedLeagueName+' • '+_season,
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
                    const SizedBox(width:7),
                    _badgeImage(_rowLogo(row),Icons.shield_rounded),
                    const SizedBox(width:8),
                    Expanded(
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:<Widget>[
                          Text(name.isEmpty?'Equipo / participante':name,maxLines:2,overflow:TextOverflow.ellipsis,
                            style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12)),
                          if(_rowIdentifier(row).isNotEmpty||subtitle.isNotEmpty)...<Widget>[
                            const SizedBox(height:3),
                            Text(<String>[_rowIdentifier(row),subtitle].where((v)=>v.isNotEmpty).join('  ·  '),
                              style:const TextStyle(color:_statsMuted,fontSize:10)),
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
          Text(_t('Los datos dependen de la cobertura y del plan de API-Sports. No se inventan resultados cuando la fuente no devuelve información.','Data depends on API-Sports coverage and subscription. Results are never fabricated when the source has no data.','Os dados dependem da cobertura e do plano API-Sports. Os resultados não são inventados quando a fonte não retorna dados.','Les données dépendent de la couverture et de l’abonnement API-Sports. Aucun résultat n’est inventé lorsque la source ne renvoie aucune donnée.'),
            textAlign:TextAlign.center,style:const TextStyle(color:_statsMuted,fontSize:10,height:1.4)),
        ],
      ),
    );
  }
}
