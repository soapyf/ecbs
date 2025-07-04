// This script should be placed inside an object that will be attached to avatars that have granted experience permissions inside your combat region
// After adding this script to an object make sure you compile it with an experience found at the bottom of the script window when editing inside of an object
// Pick up a copy of the new object containing the ebcs_handler.lsl script and place it inside an object along with the ebcs_controller.lsl script
// It is advised that you set this script to "no modify" to prevent users from tampering with it once its been attached to their avatar

vector attacker_spawn;
vector defender_spawn;

list defender_groups = [
    // Populate this list with any groups you would like to be considered 'defenders'
];

list safezones;

key agent;
key parent;

integer in_safezone(vector pos) {
    integer count = llGetListLength(safezones);
    integer i;for (; i < count; i += 2) {
        vector bottom_southwest = (vector)llList2String(safezones, i);
        vector top_northeast = (vector)llList2String(safezones, i + 1);
        if (pos.x >= bottom_southwest.x && pos.x <= top_northeast.x &&
            pos.y >= bottom_southwest.y && pos.y <= top_northeast.y &&
            pos.z >= bottom_southwest.z && pos.z <= top_northeast.z) {
            return TRUE;
        }
    }
    return FALSE;
}

integer is_defender(key id) {
    list attached_objects = llGetAttachedList(id);
    integer count = llGetListLength(attached_objects);

    integer i;
    for (i = 0; i < count; ++i) {
        key object_id = llList2Key(attached_objects, i);
        list details = llGetObjectDetails(object_id, [OBJECT_GROUP]);
        
        if (llGetListLength(details) > 0) {
            key group_id = llList2Key(details, 0);
            if (llListFindList(defender_groups, [(string)group_id]) != -1) {
                return TRUE; // Object belongs to a defender group
            }
        }
    }
    return FALSE; // No attached objects belong to a defender group
}
    


default
{
    on_rez(integer start_param)
    {
        string start = llGetStartString();
        agent = (key)llJsonGetValue(start, ["agent"]);
        attacker_spawn = (vector)llJsonGetValue(start, ["attacker_spawn"]);
        defender_spawn = (vector)llJsonGetValue(start, ["defender_spawn"]);
        safezones = llParseString2List(llJsonGetValue(start, ["safezones"]), ["|"], [""]);
        parent = llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_REZZER_KEY]),0);

        if (agent) {
            llRequestExperiencePermissions(agent, "");
            llSetTimerEvent(30); // Self destruct after 30 seconds if not attached
        } else if (llGetAttached()) {
            llRequestExperiencePermissions(llGetOwner(), "");
        }
    }
    attach(key id)
    {
        if(id) {
            llSetTimerEvent(0);
            llListen(-56175,"","","attach");
            llWhisper(-56175,"attach");
            llOwnerSay("Ready.");
        }
    }
    timer()
    {
        if(llGetAgentSize(agent)==ZERO_VECTOR){ llDie(); }
        if(!llGetAttached()) {
            llDie();
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == -56175) {
            if(llGetOwnerKey(id) == agent || id == parent){
                if (message == "attach") {
                    llOwnerSay("Detaching");
                    llRequestPermissions(llGetOwner(), PERMISSION_ATTACH);
                }
            }
        }
    }
    
    experience_permissions(key agent_id)
    {
        if (!llGetAttached()) {
            
            llAttachToAvatarTemp(ATTACH_HUD_TOP_CENTER);
        }
    }

    experience_permissions_denied(key agent_id, integer reason)
    {
        llDie(); 
    }

    // detach from the avatar when we leave the region
    changed(integer change)
    {
        if (change & CHANGED_REGION_START) {
            llOwnerSay("Detaching due to unsupported region.");
            llRequestPermissions(llGetOwner(), PERMISSION_ATTACH);
        }
    }
    run_time_permissions(integer perm)
    {
        if(perm & PERMISSION_ATTACH){
            llDetachFromAvatar();
        }
    }

    on_damage(integer count) {
        while(count--) {
            if(in_safezone(llGetPos())) {
                llAdjustDamage(count,0);
            }
        }
    }

    on_death() {
        if(!in_safezone(llGetPos())) {
            if(is_defender(llGetOwner())) {
                llTeleportAgent(llGetOwner(), "", defender_spawn, attacker_spawn);
            } else {
                llTeleportAgent(llGetOwner(), "", attacker_spawn, defender_spawn);
            }
        }
    }
}
