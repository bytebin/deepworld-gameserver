# Notes
# http://wiki.guildwars2.com/wiki/Experience

def xp_for_level(level)
  return 0 if level == 0
  xp_for_level(level - 1) + (2000 + 500*level)
end

@xp_requirements = (1..200).map{ |l| xp_for_level(l) }

def level_for_xp(xp)
  @xp_requirements.index{ |lv_xp| lv_xp >= xp }
end

def list_levels
  (1..100).each do |l|
    p "Level #{l}: #{xp_for_level l} xp"
  end
end

list_levels

peeps = [
{"name"=>'Sirentist',"achievements"=>40,"level"=>59,"minerals mined"=>77087, "chunks explored"=>198890, "maws plugged"=>2660, "purifier parts discovered"=>624, "trees mined"=>20391, "undertakings"=>455, "automata killed"=>3091, "teleporters discovered"=>345, "creatures killed"=>21300, "creatures maimed"=>628, "infernal parts discovered"=>63, "supernatural killed"=>441, "brains killed"=>968, "dungeons raided"=>1623, "deliverances"=>134, "chests looted"=>10381, "animals trapped"=>59, "landmarks upvoted"=>125},
{"name"=>'dmmagic',"achievements"=>37,"level"=>56,"chunks explored"=>45070, "minerals mined"=>87090, "automata killed"=>3572, "creatures killed"=>17335, "trees mined"=>9654, "undertakings"=>20, "creatures maimed"=>331, "maws plugged"=>114, "brains killed"=>825, "purifier parts discovered"=>224, "dungeons raided"=>611, "teleporters discovered"=>200, "chests looted"=>4408, "supernatural killed"=>547, "infernal parts discovered"=>14, "deliverances"=>17, "animals trapped"=>25, "landmarks upvoted"=>127},
{"name"=>'Cpt_FluffyBottom',"achievements"=>37,"level"=>40,"chests looted"=>2970, "minerals mined"=>18603, "chunks explored"=>34449, "trees mined"=>5124, "creatures killed"=>9629, "automata killed"=>2471, "creatures maimed"=>603, "undertakings"=>186, "brains killed"=>857, "maws plugged"=>246, "dungeons raided"=>591, "purifier parts discovered"=>201, "teleporters discovered"=>148, "supernatural killed"=>674, "infernal parts discovered"=>14, "animals trapped"=>36, "landmarks upvoted"=>91, "deliverances"=>18},
{"name"=>'KaitB',"achievements"=>34,"level"=>35,"chests looted"=>531, "minerals mined"=>5893, "chunks explored"=>8331, "trees mined"=>1678, "automata killed"=>1091, "creatures killed"=>2937, "brains killed"=>166, "creatures maimed"=>219, "undertakings"=>23, "purifier parts discovered"=>25, "teleporters discovered"=>28, "maws plugged"=>57, "landmarks upvoted"=>119, "animals trapped"=>30, "supernatural killed"=>144, "dungeons raided"=>30, "infernal parts discovered"=>1},
{"name"=>'Mk3_collector',"achievements"=>29,"chests looted"=>529, "minerals mined"=>2703, "chunks explored"=>6865, "trees mined"=>900, "purifier parts discovered"=>28, "creatures killed"=>595, "brains killed"=>58, "creatures maimed"=>23, "teleporters discovered"=>26, "automata killed"=>150, "supernatural killed"=>3, "maws plugged"=>27, "landmarks upvoted"=>11, "undertakings"=>20, "dungeons raided"=>63, "infernal parts discovered"=>1},
{"name"=>'awesomeo13',"achievements"=>26,"chests looted"=>520, "minerals mined"=>3446, "creatures killed"=>841, "chunks explored"=>5822, "trees mined"=>1378, "automata killed"=>190, "brains killed"=>41, "creatures maimed"=>10, "maws plugged"=>42, "purifier parts discovered"=>32, "teleporters discovered"=>19, "dungeons raided"=>58, "landmarks upvoted"=>20, "supernatural killed"=>20, "undertakings"=>12, "animals trapped"=>17},
{"name"=>'Doomworld',"achievements"=>23,"chests looted"=>156, "minerals mined"=>1678, "brains killed"=>43, "creatures maimed"=>20, "creatures killed"=>519, "trees mined"=>4541, "chunks explored"=>2730, "purifier parts discovered"=>8, "automata killed"=>85, "supernatural killed"=>6, "undertakings"=>34, "landmarks upvoted"=>17, "teleporters discovered"=>10, "maws plugged"=>29, "dungeons raided"=>6},
{"name"=>'Vatch',"achievements"=>13,"chests looted"=>40, "minerals mined"=>1307, "creatures killed"=>333, "automata killed"=>63, "chunks explored"=>755, "trees mined"=>549, "creatures maimed"=>5, "maws plugged"=>87, "undertakings"=>20, "teleporters discovered"=>1, "landmarks upvoted"=>1, "animals trapped"=>4, "dungeons raided"=>1, "purifier parts discovered"=>1, "supernatural killed"=>5, "deliverances"=>1},
{"name"=>'alecpingolymail.com',"achievements"=>13,"chests looted"=>94, "minerals mined"=>1704, "chunks explored"=>1306, "teleporters discovered"=>2, "trees mined"=>1453, "automata killed"=>89, "creatures killed"=>436, "creatures maimed"=>13, "brains killed"=>10, "purifier parts discovered"=>3, "landmarks upvoted"=>4},
{"name"=>'jmo4258',"achievements"=>5,"level"=>6,"chests looted"=>13, "minerals mined"=>178, "creatures killed"=>77, "chunks explored"=>31, "automata killed"=>8, "creatures maimed"=>1, "trees mined"=>3}
]

xp_more_killing_mod = 2
xp_more_deliverances_mod = 2
xp_less_single_dungeon_raiding_mod = 0.8
xp_tougher_dungeons_mod = 2
xp_no_sky_explored_mod = 0.8

scaled_bonus = 50 + 50 + (4272/13)

xp_bonuses = {
  'achievements' => 2000 + scaled_bonus, # Coded
  'automata killed' => 5 * xp_more_killing_mod, # Coded
  'creatures killed' => 2 * xp_more_killing_mod, # Coded
  'brains killed' => 15 * xp_more_killing_mod, # Coded
  'purifier parts discovered' => 50, # Coded
  'maws plugged' => 5, # Coded
  "undertakings"=> 25, # Coded
  "teleporters discovered" => 50, # Coded
  "infernal parts discovered"=> 50, # Coded
  "dungeons raided"=> 250 * xp_less_single_dungeon_raiding_mod * xp_tougher_dungeons_mod, # Coded
  "deliverances"=> 25 * xp_more_deliverances_mod, # Coded
  "chests looted"=> 25, # Coded
  "animals trapped"=> 5, # Coded
  "minerals mined"=> 2 + 8, # Coded
  "chunks explored"=> 10 * xp_no_sky_explored_mod, # Coded
  "landmarks upvoted" => 10, # Coded
  "items first discovered" => 50, # Coded
  "items first crafted" => 50, # Coded
  "items crafted" => 1 # Coded
}

peeps.each do |peep|
  lvl = peep['achievements']
  calc_xp = xp_bonuses.inject(0) do |xp, bonus|
    xp += (peep[bonus[0]] || 0) * bonus[1]
    xp
  end

  stats = [
    "#{lvl} ach",
    "#{xp_for_level(lvl)} xp",
    "#{calc_xp.to_i} xp",
    "#{(calc_xp / xp_for_level(lvl).to_f * 100).round}%",
    "lv #{(level_for_xp calc_xp).to_s.ljust(2)} vs #{lvl}"

  ].map{ |s| s.ljust(13) }
  p "#{peep['name'].ljust(20)}: #{stats.join(' ')}"
end

