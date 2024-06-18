#using scripts\core_common\values_shared;
#using scripts\core_common\system_shared;
#using scripts\core_common\callbacks_shared;
#using scripts\core_common\util_shared;
#using scripts\core_common\array_shared;
#using scripts\core_common\clientfield_shared;
#using scripts\zm_common\zm_pack_a_punch;
#using scripts\zm_common\zm_weapons;
#using scripts\zm_common\gametypes\globallogic;
#using scripts\zm_common\callbacks;
#using scripts\zm_common\zm_unitrigger;
#using scripts\zm_common\zm_utility;
#using scripts\zm_common\zm_score;

#namespace zm_pack_a_punch;

function autoexec __init__system__() {
    system::register(#"acts_zm_pack_a_punch", &__init__, &__main__, #"zm_weapons");
}

function private __init__() {
    level._effect[#"acts_zm_pack_a_punch_weapon"] = #"hash_4bd4c9b0fb97f425";
}

function private __main__() {
    waitframe(1); // just in case, for other mods
    if (!isdefined(level.zombie_weapons_upgraded) || !isdefined(level.zombie_include_weapons)) {
        a = undefined[0]; // wtf? force error
        return;
    }

    level.acts_pap_quest = {
        #weapons: [],
        #weapons_total: 0,
        #cfg: get_map_config_data(),
        #cfgg: get_config_data(),
    };

    foreach (weapon, struct in level.zombie_weapons) {
        if (isdefined(struct) && struct.is_in_box && isdefined(struct.upgrade) && struct.weapon_classname !== "equipment") {
            level.acts_pap_quest.weapons[weapon] = struct;
        }
    }
    level.acts_pap_quest.weapons_total = level.acts_pap_quest.weapons.size;


    callback::function_aebeafc0(&on_use_pack_a_punch);

    // dev things
    /#
        callback::on_spawned(&cmd_think);
    #/

    if (getdvarint(#"apap_no_looter", false) || !isdefined(level.acts_pap_quest.cfg)) {
        return; // not available for this map
    }

    // spawn weapon giver

    looter = util::spawn_model(#"tag_origin", level.acts_pap_quest.cfg.main_loc_origin + (0, 0, 40));
    looter setmodel(level.acts_pap_quest.cfgg.base_model);
    looter.beacon = util::spawn_model(#"tag_origin", looter.origin, (-90, 0, -90));
    playfxontag(level._effect[#"acts_zm_pack_a_punch_weapon"], looter.beacon, "tag_origin");
    looter.utrigger = looter zm_unitrigger::create(undefined, 64, &looter_trigger);
    level.acts_pap_quest.zombie_cost = level.acts_pap_quest.cfgg.start_price;
    level.acts_pap_quest.looter = looter;

    looter.utrigger.cursor_hint = "HINT_NOICON";
    looter.utrigger.hint_string = #"acts/pap/buy_custom_weapon";
    looter.utrigger.hint_parm1 = level.acts_pap_quest.zombie_cost;
    
    looter thread anim_looter();
}

// rotate the looter
function private anim_looter() {
    level endon(#"end_game", #"game_ended");


    while (isdefined(self)) {
        waittime = randomfloatrange(2.5, 5);
        yaw = randomint(360);
        if (yaw > 300) {
            yaw = 300;
        } else if (yaw < 60) {
            yaw = 60;
        }
        yaw = self.angles[1] + yaw;
        new_angles = (-60 + randomint(120), yaw, -45 + randomint(90));
        self rotateto(new_angles, waittime, waittime * 0.5, waittime * 0.5);
        wait randomfloat(waittime - 0.1);
    }
}

// find an unpacked weapon or return undefined
function private get_new_weapon() {
    arr = array::randomize(getarraykeys(level.acts_pap_quest.weapons));
    foreach (w in arr) {
        weap = level.acts_pap_quest.weapons[w].weapon;
        if (!self hasweapon(weap)) {
            return weap;
        }
    }
}

function private looter_trigger() {
    while (true) {
        waitresult = self waittill(#"trigger");
        player = waitresult.activator;
        if (!isdefined(player) || !isalive(player) || !zm_utility::can_use(player) || !player zm_score::can_player_purchase(level.acts_pap_quest.zombie_cost)) {
            continue;
        }

        w = player get_new_weapon();
        if (!isdefined(w)) {
            continue; // no weapon???
        }

        player zm_score::minus_to_player_score(level.acts_pap_quest.zombie_cost);

        player giveweapon(w);
        player switchtoweapon(w);

        level.acts_pap_quest.zombie_cost += level.acts_pap_quest.cfgg.increase_price;
        level.acts_pap_quest.looter.utrigger.hint_parm1 = level.acts_pap_quest.zombie_cost;
    }
}

/#
function private cmd_think() {
    setdvar(#"apap_force_next_weapon", false);
    while (true) {
        wait 1;
        if (getdvarint(#"apap_force_next_weapon", false)) {
            w = array::random(getarraykeys(level.acts_pap_quest.weapons));
            if (isdefined(w)) {
                i = level.acts_pap_quest.weapons[w];
                if (!isdefined(i)) {
                    self iprintlnbold("bad key");
                    break;
                }
                weapon = i.weapon;
                old = self getcurrentweapon();
                if (isdefined(old) && old != level.weaponnone) {
                    self takeweapon(old);
                }
                wait 0.1;
                self giveweapon(weapon);
                wait 0.1;
                self switchtoweapon(weapon);
            }
            setdvar(#"apap_force_next_weapon", false);
        }

        if (getdvarint(#"apap_force_win", false)) {
            win_game();
            setdvar(#"apap_force_win", false);
        }
    }
}
#/

function private on_use_pack_a_punch(upgraded_weapon) {
    base = zm_weapons::get_base_weapon(upgraded_weapon);

    if (isdefined(level.acts_pap_quest.weapons[base])) {
        // to remove
        level.acts_pap_quest.weapons[base] = undefined;
        foreach (player in getplayers()) {
            player iprintlnbold("^1" + (level.acts_pap_quest.weapons_total - level.acts_pap_quest.weapons.size) + " / " + level.acts_pap_quest.weapons_total);
            player playsoundtoplayer(#"hash_1377aa36d8ba27e1", self); // zm_trials end challenge sound
        }

        if (!level.acts_pap_quest.weapons.size) {
            // end of the game
            self win_game();
        }
    }

}

// global config data
function get_config_data() {
    return {
        // looter base model
        #base_model: #"p8_zm_powerup_rush_point",
        // initial weapon price
        #start_price: 1000,
        // increase for every buy
        #increase_price: 500,
    };
}

// map config data
function get_map_config_data() {
    if (isdefined(level.force_acts_pap_quest_cfg)) {
        return level.force_acts_pap_quest_cfg; // hope that one day this thing will be useful...
    }
    switch (hash(level.script)) {
        case #"zm_towers":
            return {
                #main_loc_origin: (189.393, -563.552, 31.5721),
                #main_loc_angle: (15.8533, 133.984, 0),
            };
        case #"zm_zodt8":
            return {
                #main_loc_origin: (-4.15786, -4227.36, 928.125),
                #main_loc_angle: (2.96703, 88.2072, 0),
            };
        case #"zm_escape":
            return {
                #main_loc_origin: (8782.62, 10649.7, 458.629),
                #main_loc_angle: (0.510864, -21.4453, 0),
            };
        case #"zm_office":
            return {
                #main_loc_origin: (-755.141, 2512.72, 16.125),
                #main_loc_angle: (0.439453, -179.846, 0),
            };
        case #"zm_mansion":
            return {
                #main_loc_origin: (1.3565, -1341.14, -7.875),
                #main_loc_angle: (18.3691, -91.4447, 0),
            };
        case #"zm_red":
            return {
                #main_loc_origin: (-2593.72, -750.666, 0.125),
                #main_loc_angle: (12.442, -161.548, 0),
            };
        case #"zm_white":
            return {
                #main_loc_origin: (101.538, 953.234, -60.1881),
                #main_loc_angle: (31.8549, -108.364, 0),
            };
        case #"zm_orange":
            return {
                #main_loc_origin: (-1039.3, 1052.89, 375.125),
                #main_loc_angle: (6.44348, 75.6683, 0),
            };
    }
}

function win_game() {
    level notify(#"hash_4c09c9d01060d7ad");
    level notify(#"end_game");
}