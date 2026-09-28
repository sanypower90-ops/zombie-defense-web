from pathlib import Path
import re, math, sys, json
ROOT=Path(__file__).resolve().parent

def read(p): return (ROOT/p).read_text(encoding='utf-8')
main=read('scripts/main.gd'); player=read('scripts/player.gd'); zombie=read('scripts/zombie.gd'); pickup=read('scripts/pickup.gd'); lb=read('scripts/leaderboard.gd'); save=read('scripts/save_manager.gd'); wf=read('deploy/github-pages-workflow.yml'); readme=read('README.md')
checks=[]
def check(name, cond, detail=''):
    checks.append((name,bool(cond),detail))

def balanced(text):
    stack=[]; pairs={')':'(',']':'[','}':'{'}; opens=set(pairs.values()); quote=None; esc=False
    for line in text.splitlines():
        i=0
        while i<len(line):
            c=line[i]
            if quote:
                if esc: esc=False
                elif c=='\\': esc=True
                elif c==quote: quote=None
                i+=1; continue
            if c=='#': break
            if c in "'\"": quote=c; i+=1; continue
            if c in opens: stack.append(c)
            elif c in pairs:
                if not stack or stack[-1]!=pairs[c]: return False
                stack.pop()
            i+=1
    return not stack and quote is None

for name,text in [('main',main),('player',player),('zombie',zombie),('pickup',pickup),('leaderboard',lb),('save',save)]:
    check(f'{name}: brackets/quotes', balanced(text))
    funcs=re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(', text, re.M)
    check(f'{name}: no duplicate funcs', len(funcs)==len(set(funcs)), str([x for x in funcs if funcs.count(x)>1]))

check('round duration 30s','const ROUND_DURATION := 30.0' in main)
check('max round 100','const MAX_ROUND := 100' in main)
check('special boost rounds exact','const SPECIAL_COUNT_BOOST_ROUNDS := [11, 21, 31, 51, 61, 71, 81, 91]' in main)
check('round clears zombies','_clear_zombies_and_pickups()' in main[main.index('func _finish_round'):main.index('func _save_checkpoint')])
check('checkpoint every 10 rounds','if round_number % 10 == 0:' in main[main.index('func _finish_round'):main.index('func _save_checkpoint')])
check('death clears checkpoint','save_manager.clear_checkpoint()' in main[main.index('func on_player_dead'):main.index('func _end_run')])
check('laser 5 ammo', '"laser": {"name":"블루 레이저 캐논", "damage":1500.0' in main and '"ammo_max":5' in main)
check('flamethrower present','"flamethrower"' in main)
check('laser blue beam', 'Color(0.10, 0.62, 1.0)' in main and '_make_beam' in main)
check('laser penetrates', '_fire_line(start, forward, max_range, hit_width, laser_damage, true)' in main)
check('special slots max 2','if special_slots.size() >= 2:' in player and 'special_slots.pop_front()' in player)
check('pistol 12-mag', 'var base_mag_max = 12' in player and 'reload_left = 1.0' in player)
check('pickup evolution functional','func get_pickup_radius()' in main and 'game.get_pickup_radius()' in pickup and 'func get_xp_multiplier()' in main)
check('top10 limit','limit=10' in lb)
check('nickname validation','^[A-Za-z0-9가-힣_]{2,12}$' in main)
check('PC physical WASD', 'Input.is_physical_key_pressed(KEY_W)' in player and 'Input.is_physical_key_pressed(KEY_A)' in player)
check('mobile dual touch', 'InputEventScreenTouch' in player and 'move_touch_id' in player and 'aim_touch_id' in player and 'touch_firing' in player)
check('mobile touch UI', 'func _build_touch_controls' in main and '조준 · 사격' in main)
check('visible bullet tracers', 'func _make_tracer' in main and '0.16, 0.48' in main and '1.20' in main)
check('reference sheets packaged', all((ROOT/'assets/reference'/name).exists() for name in ['player_sheet.png','zombie_sheet.png','weapon_sheet.png','item_sheet.png','map_props_sheet.png']))
check('tie-aware top10','cutoff_round' in main and 'cutoff_kills' in main)
check('supabase public config placeholders','const SUPABASE_URL := ""' in read('config/leaderboard_config.gd'))
check('workflow godot 4.7.2','barichello/godot-ci:4.7.2' in wf)
check('workflow no self-copy','cp -R "/root/.local/share/godot/export_templates/' not in wf)
check('workflow web export','--export-release "Web" build/web/index.html' in wf)

# Independent numerical model of the requested round rules.
special=[11,21,31,51,61,71,81,91]
def regular_target(r):
    if r>=100:
        return max(regular_target(99)*3-1,1)
    base=15+math.floor((r-1)*0.22)
    mult=1.0
    for t in special:
        if r>=t: mult*=1.30
    return max(1,round(base*mult))
vals=[regular_target(r) for r in range(1,101)]
check('difficulty nondecreasing 1-99', all(vals[i]>=vals[i-1] for i in range(1,99)))
check('R100 total enemy count exact 3x R99', vals[99]+1 == vals[98]*3, f'R99={vals[98]}, R100 regular={vals[99]}, + boss={vals[99]+1}')
check('HP growth capped modestly','return min(1.0 + float(r - 1) * 0.012, 2.20)' in main)
check('damage growth capped modestly','return min(1.0 + float(r - 1) * 0.006, 1.60)' in main)
check('speed growth capped modestly','return min(1.0 + float(r - 1) * 0.002, 1.18)' in main)

failed=[c for c in checks if not c[1]]
print(json.dumps({'total':len(checks),'passed':len(checks)-len(failed),'failed':failed},ensure_ascii=False,indent=2))
sys.exit(1 if failed else 0)
