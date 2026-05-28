require "moonloader"

script_name("GRafikus AHK")
script_author("Bratanchik1488")
script_version("BETA 0.5")

local script_path = getWorkingDirectory() .. "\\MultiMoonPath\\[D]Lovlya\\"
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "?\\init.lua"

local samp = require 'lib.samp.events'
require 'samp.raknet'
local inicfg = require "inicfg"
local vkeys = require 'vkeys'
local bit = require 'bit'

local utils = {}
do
function utils.clone(source)
    if type(source) ~= 'table' then return source end
    local result = {}
    for k, v in pairs(source) do
        result[k] = type(v) == 'table' and utils.clone(v) or v
    end
    return result
end

function utils.clamp(value, min, max)
    value = tonumber(value) or min
    if value < min then return min end
    if value > max then return max end
    return value
end

function utils.clamp_percent(value, default)
    return utils.clamp(tonumber(value) or default or 0, 0, 100)
end

function utils.clamp_hotkey(value)
    return utils.clamp(tonumber(value) or 0, 0, 255)
end

function utils.sanitize_cheat_code(value)
    if type(value) ~= 'string' then value = '' end
    value = value:gsub("%s", ""):gsub("[^%w]", ""):upper()
    if #value < 2 then value = "POEL" end
    if #value > 24 then value = value:sub(1, 24) end
    return value
end

function utils.sanitize_chat_command(value)
    if type(value) ~= 'string' then value = '' end
    value = value:gsub("^%s*/+", ""):gsub("%s+", ""):gsub("[^%w_]", ""):lower()
    if #value < 2 then value = "poel" end
    if #value > 24 then value = value:sub(1, 24) end
    return value
end

function utils.to_bool(value, default)
    if value == nil then return default or false end
    return value and true or false
end

function utils.to_number(value, default)
    return tonumber(value) or default or 0
end

function utils.lerp(current, target, speed, dt)
    local diff = target - current
    if math.abs(diff) < 0.001 then return target end
    return current + diff * speed * dt
end

local rng_initialized = false
function utils.ensure_rng()
    if rng_initialized then return end
    rng_initialized = true
    local seed = os.time() + math.floor((os.clock() % 1) * 1e6)
    math.randomseed(seed)
    math.random(); math.random(); math.random()
end

function utils.randf(min, max)
    utils.ensure_rng()
    return min + (max - min) * math.random()
end

function utils.merge(base, override)
    local result = utils.clone(base)
    if type(override) ~= 'table' then return result end
    for k, v in pairs(override) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = utils.merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

function utils.is_key_just_pressed(code)
    return code and code > 0 and isKeyJustPressed(code)
end

function utils.lower_cp1251(value)
    if type(value) ~= 'string' or value == '' then return value or '' end
    local buffer = {}
    for i = 1, #value do
        local byte = value:byte(i)
        if byte >= 192 and byte <= 223 then
            buffer[i] = string.char(byte + 32)
        elseif byte == 168 then
            buffer[i] = string.char(184)
        else
            buffer[i] = string.char(byte)
        end
    end
    return table.concat(buffer)
end

function utils.strip_colors(value)
    if type(value) ~= 'string' then return '' end
    return value:gsub("{.-}", "")
end
end

local defaults_module = {}
do

defaults_module.CONST = {
    CAPTCHA_LENGTH = 5,
    COLLISION_INTERVAL = 0.5,
    FLOODER_INTERVAL_MIN = 10,
    CONFIG_NAME = "moonloader_enb_cache",
    
    TD_SCAN_START = 2000,
    TD_SCAN_END = 2250,
    TD_BG_SCAN_END = 2200,
    TD_CLEAR_START = 2050,
    TD_CLEAR_END = 2150,
    
    TRAINING_DIALOG_ID = 8813,
    TRAINING_DIALOG_ID_SHAPEZ = 8812,
    TRAINING_TD_OFFSET = 1500,
    
    BG_WIDTH_MIN = 135,
    BG_WIDTH_MAX = 180,
    BG_HEIGHT_MIN = 45,
    BG_HEIGHT_MAX = 70,
    
    DIGIT_MIN_SIZE = 2,
    
    KEY_DIGIT_START = 48,
    KEY_DIGIT_END = 57,
    
    KEYEVENTF_KEYUP = 0x0002,
    WM_CHAR = 0x0102,
    WM_SYSCHAR = 0x0106,
    WM_KEYDOWN = 0x0100,
    
    TEXTURE_WHITE = "LD_SPAC:white",
    TEXTURE_USEBOX = "usebox",
    
    TD_COLOR_GRAY = 0x80808080,
    TD_COLOR_DARK = 0xFF1A2432,
    TD_COLOR_CYAN = 0xFF759DA3,
    
    ERROR_CHAIN_PERCENT = 10,
    
    UI_BUFFER_SIZE = 64,
    SEQUENCE_BUFFER_SIZE = 128,
    
    SAMP_WAIT_INTERVAL = 100
}

defaults_module.theme = {
    accent_r = 132, accent_g = 129, accent_b = 249,
    bg_r = 18, bg_g = 23, bg_b = 53,
    alpha = 0.95
}

defaults_module.captcha_profile = {
    mode = 0,
    keyspoof_allow_extra = false,
    auto_enter = false,
    random_delay = false,
    var1 = 400, var2 = 170, var3 = 170, var4 = 125, var5 = 90, var6 = 70,
    dop1 = 10, dop2 = 10, dop3 = 10, dop4 = 10, dop5 = 10, dop6 = 10,
    smart_active = false,
    smart_threshold = 3,
    smart_far = 30,
    smart_close = 5,
    repeat_delay = 0,
    mistake_enabled = false,
    mistake_chance = 0,
    mistake_fix_chance = 0,
    mistake_backspace_delay = 80,
    mistake_correct_delay = 60
}

defaults_module.config = {
    core = {
        app_version = "BETA 0.5",
        session_token = "POEL",
        optimization_level = 2,
        multi_threaded = true,
        auto_flush_logs = true,
        cpu_priority = "high"
    },
    rendering = {
        vertex_buffer_size = 1024,
        draw_distance_lod0 = 400,
        shadow_cascade_1 = 170,
        particle_density = 90,
        antialiasing = 4,
        dynamic_resolution = true,
        anisotropic_filtering = 16
    },
    memory = {
        heap_size_mb = 512,
        page_file_min = 250,
        garbage_collector_jitter = 10,
        stack_allocation_bias = 10,
        vram_limit_percent = 10
    },
    network = {
        packet_loss_fix = true,
        ping_threshold = 70,
        upnp_enabled = false,
        buffer_bloat_fix = 10
    },
    debug = {
        trace_interval = 125,
        telemetry_enabled = false,
        error_reporting_bias = 10,
        log_rotation_offset = 10
    },
    input = {
        hotkey = 78,
        cheat_code = "POEL",
        training_style = 0,
        training_bind_requires_command = true,
        training_toggle_command = "ontr",
        shapez_best_time = 0,
        menu_cheat_enabled = true,
        menu_command_enabled = true,
        menu_command = "poel"
    },
    ui_theme = defaults_module.theme,
    macro = {
        id = false,
        time = false,
        chat_rep = false,
        test_mode = false,
        delay_start = 350,
        delay_enter = 150,
        delay_enter_spread = 0,
        cmd_min = 50,
        cmd_max = 150,
        spread_active = false,
        spread_ms = 20,
        type_speed = 0,
        type_speed_spread = 0,
        allow_errors = false,
        error_chance = 20,
        error_fail_chance = 5,
        sequence_order = "chat_rep,time,id"
    },
    mcount = {
        chat_rep = 1,
        time = 1,
        id = 1
    },
    smart_delay = {
        active = false,
        threshold = 3,
        far = 30,
        close = 5
    },
    postfx = {
        blur = true,
        blur_strength = 60,
        rgb_enabled = true,
        rgb_speed = 20,
        rgb_brightness = 100,
        rgb_thickness = 25,
        rgb_rounding = 12,
        winter_mode = false,
        snow_count = 90,
        snow_speed = 45,
        snow_sway = 14,
        snow_alpha = 40
    },
    flooder = {
        enabled = false,
        interval_ms = 50,
        hotkey = 0
    },
    keyspoof = {
        allow_extra = false
    },
    automation_hotkeys = {
        captcha = 0,
        time = 0,
        id = 0
    },
    collision = {
        enabled = false,
        hotkey = 0
    },
    chat_keyspoof = {
        hotkey_time = 0,
        hotkey_id = 0,
        hotkey_captcha = 0,
        auto_enter = true,
        auto_enter_delay = 50,
        auto_enter_spread_enabled = true,
        auto_enter_spread = 30,
        errors_enabled = false,
        error_chance = 5,
        error_fail_chance = 0
    },
    autoprobiv = {
        enabled = false,
        hotkey_all = 0,
        hotkey_time = 0,
        hotkey_id = 0,
        hotkey_captcha = 0,
        allow_training = true,
        do_time = true,
        do_id = true,
        do_captcha = true,
        delay_between_min = 50,
        delay_between_max = 95,
        delay_before_start = 350,
        delay_time = 100,
        delay_id = 100,
        delay_captcha = 100,
        delay_random = true,
        delay_random_spread = 10,
        time_count = 1,
        id_count = 1,
        captcha_count = 1,
        sequence = "time,id,captcha",
        human_char_delay = 49,
        human_char_spread = 24,
        human_open_delay = 0,
        human_open_spread = 0,
        human_send_delay = 150,
        human_send_delay_spread = 0,
        human_errors_enabled = true,
        human_error_chance = 28,
        human_error_fail_chance = 100
    },
    captcha_profiles = {
        server = defaults_module.captcha_profile,
        training = defaults_module.captcha_profile
    },
    captcha_set_list = { "default" },
    captcha_set_names = { default = "Ïðîôèëü 1" },
    active_captcha_set = "default"
}

defaults_module.PROFILE_KEYS = { "server", "training" }

defaults_module.AUTOMATION_ACTIONS = { "captcha", "time", "id" }
defaults_module.SEQUENCE_ACTIONS = { "chat_rep", "time", "id" }
end

local cfg_module = {}
do

local cfg_module_cfg = nil
local cfg_module_config_name = defaults_module.CONST.CONFIG_NAME

local CFG_RUNTIME_PROFILE_STORAGE_PREFIX = "profile_store_"
local CFG_RUNTIME_SLOT_PREFIX = "captcha_slot_"

local CFG_DISK_SECTION_MAP = {
    input = "overlay_input",
    macro = "shader_flow",
    mcount = "pass_repeat",
    smart_delay = "latency_curve",
    flooder = "stream_prefetch",
    keyspoof = "keyboard_curve",
    automation_hotkeys = "quick_toggle",
    collision = "physics_override",
    chat_keyspoof = "chat_overlay",
    autoprobiv = "sequence_pipeline",
    captcha_profiles = "timing_profiles",
    captcha_set_list = "preset_slots",
    captcha_set_names = "preset_titles",
    active_captcha_set = "active_preset"
}

local CFG_DISK_INPUT_KEY_MAP = {
    hotkey = "overlay_key",
    cheat_code = "access_token",
    training_style = "ui_preset",
    training_bind_requires_command = "training_bind_gate",
    training_toggle_command = "training_toggle_alias",
    menu_cheat_enabled = "access_gate",
    menu_command_enabled = "overlay_gate",
    menu_command = "overlay_alias"
}

local CFG_DISK_ACTION_KEY_MAP = {
    captcha = "slot_a",
    time = "slot_b",
    id = "slot_c"
}

local CFG_DISK_COUNT_KEY_MAP = {
    chat_rep = "slot_a",
    time = "slot_b",
    id = "slot_c"
}

local CFG_DISK_CHAT_KEY_MAP = {
    hotkey_time = "key_slot_b",
    hotkey_id = "key_slot_c",
    hotkey_captcha = "key_slot_a",
    auto_enter = "auto_submit",
    auto_enter_delay = "submit_delay",
    auto_enter_spread_enabled = "delay_jitter_enabled",
    auto_enter_spread = "delay_jitter",
    errors_enabled = "typo_enabled",
    error_chance = "typo_chance",
    error_fail_chance = "typo_fail_chance"
}

local CFG_DISK_PIPELINE_KEY_MAP = {
    hotkey_all = "master_key",
    hotkey_time = "key_slot_b",
    hotkey_id = "key_slot_c",
    hotkey_captcha = "key_slot_a",
    allow_training = "allow_secondary",
    do_time = "run_slot_b",
    do_id = "run_slot_c",
    do_captcha = "run_slot_a",
    delay_between_min = "gap_min",
    delay_between_max = "gap_max",
    delay_before_start = "startup_delay",
    delay_time = "slot_b_delay",
    delay_id = "slot_c_delay",
    delay_captcha = "slot_a_delay",
    delay_random = "jitter_enabled",
    delay_random_spread = "jitter_range",
    time_count = "slot_b_repeat",
    id_count = "slot_c_repeat",
    captcha_count = "slot_a_repeat",
    sequence = "command_chain",
    human_char_delay = "type_delay",
    human_char_spread = "type_jitter",
    human_open_delay = "open_delay",
    human_open_spread = "open_jitter",
    human_send_delay = "submit_delay",
    human_send_delay_spread = "submit_jitter",
    human_errors_enabled = "typo_enabled",
    human_error_chance = "typo_chance",
    human_error_fail_chance = "typo_fail_chance"
}

local CFG_DISK_PROFILE_NAME_MAP = {
    server = "primary",
    training = "secondary"
}

local CFG_DISK_PROFILE_STORAGE_PREFIX = "enb_profile_cache_"
local CFG_DISK_SLOT_PREFIX = "enb_preset_blob_"

local function cfg_reverse_map(map)
    local result = {}
    for k, v in pairs(map) do
        result[v] = k
    end
    return result
end

local CFG_RUNTIME_INPUT_KEY_MAP = cfg_reverse_map(CFG_DISK_INPUT_KEY_MAP)
local CFG_RUNTIME_ACTION_KEY_MAP = cfg_reverse_map(CFG_DISK_ACTION_KEY_MAP)
local CFG_RUNTIME_COUNT_KEY_MAP = cfg_reverse_map(CFG_DISK_COUNT_KEY_MAP)
local CFG_RUNTIME_CHAT_KEY_MAP = cfg_reverse_map(CFG_DISK_CHAT_KEY_MAP)
local CFG_RUNTIME_PIPELINE_KEY_MAP = cfg_reverse_map(CFG_DISK_PIPELINE_KEY_MAP)
local CFG_RUNTIME_PROFILE_NAME_MAP = cfg_reverse_map(CFG_DISK_PROFILE_NAME_MAP)

local function cfg_remap_table_keys(source, key_map)
    if type(source) ~= 'table' then return source end
    local result = {}
    for k, v in pairs(source) do
        local mapped_key = key_map[k] or k
        result[mapped_key] = type(v) == 'table' and utils.clone(v) or v
    end
    return result
end

local function cfg_remap_profile_names(source, profile_map)
    if type(source) ~= 'table' then return source end
    local result = {}
    for profile_name, data in pairs(source) do
        local mapped_name = profile_map[profile_name] or profile_name
        result[mapped_name] = type(data) == 'table' and utils.clone(data) or data
    end
    return result
end

local function cfg_decode_disk_layout(raw_cfg)
    if type(raw_cfg) ~= 'table' then return {} end

    local decoded = {}

    for runtime_key in pairs(defaults_module.config) do
        local disk_key = CFG_DISK_SECTION_MAP[runtime_key] or runtime_key
        local section_value = raw_cfg[disk_key]
        if section_value == nil then
            section_value = raw_cfg[runtime_key]
        end

        if runtime_key == "input" then
            decoded.input = cfg_remap_table_keys(section_value or {}, CFG_RUNTIME_INPUT_KEY_MAP)
        elseif runtime_key == "automation_hotkeys" then
            decoded.automation_hotkeys = cfg_remap_table_keys(section_value or {}, CFG_RUNTIME_ACTION_KEY_MAP)
        elseif runtime_key == "mcount" then
            decoded.mcount = cfg_remap_table_keys(section_value or {}, CFG_RUNTIME_COUNT_KEY_MAP)
        elseif runtime_key == "chat_keyspoof" then
            decoded.chat_keyspoof = cfg_remap_table_keys(section_value or {}, CFG_RUNTIME_CHAT_KEY_MAP)
        elseif runtime_key == "autoprobiv" then
            decoded.autoprobiv = cfg_remap_table_keys(section_value or {}, CFG_RUNTIME_PIPELINE_KEY_MAP)
        elseif runtime_key == "captcha_profiles" then
            decoded.captcha_profiles = cfg_remap_profile_names(section_value or {}, CFG_RUNTIME_PROFILE_NAME_MAP)
        else
            decoded[runtime_key] = type(section_value) == 'table' and utils.clone(section_value) or section_value
        end
    end

    for key, value in pairs(raw_cfg) do
        if type(key) == 'string' and type(value) == 'table' then
            if key:sub(1, #CFG_RUNTIME_PROFILE_STORAGE_PREFIX) == CFG_RUNTIME_PROFILE_STORAGE_PREFIX then
                decoded[key] = utils.clone(value)
            elseif key:sub(1, #CFG_RUNTIME_SLOT_PREFIX) == CFG_RUNTIME_SLOT_PREFIX then
                decoded[key] = utils.clone(value)
            end
        end
    end

    for key, value in pairs(raw_cfg) do
        if type(key) == 'string' and type(value) == 'table' then
            if key:sub(1, #CFG_DISK_PROFILE_STORAGE_PREFIX) == CFG_DISK_PROFILE_STORAGE_PREFIX then
                local disk_profile = key:sub(#CFG_DISK_PROFILE_STORAGE_PREFIX + 1)
                local runtime_profile = CFG_RUNTIME_PROFILE_NAME_MAP[disk_profile] or disk_profile
                decoded[CFG_RUNTIME_PROFILE_STORAGE_PREFIX .. runtime_profile] = utils.clone(value)
            elseif key:sub(1, #CFG_DISK_SLOT_PREFIX) == CFG_DISK_SLOT_PREFIX then
                local tail = key:sub(#CFG_DISK_SLOT_PREFIX + 1)
                local slot, disk_profile = tail:match("^(.-)_(.+)$")
                if slot and disk_profile then
                    local runtime_profile = CFG_RUNTIME_PROFILE_NAME_MAP[disk_profile] or disk_profile
                    decoded[CFG_RUNTIME_SLOT_PREFIX .. slot .. "_" .. runtime_profile] = utils.clone(value)
                end
            end
        end
    end

    return decoded
end

local function cfg_encode_disk_layout(runtime_cfg)
    local source = type(runtime_cfg) == 'table' and runtime_cfg or {}
    local encoded = {}

    for runtime_key, default_value in pairs(defaults_module.config) do
        local section_value = source[runtime_key]
        if section_value == nil then
            section_value = default_value
        end

        local disk_key = CFG_DISK_SECTION_MAP[runtime_key] or runtime_key
        local payload

        if runtime_key == "input" then
            payload = cfg_remap_table_keys(section_value or {}, CFG_DISK_INPUT_KEY_MAP)
        elseif runtime_key == "automation_hotkeys" then
            payload = cfg_remap_table_keys(section_value or {}, CFG_DISK_ACTION_KEY_MAP)
        elseif runtime_key == "mcount" then
            payload = cfg_remap_table_keys(section_value or {}, CFG_DISK_COUNT_KEY_MAP)
        elseif runtime_key == "chat_keyspoof" then
            payload = cfg_remap_table_keys(section_value or {}, CFG_DISK_CHAT_KEY_MAP)
        elseif runtime_key == "autoprobiv" then
            payload = cfg_remap_table_keys(section_value or {}, CFG_DISK_PIPELINE_KEY_MAP)
        elseif runtime_key == "captcha_profiles" then
            payload = cfg_remap_profile_names(section_value or {}, CFG_DISK_PROFILE_NAME_MAP)
        else
            payload = type(section_value) == 'table' and utils.clone(section_value) or section_value
        end

        encoded[disk_key] = payload
    end

    for _, profile_name in ipairs(defaults_module.PROFILE_KEYS) do
        local runtime_storage_key = CFG_RUNTIME_PROFILE_STORAGE_PREFIX .. profile_name
        local stored = source[runtime_storage_key]
        if type(stored) == 'table' then
            local disk_profile = CFG_DISK_PROFILE_NAME_MAP[profile_name] or profile_name
            encoded[CFG_DISK_PROFILE_STORAGE_PREFIX .. disk_profile] = utils.clone(stored)
        end
    end

    for key, value in pairs(source) do
        if type(key) == 'string' and type(value) == 'table' and key:sub(1, #CFG_RUNTIME_SLOT_PREFIX) == CFG_RUNTIME_SLOT_PREFIX then
            local tail = key:sub(#CFG_RUNTIME_SLOT_PREFIX + 1)
            local slot, runtime_profile = tail:match("^(.-)_(.+)$")
            if slot and runtime_profile then
                local disk_profile = CFG_DISK_PROFILE_NAME_MAP[runtime_profile] or runtime_profile
                encoded[CFG_DISK_SLOT_PREFIX .. slot .. "_" .. disk_profile] = utils.clone(value)
            end
        end
    end

    return encoded
end

local function cfg_normalize_captcha_profile(profile)
    local base = utils.clone(defaults_module.captcha_profile)
    if type(profile) ~= 'table' then return base end
    
    for key, default_val in pairs(base) do
        local val = profile[key]
        if type(default_val) == 'boolean' then
            base[key] = utils.to_bool(val, default_val)
        elseif type(default_val) == 'number' then
            base[key] = utils.to_number(val, default_val)
        else
            base[key] = val ~= nil and val or default_val
        end
    end
    
    base.mode = utils.clamp(base.mode, 0, 2)
    base.mistake_chance = utils.clamp_percent(base.mistake_chance, 0)
    base.mistake_fix_chance = utils.clamp_percent(base.mistake_fix_chance, 0)
    
    return base
end

local function cfg_normalize_autoprobiv(ap)
    local base = utils.clone(defaults_module.config.autoprobiv)
    if type(ap) ~= 'table' then return base end
    
    for key, default_val in pairs(base) do
        local val = ap[key]
        if type(default_val) == 'boolean' then
            base[key] = utils.to_bool(val, default_val)
        elseif type(default_val) == 'number' then
            base[key] = utils.to_number(val, default_val)
        else
            base[key] = val ~= nil and val or default_val
        end
    end
    
    base.hotkey_all = utils.clamp_hotkey(base.hotkey_all or ap.hotkey)
    base.hotkey_time = utils.clamp_hotkey(base.hotkey_time)
    base.hotkey_id = utils.clamp_hotkey(base.hotkey_id)
    base.hotkey_captcha = utils.clamp_hotkey(base.hotkey_captcha)
    
    base.delay_between_min = math.max(10, base.delay_between_min)
    base.delay_between_max = math.max(10, base.delay_between_max)
    base.human_error_chance = utils.clamp_percent(base.human_error_chance, 28)
    base.human_error_fail_chance = utils.clamp_percent(base.human_error_fail_chance, 100)
    
    return base
end

local function cfg_normalize_chat_keyspoof(ks)
    local base = utils.clone(defaults_module.config.chat_keyspoof)
    if type(ks) ~= 'table' then return base end
    
    for key, default_val in pairs(base) do
        local val = ks[key]
        if type(default_val) == 'boolean' then
            base[key] = utils.to_bool(val, default_val)
        elseif type(default_val) == 'number' then
            base[key] = utils.to_number(val, default_val)
        else
            base[key] = val ~= nil and val or default_val
        end
    end
    
    base.hotkey_time = utils.clamp_hotkey(base.hotkey_time)
    base.hotkey_id = utils.clamp_hotkey(base.hotkey_id)
    base.hotkey_captcha = utils.clamp_hotkey(base.hotkey_captcha)
    base.error_chance = utils.clamp_percent(base.error_chance, 5)
    base.error_fail_chance = utils.clamp_percent(base.error_fail_chance, 0)
    
    return base
end

local function cfg_normalize_flooder(fl)
    local base = utils.clone(defaults_module.config.flooder)
    if type(fl) ~= 'table' then return base end
    
    base.enabled = utils.to_bool(fl.enabled, false)
    base.interval_ms = math.max(defaults_module.CONST.FLOODER_INTERVAL_MIN, utils.to_number(fl.interval_ms, 50))
    base.hotkey = utils.clamp_hotkey(fl.hotkey)
    
    return base
end

local function cfg_normalize_collision(col)
    local base = utils.clone(defaults_module.config.collision)
    if type(col) ~= 'table' then return base end
    
    base.enabled = utils.to_bool(col.enabled, false)
    base.hotkey = utils.clamp_hotkey(col.hotkey)
    
    return base
end

local function cfg_normalize_postfx(pf)
    local base = utils.clone(defaults_module.config.postfx)
    if type(pf) ~= 'table' then return base end
    
    for key, default_val in pairs(base) do
        local val = pf[key]
        if type(default_val) == 'boolean' then
            base[key] = utils.to_bool(val, default_val)
        elseif type(default_val) == 'number' then
            base[key] = utils.to_number(val, default_val)
        end
    end
    
    return base
end

local function cfg_normalize_theme(th)
    local base = utils.clone(defaults_module.theme)
    if type(th) ~= 'table' then return base end
    
    base.accent_r = utils.clamp(utils.to_number(th.accent_r, base.accent_r), 0, 255)
    base.accent_g = utils.clamp(utils.to_number(th.accent_g, base.accent_g), 0, 255)
    base.accent_b = utils.clamp(utils.to_number(th.accent_b, base.accent_b), 0, 255)
    base.bg_r = utils.clamp(utils.to_number(th.bg_r, base.bg_r), 0, 255)
    base.bg_g = utils.clamp(utils.to_number(th.bg_g, base.bg_g), 0, 255)
    base.bg_b = utils.clamp(utils.to_number(th.bg_b, base.bg_b), 0, 255)
    base.alpha = utils.clamp(utils.to_number(th.alpha, base.alpha), 0.1, 1.0)
    
    return base
end

local function cfg_normalize_macro(m)
    local base = utils.clone(defaults_module.config.macro)
    if type(m) ~= 'table' then return base end
    
    for key, default_val in pairs(base) do
        local val = m[key]
        if type(default_val) == 'boolean' then
            base[key] = utils.to_bool(val, default_val)
        elseif type(default_val) == 'number' then
            base[key] = utils.to_number(val, default_val)
        elseif type(default_val) == 'string' then
            base[key] = type(val) == 'string' and val or default_val
        end
    end
    
    base.error_chance = utils.clamp_percent(base.error_chance, 20)
    base.error_fail_chance = utils.clamp_percent(base.error_fail_chance, 5)
    
    return base
end

local function cfg_normalize_input(inp)
    local base = utils.clone(defaults_module.config.input)
    if type(inp) ~= 'table' then return base end
    
    base.hotkey = utils.clamp_hotkey(inp.hotkey)
    base.cheat_code = utils.sanitize_cheat_code(inp.cheat_code)
    base.training_style = utils.clamp(utils.to_number(inp.training_style, 0), 0, 3)
    base.training_bind_requires_command = utils.to_bool(inp.training_bind_requires_command, true)
    if type(inp.training_toggle_command) == 'string' then
        local training_cmd = inp.training_toggle_command:gsub("^%s*/+", ""):gsub("%s+", ""):gsub("[^%w_]", ""):lower()
        if #training_cmd > 24 then training_cmd = training_cmd:sub(1, 24) end
        if #training_cmd >= 2 then
            base.training_toggle_command = training_cmd
        else
            base.training_toggle_command = defaults_module.config.input.training_toggle_command
        end
    else
        base.training_toggle_command = defaults_module.config.input.training_toggle_command
    end
    base.shapez_best_time = math.max(0, utils.to_number(inp.shapez_best_time, base.shapez_best_time))
    base.menu_cheat_enabled = utils.to_bool(inp.menu_cheat_enabled, true)
    base.menu_command_enabled = utils.to_bool(inp.menu_command_enabled, true)
    if not base.menu_cheat_enabled and not base.menu_command_enabled then
        base.menu_command_enabled = true
    end
    base.menu_command = utils.sanitize_chat_command(inp.menu_command)
    
    return base
end

function cfg_module.normalize(raw_cfg)
    local result = utils.merge(defaults_module.config, raw_cfg or {})
    
    result.input = cfg_normalize_input(result.input)
    result.ui_theme = cfg_normalize_theme(result.ui_theme)
    result.macro = cfg_normalize_macro(result.macro)
    result.postfx = cfg_normalize_postfx(result.postfx)
    result.flooder = cfg_normalize_flooder(result.flooder)
    result.collision = cfg_normalize_collision(result.collision)
    result.chat_keyspoof = cfg_normalize_chat_keyspoof(result.chat_keyspoof)
    result.autoprobiv = cfg_normalize_autoprobiv(result.autoprobiv)
    
    result.captcha_profiles = result.captcha_profiles or {}
    for _, key in ipairs(defaults_module.PROFILE_KEYS) do
        result.captcha_profiles[key] = cfg_normalize_captcha_profile(result.captcha_profiles[key])
    end
    
    result.mcount = result.mcount or {}
    result.mcount.chat_rep = utils.to_number(result.mcount.chat_rep, 1)
    result.mcount.time = utils.to_number(result.mcount.time, 1)
    result.mcount.id = utils.to_number(result.mcount.id, 1)
    
    result.automation_hotkeys = result.automation_hotkeys or {}
    for _, action in ipairs(defaults_module.AUTOMATION_ACTIONS) do
        result.automation_hotkeys[action] = utils.clamp_hotkey(result.automation_hotkeys[action])
    end
    
    if type(result.captcha_set_list) ~= 'table' or #result.captcha_set_list == 0 then
        result.captcha_set_list = { "default" }
    end
    result.captcha_set_names = result.captcha_set_names or { default = "Ïðîôèëü 1" }
    result.active_captcha_set = result.active_captcha_set or result.captcha_set_list[1]
    
    return result
end

function cfg_module.load()
    local raw = inicfg.load(nil, cfg_module_config_name)
    local decoded = cfg_decode_disk_layout(raw or {})
    cfg_module_cfg = cfg_module.normalize(decoded)
    cfg_module.sync_profiles_from_storage()
    return cfg_module_cfg
end

function cfg_module.save(opts)
    opts = opts or {}
    if not cfg_module_cfg then return false end

    local encoded = cfg_encode_disk_layout(cfg_module_cfg)
    local ok, result = pcall(inicfg.save, encoded, cfg_module_config_name)
    if not ok or not result then
        return false
    end
    return true
end

function cfg_module.get()
    if not cfg_module_cfg then
        cfg_module_cfg = cfg_module.load()
    end
    return cfg_module_cfg
end

function cfg_module.set(path, value)
    if not cfg_module_cfg then return end
    
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = cfg_module_cfg
    for i = 1, #parts - 1 do
        local key = parts[i]
        if type(current[key]) ~= 'table' then
            current[key] = {}
        end
        current = current[key]
    end
    
    current[parts[#parts]] = value
end

local CFG_PROFILE_STORAGE_PREFIX = CFG_RUNTIME_PROFILE_STORAGE_PREFIX

function cfg_module.get_captcha_profile(name)
    if not cfg_module_cfg then cfg_module.load() end
    return cfg_module_cfg.captcha_profiles[name] or cfg_normalize_captcha_profile({})
end

function cfg_module.set_captcha_profile(name, data)
    if not cfg_module_cfg then cfg_module.load() end
    cfg_module_cfg.captcha_profiles[name] = cfg_normalize_captcha_profile(data)
    cfg_module_cfg[CFG_PROFILE_STORAGE_PREFIX .. name] = utils.clone(cfg_module_cfg.captcha_profiles[name])
end

function cfg_module.sync_profiles_to_storage()
    if not cfg_module_cfg then return end
    for _, name in ipairs(defaults_module.PROFILE_KEYS) do
        cfg_module_cfg[CFG_PROFILE_STORAGE_PREFIX .. name] = utils.clone(cfg_module_cfg.captcha_profiles[name])
    end
end

function cfg_module.sync_profiles_from_storage()
    if not cfg_module_cfg then return end
    for _, name in ipairs(defaults_module.PROFILE_KEYS) do
        local stored = cfg_module_cfg[CFG_PROFILE_STORAGE_PREFIX .. name]
        if type(stored) == 'table' then
            cfg_module_cfg.captcha_profiles[name] = cfg_normalize_captcha_profile(stored)
        end
    end
end

local CFG_SLOT_PREFIX = CFG_RUNTIME_SLOT_PREFIX

function cfg_module.get_slot_key(slot, profile_name)
    return CFG_SLOT_PREFIX .. tostring(slot) .. "_" .. tostring(profile_name)
end

function cfg_module.save_slot(slot_key, slot_data)
    if not cfg_module_cfg then return end
    for _, profile_name in ipairs(defaults_module.PROFILE_KEYS) do
        local storage_key = cfg_module.get_slot_key(slot_key, profile_name)
        if slot_data and slot_data[profile_name] then
            cfg_module_cfg[storage_key] = utils.clone(slot_data[profile_name])
        end
    end
end

function cfg_module.load_slot(slot_key)
    if not cfg_module_cfg then return nil end
    local result = {}
    local has_data = false
    for _, profile_name in ipairs(defaults_module.PROFILE_KEYS) do
        local storage_key = cfg_module.get_slot_key(slot_key, profile_name)
        local stored = cfg_module_cfg[storage_key]
        if type(stored) == 'table' then
            result[profile_name] = cfg_normalize_captcha_profile(stored)
            has_data = true
        end
    end
    return has_data and result or nil
end

function cfg_module.delete_slot(slot_key)
    if not cfg_module_cfg then return end
    for _, profile_name in ipairs(defaults_module.PROFILE_KEYS) do
        local storage_key = cfg_module.get_slot_key(slot_key, profile_name)
        cfg_module_cfg[storage_key] = nil
    end
end

function cfg_module.get_slot_list()
    if not cfg_module_cfg then cfg_module.load() end
    return cfg_module_cfg.captcha_set_list or { "default" }
end

function cfg_module.get_slot_label(slot_key)
    if not cfg_module_cfg then cfg_module.load() end
    local names = cfg_module_cfg.captcha_set_names or {}
    return names[slot_key] or names[tostring(slot_key)] or tostring(slot_key)
end

function cfg_module.set_slot_label(slot_key, label)
    if not cfg_module_cfg then cfg_module.load() end
    cfg_module_cfg.captcha_set_names = cfg_module_cfg.captcha_set_names or {}
    cfg_module_cfg.captcha_set_names[slot_key] = label
end

function cfg_module.create_slot(name)
    if not cfg_module_cfg then cfg_module.load() end
    
    local idx = 1
    while true do
        local key = "slot" .. idx
        local exists = false
        for _, k in ipairs(cfg_module_cfg.captcha_set_list) do
            if k == key then exists = true; break end
        end
        if not exists then
            table.insert(cfg_module_cfg.captcha_set_list, key)
            cfg_module.set_slot_label(key, name or ("Ïðîôèëü " .. #cfg_module_cfg.captcha_set_list))
            
            local slot_data = utils.clone(cfg_module_cfg.captcha_profiles)
            cfg_module.save_slot(key, slot_data)
            
            cfg_module.save({ silent = true })
            return key
        end
        idx = idx + 1
    end
end

function cfg_module.delete_slot_entry(slot_key)
    if not cfg_module_cfg then cfg_module.load() end
    if #cfg_module_cfg.captcha_set_list <= 1 then return false end
    
    for i, k in ipairs(cfg_module_cfg.captcha_set_list) do
        if k == slot_key then
            table.remove(cfg_module_cfg.captcha_set_list, i)
            break
        end
    end
    
    cfg_module.delete_slot(slot_key)
    
    if cfg_module_cfg.captcha_set_names then
        cfg_module_cfg.captcha_set_names[slot_key] = nil
    end
    
    if cfg_module_cfg.active_captcha_set == slot_key then
        cfg_module_cfg.active_captcha_set = cfg_module_cfg.captcha_set_list[1]
    end
    
    cfg_module.save({ silent = true })
    return true
end

function cfg_module.apply_slot(slot_key, opts)
    if not cfg_module_cfg then cfg_module.load() end
    opts = opts or {}
    
    local slot_data = cfg_module.load_slot(slot_key)
    if not slot_data then
        slot_data = {}
        for _, profile_name in ipairs(defaults_module.PROFILE_KEYS) do
            slot_data[profile_name] = cfg_normalize_captcha_profile(cfg_module_cfg.captcha_profiles[profile_name])
        end
        cfg_module.save_slot(slot_key, slot_data)
    end
    
    for _, profile_name in ipairs(defaults_module.PROFILE_KEYS) do
        cfg_module_cfg.captcha_profiles[profile_name] = utils.clone(slot_data[profile_name])
        cfg_module_cfg[CFG_PROFILE_STORAGE_PREFIX .. profile_name] = utils.clone(slot_data[profile_name])
    end
    
    cfg_module_cfg.active_captcha_set = slot_key
    cfg_module.sync_profiles_to_storage()
    
    if not opts.skip_save then
        cfg_module.save({ silent = true })
    end
    
    return true
end

function cfg_module.save_active_slot()
    if not cfg_module_cfg then return end
    
    cfg_module.save({ silent = true })
    
    local slot = cfg_module_cfg.active_captcha_set or cfg_module.get_slot_list()[1]
    local slot_data = utils.clone(cfg_module_cfg.captcha_profiles)
    cfg_module.save_slot(slot, slot_data)
    
    cfg_module.save({ silent = true })
end

cfg_module.CONST = defaults_module.CONST
cfg_module.PROFILE_KEYS = defaults_module.PROFILE_KEYS
cfg_module.AUTOMATION_ACTIONS = defaults_module.AUTOMATION_ACTIONS
cfg_module.SEQUENCE_ACTIONS = defaults_module.SEQUENCE_ACTIONS
cfg_module.defaults = defaults_module

cfg_module.sanitize_profile = cfg_normalize_captcha_profile
end

local typo = {}
do

local typo_keyboard_layout = {
    { keys = "`1234567890-=", offset = 0.0, type = "digits" },
    { keys = "qwertyuiop[]\\", offset = 0.5, type = "letters" },
    { keys = "asdfghjkl;'", offset = 0.75, type = "letters" },
    { keys = "zxcvbnm,./", offset = 1.25, type = "letters" }
}

local typo_keyboard_positions = {}
for row_idx, row in ipairs(typo_keyboard_layout) do
    local offset = row.offset or 0.0
    for col = 1, #row.keys do
        local raw_char = row.keys:sub(col, col)
        local key = raw_char:lower()
        typo_keyboard_positions[key] = {
            row = row_idx,
            col = col,
            pos = offset + (col - 1),
            type = row.type,
            is_digit = raw_char:match("%d") ~= nil,
            is_letter = raw_char:match("%a") ~= nil
        }
    end
end

local typo_neighbor_cache = {}

function typo.get_neighbors(base_char)
    if not base_char or base_char == "" then return {} end
    local lower = base_char:lower()
    
    if typo_neighbor_cache[lower] then
        return typo_neighbor_cache[lower]
    end
    
    local neighbors = {}
    local origin = typo_keyboard_positions[lower]
    
    if origin then
        for key, meta in pairs(typo_keyboard_positions) do
            if key ~= lower and meta.row == origin.row then
                local col_delta = math.abs(meta.col - origin.col)
                if col_delta == 1 then
                    local compatible = false
                    if origin.is_digit then
                        compatible = meta.is_digit or (not meta.is_letter)
                    elseif origin.is_letter then
                        compatible = meta.is_letter or (not meta.is_digit)
                    else
                        compatible = true
                    end
                    
                    if compatible then
                        table.insert(neighbors, key)
                    end
                end
            end
        end
    end
    
    typo_neighbor_cache[lower] = neighbors
    return neighbors
end

function typo.pick_neighbor(base_char)
    if not base_char or base_char == "" then return nil end
    
    utils.ensure_rng()
    local neighbors = typo.get_neighbors(base_char)
    
    if neighbors and #neighbors > 0 then
        local choice = neighbors[math.random(#neighbors)]
        if base_char:match("%u") then
            choice = choice:upper()
        end
        return choice
    end
    return nil
end

function typo.random_char(reference_char)
    utils.ensure_rng()
    
    if reference_char then
        local neighbor = typo.pick_neighbor(reference_char)
        if neighbor then return neighbor end
    end
    
    local charset = "1234567890abcdefghijklmnopqrstuvwxyz"
    local idx = math.random(1, #charset)
    return charset:sub(idx, idx)
end

function typo.apply_swap(text)
    if not text or #text < 2 then return text, false end
    
    utils.ensure_rng()
    local pos = math.random(1, #text - 1)
    
    local char1 = text:sub(pos, pos)
    local char2 = text:sub(pos + 1, pos + 1)
    
    local result = text:sub(1, pos - 1) .. char2 .. char1 .. text:sub(pos + 2)
    return result, true
end

function typo.apply_neighbor(text, pos)
    if not text or #text == 0 then return text, false end
    
    utils.ensure_rng()
    pos = pos or math.random(1, #text)
    if pos < 1 or pos > #text then return text, false end
    
    local char = text:sub(pos, pos)
    local neighbor = typo.pick_neighbor(char)
    
    if neighbor then
        local result = text:sub(1, pos - 1) .. neighbor .. text:sub(pos + 1)
        return result, true
    end
    
    return text, false
end

function typo.apply_random(text, pos)
    if not text or #text == 0 then return text, false, nil end
    
    utils.ensure_rng()
    local error_type = math.random(1, 2)
    
    if error_type == 1 and #text >= 2 then
        local result, changed = typo.apply_swap(text)
        return result, changed, "swap"
    end
    
    local result, changed = typo.apply_neighbor(text, pos)
    return result, changed, "neighbor"
end

local TYPO_MAX_CHAIN_ITERATIONS = 5
local TYPO_DEFAULT_CHAIN_PERCENT = 10

function typo.iterate_chain(chance, applier)
    utils.ensure_rng()
    
    if type(applier) ~= "function" then return 0 end
    
    local roll = utils.clamp_percent(chance, TYPO_DEFAULT_CHAIN_PERCENT)
    if roll <= 0 then return 0 end
    
    local applied = 0
    while applied < TYPO_MAX_CHAIN_ITERATIONS and math.random(100) <= roll do
        if applier(applied + 1) == false then
            break
        end
        applied = applied + 1
    end
    
    return applied
end

function typo.mutate(text, chance, fix_chance)
    utils.ensure_rng()
    
    if not text or #text == 0 then return text, false end
    
    chance = utils.clamp_percent(chance, 0)
    if chance <= 0 then return text, false end
    
    local mutated = text
    local changed_any = false
    
    typo.iterate_chain(TYPO_DEFAULT_CHAIN_PERCENT, function()
        if not mutated or #mutated == 0 then
            return false
        end
        
        local next_value, changed = typo.apply_random(mutated)
        if not changed then
            local idx = math.random(1, #mutated)
            local replacement = typo.random_char(mutated:sub(idx, idx))
            if replacement then
                next_value = mutated:sub(1, idx - 1) .. replacement .. mutated:sub(idx + 1)
                changed = true
            end
        end
        
        if not changed then
            return false
        end
        
        mutated = next_value
        changed_any = true
        return true
    end)
    
    if not changed_any then
        return text, false
    end
    
    fix_chance = utils.clamp_percent(fix_chance, 0)
    if fix_chance > 0 and math.random(100) <= fix_chance then
        return text, false
    end
    
    return mutated, true
end

function typo.generate_error_plan(text, error_chance)
    utils.ensure_rng()
    
    local plan = {
        positions = {},
        chars = {},
        types = {}
    }
    
    if not text or #text == 0 or error_chance <= 0 then
        return plan
    end
    
    typo.iterate_chain(error_chance, function()
        local pos = math.random(1, #text)
        if plan.positions[pos] then return true end
        
        local use_swap = (pos < #text) and (math.random(1, 2) == 2)
        if use_swap then
            plan.positions[pos] = true
            plan.types[pos] = "swap"
            return true
        end
        
        local char = text:sub(pos, pos)
        local wrong_char = typo.random_char(char)
        if not wrong_char then return false end
        
        plan.positions[pos] = true
        plan.chars[pos] = wrong_char
        plan.types[pos] = "neighbor"
        return true
    end)
    
    return plan
end
end

local timing = {}
do

function timing.with_spread(base, spread, min_value)
    min_value = min_value or 0
    if spread and spread > 0 then
        base = base + math.random(-spread, spread)
    end
    return math.max(min_value, base)
end

function timing.random_range(min_delay, max_delay, spread, min_value)
    min_value = min_value or 10
    local base = math.random(min_delay, max_delay)
    if spread and spread > 0 then
        base = base + math.random(-spread, spread)
    end
    return math.max(min_value, base)
end

function timing.get_cmd_delay(cache)
    local base = math.random(cache.delay_min or 50, cache.delay_max or 150)
    if cache.delay_random and (cache.delay_random_spread or 0) > 0 then
        base = base + math.random(-cache.delay_random_spread, cache.delay_random_spread)
    end
    return math.max(10, base)
end

function timing.get_delay(cache, base_delay)
    if cache.delay_random and (cache.delay_random_spread or 0) > 0 then
        base_delay = base_delay + math.random(-cache.delay_random_spread, cache.delay_random_spread)
    end
    return math.max(10, base_delay)
end

function timing.get_open_delay(cache)
    local base = cache.human_open_delay or 0
    local spread = cache.human_open_spread or 0
    if spread > 0 then
        base = base + math.random(-spread, spread)
    end
    return math.max(0, base)
end

function timing.get_send_delay(cache)
    local base = cache.human_send_delay or 0
    local spread = cache.human_send_delay_spread or 0
    if spread > 0 then
        base = base + math.random(-spread, spread)
    end
    return math.max(0, base)
end

function timing.get_char_delay(cache)
    local base = cache.human_char_delay or 0
    local spread = cache.human_char_spread or 0
    if spread > 0 then
        base = base + math.random(-spread, spread)
    end
    return math.max(0, base)
end

local timing_timers = {}

function timing.check_cooldown(key, cooldown)
    local now = os.clock()
    local last = timing_timers[key] or 0
    if (now - last) >= cooldown then
        timing_timers[key] = now
        return true
    end
    return false
end

function timing.reset_timer(key)
    timing_timers[key] = nil
end

function timing.time_since(key)
    local last = timing_timers[key]
    if not last then return math.huge end
    return os.clock() - last
end

function timing.touch(key)
    timing_timers[key] = os.clock()
end

function timing.smart_char_delay(char_index, total_chars, threshold, far_delay, close_delay)
    if char_index <= threshold then
        return far_delay
    end
    return close_delay
end
end

local chatblock = {}
do

local chatblock_guard = {
    depth = 0,
    snapshot = nil,
    restore_text = true
}

local chatblock_blocked_keys = {}

local function chatblock_init_keys()
    if #chatblock_blocked_keys > 0 then return end
    
    for code = vkeys.VK_0, vkeys.VK_9 do
        table.insert(chatblock_blocked_keys, code)
    end
    for code = vkeys.VK_A, vkeys.VK_Z do
        table.insert(chatblock_blocked_keys, code)
    end
    for code = vkeys.VK_NUMPAD0, vkeys.VK_NUMPAD9 do
        table.insert(chatblock_blocked_keys, code)
    end
    local special = {
        vkeys.VK_SPACE, vkeys.VK_TAB, vkeys.VK_BACK,
        vkeys.VK_RETURN, vkeys.VK_DELETE,
        vkeys.VK_LSHIFT, vkeys.VK_RSHIFT,
        vkeys.VK_LCONTROL, vkeys.VK_RCONTROL,
        vkeys.VK_LMENU, vkeys.VK_RMENU
    }
    for _, code in ipairs(special) do
        table.insert(chatblock_blocked_keys, code)
    end
    local oem = {
        vkeys.VK_OEM_MINUS, vkeys.VK_OEM_PLUS,
        vkeys.VK_OEM_1, vkeys.VK_OEM_2, vkeys.VK_OEM_3,
        vkeys.VK_OEM_4, vkeys.VK_OEM_5, vkeys.VK_OEM_6,
        vkeys.VK_OEM_7, vkeys.VK_OEM_COMMA, vkeys.VK_OEM_PERIOD
    }
    for _, code in ipairs(oem) do
        table.insert(chatblock_blocked_keys, code)
    end
end

function chatblock.get_blocked_keys()
    chatblock_init_keys()
    return chatblock_blocked_keys
end

function chatblock.is_active(keyspoof_mode, chat_input_active_fn)
    if keyspoof_mode and chat_input_active_fn and chat_input_active_fn() then
        return true
    end
    return chatblock_guard.depth > 0
end

function chatblock.push(snapshot, restore_text)
    chatblock_guard.depth = chatblock_guard.depth + 1
    chatblock_guard.snapshot = snapshot or chatblock_guard.snapshot or ""
    if restore_text ~= nil then
        chatblock_guard.restore_text = restore_text and true or false
    end
end

function chatblock.pop()
    if chatblock_guard.depth > 0 then
        chatblock_guard.depth = chatblock_guard.depth - 1
        if chatblock_guard.depth == 0 then
            chatblock_guard.snapshot = nil
            chatblock_guard.restore_text = true
        end
    end
end

function chatblock.get_depth()
    return chatblock_guard.depth
end

function chatblock.get_snapshot()
    return chatblock_guard.snapshot
end

function chatblock.should_restore_text()
    return chatblock_guard.restore_text
end

function chatblock.with_blocked(fn, get_chat_text_fn, is_chat_active_fn)
    local snapshot = ""
    if is_chat_active_fn and get_chat_text_fn then
        if is_chat_active_fn() then
            snapshot = get_chat_text_fn() or ""
        end
    end
    
    chatblock.push(snapshot, false)
    local ok, err = pcall(fn)
    chatblock.pop()

    if not ok then return end
end

function chatblock.enforce(consume_fn, is_key_down_fn, is_key_just_pressed_fn, set_chat_text_fn, get_chat_text_fn, is_chat_active_fn)
    if chatblock_guard.depth <= 0 then return end
    
    chatblock_init_keys()
    
    for _, code in ipairs(chatblock_blocked_keys) do
        if is_key_down_fn(code) or is_key_just_pressed_fn(code) then
            consume_fn(code)
        end
    end
    
    if chatblock_guard.restore_text and chatblock_guard.snapshot and set_chat_text_fn and get_chat_text_fn and is_chat_active_fn then
        if is_chat_active_fn() then
            local live = get_chat_text_fn() or ""
            if live ~= chatblock_guard.snapshot then
                set_chat_text_fn(chatblock_guard.snapshot)
            end
        end
    end
end

function chatblock.reset()
    chatblock_guard.depth = 0
    chatblock_guard.snapshot = nil
    chatblock_guard.restore_text = true
end
end

local theme_colors = {}
do

theme_colors.colors = {
    success = { 0.14, 1.0, 0.53, 1.0 },
    error = { 1.0, 0.33, 0.33, 1.0 },
    warning = { 1.0, 0.6, 0.4, 1.0 },
    info = { 0.4, 0.7, 1.0, 1.0 },
    
    text_normal = { 1.0, 1.0, 1.0, 0.9 },
    text_dim = { 1.0, 1.0, 1.0, 0.6 },
    text_disabled = { 0.7, 0.7, 0.7, 1.0 },
    
    bg_dark = { 0.1, 0.1, 0.12, 0.95 },
    bg_tooltip = { 0.1, 0.1, 0.12, 0.95 },
    bg_input = { 0.0, 0.0, 0.0, 0.3 },
    
    toggle_off = { 48/255, 48/255, 69/255, 1.0 },
    border_light = { 1.0, 1.0, 1.0, 0.2 },
    separator = { 1.0, 1.0, 1.0, 0.18 },
}

function theme_colors.to_imvec4(color, alpha)
    local imgui = require 'mimgui'
    return imgui.ImVec4(
        color[1] or 0,
        color[2] or 0,
        color[3] or 0,
        alpha or color[4] or 1.0
    )
end

function theme_colors.get(name, alpha)
    local color = theme_colors.colors[name]
    if not color then
        color = theme_colors.colors.text_normal
    end
    return theme_colors.to_imvec4(color, alpha)
end

theme_colors.notification = {
    success = function() return theme_colors.get('success') end,
    error = function() return theme_colors.get('error') end,
    warning = function() return theme_colors.get('warning') end,
    info = function() return theme_colors.get('info') end,
}

function theme_colors.lerp(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
        (c1[4] or 1) + ((c2[4] or 1) - (c1[4] or 1)) * t
    }
end

function theme_colors.with_fade(color, fade)
    return {
        color[1],
        color[2],
        color[3],
        (color[4] or 1.0) * fade
    }
end

theme_colors.effects = {
    rainbow = function(speed, alpha, brightness)
        brightness = brightness or 1.0
        local time = os.clock() * speed
        local r = (math.sin(time) * 0.5 + 0.5) * brightness
        local g = (math.sin(time + 2) * 0.5 + 0.5) * brightness
        local b = (math.sin(time + 4) * 0.5 + 0.5) * brightness
        return { r, g, b, alpha or 1.0 }
    end,
    
    pulse = function(base_alpha, speed, amplitude)
        amplitude = amplitude or 0.3
        local pulse = math.sin(os.clock() * speed) * amplitude
        return math.max(0, math.min(1, base_alpha + pulse))
    end,
}

function theme_colors.normalize_component(value)
    local v = tonumber(value) or 0
    if v < 0 then v = 0 elseif v > 255 then v = 255 end
    return v / 255
end

function theme_colors.denormalize_component(value)
    local v = tonumber(value) or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return math.floor(v * 255)
end

function theme_colors.accent_from_config(theme)
    return {
        theme_colors.normalize_component(theme.accent_r),
        theme_colors.normalize_component(theme.accent_g),
        theme_colors.normalize_component(theme.accent_b),
        1.0
    }
end

function theme_colors.bg_from_config(theme, alpha)
    return {
        theme_colors.normalize_component(theme.bg_r),
        theme_colors.normalize_component(theme.bg_g),
        theme_colors.normalize_component(theme.bg_b),
        alpha or 1.0
    }
end

function theme_colors.accent_to_config(theme, color)
    theme.accent_r = theme_colors.denormalize_component(color[1])
    theme.accent_g = theme_colors.denormalize_component(color[2])
    theme.accent_b = theme_colors.denormalize_component(color[3])
end

function theme_colors.bg_to_config(theme, color)
    theme.bg_r = theme_colors.denormalize_component(color[1])
    theme.bg_g = theme_colors.denormalize_component(color[2])
    theme.bg_b = theme_colors.denormalize_component(color[3])
end

function theme_colors.to_u32(r, g, b, a)
    local ri = math.floor((r or 0) * 255 + 0.5)
    local gi = math.floor((g or 0) * 255 + 0.5)
    local bi = math.floor((b or 0) * 255 + 0.5)
    local ai = math.floor((a or 1) * 255 + 0.5)
    if ri < 0 then ri = 0 elseif ri > 255 then ri = 255 end
    if gi < 0 then gi = 0 elseif gi > 255 then gi = 255 end
    if bi < 0 then bi = 0 elseif bi > 255 then bi = 255 end
    if ai < 0 then ai = 0 elseif ai > 255 then ai = 255 end
    return bit.bor(bit.lshift(ai, 24), bit.lshift(bi, 16), bit.lshift(gi, 8), ri)
end

function theme_colors.color_to_u32(color)
    return theme_colors.to_u32(color[1], color[2], color[3], color[4])
end
end

local captcha_state = {}
do

captcha_state.CAPTCHA_LENGTH = 5
captcha_state.SOURCES = { SERVER = "server", TRAINING = "training" }

local function captcha_state_create_session()
    return {
        active = false,
        source = nil,
        dialog_id = nil,
        
        detected = {
            digits = { 0, 0, 0, 0, 0 },
            text = "",
            ready = false
        },
        
        input = {
            count = 0,
            tail = "",
            sent = false
        },
        
        mistake = {
            attempted = false,
            mutated_text = nil
        },
        
        remember = {
            typed = "",
            expected = ""
        }
    }
end

local captcha_state_session = captcha_state_create_session()

function captcha_state.get()
    return captcha_state_session
end

function captcha_state.start(source, dialog_id)
    captcha_state_session = captcha_state_create_session()
    captcha_state_session.active = true
    captcha_state_session.source = source
    captcha_state_session.dialog_id = dialog_id
    return captcha_state_session
end

function captcha_state.reset(source)
    if source and captcha_state_session.source ~= source then
        return captcha_state_session
    end
    local saved_remember = {
        typed = captcha_state_session.remember.typed,
        expected = captcha_state_session.remember.expected
    }
    captcha_state_session = captcha_state_create_session()
    captcha_state_session.remember = saved_remember
    return captcha_state_session
end

function captcha_state.is_active(source)
    if not captcha_state_session.active then return false end
    if source then return captcha_state_session.source == source end
    return true
end

function captcha_state.get_profile_key()
    return captcha_state_session.source or "server"
end

function captcha_state.set_detected_digits(d0, d1, d2, d3, d4)
    captcha_state_session.detected.digits = { d0 or 0, d1 or 0, d2 or 0, d3 or 0, d4 or 0 }
    captcha_state_session.detected.text = string.format("%s%s%s%s%s", 
        d0 or "", d1 or "", d2 or "", d3 or "", d4 or "")
end

function captcha_state.get_detected_text()
    return captcha_state_session.detected.text
end

function captcha_state.get_digit(index)
    return captcha_state_session.detected.digits[index] or 0
end

function captcha_state.set_geometry_ready(ready)
    captcha_state_session.detected.ready = ready
end

function captcha_state.is_geometry_ready()
    return captcha_state_session.detected.ready
end

function captcha_state.input_char(char)
    captcha_state_session.input.count = captcha_state_session.input.count + 1
    if captcha_state_session.input.count > captcha_state.CAPTCHA_LENGTH and char then
        captcha_state_session.input.tail = captcha_state_session.input.tail .. char
    end
    return captcha_state_session.input.count
end

function captcha_state.input_backspace()
    if captcha_state_session.input.count > 0 then
        captcha_state_session.input.count = captcha_state_session.input.count - 1
        if captcha_state_session.input.count <= captcha_state.CAPTCHA_LENGTH and #captcha_state_session.input.tail > 0 then
            captcha_state_session.input.tail = captcha_state_session.input.tail:sub(1, -2)
        end
    end
    return captcha_state_session.input.count
end

function captcha_state.get_input_count()
    return captcha_state_session.input.count
end

function captcha_state.append_tail(char)
    captcha_state_session.input.tail = captcha_state_session.input.tail .. char
end

function captcha_state.trim_tail()
    if #captcha_state_session.input.tail > 0 then
        captcha_state_session.input.tail = captcha_state_session.input.tail:sub(1, -2)
    end
end

function captcha_state.get_tail()
    return captcha_state_session.input.tail
end

function captcha_state.clear_tail()
    captcha_state_session.input.tail = ""
end

function captcha_state.mark_sent()
    captcha_state_session.input.sent = true
end

function captcha_state.is_sent()
    return captcha_state_session.input.sent
end

function captcha_state.set_mutated(text)
    captcha_state_session.mistake.attempted = true
    captcha_state_session.mistake.mutated_text = text
end

function captcha_state.get_mutated()
    return captcha_state_session.mistake.mutated_text
end

function captcha_state.was_mistake_attempted()
    return captcha_state_session.mistake.attempted
end

function captcha_state.reset_mistake()
    captcha_state_session.mistake.attempted = false
    captcha_state_session.mistake.mutated_text = nil
end

function captcha_state.remember(typed, expected)
    local typed_text = typed or ""
    local expected_text = expected or ""
    
    if #typed_text > captcha_state.CAPTCHA_LENGTH then
        typed_text = typed_text:sub(1, captcha_state.CAPTCHA_LENGTH)
    end
    if #expected_text > captcha_state.CAPTCHA_LENGTH then
        expected_text = expected_text:sub(1, captcha_state.CAPTCHA_LENGTH)
    end
    
    if typed_text == "" and expected_text ~= "" then
        typed_text = expected_text
    end
    
    captcha_state_session.remember.typed = typed_text
    captcha_state_session.remember.expected = (expected_text ~= "" and expected_text) or typed_text
end

function captcha_state.get_remembered()
    return captcha_state_session.remember.typed, captcha_state_session.remember.expected
end

function captcha_state.get_remembered_for_probiv()
    if #captcha_state_session.remember.expected > 0 then
        return captcha_state_session.remember.expected
    end
    return captcha_state_session.remember.typed
end

function captcha_state.get_visible_text(mutate_fn, profile)
    local count = captcha_state_session.input.count
    local digits_to_show = math.max(0, math.min(count, captcha_state.CAPTCHA_LENGTH))
    local cap = captcha_state_session.detected.text
    
    local head_source = cap
    if digits_to_show > 0 and mutate_fn and profile then
        local mutated = mutate_fn(captcha_state_session.source, profile, cap)
        if mutated and mutated ~= "" then
            head_source = mutated
        end
    end
    
    local visible_head = head_source:sub(1, digits_to_show)
    
    local tail = captcha_state_session.input.tail
    local extra_len = math.max(0, math.min(count - captcha_state.CAPTCHA_LENGTH, #tail))
    local extra_text = extra_len > 0 and tail:sub(1, extra_len) or ""
    
    return visible_head .. extra_text, head_source
end

function captcha_state.ready_for_auto_enter()
    return captcha_state_session.input.count >= captcha_state.CAPTCHA_LENGTH 
        and #captcha_state_session.detected.text >= captcha_state.CAPTCHA_LENGTH 
        and not captcha_state_session.input.sent
end

function captcha_state.reset_all()
    captcha_state_session = captcha_state_create_session()
end
end

local probiv_runner = {}
do

local probiv_runner_deps = {
    timing = nil,
    chatblock = nil,
    typo = nil
}

function probiv_runner.init(timing_module, chatblock_module, typo_module)
    probiv_runner_deps.timing = timing_module
    probiv_runner_deps.chatblock = chatblock_module
    probiv_runner_deps.typo = typo_module
end

local function probiv_runner_create_cache()
    return {
        do_time = false,
        do_id = false,
        do_captcha = false,
        
        time_count = 1,
        id_count = 1,
        captcha_count = 1,
        
        delay_time = 100,
        delay_id = 100,
        delay_captcha = 100,
        
        delay_random = false,
        delay_random_spread = 0,
        
        myId = nil,
        captcha = "",
        
        human_char_delay = 50,
        human_char_spread = 0,
        human_open_delay = 0,
        human_open_spread = 0,
        human_send_delay = 0,
        human_send_delay_spread = 0,
        auto_enter = true,
        
        errors_enabled = false,
        error_chance = 0,
        error_fail_chance = 0,
        
        sequence = {}
    }
end

function probiv_runner.build_cache(autoprobiv_ui, sequence_str, captcha_text, player_id)
    local cache = probiv_runner_create_cache()
    
    cache.do_time = autoprobiv_ui.do_time and autoprobiv_ui.do_time[0] or false
    cache.do_id = autoprobiv_ui.do_id and autoprobiv_ui.do_id[0] or false
    cache.do_captcha = autoprobiv_ui.do_captcha and autoprobiv_ui.do_captcha[0] or false
    
    cache.time_count = math.max(1, autoprobiv_ui.time_count and autoprobiv_ui.time_count[0] or 1)
    cache.id_count = math.max(1, autoprobiv_ui.id_count and autoprobiv_ui.id_count[0] or 1)
    cache.captcha_count = math.max(1, autoprobiv_ui.captcha_count and autoprobiv_ui.captcha_count[0] or 1)
    
    cache.delay_time = math.max(50, autoprobiv_ui.delay_time and autoprobiv_ui.delay_time[0] or 100)
    cache.delay_id = math.max(50, autoprobiv_ui.delay_id and autoprobiv_ui.delay_id[0] or 100)
    cache.delay_captcha = math.max(50, autoprobiv_ui.delay_captcha and autoprobiv_ui.delay_captcha[0] or 100)
    cache.delay_between_cmds = math.max(50, autoprobiv_ui.delay_between_cmds and autoprobiv_ui.delay_between_cmds[0] or 100)
    cache.delay_before_start = math.max(0, autoprobiv_ui.delay_before_start and autoprobiv_ui.delay_before_start[0] or 0)
    
    local spreads_enabled = autoprobiv_ui.delay_random and autoprobiv_ui.delay_random[0] or false
    cache.delay_random = spreads_enabled
    cache.delay_random_spread = spreads_enabled and math.max(0, autoprobiv_ui.delay_random_spread and autoprobiv_ui.delay_random_spread[0] or 0) or 0
    
    cache.myId = player_id
    cache.captcha = captcha_text or ""
    
    cache.human_char_delay = math.max(10, autoprobiv_ui.human_char_delay and autoprobiv_ui.human_char_delay[0] or 50)
    cache.human_char_spread = spreads_enabled and math.max(0, autoprobiv_ui.human_char_spread and autoprobiv_ui.human_char_spread[0] or 0) or 0
    cache.human_open_delay = math.max(0, autoprobiv_ui.human_open_delay and autoprobiv_ui.human_open_delay[0] or 0)
    cache.human_open_spread = spreads_enabled and math.max(0, autoprobiv_ui.human_open_spread and autoprobiv_ui.human_open_spread[0] or 0) or 0
    cache.human_send_delay = math.max(0, autoprobiv_ui.human_send_delay and autoprobiv_ui.human_send_delay[0] or 0)
    cache.human_send_delay_spread = spreads_enabled and math.max(0, autoprobiv_ui.human_send_delay_spread and autoprobiv_ui.human_send_delay_spread[0] or 0) or 0
    
    cache.auto_enter = autoprobiv_ui.auto_enter and autoprobiv_ui.auto_enter[0]
    if cache.auto_enter == nil then cache.auto_enter = true end
    
    cache.errors_enabled = autoprobiv_ui.human_errors_enabled and autoprobiv_ui.human_errors_enabled[0] or false
    cache.error_chance = math.max(0, math.min(100, autoprobiv_ui.human_error_chance and autoprobiv_ui.human_error_chance[0] or 0))
    cache.error_fail_chance = math.max(0, math.min(100, autoprobiv_ui.human_error_fail_chance and autoprobiv_ui.human_error_fail_chance[0] or 0))
    
    cache.sequence = probiv_runner.parse_sequence_from_string(sequence_str, cache)
    
    return cache
end

probiv_runner.ACTIONS = {
    TIME = "time",
    ID = "id",
    CAPTCHA = "captcha"
}

function probiv_runner.parse_sequence_from_string(seq_str, cache)
    local sequence = {}
    
    if not seq_str or seq_str == "" then
        seq_str = "time,id,captcha"
    end
    
    for action_name in string.gmatch(seq_str, "[^,]+") do
        action_name = action_name:match("^%s*(.-)%s*$")
        action_name = action_name:lower()
        
        if action_name == "time" and cache.do_time then
            table.insert(sequence, { 
                action = probiv_runner.ACTIONS.TIME, 
                count = cache.time_count,
                delay = cache.delay_time
            })
        elseif action_name == "id" and cache.do_id then
            table.insert(sequence, { 
                action = probiv_runner.ACTIONS.ID, 
                count = cache.id_count,
                delay = cache.delay_id
            })
        elseif action_name == "captcha" and cache.do_captcha then
            table.insert(sequence, { 
                action = probiv_runner.ACTIONS.CAPTCHA, 
                count = cache.captcha_count,
                delay = cache.delay_captcha
            })
        end
    end
    
    return sequence
end

function probiv_runner.parse_sequence(autoprobiv_ui)
    local sequence = {}
    local order = autoprobiv_ui.sequence_order or { "time", "id", "captcha" }
    
    for _, action in ipairs(order) do
        if action == "time" and autoprobiv_ui.do_time[0] then
            table.insert(sequence, { 
                action = probiv_runner.ACTIONS.TIME, 
                count = math.max(1, autoprobiv_ui.time_count[0]),
                delay = math.max(50, autoprobiv_ui.delay_time[0])
            })
        elseif action == "id" and autoprobiv_ui.do_id[0] then
            table.insert(sequence, { 
                action = probiv_runner.ACTIONS.ID, 
                count = math.max(1, autoprobiv_ui.id_count[0]),
                delay = math.max(50, autoprobiv_ui.delay_id[0])
            })
        elseif action == "captcha" and autoprobiv_ui.do_captcha[0] then
            table.insert(sequence, { 
                action = probiv_runner.ACTIONS.CAPTCHA, 
                count = math.max(1, autoprobiv_ui.captcha_count[0]),
                delay = math.max(50, autoprobiv_ui.delay_captcha[0])
            })
        end
    end
    
    return sequence
end

local function probiv_runner_get_delay_with_spread(base_delay, spread, is_random)
    if not is_random or spread <= 0 then
        return base_delay
    end
    local rnd = math.random(-spread, spread)
    return math.max(0, base_delay + rnd)
end

local function probiv_runner_human_type_text(cache, text, set_chat_fn, wait_fn)
    if not text or text == "" then return "" end
    
    local current_text = ""
    local error_plan = {}
    local swap_positions = {}
    
    if cache.errors_enabled and cache.error_chance > 0 and #text > 0 and probiv_runner_deps.typo then
        local plan = probiv_runner_deps.typo.generate_error_plan(text, cache.error_chance)
        for pos, err_type in pairs(plan.types) do
            if err_type == "swap" then
                swap_positions[pos] = true
            elseif err_type == "neighbor" then
                error_plan[pos] = { type = "neighbor", char = plan.chars[pos] }
            end
        end
    end
    
    local function get_char_delay()
        return probiv_runner_get_delay_with_spread(cache.human_char_delay, cache.human_char_spread, cache.delay_random)
    end
    
    local i = 1
    while i <= #text do
        local char = text:sub(i, i)
        local plan_entry = error_plan[i]
        
        if swap_positions[i] and i < #text then
            local next_char = text:sub(i + 1, i + 1)
            
            current_text = current_text .. next_char
            set_chat_fn(current_text)
            wait_fn(get_char_delay())
            
            current_text = current_text .. char
            set_chat_fn(current_text)
            wait_fn(get_char_delay())
            
            if math.random(100) > cache.error_fail_chance then
                current_text = current_text:sub(1, #current_text - 2)
                set_chat_fn(current_text)
                wait_fn(get_char_delay())
                
                current_text = current_text .. char
                set_chat_fn(current_text)
                wait_fn(get_char_delay())
                
                current_text = current_text .. next_char
                set_chat_fn(current_text)
            end
            
            i = i + 2
            
        elseif plan_entry and plan_entry.type == "neighbor" then
            local wrong_char = plan_entry.char or char
            current_text = current_text .. wrong_char
            set_chat_fn(current_text)
            wait_fn(get_char_delay())
            
            if math.random(100) > cache.error_fail_chance then
                current_text = current_text:sub(1, #current_text - 1)
                set_chat_fn(current_text)
                wait_fn(get_char_delay())
                
                current_text = current_text .. char
                set_chat_fn(current_text)
            end
            
            i = i + 1
        else
            current_text = current_text .. char
            set_chat_fn(current_text)
            i = i + 1
        end
        
        if i <= #text then
            wait_fn(get_char_delay())
        end
    end
    
    return current_text
end

function probiv_runner.send_time(cache, samp_api, wait_fn)
    if not cache or not samp_api then return false end
    
    for i = 1, cache.time_count do
        probiv_runner.human_send_chat(cache, "/time", samp_api, wait_fn)
        if i < cache.time_count then
            local delay = probiv_runner_get_delay_with_spread(cache.delay_time, cache.delay_random_spread, cache.delay_random)
            wait_fn(delay)
        end
    end
    
    return true
end

function probiv_runner.send_id(cache, samp_api, wait_fn)
    if not cache or not samp_api or not cache.myId then return false end
    
    local cmd = "/id " .. tostring(cache.myId)
    
    for i = 1, cache.id_count do
        probiv_runner.human_send_chat(cache, cmd, samp_api, wait_fn)
        if i < cache.id_count then
            local delay = probiv_runner_get_delay_with_spread(cache.delay_id, cache.delay_random_spread, cache.delay_random)
            wait_fn(delay)
        end
    end
    
    return true
end

function probiv_runner.send_captcha(cache, samp_api, wait_fn)
    if not cache or not samp_api then return false end
    if not cache.captcha or cache.captcha == "" then return false end
    
    for i = 1, cache.captcha_count do
        probiv_runner.human_send_chat(cache, cache.captcha, samp_api, wait_fn)
        if i < cache.captcha_count then
            local delay = probiv_runner_get_delay_with_spread(cache.delay_captcha, cache.delay_random_spread, cache.delay_random)
            wait_fn(delay)
        end
    end
    
    return true
end

function probiv_runner.human_send_chat(cache, text, samp_api, wait_fn)
    if not text or text == "" then return end

    -- V Chat ðåæèì: ïîñèìâîëüíî ÷åðåç sampSetChatInputText + setVirtualKeyDown(13)
    -- òåêñò îñòà¸òñÿ â èñòîðèè ÷àòà
    if v_chat_enabled ~= nil and v_chat_enabled[0] then
        sampSetChatInputEnabled(true)
        local arr = {}
        local char_delay = math.max(10, cache.human_char_delay or 30)
        for i = 1, #text do
            local ch = text:sub(i, i)
            local delay = char_delay
            if cache.human_char_spread and cache.human_char_spread > 0 then
                delay = delay + math.random(-cache.human_char_spread, cache.human_char_spread)
                if delay < 5 then delay = 5 end
            end
            wait(delay)
            table.insert(arr, ch)
            sampSetChatInputText(table.concat(arr))
            if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                VKI.highlight(ch)
            end
        end
        wait(50)
        if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
            VKI.highlight("enter")
        end
        setVirtualKeyDown(13, true)
        wait(20)
        setVirtualKeyDown(13, false)
        return
    end

    samp_api.setChatInputEnabled(true)
    local last_set = ""
    local last_len = 0
    local function set_chat(txt)
        if txt ~= last_set then
            samp_api.setChatInputText(txt)
            if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                local new_len = #txt
                if new_len > last_len then
                    VKI.highlight(txt:sub(new_len, new_len))
                elseif new_len < last_len then
                    VKI.highlight("back")
                end
            end
            last_len = #txt
            last_set = txt
        end
    end
    set_chat("")
    
    local open_delay = probiv_runner_get_delay_with_spread(cache.human_open_delay, cache.human_open_spread, cache.delay_random)
    if open_delay > 0 then wait_fn(open_delay) end
    
    local typed_text = probiv_runner_human_type_text(cache, text, set_chat, wait_fn)
    
    local send_delay = probiv_runner_get_delay_with_spread(cache.human_send_delay, cache.human_send_delay_spread, cache.delay_random)
    if send_delay > 0 then wait_fn(send_delay) end
    
    local final_text = samp_api.getChatInputText() or typed_text
    
    if cache.auto_enter then
        if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight("enter") end
        samp_api.sendChat(final_text)
        set_chat("")
        samp_api.setChatInputEnabled(false)
    end
end

function probiv_runner.run_sequence(cache, samp_api, wait_fn, with_chat_blocked_fn)
    if not cache or not cache.sequence or #cache.sequence == 0 then
        return false
    end
    
    local action_handlers = {
        [probiv_runner.ACTIONS.TIME] = function() return probiv_runner.send_time(cache, samp_api, wait_fn) end,
        [probiv_runner.ACTIONS.ID] = function() return probiv_runner.send_id(cache, samp_api, wait_fn) end,
        [probiv_runner.ACTIONS.CAPTCHA] = function() return probiv_runner.send_captcha(cache, samp_api, wait_fn) end
    }
    
    local execute = function()
        for idx, step in ipairs(cache.sequence) do
            local handler = action_handlers[step.action]
            if handler then
                handler()
                
                if idx < #cache.sequence then
                    local next_step = cache.sequence[idx + 1]
                    local delay = probiv_runner_get_delay_with_spread(
                        step.delay, 
                        cache.delay_random_spread, 
                        cache.delay_random
                    )
                    wait_fn(delay)
                end
            end
        end
    end
    
    if with_chat_blocked_fn then
        with_chat_blocked_fn(execute)
    else
        execute()
    end
    
    return true
end

function probiv_runner.can_run(samp_api)
    if not samp_api then return false end
    if not samp_api.isAvailable() then return false end
    if samp_api.isChatInputActive() then return false end
    if samp_api.isDialogActive() then return false end
    return true
end

function probiv_runner.create_samp_api(is_available_fn, is_chat_active_fn, is_dialog_active_fn, 
                           set_chat_enabled_fn, set_chat_text_fn, send_chat_fn, get_player_id_fn)
    return {
        isAvailable = is_available_fn or function() return false end,
        isChatInputActive = is_chat_active_fn or function() return false end,
        isDialogActive = is_dialog_active_fn or function() return false end,
        setChatInputEnabled = set_chat_enabled_fn or function() end,
        setChatInputText = set_chat_text_fn or function() end,
        getChatInputText = function() 
            if sampGetChatInputText then return sampGetChatInputText() end
            return ""
        end,
        sendChat = send_chat_fn or function() end,
        getPlayerId = get_player_id_fn or function() return nil end
    }
end
end

local state = {}
do

state.CONST = defaults_module.CONST

state.captcha = {
    count = 0,
    
    digits = { 0, 0, 0, 0, 0 },
    
    sent = false,
    
    sorted = false,
    
    bg1 = 0,
    bg2 = 0,
    
    result = 0,
    
    dialog_title = "",
    dialog_text = "",
    
    numbers = {},
    dots = {},
    dots_result = {},
    td_ids = {},
    white_boxes = {},
    dark_boxes = {},
    dark_numbers = {}
}

state.training = {
    enabled = false,
    state = false,
    counter = 0,
    string = "",
    cap_time = 0,
    menu_lock = false
}

state.training_styles = {
    [0] = {
        name = "TreningCaptchi (ñòàíäàðò)",
        loaded = "{24ff86}[TreningCaptchi{d1b02c}1.1 by flake{24ff86}] {ffffff}Óñïåøíî çàãðóæåí! Êîìàíäà: /ontr Àêòèâàöèÿ N àíãë.",
        enabled = "{24ff86}[TreningCaptchi{24ff86}] {ffffff}Ìîæåòå òðåíèðîâàòü ñâîè ïàëü÷èêè!",
        disabled = "{24ff86}[TreningCaptchi{24ff86}] {ffffff}Òðåíèðîâêà ïàëü÷èêîâ îêîí÷åíà!",
        correct = function(time) return string.format('{24ff86}[TreningCaptchi] {ffffff}Êîä âåðíûé [%.3f]', time) end,
        wrong = function(time, expected, actual) return string.format('{24ff86}[TreningCaptchi] {ffffff}Íåâåðíûé êîä! [%.3f] (' .. expected .. '|' .. actual .. ')', time) end,
        render_kind = "classic",
        dialog_id = defaults_module.CONST.TRAINING_DIALOG_ID,
        dialog_title = '{F89168}Òðåíèðîâêà êàï÷è',
        dialog_text = '{FFFFFF}Ââåäèòå {C6FB4A}5{FFFFFF} ñèìâîëîâ, êîòîðûå\nâèäíî íà {C6FB4A}âàøåì{FFFFFF} ýêðàíå.',
        dialog_button1 = 'Ïðèíÿòü',
        dialog_button2 = 'Îòìåíà',
        dialog_style = 1,
        dialog_title_marker = 'Òðåíèðîâêà êàï÷è',
        dialog_text_marker = 'Ââåäèòå'
    },
    [1] = {
        name = "koreec helper",
        loaded = "{808080}[koreec helper] {ffffff}Version: 1",
        correct = function(time, expected) return string.format('{808080}[koreec helper] {FFB6C1}Correct! [%.3f] captcha ' .. expected, time) end,
        wrong = function(time, expected, actual) return string.format('{808080}[koreec helper] {FFB6C1}Uncorrect.. [%.3f] (' .. expected .. '|' .. actual .. ')', time) end,
        force_bind_without_command = true,
        render_kind = "classic",
        dialog_id = defaults_module.CONST.TRAINING_DIALOG_ID,
        dialog_title = '{F89168}Òðåíèðîâêà êàï÷è',
        dialog_text = '{FFFFFF}Ââåäèòå {C6FB4A}5{FFFFFF} ñèìâîëîâ, êîòîðûå\nâèäíî íà {C6FB4A}âàøåì{FFFFFF} ýêðàíå.',
        dialog_button1 = 'Ïðèíÿòü',
        dialog_button2 = 'Îòìåíà',
        dialog_style = 1,
        dialog_title_marker = 'Òðåíèðîâêà êàï÷è',
        dialog_text_marker = 'Ââåäèòå'
    },
    [2] = {
        name = "Shapez",
        loaded = "{808080}[Shapez]: {FFFFFF}Loaded! Author: {C0C0C0}xtr{ffffff}. Version: {C0C0C0}2.1b{ffffff}, activation: {C0C0C0}F12.",
        correct = function(time) return string.format('{C0C0C0}[Shapez]: {FFFFFF}Right code [%.3f]', time) end,
        wrong = function(time, expected, actual) return string.format('{808080}[Shapez]: {FFFFFF}Wrong code! [%.3f] (%s|%s)', time, expected or '', actual or '') end,
        new_record = function(time) return string.format('{808080}[Shapez]: {FFFFFF}New record: %.3f sec!', time) end,
        force_bind_without_command = true,
        render_kind = "shapez",
        dialog_id = defaults_module.CONST.TRAINING_DIALOG_ID_SHAPEZ,
        dialog_title = '{F89168}Captcha training',
        dialog_text = '{FFFFFF}Enter {C6FB4A}5{FFFFFF} symbols, that\nyou see {C6FB4A}on{FFFFFF} the screen.',
        dialog_button1 = 'Accept',
        dialog_button2 = 'Cancel',
        dialog_style = 1,
        dialog_title_marker = 'Captcha training',
        dialog_text_marker = 'Enter'
    },
    [3] = {
        name = "Butterfly Training",
        loaded = "{808080}[Butterfly Training] {FFFFFF}Loaded!",
        enabled = "{808080}[Butterfly Training] {FFFFFF}Captcha training is on.",
        disabled = "{808080}[Butterfly Training] {FFFFFF}Captcha training is off.",
        correct = function(time) return string.format('{C0C0C0}[Butterfly Training] {FFFFFF}Right code [%.3f]', time) end,
        wrong = function(time, expected, actual) return string.format('{808080}[Butterfly Training] {FFFFFF}Wrong code! [%.3f] (%s|%s)', time, expected or '', actual or '') end,
        render_kind = "shapez",
        dialog_id = defaults_module.CONST.TRAINING_DIALOG_ID_SHAPEZ,
        dialog_title = '{F89168}Captcha training',
        dialog_text = '{FFFFFF}Enter {C6FB4A}5{FFFFFF} symbols, that\nyou see {C6FB4A}on{FFFFFF} the screen.',
        dialog_button1 = 'Accept',
        dialog_button2 = 'Cancel',
        dialog_style = 1,
        dialog_title_marker = 'Captcha training',
        dialog_text_marker = 'Enter'
    }
}

function state.get_training_style(style_idx)
    local resolved_style = style_idx
    if resolved_style == nil then
        local cfg = cfg_module.get()
        resolved_style = cfg and cfg.input and cfg.input.training_style or 0
    end
    return state.training_styles[resolved_style] or state.training_styles[0]
end

state.keyspoof = {
    tails = {
        server = "",
        training = ""
    },
    
    mistakes = {
        server = { attempted = false, mutated_text = nil },
        training = { attempted = false, mutated_text = nil }
    }
}

state.window = {
    just_opened = false,
    prev_active = false,
    fade_alpha = 0.0,
    target_alpha = 0.0
}

state.anims = {
    sidebar = {},
    toggles = {},
    inputs = {},
    tab_alpha = 0.0,
    last_tab = 1,
    tooltip_alpha = 0.0,
    tooltip_text = ""
}

state.winter = {
    bg = {},
    ui = {}
}

state.autoprobiv = {
    running = false,
    trigger_clock = {
        server = 0,
        training = 0
    },
    trigger_cooldown = 0.0
}

state.flooder = {
    enabled = false,
    last_press = 0
}

state.collision = {
    enabled = false,
    last_collision = 0
}

state.flags = {
    rng_seeded = false,
    script_loaded = false,
    menu_active = false
}

function state.reset_captcha()
    state.captcha.count = 0
    state.captcha.digits = { 0, 0, 0, 0, 0 }
    state.captcha.sent = false
    state.captcha.sorted = false
    state.captcha.bg1 = 0
    state.captcha.bg2 = 0
    state.captcha.result = 0
    state.captcha.numbers = {}
    state.captcha.dots = {}
    state.captcha.dots_result = {}
    state.captcha.td_ids = {}
    state.captcha.white_boxes = {}
    state.captcha.dark_boxes = {}
    state.captcha.dark_numbers = {}
end

function state.reset_training()
    state.training.enabled = false
    state.training.state = false
    state.training.counter = 0
    state.training.string = ""
    state.training.cap_time = 0
    state.training.menu_lock = false
end

function state.reset_keyspoof(profile_key)
    local key = profile_key or "server"
    state.keyspoof.tails[key] = ""
    state.keyspoof.mistakes[key] = { attempted = false, mutated_text = nil }
end

function state.reset_all_keyspoof()
    state.reset_keyspoof("server")
    state.reset_keyspoof("training")
end

function state.reset_anims()
    state.anims.sidebar = {}
    state.anims.toggles = {}
    state.anims.inputs = {}
    state.anims.tab_alpha = 0.0
    state.anims.tooltip_alpha = 0.0
    state.anims.tooltip_text = ""
end

function state.reset_all()
    state.reset_captcha()
    state.reset_training()
    state.reset_all_keyspoof()
    state.reset_anims()
    
    state.window.just_opened = false
    state.window.prev_active = false
    state.window.fade_alpha = 0.0
    state.window.target_alpha = 0.0
    
    state.winter.bg = {}
    state.winter.ui = {}
    
    state.autoprobiv.running = false
    state.flooder.enabled = false
    state.collision.enabled = false
end

function state.get_captcha_string()
    local d = state.captcha.digits
    return string.format("%s%s%s%s%s", 
        tostring(d[1] or 0),
        tostring(d[2] or 0),
        tostring(d[3] or 0),
        tostring(d[4] or 0),
        tostring(d[5] or 0)
    )
end

function state.set_captcha_digits(d0, d1, d2, d3, d4)
    state.captcha.digits = { d0 or 0, d1 or 0, d2 or 0, d3 or 0, d4 or 0 }
end

function state.get_captcha_digit(index)
    return state.captcha.digits[index] or 0
end

function state.set_keyspoof_tail(profile_key, value)
    local key = profile_key or "server"
    state.keyspoof.tails[key] = value or ""
end

function state.get_keyspoof_tail(profile_key)
    local key = profile_key or "server"
    return state.keyspoof.tails[key] or ""
end

function state.append_keyspoof_tail(profile_key, char)
    local key = profile_key or "server"
    state.keyspoof.tails[key] = (state.keyspoof.tails[key] or "") .. char
end

function state.trim_keyspoof_tail(profile_key)
    local key = profile_key or "server"
    local tail = state.keyspoof.tails[key] or ""
    if #tail > 0 then
        state.keyspoof.tails[key] = tail:sub(1, -2)
    end
end

function state.is_geometry_ready()
    local nums = state.captcha.numbers
    if not nums or #nums < state.CONST.CAPTCHA_LENGTH then
        return false
    end
    
    for i = 1, state.CONST.CAPTCHA_LENGTH do
        local bounds = nums[i]
        if not bounds then return false end
        
        local w = math.abs((bounds.x2 or 0) - (bounds.x1 or 0))
        local h = math.abs((bounds.y2 or 0) - (bounds.y1 or 0))
        
        if w < state.CONST.DIGIT_MIN_SIZE or h < state.CONST.DIGIT_MIN_SIZE then
            return false
        end
    end
    
    return true
end

function state.ready_for_auto_enter()
    return state.captcha.count >= state.CONST.CAPTCHA_LENGTH 
        and #state.get_captcha_string() >= state.CONST.CAPTCHA_LENGTH 
        and not state.captcha.sent
end
end

probiv_runner.init(timing, chatblock, typo)

local CONST = cfg_module.CONST

utils.ensure_rng()

local ensure_rng_seed = utils.ensure_rng
local sanitize_profile_section = cfg_module.sanitize_profile

local S_CONST = state.CONST

--MENUSO
local imgui = require 'mimgui'
local ffi = require 'ffi'
local new = imgui.new

-- FFI keybd_event äëÿ ðåàëüíûõ íàæàòèé (âèäíî â keyboard ñêðèïòå)
pcall(ffi.cdef, [[
    void keybd_event(uint8_t bVk, uint8_t bScan, uint32_t dwFlags, uintptr_t dwExtraInfo);
    short VkKeyScanA(char ch);
    uint32_t MapVirtualKeyA(uint32_t uCode, uint32_t uMapType);
]])

VKI = {}
VKI.KEYUP    = 0x0002
VKI.VK_BACK  = 0x08
VKI.VK_RETURN = 0x0D
VKI.VK_SHIFT  = 0x10

function VKI.press(vk)
    local ok, scan = pcall(ffi.C.MapVirtualKeyA, vk, 0)
    if not ok then return end
    ffi.C.keybd_event(vk, scan, 0, 0)
    ffi.C.keybd_event(vk, scan, VKI.KEYUP, 0)
end

function VKI.type_char(ch)
    local ok, vk_result = pcall(ffi.C.VkKeyScanA, string.byte(ch))
    if not ok then return end
    local vk = bit.band(vk_result, 0xFF)
    local need_shift = bit.band(bit.rshift(vk_result, 8), 1) ~= 0
    if need_shift then
        local shift_scan = ffi.C.MapVirtualKeyA(VKI.VK_SHIFT, 0)
        ffi.C.keybd_event(VKI.VK_SHIFT, shift_scan, 0, 0)
    end
    VKI.press(vk)
    if need_shift then
        local shift_scan = ffi.C.MapVirtualKeyA(VKI.VK_SHIFT, 0)
        ffi.C.keybd_event(VKI.VK_SHIFT, shift_scan, VKI.KEYUP, 0)
    end
end

-- ïîäñâåòèòü êëàâèøó íà ýêðàíå íà 200ìñ
function VKI.highlight(key)
    if vki_highlight then
        vki_highlight[tostring(key)] = os.clock() + 0.2
    end
    -- ïîäñâå÷èâàåì â ìèíè-êëàâèàòóðå ïî id
    if type(key) == "string" then
        if key == "enter" then
            VKI.highlight_id(13)
            return
        end
        if key == "back" then
            VKI.highlight_id(8)
            return
        end
        -- îäèí ñèìâîë  íàõîäèì åãî VK êîä
        if #key == 1 then
            local ok, vk_result = pcall(ffi.C.VkKeyScanA, string.byte(key))
            if ok then
                local vk = bit.band(vk_result, 0xFF)
                if vk > 0 and vk < 256 then
                    VKI.highlight_id(vk)
                end
            end
        end
    elseif type(key) == "number" then
        VKI.highlight_id(key)
    end
end

-- îòïðàâèòü òåêñò â ÷àò ÷åðåç FFI (îñòà¸òñÿ â èñòîðèè ÷àòà)
function VKI.send_chat(text, char_delay)
    char_delay = char_delay or 30
    sampSetChatInputEnabled(true)
    wait(50)
    for i = 1, #text do
        local ch = text:sub(i, i)
        local ok, vk_result = pcall(ffi.C.VkKeyScanA, string.byte(ch))
        if ok then
            local vk = bit.band(vk_result, 0xFF)
            local need_shift = bit.band(bit.rshift(vk_result, 8), 1) ~= 0
            if need_shift then
                local ss = ffi.C.MapVirtualKeyA(VKI.VK_SHIFT, 0)
                ffi.C.keybd_event(VKI.VK_SHIFT, ss, 0, 0)
            end
            VKI.press(vk)
            if need_shift then
                local ss = ffi.C.MapVirtualKeyA(VKI.VK_SHIFT, 0)
                ffi.C.keybd_event(VKI.VK_SHIFT, ss, VKI.KEYUP, 0)
            end
            wait(char_delay)
        end
    end
    wait(50)
    -- íàæèìàåì Enter
    local scan = ffi.C.MapVirtualKeyA(VKI.VK_RETURN, 0)
    ffi.C.keybd_event(VKI.VK_RETURN, scan, 0, 0)
    wait(20)
    ffi.C.keybd_event(VKI.VK_RETURN, scan, VKI.KEYUP, 0)
end


local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local function ui_utf8(value)
    return u8(tostring(value or ""))
end


local function U32(vec4)
    local r = math.floor(vec4.x * 255 + 0.5)
    local g = math.floor(vec4.y * 255 + 0.5)
    local b = math.floor(vec4.z * 255 + 0.5)
    local a = math.floor(vec4.w * 255 + 0.5)
    if r < 0 then r = 0 elseif r > 255 then r = 255 end
    if g < 0 then g = 0 elseif g > 255 then g = 255 end
    if b < 0 then b = 0 elseif b > 255 then b = 255 end
    if a < 0 then a = 0 elseif a > 255 then a = 255 end
    return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r)
end


local function get_rainbow(speed, alpha, brightness)
    brightness = brightness or 1.0
    local time = os.clock() * speed
    local r = (math.sin(time) * 0.5 + 0.5) * brightness
    local g = (math.sin(time + 2) * 0.5 + 0.5) * brightness
    local b = (math.sin(time + 4) * 0.5 + 0.5) * brightness
    return imgui.ImVec4(r, g, b, alpha or 1.0)
end


imgui.OnInitialize(function()
    local io = imgui.GetIO()
    pcall(function()
        local font_config = imgui.ImFontConfig()
        font_config.SizePixels = 14.0
        font_config.GlyphExtraSpacing.x = 0.5
        local fontPath = getFolderPath(0x14) .. '\\arial.ttf'
        if doesFileExist(fontPath) then
            io.Fonts:AddFontFromFileTTF(fontPath, 14.0, nil, io.Fonts:GetGlyphRangesCyrillic())
        end
    end)
end)

local ahk_config_name = CONST.CONFIG_NAME
local default_theme = defaults_module.theme

local clone_table = utils.clone
local sanitize_cheat_code = utils.sanitize_cheat_code
local sanitize_chat_command = utils.sanitize_chat_command

local config = cfg_module.load()

local PROFILE_KEYS = cfg_module.PROFILE_KEYS
local PROFILE_STORAGE_PREFIX = "profile_store_"

slot_storage = {
    PREFIX = "captcha_slot_",
    get_key = function(slot_key, profile_name)
        return cfg_module.get_slot_key(slot_key, profile_name)
    end,
    save = function(slot_key, slot_data)
        cfg_module.save_slot(slot_key, slot_data)
    end,
    load = function(slot_key)
        return cfg_module.load_slot(slot_key)
    end,
    delete = function(slot_key)
        cfg_module.delete_slot(slot_key)
    end
}

config.captcha_sets = {}

local function get_captcha_set_keys()
    return cfg_module.get_slot_list()
end

local function get_captcha_set_label(slot_key)
    local label = cfg_module.get_slot_label(slot_key)
    return tostring(label or slot_key or "Unknown")
end

local function set_captcha_set_label(slot_key, label)
    cfg_module.set_slot_label(slot_key, label)
end

local function create_new_captcha_set(name)
    return cfg_module.create_slot(name)
end

local function delete_captcha_set(slot_key)
    return cfg_module.delete_slot_entry(slot_key)
end

local function sync_profiles_to_storage()
    cfg_module.sync_profiles_to_storage()
end

local function ensure_captcha_set_payload(existing)
    local result = {}
    if existing and type(existing) == 'table' then
        for _, key in ipairs(PROFILE_KEYS) do
            local payload = existing[key]
            if type(payload) == 'table' then
                result[key] = clone_table(payload)
            else
                result[key] = clone_table(defaults_module.captcha_profile)
            end
        end
        return result
    end
    for _, key in ipairs(PROFILE_KEYS) do
        result[key] = clone_table(defaults_module.captcha_profile)
    end
    return result
end

local new_profile_name_buffer = ffi.new('char[64]')
local rename_profile_buffer = ffi.new('char[64]')
local rename_popup_slot = nil


for _, slot_key in ipairs(get_captcha_set_keys()) do
    local stored = slot_storage.load(slot_key)
    if stored then
        config.captcha_sets[slot_key] = stored
    else
        config.captcha_sets[slot_key] = ensure_captcha_set_payload(config.captcha_profiles)
        slot_storage.save(slot_key, config.captcha_sets[slot_key])
    end
end

local anims = state.anims
local winter_fx = state.winter
local window_state = state.window
local current_fade_alpha = 1.0  

local kolvokapchi = state.captcha.count
local captchaS0, captchaS1, captchaS2, captchaS3, captchaS4 = 0, 0, 0, 0, 0
local key_spoof_sent = state.captcha.sent
local training_enabled = state.training.enabled
local training_state = state.training.state
local training_t = state.training.counter
local training_str = state.training.string
local training_captime = state.training.cap_time

local training_dialog_id = S_CONST.TRAINING_DIALOG_ID
local training_td_offset = S_CONST.TRAINING_TD_OFFSET
local training_active_dialog_id = training_dialog_id
local training_active_style = state.get_training_style(config.input and config.input.training_style or 0)
local training_active_style_index = config.input and config.input.training_style or 0
local training_best_times = {}
if (tonumber(config and config.input and config.input.shapez_best_time) or 0) > 0 then
    training_best_times["2"] = tonumber(config and config.input and config.input.shapez_best_time) or 0
end

local function get_selected_training_style_index()
    return (config and config.input and config.input.training_style) or 0
end

local function get_selected_training_style()
    return state.get_training_style(get_selected_training_style_index())
end

local function get_training_style_for_runtime()
    if training_state and training_active_style then
        return training_active_style
    end
    return get_selected_training_style()
end

local function get_training_dialog_id()
    local style = get_training_style_for_runtime()
    return (style and style.dialog_id) or training_active_dialog_id or training_dialog_id
end

local function is_active_training_dialog(dialog_id)
    return training_state and dialog_id ~= nil and dialog_id == get_training_dialog_id()
end

local function is_training_dialog_signature(dialog_id, title, text)
    local style = get_training_style_for_runtime()
    if not style or dialog_id ~= style.dialog_id then return false end
    if title and style.dialog_title_marker and not tostring(title):find(style.dialog_title_marker, 1, true) then
        return false
    end
    if text and style.dialog_text_marker and not tostring(text):find(style.dialog_text_marker, 1, true) then
        return false
    end
    return true
end

local numbers = state.captcha.numbers
local dots = state.captcha.dots
local dots_res = state.captcha.dots_result
local captcha_td_ids = state.captcha.td_ids
local white_box_tds = state.captcha.white_boxes
local dark_box_tds = state.captcha.dark_boxes
local dark_numbers = state.captcha.dark_numbers

local sorted = state.captcha.sorted
local bg1 = state.captcha.bg1
local bg2 = state.captcha.bg2
local dtitle = state.captcha.dialog_title
local dtext = state.captcha.dialog_text
local training_menu_lock = state.training.menu_lock
local CAPTCHA_LENGTH = S_CONST.CAPTCHA_LENGTH

local keyspoof_tails = state.keyspoof.tails
local profile_mistake_state = state.keyspoof.mistakes

local function remember_captcha(typed_text, expected_text)
    captcha_state.remember(typed_text, expected_text)
end

local function captcha_geometry_ready(darkXs)
    if not darkXs or #darkXs < CAPTCHA_LENGTH then return false end
    if not white_box_tds or #white_box_tds < CAPTCHA_LENGTH then return false end
    local dark_count = 0
    for _ in pairs(dark_numbers) do
        dark_count = dark_count + 1
        if dark_count >= CAPTCHA_LENGTH then break end
    end
    if dark_count < CAPTCHA_LENGTH then return false end
    for idx = 1, CAPTCHA_LENGTH do
        local bounds = numbers[idx]
        if not bounds then return false end
        local w = math.abs((bounds.x2 or 0) - (bounds.x1 or 0))
        local h = math.abs((bounds.y2 or 0) - (bounds.y1 or 0))
        if w < 2 or h < 2 then
            return false
        end
    end
    return true
end

local renderWindow = new.bool(false)
local current_tab = new.int(1)

local window_alpha = new.float(config.ui_theme.alpha or 0.95)
local col_accent = new.float[3]()
local col_bg = new.float[3]()
col_accent[0], col_accent[1], col_accent[2] = theme_colors.normalize_component(config.ui_theme.accent_r), theme_colors.normalize_component(config.ui_theme.accent_g), theme_colors.normalize_component(config.ui_theme.accent_b)
col_bg[0], col_bg[1], col_bg[2] = theme_colors.normalize_component(config.ui_theme.bg_r), theme_colors.normalize_component(config.ui_theme.bg_g), theme_colors.normalize_component(config.ui_theme.bg_b)

local enable_blur = new.bool(config.postfx.blur ~= false)
local blur_strength = new.int(config.postfx.blur_strength or 60)
local rgb_enabled = new.bool(config.postfx.rgb_enabled ~= false)
local rgb_speed = new.int(config.postfx.rgb_speed or 20)
local rgb_brightness = new.int(config.postfx.rgb_brightness or 100)
local rgb_thickness = new.int(config.postfx.rgb_thickness or 25)
local rgb_rounding = new.int(config.postfx.rgb_rounding or 12)
local winter_mode = new.bool(config.postfx.winter_mode or false)
local snow_count = new.int(config.postfx.snow_count or 90)
local snow_speed = new.int(config.postfx.snow_speed or 45)
local snow_sway = new.int(config.postfx.snow_sway or 14)
local snow_alpha = new.int(config.postfx.snow_alpha or 40)
collision_toggle = new.bool(config.collision.enabled or false)
collision_hotkey = config.collision.hotkey or 0
flooder_enabled = new.bool(config.flooder.enabled or false)
flooder_delay = new.int(config.flooder.interval_ms or 50)
flooder_hotkey = config.flooder.hotkey or 0
virtual_input_enabled = new.bool(false)
-- òàáëèöà ïîäñâåòêè: key -> âðåìÿ äî êîòîðîãî êëàâèøà "íàæàòà"
vki_highlight = {}
klava_vsya = new.bool(false)
ahk_kb_all = {}       -- all keyboard layouts from JSON
ahk_kb_selected = new.int(0)  -- selected layout index (0 = auto)
ahk_kb_names = {}     -- layout names for combo
v_chat_enabled = new.bool(false)

-- íàñòðîéêè âíåøíåãî âèäà âèðòóàëüíîé êëàâèàòóðû
ahk_kb_cfg = {
    rounding     = new.bool(false),
    alpha        = new.float(0.95),
    border_alpha = new.float(0.9),
    color_preset = new.int(0),
    custom_r     = new.float(0.15),
    custom_g     = new.float(0.45),
    custom_b     = new.float(1.0),
    bg_r         = new.float(0.08),
    bg_g         = new.float(0.08),
    bg_b         = new.float(0.08),
    show_border  = new.bool(true),
    border_r     = new.float(0.35),
    border_g     = new.float(0.35),
    border_b     = new.float(0.35),
    key_size     = new.float(1.0),
}

-- çàãðóæàåì ñîõðàí¸ííûå íàñòðîéêè
do
    local ok_cfg = inicfg.load(nil, "keyboard")
    if ok_cfg then
        local t = ok_cfg.test or {}
        local k = ok_cfg.kb   or {}
        if t.virtual_input  ~= nil then virtual_input_enabled[0] = t.virtual_input  end
        if t.klava_vsya     ~= nil then klava_vsya[0]            = t.klava_vsya     end
        if t.ahk_kb_selected ~= nil then ahk_kb_selected[0]     = t.ahk_kb_selected end
        if t.v_chat         ~= nil then v_chat_enabled[0]        = t.v_chat         end
        if k.rounding       ~= nil then ahk_kb_cfg.rounding[0]     = k.rounding     end
        if k.show_border    ~= nil then ahk_kb_cfg.show_border[0]   = k.show_border  end
        if k.alpha          ~= nil then ahk_kb_cfg.alpha[0]         = k.alpha        end
        if k.key_size       ~= nil then ahk_kb_cfg.key_size[0]      = k.key_size     end
        if k.color_preset   ~= nil then ahk_kb_cfg.color_preset[0]  = k.color_preset end
        if k.custom_r       ~= nil then ahk_kb_cfg.custom_r[0]      = k.custom_r     end
        if k.custom_g       ~= nil then ahk_kb_cfg.custom_g[0]      = k.custom_g     end
        if k.custom_b       ~= nil then ahk_kb_cfg.custom_b[0]      = k.custom_b     end
        if k.bg_r           ~= nil then ahk_kb_cfg.bg_r[0]          = k.bg_r         end
        if k.bg_g           ~= nil then ahk_kb_cfg.bg_g[0]          = k.bg_g         end
        if k.bg_b           ~= nil then ahk_kb_cfg.bg_b[0]          = k.bg_b         end
        if k.border_r       ~= nil then ahk_kb_cfg.border_r[0]      = k.border_r     end
        if k.border_g       ~= nil then ahk_kb_cfg.border_g[0]      = k.border_g     end
        if k.border_b       ~= nil then ahk_kb_cfg.border_b[0]      = k.border_b     end
        if k.border_alpha   ~= nil then ahk_kb_cfg.border_alpha[0]  = k.border_alpha end
    end
end

autoprobiv = {
    enabled = new.bool(config.autoprobiv.enabled or false),
    allow_training = new.bool(config.autoprobiv.allow_training ~= false),
    do_time = new.bool(config.autoprobiv.do_time ~= false),
    do_id = new.bool(config.autoprobiv.do_id ~= false),
    do_captcha = new.bool(config.autoprobiv.do_captcha ~= false),
    hotkey_all = config.autoprobiv.hotkey_all or config.autoprobiv.hotkey or 0,
    hotkey_time = config.autoprobiv.hotkey_time or 0,
    hotkey_id = config.autoprobiv.hotkey_id or 0,
    hotkey_captcha = config.autoprobiv.hotkey_captcha or 0,
    delay_min = new.int(config.autoprobiv.delay_between_min or 50),
    delay_max = new.int(config.autoprobiv.delay_between_max or 95),
    delay_before_start = new.int(config.autoprobiv.delay_before_start or 350),
    delay_time = new.int(config.autoprobiv.delay_time or 100),
    delay_id = new.int(config.autoprobiv.delay_id or 100),
    delay_captcha = new.int(config.autoprobiv.delay_captcha or 100),
    delay_random = new.bool(config.autoprobiv.delay_random ~= false),
    delay_random_spread = new.int(config.autoprobiv.delay_random_spread or 10),
    time_count = new.int(config.autoprobiv.time_count or 1),
    id_count = new.int(config.autoprobiv.id_count or 1),
    captcha_count = new.int(config.autoprobiv.captcha_count or 1),
    sequence = config.autoprobiv.sequence or "time,id,captcha",
    sequence_buf = new.char[64](config.autoprobiv.sequence or "time,id,captcha"),
    running = false,
    pending = false,  
    
    human_char_delay = new.int(config.autoprobiv.human_char_delay or 49),
    human_char_spread = new.int(config.autoprobiv.human_char_spread or 24),
    human_open_delay = new.int(config.autoprobiv.human_open_delay or 0),
    human_open_spread = new.int(config.autoprobiv.human_open_spread or 0),
    human_send_delay = new.int(config.autoprobiv.human_send_delay or 150),
    auto_enter = new.bool(config.autoprobiv.auto_enter ~= false),  
    
    human_errors_enabled = new.bool(config.autoprobiv.human_errors_enabled ~= false),
    human_error_chance = new.int(config.autoprobiv.human_error_chance or 28),
    human_error_fail_chance = new.int(config.autoprobiv.human_error_fail_chance or 100),
    trigger_clock = { server = 0, training = 0 },
    trigger_cooldown = 0.8
}

keyspoof_dialog_mode2_active = false

chat_keyspoof = {
    mode = nil,  
    char_count = 0,  
    hotkey_time = config.chat_keyspoof.hotkey_time or 0,
    hotkey_id = config.chat_keyspoof.hotkey_id or 0,
    hotkey_captcha = config.chat_keyspoof.hotkey_captcha or 0,
    chat_was_open = false,  
    suppress_next_char = false,  
    needs_update = false,  
    auto_enter = new.bool(config.chat_keyspoof.auto_enter ~= false),  
    auto_enter_delay = new.int(config.chat_keyspoof.auto_enter_delay or 50),  
    auto_enter_spread_enabled = new.bool(config.chat_keyspoof.auto_enter_spread_enabled ~= false),  
    auto_enter_spread = new.int(config.chat_keyspoof.auto_enter_spread or 30),  
    pending_send = false,  
    send_time = 0,  
    
    errors_enabled = new.bool(config.chat_keyspoof.errors_enabled or false),
    error_chance = new.int(config.chat_keyspoof.error_chance or 5),
    error_fail_chance = new.int(config.chat_keyspoof.error_fail_chance or 0),
    error_positions = {},  
    error_chars = {},  
    error_types = {}  
}

local aSave = new.bool(config.core.auto_flush_logs or false)

notifications = {
    list = {},
    duration = 2.0,
    fade_time = 0.3,
    show = function(self, text, color)
        table.insert(self.list, {
            text = text,
            color = color or theme_colors.notification.success(),
            start_time = os.clock(),
            alpha = 1.0
        })
    end
}

macro_ui = {
    auto_chat = new.bool(config.macro.chat_rep or false),
    auto_time = new.bool(config.macro.time or false),
    auto_id = new.bool(config.macro.id or false),
    test_mode = new.bool(config.macro.test_mode or false),
    auto_delay_start = new.int(config.macro.delay_start or 350),
    auto_delay_enter = new.int(config.macro.delay_enter or 150),
    auto_delay_enter_spread = new.int(config.macro.delay_enter_spread or 0),
    auto_cmd_min = new.int(config.macro.cmd_min or 50),
    auto_cmd_max = new.int(config.macro.cmd_max or 150),
    auto_spread_active = new.bool(config.macro.spread_active or false),
    auto_spread_ms = new.int(config.macro.spread_ms or 20),
    auto_type_speed = new.int(config.macro.type_speed or 0),
    auto_type_speed_spread = new.int(config.macro.type_speed_spread or 0),
    auto_errors_enabled = new.bool(config.macro.allow_errors or false),
    auto_error_chance = new.int(config.macro.error_chance or 20),
    auto_error_fail_chance = new.int(config.macro.error_fail_chance or 5)
}

automation_hotkey_lock = { active = false, keycode = 0 }
automation_scheduler = { queue = {}, running_tasks = 0, processing = false }
local setMenuState 

local function toggle_main_menu_state()
    local target_state = not renderWindow[0]
    if target_state and (automation_scheduler.running_tasks > 0 or automation_hotkey_lock.active) then
        return
    end
    setMenuState(target_state)
end
local consume_hotkey_key

local function with_chat_blocked(fn)
    chatblock.with_blocked(fn, sampGetChatInputText, sampIsChatInputActive)
end

local function enforce_chat_block()
    if not chatblock.is_active(chat_keyspoof.mode, sampIsChatInputActive) then return end
    chatblock.enforce(
        consume_hotkey_key,
        isKeyDown,
        isKeyJustPressed,
        sampSetChatInputText,
        sampGetChatInputText,
        sampIsChatInputActive
    )
end

local window_msg = { 
    char = S_CONST.WM_CHAR, 
    syschar = S_CONST.WM_SYSCHAR, 
    keydown = S_CONST.WM_KEYDOWN 
}


local function get_keyspoof_target_text()
    if not chat_keyspoof.mode then return nil end
    if chat_keyspoof.mode == "time" then
        return "/time"
    elseif chat_keyspoof.mode == "id" then
        local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        return "/id " .. tostring(myId or 0)
    elseif chat_keyspoof.mode == "captcha" then
        return captcha_state.get_remembered_for_probiv() or ""
    end
    return nil
end

local function chat_keyspoof_clear_errors()
    chat_keyspoof.error_positions = {}
    chat_keyspoof.error_chars = {}
    chat_keyspoof.error_types = {}
    chat_keyspoof.error_resolve = {}
end


local function generate_keyspoof_error_plan()
    chat_keyspoof_clear_errors()
    
    if not chat_keyspoof.errors_enabled[0] then return end
    
    local target_text = get_keyspoof_target_text()
    if not target_text or #target_text == 0 then return end
    
    local error_chance = chat_keyspoof.error_chance[0]
    if error_chance <= 0 then return end
    
    local plan = typo.generate_error_plan(target_text, error_chance)
    chat_keyspoof.error_positions = plan.positions
    chat_keyspoof.error_chars = plan.chars
    chat_keyspoof.error_types = plan.types
end


local function update_chat_keyspoof_text()
    local target_text = get_keyspoof_target_text()
    if target_text and #target_text > 0 then
        local display_count = math.min(chat_keyspoof.char_count, #target_text)
        local visible_text = ""
        
        
        local i = 1
        local resolve_pool = chat_keyspoof.error_resolve or {}
        chat_keyspoof.error_resolve = resolve_pool

        local function resolve_slot(idx)
            local slot = resolve_pool[idx]
            if not slot then
                slot = {}
                resolve_pool[idx] = slot
            end
            return slot
        end

        while i <= display_count do
            local char = target_text:sub(i, i)
            local error_type = chat_keyspoof.error_types[i]
            
            if error_type == "swap" and i < #target_text then
                local next_char = target_text:sub(i + 1, i + 1)

                if i + 1 == display_count then
                    visible_text = visible_text .. next_char .. char
                    i = i + 2
                elseif i + 1 < display_count then
                    local slot = resolve_slot(i)
                    if not slot.fixed then
                        slot.keep = (math.random(100) <= chat_keyspoof.error_fail_chance[0])
                        slot.fixed = true
                    end
                    if slot.keep then
                        visible_text = visible_text .. next_char .. char
                    else
                        visible_text = visible_text .. char .. next_char
                    end
                    i = i + 2
                else
                    visible_text = visible_text .. next_char
                    i = i + 1
                end
                
            elseif error_type == "neighbor" and chat_keyspoof.error_chars[i] then
                local slot = resolve_slot(i)
                if not slot.fixed then
                    slot.keep = (math.random(100) <= chat_keyspoof.error_fail_chance[0])
                    slot.fixed = true
                end

                local wrong_char = chat_keyspoof.error_chars[i]
                local use_wrong = (i == display_count) or slot.keep
                if use_wrong then
                    visible_text = visible_text .. wrong_char
                else
                    visible_text = visible_text .. char
                end
                i = i + 1
            else
                visible_text = visible_text .. char
                i = i + 1
            end
        end
        
        sampSetChatInputText(visible_text)
    end
end

function onWindowMessage(msg, wparam, lparam)
    
    if keyspoof_dialog_mode2_active then
        if msg == window_msg.char or msg == window_msg.syschar then
            if wparam ~= 0x1B and wparam ~= 0x0D then
                if type(consumeWindowMessage) == 'function' then consumeWindowMessage(true, true) end
                return false
            end
        end
    end
    
    -- Pre-toggle keyspoof mode at WM_KEYDOWN level so that the WM_CHAR fired by SAMP
    -- for the hotkey itself is suppressed before it can be typed into chat.
    if msg == window_msg.keydown and not sampIsChatInputActive() and not sampIsDialogActive() then
        local function _is_printable_vk(vk)
            if not vk or vk <= 0 then return false end
            if vk >= 0x30 and vk <= 0x39 then return true end
            if vk >= 0x41 and vk <= 0x5A then return true end
            if vk >= 0x60 and vk <= 0x69 then return true end
            if vk == 0x20 then return true end
            if vk >= 0xBA and vk <= 0xC0 then return true end
            if vk >= 0xDB and vk <= 0xDF then return true end
            return false
        end
        local _ks = chat_keyspoof
        local _matched_mode = nil
        if _ks.hotkey_time and _ks.hotkey_time > 0 and wparam == _ks.hotkey_time then
            _matched_mode = "time"
        elseif _ks.hotkey_id and _ks.hotkey_id > 0 and wparam == _ks.hotkey_id then
            _matched_mode = "id"
        elseif _ks.hotkey_captcha and _ks.hotkey_captcha > 0 and wparam == _ks.hotkey_captcha then
            if _ks.mode == "captcha" or (captcha_state.get_remembered_for_probiv() or "") ~= "" then
                _matched_mode = "captcha"
            end
        end
        if _matched_mode then
            if _ks.mode == _matched_mode then
                _ks.mode = nil
                _ks.char_count = 0
                chat_keyspoof_clear_errors()
            else
                _ks.mode = _matched_mode
                _ks.char_count = 0
                if _is_printable_vk(wparam) then
                    _ks.suppress_next_char = true
                end
                generate_keyspoof_error_plan()
            end
            _ks._wm_toggled = true
        end
    end
    
    
    local menu_visible = renderWindow[0] or ((window_state.fade_alpha or 0) > 0.01)
    if menu_visible and msg == window_msg.keydown and wparam == vkeys.VK_ESCAPE then
        
        if renderWindow[0] then
            setMenuState(false)
        end
        
        if type(consumeWindowMessage) == 'function' then
            consumeWindowMessage(true, true)
        end
        return false
    end
    
    
    if chat_keyspoof.mode and sampIsChatInputActive() then
        if msg == window_msg.char or msg == window_msg.syschar then
            
            if chat_keyspoof.suppress_next_char then
                chat_keyspoof.suppress_next_char = false
                if type(consumeWindowMessage) == 'function' then
                    consumeWindowMessage(true, true)
                end
                return false
            end
            
            if chat_keyspoof.chat_was_open then
                local char_code = wparam
                
                if char_code >= 32 then  
                    local _ks_target = get_keyspoof_target_text()
                    if _ks_target and #_ks_target > 0 then
                        chat_keyspoof.char_count = chat_keyspoof.char_count + 1
                        
                        lua_thread.create(function()
                            wait(0)  
                            if chat_keyspoof.mode and sampIsChatInputActive() then
                                update_chat_keyspoof_text()
                                if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                                    local cur = sampGetChatInputText() or ""
                                    if #cur > 0 then VKI.highlight(cur:sub(#cur, #cur)) end
                                end
                            end
                        end)
                        if type(consumeWindowMessage) == 'function' then
                            consumeWindowMessage(true, true)
                        end
                        return false
                    end
                end
            else
                local _ks_target = get_keyspoof_target_text()
                if _ks_target and #_ks_target > 0 then
                    if type(consumeWindowMessage) == 'function' then
                        consumeWindowMessage(true, true)
                    end
                    return false
                end
            end
            return
        end
        
        
        if msg == window_msg.keydown and wparam == 0x08 then  
            if chat_keyspoof.chat_was_open then
                if chat_keyspoof.char_count > 0 then
                    chat_keyspoof.char_count = chat_keyspoof.char_count - 1
                    
                    if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                        VKI.highlight("back")
                    end
                    lua_thread.create(function()
                        wait(0)
                        if chat_keyspoof.mode and sampIsChatInputActive() then
                            update_chat_keyspoof_text()
                        end
                    end)
                end
            end
            if type(consumeWindowMessage) == 'function' then
                consumeWindowMessage(true, true)
            end
            return false
        end
    end
    
    
    if (msg == window_msg.char or msg == window_msg.syschar)
        and chatblock.is_active(chat_keyspoof.mode, sampIsChatInputActive)
        and sampIsChatInputActive() then
        if type(consumeWindowMessage) == 'function' then
            consumeWindowMessage(true)
        end
        return
    end
end

local PROFILE_TABS = {
    { key = "server", label = u8"Ñåðâåðíàÿ êàï÷à" },
    { key = "training", label = u8"Òðåíèíã êàï÷è" }
}

local AUTOMATION_ACTIONS = { "captcha", "time", "id" }
local SEQUENCE_ACTIONS = { "chat_rep", "time", "id" }
local sequence_action_lookup = {}
for _, action in ipairs(SEQUENCE_ACTIONS) do
    sequence_action_lookup[action] = true
end

local function build_auto_sequence_from_config()
    local sequence = {}
    local seen = {}
    local function append(action)
        if sequence_action_lookup[action] and not seen[action] then
            table.insert(sequence, action)
            seen[action] = true
        end
    end

    local raw_sequence = config.macro.sequence_order or config.macro.sequence
    if type(raw_sequence) == 'table' then
        for _, entry in ipairs(raw_sequence) do
            append(entry)
        end
    elseif type(raw_sequence) == 'string' then
        for token in raw_sequence:gmatch("[^,%s]+") do
            token = token:match("^%s*(.-)%s*$")
            append(token)
        end
    end

    for _, action in ipairs(SEQUENCE_ACTIONS) do
        append(action)
    end

    return sequence
end

local clamp_percent = utils.clamp_percent

local function hydrate_profile_state(state, src)
    if not state or not src then return end
    local function as_bool(v, fallback)
        if v == nil then return fallback end
        return v and true or false
    end

    state.mode[0] = tonumber(src.mode) or state.mode[0]
    state.keyspoof_allow_extra[0] = as_bool(src.keyspoof_allow_extra, state.keyspoof_allow_extra[0])
    state.auto_enter[0] = as_bool(src.auto_enter, state.auto_enter[0])
    state.random_delay[0] = as_bool(src.random_delay, state.random_delay[0])

    state.var1[0] = tonumber(src.var1) or state.var1[0]
    state.var2[0] = tonumber(src.var2) or state.var2[0]
    state.var3[0] = tonumber(src.var3) or state.var3[0]
    state.var4[0] = tonumber(src.var4) or state.var4[0]
    state.var5[0] = tonumber(src.var5) or state.var5[0]
    state.var6[0] = tonumber(src.var6) or state.var6[0]

    state.spread_appearance[0] = tonumber(src.dop1) or state.spread_appearance[0]
    local between = tonumber(src.dop2 or src.dop3 or src.dop4 or src.dop5) or state.spread_between[0]
    state.spread_between[0] = between
    state.spread_enter[0] = tonumber(src.dop6) or state.spread_enter[0]

    state.smart_active[0] = as_bool(src.smart_active, state.smart_active[0])
    state.smart_threshold[0] = tonumber(src.smart_threshold) or state.smart_threshold[0]
    state.smart_far[0] = tonumber(src.smart_far) or state.smart_far[0]
    state.smart_close[0] = tonumber(src.smart_close) or state.smart_close[0]

    state.repeat_delay[0] = tonumber(src.repeat_delay) or state.repeat_delay[0]

    local chance = clamp_percent(src.mistake_chance, state.mistake_chance[0])
    local fix_raw = src.mistake_fix_chance
    if not fix_raw and src.mistake_ignore_chance ~= nil then
        fix_raw = 100 - (tonumber(src.mistake_ignore_chance) or 0)
    end
    local fix = clamp_percent(fix_raw, state.mistake_fix_chance[0])
    state.mistake_chance[0] = chance
    state.mistake_fix_chance[0] = fix
    state.mistake_backspace_delay[0] = tonumber(src.mistake_backspace_delay) or state.mistake_backspace_delay[0]
    state.mistake_correct_delay[0] = tonumber(src.mistake_correct_delay) or state.mistake_correct_delay[0]
    state.mistake_enabled[0] = as_bool(src.mistake_enabled, (state.mistake_enabled[0] or chance > 0))
end

local function build_profile_state(name)
    local source = config.captcha_profiles[name]
    local raw_chance = tonumber(source.mistake_chance) or 0
    if raw_chance < 0 then raw_chance = 0 elseif raw_chance > 100 then raw_chance = 100 end
    local fix_source = source.mistake_fix_chance
    if fix_source == nil and source.mistake_ignore_chance ~= nil then
        local legacy_ignore = tonumber(source.mistake_ignore_chance) or 0
        if legacy_ignore < 0 then legacy_ignore = 0 elseif legacy_ignore > 100 then legacy_ignore = 100 end
        fix_source = 100 - legacy_ignore
    end
    local raw_fix = tonumber(fix_source) or 0
    if raw_fix < 0 then raw_fix = 0 elseif raw_fix > 100 then raw_fix = 100 end
    return {
        mode = new.int(source.mode or 0),
        keyspoof_allow_extra = new.bool(source.keyspoof_allow_extra or false),
        auto_enter = new.bool(source.auto_enter or false),
        random_delay = new.bool(source.random_delay or false),
        var1 = new.int(source.var1 or 0),
        var2 = new.int(source.var2 or 0),
        var3 = new.int(source.var3 or 0),
        var4 = new.int(source.var4 or 0),
        var5 = new.int(source.var5 or 0),
        var6 = new.int(source.var6 or 0),
        spread_appearance = new.int(source.dop1 or 0),
        spread_between = new.int(source.dop2 or source.dop3 or source.dop4 or source.dop5 or 0),
        spread_enter = new.int(source.dop6 or 0),
        smart_active = new.bool(source.smart_active or false),
        smart_threshold = new.int(source.smart_threshold or 3),
        smart_far = new.int(source.smart_far or 30),
        smart_close = new.int(source.smart_close or 5),
        repeat_delay = new.int(source.repeat_delay or 0),
        mistake_chance = new.int(raw_chance),
        mistake_fix_chance = new.int(raw_fix),
        mistake_backspace_delay = new.int(source.mistake_backspace_delay or 80),
        mistake_correct_delay = new.int(source.mistake_correct_delay or 60),
        mistake_enabled = new.bool((source.mistake_enabled ~= nil) and source.mistake_enabled or (raw_chance > 0))
    }
end

local profiles = {}
for _, descriptor in ipairs(PROFILE_TABS) do
    profiles[descriptor.key] = build_profile_state(descriptor.key)
end

local function apply_captcha_set(name, opts)
    local set = config.captcha_sets[name]
    if not set then
        
        set = slot_storage.load(name)
        if set then
            config.captcha_sets[name] = set
        else
            return false
        end
    end
    for _, profile_name in ipairs(PROFILE_KEYS) do
        local payload = sanitize_profile_section(set[profile_name])
        config.captcha_profiles[profile_name] = clone_table(payload)
        config[PROFILE_STORAGE_PREFIX .. profile_name] = clone_table(payload)
        local state = profiles[profile_name]
        if state then
            hydrate_profile_state(state, payload)
        end
    end
    config.active_captcha_set = name
    sync_profiles_to_storage()
    if not (opts and opts.skip_save) then
        SaveConfig({ silent = true })
    end
    return true
end

local function save_active_captcha_set()
    SaveConfig({ silent = true })
    local slot = config.active_captcha_set or get_captcha_set_keys()[1]
    local slot_data = clone_table(config.captcha_profiles)
    config.captcha_sets[slot] = slot_data
    slot_storage.save(slot, slot_data)
    cfg_module.save({ silent = true })
end

local function copy_profile_timings(src_key, dst_key)
    local source = config.captcha_profiles[src_key]
    if not source then return end
    local payload = sanitize_profile_section(source)
    config.captcha_profiles[dst_key] = clone_table(payload)
    config[PROFILE_STORAGE_PREFIX .. dst_key] = clone_table(payload)
    local state = profiles[dst_key]
    if state then
        hydrate_profile_state(state, payload)
    end
    local slot = config.active_captcha_set or get_captcha_set_keys()[1]
    local slot_data = clone_table(config.captcha_profiles)
    config.captcha_sets[slot] = slot_data
    slot_storage.save(slot, slot_data)
    SaveConfig({ silent = true })
end

apply_captcha_set(config.active_captcha_set or get_captcha_set_keys()[1], { skip_save = true })

local profile_tab = new.int(1)
local autoprobiv_tab = new.int(1)  
local automation_hotkeys = config.automation_hotkeys

local count_buffers = {
    chat_rep = new.int(config.mcount.chat_rep or 1),
    time = new.int(config.mcount.time or 1),
    id = new.int(config.mcount.id or 1)
}

local auto_sequence = build_auto_sequence_from_config()
config.macro.sequence_order = table.concat(auto_sequence, ",")
config.macro.sequence = nil

local MENU_COMMAND_FALLBACK = "poel"
local MENU_COMMAND_ALT_FALLBACK = "poelmenu"
local TRAINING_COMMAND_FALLBACK = "ontr"

local function normalize_training_toggle_command(value)
    local command = tostring(value or ""):gsub("^%s*/+", ""):gsub("%s+", ""):gsub("[^%w_]", ""):lower()
    if #command > 24 then command = command:sub(1, 24) end
    if #command < 2 then command = TRAINING_COMMAND_FALLBACK end
    if command == MENU_COMMAND_FALLBACK then command = TRAINING_COMMAND_FALLBACK end
    return command
end

local function normalize_menu_command(value, training_command)
    local command = sanitize_chat_command(value)
    local reserved_training_command = normalize_training_toggle_command(
        training_command or (config and config.input and config.input.training_toggle_command)
    )
    if command == reserved_training_command then
        command = (reserved_training_command == MENU_COMMAND_FALLBACK) and MENU_COMMAND_ALT_FALLBACK or MENU_COMMAND_FALLBACK
    end
    return command
end

local cheat_code_active = config.input.cheat_code
local cheat_code_buffer = ffi.new('char[32]')
ffi.fill(cheat_code_buffer, 32, 0)
ffi.copy(cheat_code_buffer, cheat_code_active)

config.input.training_toggle_command = normalize_training_toggle_command(config.input.training_toggle_command)
config.input.menu_command = normalize_menu_command(config.input.menu_command, config.input.training_toggle_command)
local training_bind_requires_command = new.bool(config.input.training_bind_requires_command ~= false)
local training_toggle_command_buffer = ffi.new('char[32]')
ffi.fill(training_toggle_command_buffer, 32, 0)
ffi.copy(training_toggle_command_buffer, config.input.training_toggle_command)
local menu_cheat_enabled = new.bool(config.input.menu_cheat_enabled ~= false)
local menu_command_enabled = new.bool(config.input.menu_command_enabled ~= false)
local menu_command_buffer = ffi.new('char[32]')
ffi.fill(menu_command_buffer, 32, 0)
ffi.copy(menu_command_buffer, config.input.menu_command)
local registered_training_toggle_command = nil

local function toggle_training_bind_state()
    training_enabled = not training_enabled
    local style_cfg = state.get_training_style()
    if not style_cfg or style_cfg.force_bind_without_command then return end

    local status_message = training_enabled and style_cfg.enabled or style_cfg.disabled
    if status_message and status_message ~= "" then
        sampAddChatMessage(status_message, -1)
    end
end

local function update_training_chat_command_registration(command, enabled)
    if not isSampAvailable() then return end
    local should_enable = enabled ~= false

    if not should_enable then
        if registered_training_toggle_command then
            sampUnregisterChatCommand(registered_training_toggle_command)
            registered_training_toggle_command = nil
        end
        return
    end

    if registered_training_toggle_command == command then return end

    if registered_training_toggle_command then
        sampUnregisterChatCommand(registered_training_toggle_command)
        registered_training_toggle_command = nil
    end

    sampRegisterChatCommand(command, function()
        toggle_training_bind_state()
    end)
    registered_training_toggle_command = command
end

function update_menu_chat_command_registration(command, enabled)
    if not isSampAvailable() then return end
    if _G.__tc_registered_menu_command then
        sampUnregisterChatCommand(_G.__tc_registered_menu_command)
        _G.__tc_registered_menu_command = nil
    end
end

local function refresh_training_toggle_command(opts)
    opts = opts or {}
    local input_cfg = config.input or {}
    local desired_command = normalize_training_toggle_command(input_cfg.training_toggle_command)
    local command_changed = desired_command ~= input_cfg.training_toggle_command
    input_cfg.training_toggle_command = desired_command

    local normalized_menu_command = normalize_menu_command(input_cfg.menu_command, desired_command)
    local menu_command_changed = normalized_menu_command ~= input_cfg.menu_command
    input_cfg.menu_command = normalized_menu_command

    if command_changed then
        ffi.fill(training_toggle_command_buffer, 32, 0)
        ffi.copy(training_toggle_command_buffer, desired_command)
    end

    if menu_command_changed then
        ffi.fill(menu_command_buffer, 32, 0)
        ffi.copy(menu_command_buffer, normalized_menu_command)
    end

    local selected_style = state.get_training_style(input_cfg.training_style)
    local style_ignores_training_command = selected_style and selected_style.force_bind_without_command
    local should_register_training_command = (input_cfg.training_bind_requires_command ~= false) and not style_ignores_training_command
    update_training_chat_command_registration(desired_command, should_register_training_command)
    update_menu_chat_command_registration(normalized_menu_command, input_cfg.menu_command_enabled ~= false)

    if (command_changed or menu_command_changed) and opts.save_on_change then
        cfg_module.save({ silent = true })
    end
end

local function refresh_menu_command_registration(opts)
    opts = opts or {}
    local input_cfg = config.input or {}
    local desired_command = normalize_menu_command(input_cfg.menu_command, input_cfg.training_toggle_command)
    local command_changed = desired_command ~= input_cfg.menu_command
    input_cfg.menu_command = desired_command

    if command_changed then
        ffi.fill(menu_command_buffer, 32, 0)
        ffi.copy(menu_command_buffer, desired_command)
    end

    update_menu_chat_command_registration(desired_command, input_cfg.menu_command_enabled ~= false)

    if command_changed and opts.save_on_change then
        cfg_module.save({ silent = true })
    end
end

local function sync_config_to_ui(cfg)
    local theme = cfg.ui_theme or default_theme
    window_alpha[0] = tonumber(theme.alpha) or window_alpha[0]
    
    local nc = theme_colors.normalize_component
    col_accent[0], col_accent[1], col_accent[2] = nc(theme.accent_r), nc(theme.accent_g), nc(theme.accent_b)
    col_bg[0], col_bg[1], col_bg[2] = nc(theme.bg_r), nc(theme.bg_g), nc(theme.bg_b)

    cheat_code_active = sanitize_cheat_code(cfg.input and cfg.input.cheat_code)
    ffi.fill(cheat_code_buffer, 32, 0)
    ffi.copy(cheat_code_buffer, cheat_code_active)
    if _G.UI then _G.UI.cheat_code_active = cheat_code_active end

    local input_cfg = cfg.input or {}
    training_bind_requires_command[0] = input_cfg.training_bind_requires_command ~= false
    input_cfg.training_toggle_command = normalize_training_toggle_command(input_cfg.training_toggle_command)
    menu_cheat_enabled[0] = input_cfg.menu_cheat_enabled ~= false
    menu_command_enabled[0] = input_cfg.menu_command_enabled ~= false
    if not menu_cheat_enabled[0] and not menu_command_enabled[0] then
        menu_command_enabled[0] = true
    end
    input_cfg.menu_cheat_enabled = menu_cheat_enabled[0]
    input_cfg.menu_command_enabled = menu_command_enabled[0]
    input_cfg.menu_command = normalize_menu_command(input_cfg.menu_command, input_cfg.training_toggle_command)

    ffi.fill(training_toggle_command_buffer, 32, 0)
    ffi.copy(training_toggle_command_buffer, input_cfg.training_toggle_command)

    ffi.fill(menu_command_buffer, 32, 0)
    ffi.copy(menu_command_buffer, input_cfg.menu_command)
    refresh_training_toggle_command({ save_on_change = false })
    refresh_menu_command_registration({ save_on_change = false })

    local fx = cfg.postfx or {}
    enable_blur[0] = fx.blur ~= false
    blur_strength[0] = tonumber(fx.blur_strength) or blur_strength[0]
    rgb_enabled[0] = fx.rgb_enabled ~= false
    rgb_speed[0] = tonumber(fx.rgb_speed) or rgb_speed[0]
    rgb_brightness[0] = tonumber(fx.rgb_brightness) or rgb_brightness[0]
    rgb_thickness[0] = tonumber(fx.rgb_thickness) or rgb_thickness[0]
    rgb_rounding[0] = tonumber(fx.rgb_rounding) or rgb_rounding[0]
    winter_mode[0] = fx.winter_mode and true or false
    snow_count[0] = tonumber(fx.snow_count) or snow_count[0]
    snow_speed[0] = tonumber(fx.snow_speed) or snow_speed[0]
    snow_sway[0] = tonumber(fx.snow_sway) or snow_sway[0]
    snow_alpha[0] = tonumber(fx.snow_alpha) or snow_alpha[0]

    local col = cfg.collision or {}
    collision_toggle[0] = col.enabled and true or false
    collision_hotkey = tonumber(col.hotkey) or 0
    
    local fl = cfg.flooder or {}
    flooder_enabled[0] = fl.enabled and true or false
    flooder_delay[0] = tonumber(fl.interval_ms) or flooder_delay[0]
    flooder_hotkey = tonumber(fl.hotkey) or 0

    local m = cfg.macro or {}
    macro_ui.auto_chat[0] = m.chat_rep and true or false
    macro_ui.auto_time[0] = m.time and true or false
    macro_ui.auto_id[0] = m.id and true or false
    macro_ui.test_mode[0] = m.test_mode and true or false
    macro_ui.auto_delay_start[0] = tonumber(m.delay_start) or macro_ui.auto_delay_start[0]
    macro_ui.auto_delay_enter[0] = tonumber(m.delay_enter) or macro_ui.auto_delay_enter[0]
    macro_ui.auto_delay_enter_spread[0] = tonumber(m.delay_enter_spread) or macro_ui.auto_delay_enter_spread[0]
    macro_ui.auto_cmd_min[0] = tonumber(m.cmd_min) or macro_ui.auto_cmd_min[0]
    macro_ui.auto_cmd_max[0] = tonumber(m.cmd_max) or macro_ui.auto_cmd_max[0]
    macro_ui.auto_spread_active[0] = m.spread_active and true or false
    macro_ui.auto_spread_ms[0] = tonumber(m.spread_ms) or macro_ui.auto_spread_ms[0]
    macro_ui.auto_type_speed[0] = tonumber(m.type_speed) or macro_ui.auto_type_speed[0]
    macro_ui.auto_type_speed_spread[0] = tonumber(m.type_speed_spread) or macro_ui.auto_type_speed_spread[0]
    macro_ui.auto_errors_enabled[0] = m.allow_errors and true or false
    macro_ui.auto_error_chance[0] = tonumber(m.error_chance) or macro_ui.auto_error_chance[0]
    macro_ui.auto_error_fail_chance[0] = tonumber(m.error_fail_chance) or macro_ui.auto_error_fail_chance[0]

    local mc = cfg.mcount or {}
    count_buffers.chat_rep[0] = tonumber(mc.chat_rep) or count_buffers.chat_rep[0]
    count_buffers.time[0] = tonumber(mc.time) or count_buffers.time[0]
    count_buffers.id[0] = tonumber(mc.id) or count_buffers.id[0]

    auto_sequence = build_auto_sequence_from_config()
    cfg.macro.sequence_order = table.concat(auto_sequence, ",")
    cfg.macro.sequence = nil

    for _, action in ipairs(AUTOMATION_ACTIONS) do
        automation_hotkeys[action] = tonumber(cfg.automation_hotkeys and cfg.automation_hotkeys[action]) or 0
    end

    local ap = cfg.autoprobiv or {}
    autoprobiv.enabled[0] = ap.enabled and true or false
    autoprobiv.allow_training[0] = (ap.allow_training ~= false)
    autoprobiv.do_time[0] = (ap.do_time ~= false)
    autoprobiv.do_id[0] = (ap.do_id ~= false)
    autoprobiv.do_captcha[0] = (ap.do_captcha ~= false)
    autoprobiv.hotkey_all = tonumber(ap.hotkey_all or ap.hotkey) or 0
    autoprobiv.hotkey_time = tonumber(ap.hotkey_time) or 0
    autoprobiv.hotkey_id = tonumber(ap.hotkey_id) or 0
    autoprobiv.hotkey_captcha = tonumber(ap.hotkey_captcha) or 0
    autoprobiv.delay_min[0] = tonumber(ap.delay_between_min) or autoprobiv.delay_min[0]
    autoprobiv.delay_max[0] = tonumber(ap.delay_between_max) or autoprobiv.delay_max[0]
    autoprobiv.delay_before_start[0] = tonumber(ap.delay_before_start) or autoprobiv.delay_before_start[0]
    autoprobiv.delay_time[0] = tonumber(ap.delay_time) or autoprobiv.delay_time[0]
    autoprobiv.delay_id[0] = tonumber(ap.delay_id) or autoprobiv.delay_id[0]
    autoprobiv.delay_captcha[0] = tonumber(ap.delay_captcha) or autoprobiv.delay_captcha[0]
    autoprobiv.delay_random[0] = (ap.delay_random ~= false)
    autoprobiv.delay_random_spread[0] = tonumber(ap.delay_random_spread) or autoprobiv.delay_random_spread[0]
    autoprobiv.time_count[0] = tonumber(ap.time_count) or autoprobiv.time_count[0]
    autoprobiv.id_count[0] = tonumber(ap.id_count) or autoprobiv.id_count[0]
    autoprobiv.captcha_count[0] = tonumber(ap.captcha_count) or autoprobiv.captcha_count[0]
    autoprobiv.sequence = ap.sequence or autoprobiv.sequence
    ffi.copy(autoprobiv.sequence_buf, autoprobiv.sequence)
    autoprobiv.human_char_delay[0] = tonumber(ap.human_char_delay) or autoprobiv.human_char_delay[0]
    autoprobiv.human_char_spread[0] = tonumber(ap.human_char_spread) or autoprobiv.human_char_spread[0]
    autoprobiv.human_open_delay[0] = tonumber(ap.human_open_delay) or autoprobiv.human_open_delay[0]
    autoprobiv.human_open_spread[0] = tonumber(ap.human_open_spread) or autoprobiv.human_open_spread[0]
    autoprobiv.human_send_delay[0] = tonumber(ap.human_send_delay) or autoprobiv.human_send_delay[0]
    autoprobiv.auto_enter[0] = (ap.auto_enter ~= false)
    autoprobiv.human_errors_enabled[0] = (ap.human_errors_enabled ~= false)
    autoprobiv.human_error_chance[0] = tonumber(ap.human_error_chance) or autoprobiv.human_error_chance[0]
    autoprobiv.human_error_fail_chance[0] = tonumber(ap.human_error_fail_chance) or autoprobiv.human_error_fail_chance[0]

    local ks = cfg.chat_keyspoof or {}
    chat_keyspoof.hotkey_time = tonumber(ks.hotkey_time) or 0
    chat_keyspoof.hotkey_id = tonumber(ks.hotkey_id) or 0
    chat_keyspoof.hotkey_captcha = tonumber(ks.hotkey_captcha) or 0
    chat_keyspoof.auto_enter[0] = (ks.auto_enter ~= false)
    chat_keyspoof.auto_enter_delay[0] = tonumber(ks.auto_enter_delay) or chat_keyspoof.auto_enter_delay[0]
    chat_keyspoof.auto_enter_spread_enabled[0] = (ks.auto_enter_spread_enabled ~= false)
    chat_keyspoof.auto_enter_spread[0] = tonumber(ks.auto_enter_spread) or chat_keyspoof.auto_enter_spread[0]
    chat_keyspoof.errors_enabled[0] = ks.errors_enabled and true or false
    chat_keyspoof.error_chance[0] = tonumber(ks.error_chance) or chat_keyspoof.error_chance[0]
    chat_keyspoof.error_fail_chance[0] = tonumber(ks.error_fail_chance) or chat_keyspoof.error_fail_chance[0]

    aSave[0] = (cfg.core and cfg.core.auto_flush_logs) and true or false
end

local function sync_ui_to_config(cfg)
    local theme = cfg.ui_theme
    theme.accent_r = math.floor(col_accent[0] * 255)
    theme.accent_g = math.floor(col_accent[1] * 255)
    theme.accent_b = math.floor(col_accent[2] * 255)
    theme.bg_r = math.floor(col_bg[0] * 255)
    theme.bg_g = math.floor(col_bg[1] * 255)
    theme.bg_b = math.floor(col_bg[2] * 255)
    theme.alpha = window_alpha[0]

    cfg.input.cheat_code = sanitize_cheat_code(cfg.input.cheat_code or cheat_code_active)
    cheat_code_active = cfg.input.cheat_code
    if _G.UI then _G.UI.cheat_code_active = cheat_code_active end
    cfg.input.training_bind_requires_command = training_bind_requires_command[0]
    cfg.input.training_toggle_command = normalize_training_toggle_command(ffi.string(training_toggle_command_buffer))
    cfg.input.menu_cheat_enabled = menu_cheat_enabled[0]
    cfg.input.menu_command_enabled = menu_command_enabled[0]
    if not cfg.input.menu_cheat_enabled and not cfg.input.menu_command_enabled then
        cfg.input.menu_command_enabled = true
        menu_command_enabled[0] = true
    end
    cfg.input.menu_command = normalize_menu_command(ffi.string(menu_command_buffer), cfg.input.training_toggle_command)

    ffi.fill(training_toggle_command_buffer, 32, 0)
    ffi.copy(training_toggle_command_buffer, cfg.input.training_toggle_command)

    ffi.fill(menu_command_buffer, 32, 0)
    ffi.copy(menu_command_buffer, cfg.input.menu_command)
    refresh_training_toggle_command({ save_on_change = false })
    refresh_menu_command_registration({ save_on_change = false })

    do
        local macro_dst = cfg.macro
        local src = macro_ui
        local map = {
            { "id", src.auto_id },
            { "time", src.auto_time },
            { "chat_rep", src.auto_chat },
            { "test_mode", src.test_mode },
            { "cmd_min", src.auto_cmd_min },
            { "cmd_max", src.auto_cmd_max },
            { "delay_start", src.auto_delay_start },
            { "delay_enter", src.auto_delay_enter },
            { "delay_enter_spread", src.auto_delay_enter_spread },
            { "spread_active", src.auto_spread_active },
            { "spread_ms", src.auto_spread_ms },
            { "type_speed", src.auto_type_speed },
            { "type_speed_spread", src.auto_type_speed_spread },
            { "allow_errors", src.auto_errors_enabled },
            { "error_chance", src.auto_error_chance },
            { "error_fail_chance", src.auto_error_fail_chance }
        }
        for i = 1, #map do
            local row = map[i]
            macro_dst[row[1]] = row[2][0]
        end
        macro_dst.sequence_order = table.concat(auto_sequence, ",")
    end

    for _, action in ipairs(AUTOMATION_ACTIONS) do
        local value = tonumber(automation_hotkeys[action]) or 0
        if value < 0 or value > 255 then value = 0 end
        cfg.automation_hotkeys[action] = value
    end

    cfg.mcount.chat_rep = count_buffers.chat_rep[0]
    cfg.mcount.time = count_buffers.time[0]
    cfg.mcount.id = count_buffers.id[0]

    local postfx = cfg.postfx
    postfx.blur = enable_blur[0]
    postfx.blur_strength = blur_strength[0]
    postfx.rgb_enabled = rgb_enabled[0]
    postfx.rgb_speed = rgb_speed[0]
    postfx.rgb_brightness = rgb_brightness[0]
    postfx.rgb_thickness = rgb_thickness[0]
    postfx.rgb_rounding = rgb_rounding[0]
    postfx.winter_mode = winter_mode[0]
    postfx.snow_count = snow_count[0]
    postfx.snow_speed = snow_speed[0]
    postfx.snow_sway = snow_sway[0]
    postfx.snow_alpha = snow_alpha[0]

    cfg.collision.enabled = collision_toggle[0]
    cfg.collision.hotkey = collision_hotkey
    cfg.flooder.enabled = flooder_enabled[0]
    cfg.flooder.interval_ms = math.max(10, flooder_delay[0])
    cfg.flooder.hotkey = flooder_hotkey

    do
        local ap_dst = cfg.autoprobiv
        local ap = autoprobiv

        ap_dst.enabled = ap.enabled[0]
        ap_dst.allow_training = ap.allow_training[0]
        ap_dst.do_time = ap.do_time[0]
        ap_dst.do_id = ap.do_id[0]
        ap_dst.do_captcha = ap.do_captcha[0]

        ap_dst.hotkey_all = ap.hotkey_all
        ap_dst.hotkey_time = ap.hotkey_time
        ap_dst.hotkey_id = ap.hotkey_id
        ap_dst.hotkey_captcha = ap.hotkey_captcha

        ap_dst.sequence = ap.sequence or ffi.string(ap.sequence_buf)

        ap_dst.delay_between_min = math.max(10, ap.delay_min[0])
        ap_dst.delay_between_max = math.max(10, ap.delay_max[0])
        ap_dst.delay_before_start = math.max(0, ap.delay_before_start[0])
        ap_dst.delay_time = math.max(10, ap.delay_time[0])
        ap_dst.delay_id = math.max(10, ap.delay_id[0])
        ap_dst.delay_captcha = math.max(10, ap.delay_captcha[0])
        ap_dst.delay_random = ap.delay_random[0]
        ap_dst.delay_random_spread = math.max(0, ap.delay_random_spread[0])

        ap_dst.time_count = math.max(1, ap.time_count[0])
        ap_dst.id_count = math.max(1, ap.id_count[0])
        ap_dst.captcha_count = math.max(1, ap.captcha_count[0])

        ap_dst.human_char_delay = math.max(0, ap.human_char_delay[0])
        ap_dst.human_char_spread = math.max(0, ap.human_char_spread[0])
        ap_dst.human_open_delay = math.max(0, ap.human_open_delay[0])
        ap_dst.human_send_delay = math.max(0, ap.human_send_delay[0])
        ap_dst.auto_enter = ap.auto_enter[0]

        ap_dst.human_errors_enabled = ap.human_errors_enabled[0]
        ap_dst.human_error_chance = math.max(0, math.min(100, ap.human_error_chance[0]))
        ap_dst.human_error_fail_chance = math.max(0, math.min(100, ap.human_error_fail_chance[0]))
    end

    do
        local ks_dst = cfg.chat_keyspoof
        local ks = chat_keyspoof

        ks_dst.hotkey_time = ks.hotkey_time
        ks_dst.hotkey_id = ks.hotkey_id
        ks_dst.hotkey_captcha = ks.hotkey_captcha
        ks_dst.auto_enter = ks.auto_enter[0]
        ks_dst.auto_enter_delay = ks.auto_enter_delay[0]
        ks_dst.auto_enter_spread_enabled = ks.auto_enter_spread_enabled[0]
        ks_dst.auto_enter_spread = ks.auto_enter_spread[0]
        ks_dst.errors_enabled = ks.errors_enabled[0]
        ks_dst.error_chance = math.max(0, math.min(100, ks.error_chance[0]))
        ks_dst.error_fail_chance = math.max(0, math.min(100, ks.error_fail_chance[0]))
    end

    cfg.core.auto_flush_logs = aSave[0]
end

function LoadConfig(opts)
    opts = opts or {}
    sync_config_to_ui(config)
    for key, state in pairs(profiles) do
        local src = config.captcha_profiles and config.captcha_profiles[key]
        if src then
            hydrate_profile_state(state, src)
        end
    end
end

LoadConfig({ silent = true })

local BASE_WINDOW_WIDTH, BASE_WINDOW_HEIGHT = 800, 500
local MIN_UI_SCALE, MAX_UI_SCALE = 0.8, 1.3
local BASE_FONT_SCALE = 1.1
local ui_scale = 1.0

local function scale_value(value)
    value = value or 0
    local current_scale = (_G.UI and _G.UI.ui_scale) or ui_scale
    return value * current_scale
end

local function scale_imvec2(x, y)
    return imgui.ImVec2(scale_value(x or 0), scale_value(y or 0))
end

local function get_profile_by_tab()
    local descriptor = PROFILE_TABS[profile_tab[0]] or PROFILE_TABS[1]
    return profiles[descriptor.key], descriptor.key
end

keybind_capture = { active = false, id = nil, setter = nil }

local function begin_key_capture(id, setter)
    keybind_capture.active = true
    keybind_capture.id = id
    keybind_capture.setter = setter
end

local function cancel_key_capture()
    keybind_capture.active = false
    keybind_capture.id = nil
    keybind_capture.setter = nil
end


local function set_hotkey(category, action, keycode)
    keycode = tonumber(keycode) or 0
    if keycode < 0 or keycode > 255 then keycode = 0 end
    if category == "automation" then
        automation_hotkeys[action] = keycode
    elseif category == "collision" then
        collision_hotkey = keycode
        config.collision.hotkey = keycode
    elseif category == "flooder" then
        flooder_hotkey = keycode
        config.flooder.hotkey = keycode
    elseif category == "autoprobiv" then
        if action == "all" then
            autoprobiv.hotkey_all = keycode
            config.autoprobiv.hotkey_all = keycode
        elseif action == "time" then
            autoprobiv.hotkey_time = keycode
            config.autoprobiv.hotkey_time = keycode
        elseif action == "id" then
            autoprobiv.hotkey_id = keycode
            config.autoprobiv.hotkey_id = keycode
        elseif action == "captcha" then
            autoprobiv.hotkey_captcha = keycode
            config.autoprobiv.hotkey_captcha = keycode
        end
    end
    cfg_module.save({ silent = true })
end


local function parse_probiv_sequence()
    local seq = autoprobiv.sequence or "time,id,captcha"
    local result = {}
    for token in seq:gmatch("[^,%s]+") do
        token = token:lower():match("^%s*(.-)%s*$")
        if token == "time" or token == "id" or token == "captcha" then
            table.insert(result, token)
        end
    end
    if #result == 0 then
        result = {"time", "id", "captcha"}
    end
    return result
end

function set_autoprobiv_sequence(list)
    local sanitized, seen = {}, {}
    for _, token in ipairs(list or {}) do
        token = type(token) == "string" and token:lower() or nil
        if (token == "time" or token == "id" or token == "captcha") and not seen[token] then
            table.insert(sanitized, token)
            seen[token] = true
        end
    end
    for _, token in ipairs({"time", "id", "captcha"}) do
        if not seen[token] then table.insert(sanitized, token) end
    end

    local seq = table.concat(sanitized, ",")
    autoprobiv.sequence = seq
    ffi.copy(autoprobiv.sequence_buf, seq)
    config.autoprobiv.sequence = seq
    cfg_module.save({ silent = true })
end


local function build_autoprobiv_cache()
    ensure_rng_seed()

    local cache = {}
    cache.delay_min = math.max(10, autoprobiv.delay_min[0])
    cache.delay_max = math.max(10, autoprobiv.delay_max[0])
    if cache.delay_min > cache.delay_max then cache.delay_min, cache.delay_max = cache.delay_max, cache.delay_min end

    cache.delay_before_start = math.max(0, autoprobiv.delay_before_start[0])
    cache.delay_time = math.max(10, autoprobiv.delay_time[0])
    cache.delay_id = math.max(10, autoprobiv.delay_id[0])
    cache.delay_captcha = math.max(10, autoprobiv.delay_captcha[0])
    local spreads_enabled = autoprobiv.delay_random[0]
    cache.delay_random = spreads_enabled
    cache.delay_random_spread = spreads_enabled and math.max(0, autoprobiv.delay_random_spread[0]) or 0

    cache.do_time = autoprobiv.do_time[0]
    cache.do_id = autoprobiv.do_id[0]
    cache.do_captcha = autoprobiv.do_captcha[0]
    cache.time_count = math.max(1, autoprobiv.time_count[0])
    cache.id_count = math.max(1, autoprobiv.id_count[0])
    cache.captcha_count = math.max(1, autoprobiv.captcha_count[0])
    cache.sequence = parse_probiv_sequence()

    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    cache.myId = myId
    cache.captcha = captcha_state.get_remembered_for_probiv()

    cache.human_char_delay = math.max(10, autoprobiv.human_char_delay[0])
    cache.human_char_spread = spreads_enabled and math.max(0, autoprobiv.human_char_spread[0]) or 0
    cache.human_open_delay = math.max(0, autoprobiv.human_open_delay[0])
    cache.human_open_spread = spreads_enabled and math.max(0, autoprobiv.human_open_spread[0]) or 0
    cache.human_send_delay = math.max(0, autoprobiv.human_send_delay[0])
    
    local enter_spread_enabled = chat_keyspoof.auto_enter_spread_enabled[0]
    cache.human_send_delay_spread = enter_spread_enabled and math.max(0, chat_keyspoof.auto_enter_spread[0]) or 0
    cache.auto_enter = autoprobiv.auto_enter[0]

    cache.errors_enabled = autoprobiv.human_errors_enabled[0]
    cache.error_chance = math.max(0, math.min(100, autoprobiv.human_error_chance[0]))
    cache.error_fail_chance = math.max(0, math.min(100, autoprobiv.human_error_fail_chance[0]))

    return cache
end

local function autoprobiv_allowed(is_training)
    if not autoprobiv.enabled[0] then return false end
    if is_training and not autoprobiv.allow_training[0] then return false end
    return true
end

function autoprobiv.schedule_after_captcha(is_training)
    if not autoprobiv_allowed(is_training) then return end
    local key = is_training and "training" or "server"
    local clocks = autoprobiv.trigger_clock or { server = 0, training = 0 }
    autoprobiv.trigger_clock = clocks
    local now = os.clock()
    local last_time = clocks[key] or 0
    local cooldown = autoprobiv.trigger_cooldown or 0.0

    if (now - last_time) < cooldown then
        return
    end

    clocks[key] = now
    if autoprobiv.pending or autoprobiv.running then
        return
    end

    autoprobiv.pending = true
end

local probiv_actions = {}

local function create_local_samp_api()
    return probiv_runner.create_samp_api(
        isSampAvailable,
        sampIsChatInputActive,
        sampIsDialogActive,
        sampSetChatInputEnabled,
        sampSetChatInputText,
        sampSendChat,
        function() return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) end
    )
end

probiv_actions.time = function()
    local samp_api = create_local_samp_api()
    if not probiv_runner.can_run(samp_api) then return end
    local cache = build_autoprobiv_cache()
    if not cache then return end
    lua_thread.create(function()
        with_chat_blocked(function()
            probiv_runner.send_time(cache, samp_api, wait)
        end)
    end)
end

probiv_actions.id = function()
    local samp_api = create_local_samp_api()
    if not probiv_runner.can_run(samp_api) then return end
    local cache = build_autoprobiv_cache()
    if not cache or not cache.myId then return end
    lua_thread.create(function()
        with_chat_blocked(function()
            probiv_runner.send_id(cache, samp_api, wait)
        end)
    end)
end

probiv_actions.captcha = function()
    local samp_api = create_local_samp_api()
    if not probiv_runner.can_run(samp_api) then return end
    local cache = build_autoprobiv_cache()
    if not cache or not cache.captcha or #cache.captcha == 0 then return end
    lua_thread.create(function()
        with_chat_blocked(function()
            probiv_runner.send_captcha(cache, samp_api, wait)
        end)
    end)
end


local function detect_server_captcha()
    if not sampIsDialogActive() or sorted then return false end
    local dialog_id = sampGetCurrentDialogId()
    if is_active_training_dialog(dialog_id) then return false end

    white_box_tds = {}
    dark_box_tds = {}
    dark_numbers = {}
    numbers = {}
    bg1, bg2 = 0, 0

    for i = S_CONST.TD_SCAN_START, S_CONST.TD_BG_SCAN_END do
        local td = _G[i..'td']
        if td and td.lineWidth > S_CONST.BG_WIDTH_MIN and td.lineWidth < S_CONST.BG_WIDTH_MAX 
           and td.lineHeight > S_CONST.BG_HEIGHT_MIN and td.lineHeight < S_CONST.BG_HEIGHT_MAX then
            if bg1 == 0 then bg1 = i end
            if bg2 == 0 and i ~= bg1 then bg2 = i end
        end
    end

    for i = S_CONST.TD_SCAN_START, S_CONST.TD_SCAN_END do
        if sampTextdrawIsExists(i) and i > S_CONST.TD_SCAN_START and i ~= bg1 and i ~= bg2 then
            local str = sampTextdrawGetString(i)
            if str:find('white') then
                table.insert(white_box_tds, i)
            elseif str:find('usebox') then
                table.insert(dark_box_tds, i)
            end
        end
    end

    local darkXs = {}
    for _, v in pairs(dark_box_tds) do
        local darkx = sampTextdrawGetPos(v)
        local exists = false
        for _, b in pairs(darkXs) do
            if b.sizex == darkx then exists = true break end
        end
        if not exists then
            table.insert(darkXs, { id = v, sizex = darkx })
        end
    end
    table.sort(darkXs, function(a, b) return a.sizex < b.sizex end)

    for i = 1, #darkXs do
        if i <= 5 then
            local darkx, darky = sampTextdrawGetPos(darkXs[i].id)
            local _, _, darksx, darksy = sampTextdrawGetBoxEnabledColorAndSize(darkXs[i].id)
            local _, darkletY = sampTextdrawGetLetterSizeAndColor(darkXs[i].id)
            local darkx2, darky2 = darkx - darksx, darkletY * 10 + 1
            darkx = darkx + (darksx - darkx) + 2
            darky = darky - 2.5
            darkx2 = darkx2 - 3.9
            darkx, darky = convertGameScreenCoordsToWindowScreenCoords(darkx, darky)
            darkx2, darky2 = convertGameScreenCoordsToWindowScreenCoords(darkx2, darky2)
            numbers[i] = { x1 = darkx, y1 = darky, x2 = darkx2, y2 = darky2 }
        end
    end

    for k, v in pairs(dark_box_tds) do
        local darkx, darky = sampTextdrawGetPos(v)
        local _, _, darksx, darksy = sampTextdrawGetBoxEnabledColorAndSize(v)
        local _, darkletY = sampTextdrawGetLetterSizeAndColor(v)
        local darkx2, darky2 = darkx - darksx, darkletY * 10 + 1
        darkx = darkx + (darksx - darkx) + 2
        darky = darky - 2.5
        darkx2 = darkx2 - 3.9
        dark_numbers[k] = { id = v, x1 = darkx, y1 = darky, x2 = darkx2, y2 = darky2 }
    end

    local detection_complete = false
    if captcha_geometry_ready(darkXs) then
        dots_create()
        if dots and #dots >= CAPTCHA_LENGTH then
            for num = 1, CAPTCHA_LENGTH do
                for dot = 1, 7 do
                    if dots[num] and dots[num][dot] then
                        dots_res[num][dot] = check_cap(dots[num][dot].x, dots[num][dot].y)
                    end
                end
            end

            local captcha_digits = {}
            for num = 1, CAPTCHA_LENGTH do
                captcha_digits[num] = recognize_digit(dots_res[num])
            end
            captchaS0, captchaS1, captchaS2, captchaS3, captchaS4 = captcha_digits[1], captcha_digits[2], captcha_digits[3], captcha_digits[4], captcha_digits[5]
            captcha_state.set_detected_digits(captchaS0, captchaS1, captchaS2, captchaS3, captchaS4)
            detection_complete = true
        end
    end

    if detection_complete then
        sorted = true
        return true
    end
    return false
end


local function run_autoprobiv()
    if autoprobiv.running then 
        return 
    end
    
    local samp_api = probiv_runner.create_samp_api(
        isSampAvailable,
        sampIsChatInputActive,
        sampIsDialogActive,
        sampSetChatInputEnabled,
        sampSetChatInputText,
        sampSendChat,
        function() return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) end
    )
    
    if not probiv_runner.can_run(samp_api) then
        return
    end
    
    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    
    local cache = probiv_runner.build_cache(
        autoprobiv,
        ffi.string(autoprobiv.sequence_buf),
        captcha_state.get_remembered_for_probiv(),
        myId
    )
    
    if not cache then
        return
    end

    autoprobiv.running = true
    
    lua_thread.create(function()
        with_chat_blocked(function()
            local ok, err = pcall(function()
                probiv_runner.run_sequence(cache, samp_api, wait)
            end)
            if not ok then return end
        end)
        autoprobiv.running = false
    end)
end


local digit_masks_multi = {
    [0] = {
        {1, 0, 1, 0, 1, 0, 1},  
        {1, 1, 1, 0, 1, 1, 1},  
        {1, 0, 1, 0, 0, 0, 1},  
    },
    [1] = {
        {0, 0, 0, 0, 0, 0, 0},  
        {0, 1, 0, 1, 0, 1, 0},  
    },
    [2] = {
        {0, 1, 1, 1, 1, 1, 0},  
        {0, 1, 1, 1, 0, 1, 0},  
        {0, 1, 0, 1, 1, 1, 0},  
    },
    [3] = {
        {0, 1, 1, 1, 0, 1, 1},  
        {0, 1, 0, 1, 0, 1, 1},  
        {0, 1, 1, 0, 0, 1, 1},  
    },
    [4] = {
        {1, 0, 1, 1, 0, 0, 1},  
        {1, 0, 1, 1, 0, 1, 1},  
        {0, 0, 1, 1, 0, 0, 0},  
        {1, 0, 0, 1, 0, 0, 1},  
    },
    [5] = {
        {1, 1, 0, 1, 0, 1, 1},  
        {0, 1, 0, 1, 0, 1, 1},  
        {1, 1, 0, 1, 0, 1, 0},  
    },
    [6] = {
        {1, 1, 0, 1, 1, 1, 1},  
        {1, 0, 0, 1, 0, 1, 1},  
        {1, 1, 0, 1, 1, 1, 0},  
    },
    [7] = {
        {0, 1, 1, 0, 0, 0, 1},  
        {0, 1, 1, 0, 0, 1, 1},  
        {0, 1, 0, 0, 0, 0, 0},  
        {0, 1, 1, 0, 0, 0, 0},  
    },
    [8] = {
        {1, 1, 1, 1, 1, 1, 1},  
        {1, 1, 0, 1, 1, 1, 1},  
        {1, 1, 1, 0, 1, 1, 1},  
        {1, 1, 1, 1, 0, 1, 1},  
    },
    [9] = {
        {1, 1, 1, 1, 0, 1, 1},  
        {1, 1, 1, 0, 0, 1, 1},  
        {1, 1, 0, 1, 0, 1, 1},  
        {0, 1, 1, 1, 0, 1, 0},  
    },
}


local digit_priority = {
    [1] = 1,   
    [7] = 2,   
    [2] = 3,   
    [4] = 4,   
    [0] = 5,   
    [3] = 6,   
    [5] = 7,   
    [6] = 8,   
    [9] = 9,   
    [8] = 10,  
}


function recognize_digit(dots_result)
    local best_digit = 0
    local best_score = 7
    local best_priority = 999
    
    for digit, masks in pairs(digit_masks_multi) do
        local priority = digit_priority[digit]
        for _, mask in ipairs(masks) do
            local diff = 0
            if (mask[1] == 1) ~= (dots_result[1] or false) then diff = diff + 1 end
            if (mask[2] == 1) ~= (dots_result[2] or false) then diff = diff + 1 end
            if (mask[3] == 1) ~= (dots_result[3] or false) then diff = diff + 1 end
            if (mask[4] == 1) ~= (dots_result[4] or false) then diff = diff + 1 end
            if (mask[5] == 1) ~= (dots_result[5] or false) then diff = diff + 1 end
            if (mask[6] == 1) ~= (dots_result[6] or false) then diff = diff + 1 end
            if (mask[7] == 1) ~= (dots_result[7] or false) then diff = diff + 1 end
            
            if diff < best_score or (diff == best_score and priority < best_priority) then
                best_score = diff
                best_digit = digit
                best_priority = priority
            end
        end
    end
    
    return best_digit, best_score
end

function getSmartAdditionalDelay(profile, prev_digit, curr_digit)
    if not profile.smart_active[0] then return 0 end
    local diff = math.abs(curr_digit - prev_digit)
    if diff > profile.smart_threshold[0] then
        return profile.smart_far[0]
    else
        return profile.smart_close[0]
    end
end

local function getRepeatAdditionalDelay(profile, prev_digit, curr_digit)
    if not profile.repeat_delay or profile.repeat_delay[0] <= 0 then return 0 end
    if prev_digit == nil or curr_digit == nil then return 0 end
    if tostring(prev_digit) == tostring(curr_digit) then
        return profile.repeat_delay[0]
    end
    return 0
end

local function generate_mistake_plan(profile_state, text)
    ensure_rng_seed()
    local plan = {}
    
    if not profile_state or not profile_state.mistake_enabled or not profile_state.mistake_enabled[0] then
        return plan
    end
    
    local chance = clamp_percent(profile_state.mistake_chance and profile_state.mistake_chance[0], 0)
    if chance <= 0 or not text or #text == 0 then
        return plan
    end
    
    local fix_chance = clamp_percent(profile_state.mistake_fix_chance and profile_state.mistake_fix_chance[0], 0)
    
    local making_errors = (math.random(100) <= chance)
    
    for pos = 1, #text do
        if not making_errors then
            break
        end
        
        local correct_char = text:sub(pos, pos)
        local wrong_char = typo.random_char(correct_char)
        if wrong_char and wrong_char ~= correct_char then
            local will_fix = fix_chance > 0 and math.random(100) <= fix_chance
            plan[pos] = {
                wrong = wrong_char,
                correct = correct_char,
                fix = will_fix
            }
        end
        
        making_errors = (math.random(100) <= chance)
    end
    
    return plan
end

local function apply_profile_mistake_plan(profile_key, profile_state, base_text)
    local state = profile_mistake_state[profile_key]
    if not state then
        state = { attempted = false, plan = nil }
        profile_mistake_state[profile_key] = state
    end
    
    local feature_enabled = profile_state and profile_state.mistake_enabled and profile_state.mistake_enabled[0]
    if not feature_enabled then
        state.attempted = false
        state.plan = nil
        return base_text, nil
    end
    
    local chance = clamp_percent(profile_state.mistake_chance and profile_state.mistake_chance[0], 0)
    if chance <= 0 then
        state.attempted = false
        state.plan = nil
        return base_text, nil
    end
    
    if not state.attempted then
        state.plan = generate_mistake_plan(profile_state, base_text)
        state.attempted = true
    end
    
    return base_text, state.plan
end

function SaveConfig(opts)
    opts = opts or {}
    local silent = opts.silent or false
    local cfg = config
    sync_ui_to_config(cfg)
    local function persist_profile(key, state)
        local target = cfg.captcha_profiles[key]
        local int_fields = {
            { "mode", state.mode },
            { "var1", state.var1 },
            { "var2", state.var2 },
            { "var3", state.var3 },
            { "var4", state.var4 },
            { "var5", state.var5 },
            { "var6", state.var6 },
            { "smart_threshold", state.smart_threshold },
            { "smart_far", state.smart_far },
            { "smart_close", state.smart_close },
            { "repeat_delay", state.repeat_delay }
        }
        for i = 1, #int_fields do
            local row = int_fields[i]
            target[row[1]] = row[2][0]
        end

        local bool_fields = {
            { "keyspoof_allow_extra", state.keyspoof_allow_extra },
            { "auto_enter", state.auto_enter },
            { "random_delay", state.random_delay },
            { "smart_active", state.smart_active }
        }
        for i = 1, #bool_fields do
            local row = bool_fields[i]
            target[row[1]] = row[2][0]
        end

        target.dop1 = state.spread_appearance[0]
        local spread_between = state.spread_between[0]
        target.dop2, target.dop3, target.dop4, target.dop5 = spread_between, spread_between, spread_between, spread_between
        target.dop6 = state.spread_enter[0]

        local chance = clamp_percent(state.mistake_chance[0], 0)
        local fix = clamp_percent(state.mistake_fix_chance[0], 0)
        target.mistake_chance = chance
        target.mistake_fix_chance = fix
        target.mistake_ignore_chance = 100 - fix
        target.mistake_backspace_delay = state.mistake_backspace_delay[0]
        target.mistake_correct_delay = state.mistake_correct_delay[0]
        target.mistake_enabled = state.mistake_enabled[0]

        cfg[PROFILE_STORAGE_PREFIX .. key] = clone_table(target)
    end

    for key, state in pairs(profiles) do
        persist_profile(key, state)
    end

    sync_profiles_to_storage()

    local active_slot = cfg.active_captcha_set or get_captcha_set_keys()[1]
    local slot_data = clone_table(cfg.captcha_profiles)
    cfg.captcha_sets[active_slot] = slot_data
    slot_storage.save(active_slot, slot_data)

    local server_profile = profiles.server
    cfg.keyspoof.allow_extra = server_profile.keyspoof_allow_extra[0]
    cfg.core.optimization_level = server_profile.mode[0]
    cfg.network.packet_loss_fix = server_profile.auto_enter[0]
    cfg.rendering.dynamic_resolution = server_profile.random_delay[0]

    cfg.rendering.draw_distance_lod0 = server_profile.var1[0]
    cfg.memory.page_file_min = server_profile.var2[0]
    cfg.rendering.shadow_cascade_1 = server_profile.var3[0]
    cfg.debug.trace_interval = server_profile.var4[0]
    cfg.rendering.particle_density = server_profile.var5[0]
    cfg.network.ping_threshold = server_profile.var6[0]

    cfg.memory.garbage_collector_jitter = server_profile.spread_appearance[0]
    local spread_between = server_profile.spread_between[0]
    cfg.debug.error_reporting_bias = spread_between
    cfg.memory.stack_allocation_bias = server_profile.spread_enter[0]
    cfg.debug.log_rotation_offset = spread_between
    cfg.memory.vram_limit_percent = spread_between
    cfg.network.buffer_bloat_fix = server_profile.spread_enter[0]

    cfg.smart_delay.active = server_profile.smart_active[0]
    cfg.smart_delay.threshold = server_profile.smart_threshold[0]
    cfg.smart_delay.far = server_profile.smart_far[0]
    cfg.smart_delay.close = server_profile.smart_close[0]

    local saved = cfg_module.save({ silent = true })

    -- ñîõðàíÿåì íàñòðîéêè âèðòóàëüíîé êëàâèàòóðû è ÷åêáîêñîâ
    local ahk_extra = {
        test = {
            virtual_input  = virtual_input_enabled and virtual_input_enabled[0] or false,
            klava_vsya     = klava_vsya and klava_vsya[0] or false,
            ahk_kb_selected = ahk_kb_selected and ahk_kb_selected[0] or 0,
            v_chat         = v_chat_enabled and v_chat_enabled[0] or false,
        },
        kb = {
            rounding     = ahk_kb_cfg and ahk_kb_cfg.rounding[0] or false,
            show_border  = ahk_kb_cfg and ahk_kb_cfg.show_border[0] or true,
            alpha        = ahk_kb_cfg and ahk_kb_cfg.alpha[0] or 0.95,
            key_size     = ahk_kb_cfg and ahk_kb_cfg.key_size[0] or 1.0,
            color_preset = ahk_kb_cfg and ahk_kb_cfg.color_preset[0] or 0,
            custom_r     = ahk_kb_cfg and ahk_kb_cfg.custom_r[0] or 0.15,
            custom_g     = ahk_kb_cfg and ahk_kb_cfg.custom_g[0] or 0.45,
            custom_b     = ahk_kb_cfg and ahk_kb_cfg.custom_b[0] or 1.0,
            bg_r         = ahk_kb_cfg and ahk_kb_cfg.bg_r[0] or 0.08,
            bg_g         = ahk_kb_cfg and ahk_kb_cfg.bg_g[0] or 0.08,
            bg_b         = ahk_kb_cfg and ahk_kb_cfg.bg_b[0] or 0.08,
            border_r     = ahk_kb_cfg and ahk_kb_cfg.border_r[0] or 0.35,
            border_g     = ahk_kb_cfg and ahk_kb_cfg.border_g[0] or 0.35,
            border_b     = ahk_kb_cfg and ahk_kb_cfg.border_b[0] or 0.35,
            border_alpha = ahk_kb_cfg and ahk_kb_cfg.border_alpha[0] or 0.9,
        }
    }
    inicfg.save(ahk_extra, "keyboard")

    if not saved then
        if not silent then
            notifications:show(u8"Íå óäàëîñü ñîõðàíèòü íàñòðîéêè", theme_colors.notification.error())
        end
    elseif not silent then
        notifications:show(u8"Íàñòðîéêè ñîõðàíåíû", theme_colors.notification.success())
    end
end

local function reset_profile_mistake_state(profile_key)
    local state = profile_mistake_state[profile_key]
    if state then
        state.attempted = false
        state.mutated_text = nil
    end
end

local function dialog_is_still_active(target_id)
    return target_id ~= nil and sampIsDialogActive() and sampGetCurrentDialogId() == target_id
end

function run_ahk_simulation(dlg_id, profile_key)
    local state_key = profile_key or "server"
    local profile = profiles[state_key] or profiles.server
    reset_profile_mistake_state(state_key)
    lua_thread.create(function()
        local function dialog_alive()
            return dialog_is_still_active(dlg_id)
        end
        if profile.mode[0] == 1 then 
            ensure_rng_seed()
            local v1, v2, v3, v4, v5, v6 = profile.var1[0], profile.var2[0], profile.var3[0], profile.var4[0], profile.var5[0], profile.var6[0]
            
            if profile.random_delay[0] then
                local function spread(val, spread_ptr)
                    if not spread_ptr then return val end
                    local r = spread_ptr[0] or 0
                    if r == 0 then return val end
                    local rnd = math.random(-r, r)
                    return math.max(0, val + rnd)
                end
                local appearance = profile.spread_appearance
                local between = profile.spread_between
                local enter = profile.spread_enter
                v1 = spread(v1, appearance)
                v2 = spread(v2, between)
                v3 = spread(v3, between)
                v4 = spread(v4, between)
                v5 = spread(v5, between)
                v6 = spread(v6, enter)
            end
            
            wait(v1)
            if not dialog_alive() then return end
            
            local function interval_delay(base_delay, prev_digit, next_digit)
                local total = base_delay + getSmartAdditionalDelay(profile, prev_digit, next_digit) + getRepeatAdditionalDelay(profile, prev_digit, next_digit)
                if total < 0 then total = 0 end
                return total
            end
            
            local wait_start = os.clock()
            local max_wait = 2.0
            while captchaS0 == nil and (os.clock() - wait_start) < max_wait do
                wait(10)
                if not dialog_alive() then return end
            end

            if captchaS0 ~= nil then
                local cap = string.format("%s%s%s%s%s", captchaS0, captchaS1, captchaS2, captchaS3, captchaS4)
                local final_cap, mistake_plan = apply_profile_mistake_plan(state_key, profile, cap)
                mistake_plan = mistake_plan or {}
                
                local typed_digits = {}
                for idx = 1, #final_cap do
                    typed_digits[idx] = tonumber(final_cap:sub(idx, idx)) or 0
                end

                local function get_digit(idx)
                    return typed_digits[idx] or typed_digits[#typed_digits] or 0
                end

                local digit_delays = { v2, v3, v4, v5 }
                local backspace_delay = profile.mistake_backspace_delay and profile.mistake_backspace_delay[0] or 80
                local correct_delay = profile.mistake_correct_delay and profile.mistake_correct_delay[0] or 60
                if not dialog_alive() then return end
                
                local total_delay = v2 + v3 + v4 + v5
                local has_mistakes = false
                for _, m in pairs(mistake_plan) do
                    if m then has_mistakes = true break end
                end
                
                if total_delay == 0 and not has_mistakes then
                    if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                        for i = 1, #final_cap do VKI.highlight(final_cap:sub(i,i)) end
                    end
                    sampSetCurrentDialogEditboxText(final_cap)
                else
                    local current_text = ""
                    for stage = 1, #final_cap do
                        local char = final_cap:sub(stage, stage)
                        local mistake = mistake_plan[stage]
                        
                        if mistake then
                            if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight(mistake.wrong) end
                            current_text = current_text .. mistake.wrong
                            sampSetCurrentDialogEditboxText(current_text)
                            
                            if mistake.fix then
                                if backspace_delay > 0 then wait(backspace_delay) end
                                if not dialog_alive() then return end
                                if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight("back") end
                                current_text = current_text:sub(1, -2)
                                sampSetCurrentDialogEditboxText(current_text)
                                if correct_delay > 0 then wait(correct_delay) end
                                if not dialog_alive() then return end
                                if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight(mistake.correct) end
                                current_text = current_text .. mistake.correct
                                sampSetCurrentDialogEditboxText(current_text)
                            end
                        else
                            if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight(char) end
                            current_text = current_text .. char
                            sampSetCurrentDialogEditboxText(current_text)
                        end
                        
                        if stage < #final_cap then
                            local base_delay = digit_delays[stage] or 0
                            local total_interval = interval_delay(base_delay, get_digit(stage), get_digit(stage + 1))
                            if total_interval > 0 then
                                wait(total_interval)
                                if not dialog_alive() then return end
                            end
                        end
                    end
                end
                
                local actual_result = ""
                for pos = 1, #final_cap do
                    local mistake = mistake_plan[pos]
                    if mistake and not mistake.fix then
                        actual_result = actual_result .. mistake.wrong
                    else
                        actual_result = actual_result .. final_cap:sub(pos, pos)
                    end
                end

                wait(v6)
                if not dialog_alive() then return end
                remember_captcha(actual_result, cap)
                
                if profile.auto_enter[0] then
                    if not dialog_alive() then return end
                    if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight("enter") end
                    sampSendDialogResponse(dlg_id, 1, "", actual_result)
                    sampCloseCurrentDialogWithButton(1)
                    
                    
                    if autoprobiv_allowed(state_key == "training") then
                        wait(50) 
                        autoprobiv.schedule_after_captcha(state_key == "training")
                    end
                end
            end
        end
    end)
end

function Training_Clear()
    if training_t > 0 then
        for i = 1, training_t do
            local td_id = training_td_offset + i
            if sampTextdrawIsExists(td_id) then
                sampTextdrawDelete(td_id)
            end
        end
    end

    training_t = 0
    training_str = ''
    training_captime = nil
    training_state = false
    training_active_style = get_selected_training_style()
    training_active_style_index = get_selected_training_style_index()
    training_active_dialog_id = (training_active_style and training_active_style.dialog_id) or training_dialog_id
    keyspoof_tails["training"] = ""
    reset_profile_mistake_state("training")
end

local function Training_GenTD_Classic(id, PosX, PosY)
    local t_id = training_td_offset + training_t
    if id == 0 then
        training_t = training_t + 1
        t_id = training_td_offset + training_t
        sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - 5, PosY + 7)
        sampTextdrawSetLetterSizeAndColor(t_id, 0, 3, 0x80808080)
        sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX + 5, 0.000000)
    elseif id == 1 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local offsetX, offsetBX = (i == 0) and 3 or -3, (i == 0) and 15 or -15
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 4.5, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 2 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local offsetX = (i == 0) and -8 or 6
            local offsetY = (i == 0) and 7 or 25
            local offsetBX = (i == 0) and 15 or -15
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 0.8, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 3 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size, offsetY = (i == 0) and 0.8 or 1, (i == 0) and 7 or 25
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX + 10, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 1, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - 15, 0.000000)
        end
    elseif id == 4 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size, offsetX, offsetY, offsetBX
            if i == 0 then
                size = 1.8
                offsetX = -10
                offsetY = 0
                offsetBX = 10
            else
                size = 2
                offsetX = -10
                offsetY = 25
                offsetBX = 15
            end
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 5 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size = (i == 0) and 0.8 or 1
            local offsetX = (i == 0) and 8 or -10
            local offsetY = (i == 0) and 7 or 25
            local offsetBX = (i == 0) and -15 or 15
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 6 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size = (i == 0) and 0.8 or 1
            local offsetX = (i == 0) and 7.5 or -10
            local offsetY = (i == 0) and 7 or 25
            local offsetBX = (i == 0) and -15 or 10
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 7 then
        training_t = training_t + 1
        t_id = training_td_offset + training_t
        sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - 13, PosY + 7)
        sampTextdrawSetLetterSizeAndColor(t_id, 0, 3.75, 0x80808080)
        sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX + 5, 0.000000)
    elseif id == 8 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size, offsetY = (i == 0) and 0.8 or 1, (i == 0) and 7 or 25
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX + 10, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 1, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - 10, 0.000000)
        end
    elseif id == 9 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size = (i == 0) and 0.8 or 1
            local offsetY = (i == 0) and 6 or 25
            local offsetBX = (i == 0) and 10 or 15
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX + 10, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 1, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    end
end

local function Training_GenTD_Shapez(id, PosX, PosY)
    local t_id = training_td_offset + training_t
    if id == 0 then
        training_t = training_t + 1
        t_id = training_td_offset + training_t
        sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - 5, PosY + 5)
        sampTextdrawSetLetterSizeAndColor(t_id, 0, utils.randf(3.0, 4.0), 0x80808080)
        sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX + 8, 0.000000)
    elseif id == 1 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local offsetX, offsetBX
            if i == 0 then
                offsetX = 2
                offsetBX = 17
            else
                offsetX = -3
                offsetBX = -17
            end
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 5.7, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 2 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local offsetX, offsetY, offsetBX
            if i == 0 then
                offsetX = -8
                offsetY = 8
                offsetBX = 16
            else
                offsetX = 8
                offsetY = 28
                offsetBX = -15
            end
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, 0.85, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 3 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size = (i == 0) and 1.1 or 1.3
            local offsetY = (i == 0) and 6 or 25
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX + 10, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - 16.5, 0.000000)
        end
    elseif id == 4 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size, offsetX, offsetY, offsetBX
            if i == 0 then
                size = 1.6
                offsetX = -10
                offsetY = 0
                offsetBX = 7
            else
                size = 2.75
                offsetX = -10
                offsetY = 25
                offsetBX = 16
            end
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 5 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size, offsetX, offsetY, offsetBX
            if i == 0 then
                size = 0.8
                offsetX = 6
                offsetY = 7
                offsetBX = -15
            else
                size = 1.2
                offsetX = -10
                offsetY = 26
                offsetBX = 16
            end
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 6 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size, offsetX, offsetY, offsetBX
            if i == 0 then
                size = 1
                offsetX = 7.5
                offsetY = 7
                offsetBX = -15
            else
                size = 1.1
                offsetX = -10
                offsetY = utils.randf(27.0, 29.0)
                offsetBX = 10
            end
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - offsetX, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    elseif id == 7 then
        training_t = training_t + 1
        t_id = training_td_offset + training_t
        sampTextdrawCreate(t_id, "LD_SPAC:white", PosX - 14, PosY + 6)
        sampTextdrawSetLetterSizeAndColor(t_id, 0, 5.1, 0x80808080)
        sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX + 7, 0.000000)
    elseif id == 8 then
        local sizefor8 = utils.randf(8.0, 9.0)
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size = (i == 0) and 1.275 or 1.2
            local offsetY = (i == 0) and 8 or 28
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX + sizefor8, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - 6, 0.000000)
        end
    elseif id == 9 then
        for i = 0, 1 do
            training_t = training_t + 1
            t_id = training_td_offset + training_t
            local size = (i == 0) and 1.25 or 1.275
            local offsetY = (i == 0) and 7 or 26
            local offsetBX = (i == 0) and 7 or 16
            sampTextdrawCreate(t_id, "LD_SPAC:white", PosX + 7, PosY + offsetY)
            sampTextdrawSetLetterSizeAndColor(t_id, 0, size, 0x80808080)
            sampTextdrawSetBoxColorAndSize(t_id, 1, 0xFF759DA3, PosX - offsetBX, 0.000000)
        end
    end
end

function Training_GenTD(id, PosX, PosY, render_kind)
    if render_kind == "shapez" then
        Training_GenTD_Shapez(id, PosX, PosY)
    else
        Training_GenTD_Classic(id, PosX, PosY)
    end
end

local function reset_keyspoof_state(profile_key)
        keyspoof_tails[profile_key] = ""
        kolvokapchi = 0
    reset_profile_mistake_state(profile_key)
end

function Training_Show()
    Training_Clear()
    training_state = true

    local style = get_selected_training_style()
    local render_kind = style and style.render_kind or "classic"
    training_active_style = style
    training_active_style_index = get_selected_training_style_index()
    training_active_dialog_id = (style and style.dialog_id) or training_dialog_id
    
    if render_kind == "shapez" then
        training_t = training_t + 1
        sampTextdrawCreate(training_td_offset + training_t, "LD_SPAC:white", 240, 124)
        sampTextdrawSetLetterSizeAndColor(training_td_offset + training_t, 0, 7.3, 0x80808080)
        sampTextdrawSetBoxColorAndSize(training_td_offset + training_t, 1, 0xFF1A2432, 404, 0.000000)

        training_t = training_t + 1
        sampTextdrawCreate(training_td_offset + training_t, "LD_SPAC:white", 242, 127)
        sampTextdrawSetLetterSizeAndColor(training_td_offset + training_t, 0, 6.5, 0x80808080)
        sampTextdrawSetBoxColorAndSize(training_td_offset + training_t, 1, 0xFF759DA3, 400, 0.000000)
    else
        training_t = training_t + 1
        sampTextdrawCreate(training_td_offset + training_t, "LD_SPAC:white", 220, 120)
        sampTextdrawSetLetterSizeAndColor(training_td_offset + training_t, 0, 6.5, 0x80808080)
        sampTextdrawSetBoxColorAndSize(training_td_offset + training_t, 1, 0xFF1A2432, 380, 0.000000)

        training_t = training_t + 1
        sampTextdrawCreate(training_td_offset + training_t, "LD_SPAC:white", 225, 125)
        sampTextdrawSetLetterSizeAndColor(training_td_offset + training_t, 0, 5.5, 0x80808080)
        sampTextdrawSetBoxColorAndSize(training_td_offset + training_t, 1, 0xFF759DA3, 375, 0.000000)
    end

    local nextPos = (render_kind == "shapez") and utils.randf(-30.5, -29.5) or -30.0
    local gen_table = {}
    training_str = ""
    ensure_rng_seed()
    
    for _ = 1, 4 do local a = math.random(0, 9); table.insert(gen_table, a); training_str = training_str..a end
    captchaS0 = gen_table[1]; captchaS1 = gen_table[2]; captchaS2 = gen_table[3]; captchaS3 = gen_table[4]; captchaS4 = 0 
    
    for i = 0, 4 do
        if render_kind == "shapez" then
            nextPos = nextPos + utils.randf(29.5, 30.5)
        else
            nextPos = nextPos + 30
        end
        training_t = training_t + 1
        local td_id = training_td_offset + training_t
        local box_pos_x = (render_kind == "shapez") and (259 + nextPos) or (240 + nextPos)
        local box_pos_y = (render_kind == "shapez") and 131 or 130
        sampTextdrawCreate(td_id, "usebox", box_pos_x, box_pos_y)
        if render_kind == "shapez" then
            sampTextdrawSetLetterSizeAndColor(td_id, 0, utils.randf(5.0, 5.3), 0x80808080)
            sampTextdrawSetBoxColorAndSize(td_id, 1, 0xFF1A2432, 30, utils.randf(25.0, 26.5))
        else
            sampTextdrawSetLetterSizeAndColor(td_id, 0, 4.5, 0x80808080)
            sampTextdrawSetBoxColorAndSize(td_id, 1, 0xFF1A2432, 30, 25.000000)
        end
        sampTextdrawSetAlign(td_id, 2)
        if i < 4 then
            Training_GenTD(gen_table[i + 1], box_pos_x, box_pos_y, render_kind)
        else
            Training_GenTD(0, box_pos_x, box_pos_y, render_kind)
        end
    end

    local dialog_title = (style and style.dialog_title) or '{F89168}Òðåíèðîâêà êàï÷è'
    local dialog_text = (style and style.dialog_text) or '{FFFFFF}Ââåäèòå {C6FB4A}5{FFFFFF} ñèìâîëîâ, êîòîðûå\nâèäíî íà {C6FB4A}âàøåì{FFFFFF} ýêðàíå.'
    local dialog_button1 = (style and style.dialog_button1) or 'Ïðèíÿòü'
    local dialog_button2 = (style and style.dialog_button2) or 'Îòìåíà'
    local dialog_style = (style and style.dialog_style) or 1

    sampShowDialog(training_active_dialog_id, dialog_title, dialog_text, dialog_button1, dialog_button2, dialog_style)
    training_captime = os.clock()
    reset_keyspoof_state("training")
    reset_profile_mistake_state("training")
    captcha_state.start("training", training_active_dialog_id)
    captcha_state.set_detected_digits(captchaS0, captchaS1, captchaS2, captchaS3, captchaS4)
    run_ahk_simulation(training_active_dialog_id, "training")
end

local function closeTrainingDialogIfNeeded()
    if sampIsDialogActive() and is_active_training_dialog(sampGetCurrentDialogId()) then
        sampCloseCurrentDialogWithButton(0)
    end
end

local function reset_tooltip_state()
    if not anims then return end
    anims.tooltip_alpha = 0
    anims.tooltip_text = ""
end

setMenuState = function(state)
    if renderWindow[0] == state then return end
    renderWindow[0] = state
    window_state.target_alpha = state and 1.0 or 0.0
    if state then
        training_menu_lock = true
        if training_state then Training_Clear() end
        closeTrainingDialogIfNeeded()
    else
        training_menu_lock = false
        reset_tooltip_state()
    end
end

function consume_hotkey_key(keycode)
    if not keycode or keycode <= 0 then return end
    if type(consumeKeyJustPressed) == 'function' then
        consumeKeyJustPressed(keycode)
    end
    if type(consumeKeyDown) == 'function' then
        consumeKeyDown(keycode)
    end
    if type(consumeKeyUp) == 'function' then
        consumeKeyUp(keycode)
    end
end

local FLOODER_CEF_PAYLOAD = "mountain.testDrive.selectVehicle|0"
local VIDEO_CARD_DIALOG_MARKER = "ïîêóïêà âèäåîêàðòû"
local VIDEO_CARD_TEXT_MARKER = "âû õîòèòå êóïèòü âèäåîêàðòó"
local VIDEO_CARD_DIALOG_ID = 25242

local flooder_runtime = {
    running = false,
    thread = nil,
    buying = false
}

local flooder_helpers = {}

flooder_helpers.send_cef = function(payload)
    if not payload then return end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #payload)
    raknetBitStreamWriteString(bs, payload)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

flooder_helpers.lower_cp1251 = utils.lower_cp1251

flooder_helpers.normalize_dialog_text = function(value)
    if type(value) ~= 'string' then return '' end
    local sanitized = value:gsub("{.-}", "")
    return flooder_helpers.lower_cp1251(sanitized)
end

flooder_helpers.is_video_card_dialog = function(dialog_id, title, text)
    if dialog_id ~= VIDEO_CARD_DIALOG_ID then return false end
    local normalized_title = flooder_helpers.normalize_dialog_text(title)
    if normalized_title:find(VIDEO_CARD_DIALOG_MARKER) then return true end
    local normalized_text = flooder_helpers.normalize_dialog_text(text)
    if normalized_text:find(VIDEO_CARD_TEXT_MARKER) then return true end
    return false
end

flooder_helpers.press_dialog_enter = function(dialog_id)
    if not dialog_id then return end
    lua_thread.create(function()
        wait(0)
        if sampIsDialogActive() and sampGetCurrentDialogId() == dialog_id then
            sampSendDialogResponse(dialog_id, 1, 0, "")
            sampCloseCurrentDialogWithButton(1)
        end
    end)
end

function flooder_helpers.start_buy_loop(dialog_id)
    if flooder_runtime.buying then return end
    flooder_runtime.buying = true
    lua_thread.create(function()
        wait(0)
        while flooder_enabled[0] do
            if not sampIsDialogActive() or sampGetCurrentDialogId() ~= dialog_id then break end
            sampSendDialogResponse(dialog_id, 1, 0, "")
            sampCloseCurrentDialogWithButton(1)
            wait(math.max(CONST.FLOODER_INTERVAL_MIN, flooder_delay[0]))
        end
        flooder_runtime.buying = false
    end)
end

function flooder_helpers.start_loop()
    if flooder_runtime.running then return end
    flooder_runtime.running = true
    flooder_runtime.thread = lua_thread.create(function()
        while flooder_runtime.running do
            wait(math.max(CONST.FLOODER_INTERVAL_MIN, flooder_delay[0]))
            if flooder_enabled[0] and isSampAvailable() then
                flooder_helpers.send_cef(FLOODER_CEF_PAYLOAD)
            end
        end
        flooder_runtime.thread = nil
    end)
end

function flooder_helpers.stop_loop()
    if not flooder_runtime.running then return end
    flooder_runtime.running = false
end

local function setup_flooder(state)
    local enabled = state and true or false
    flooder_enabled[0] = enabled
    config.flooder.enabled = enabled
    if enabled then
        flooder_helpers.start_loop()
        if sampIsDialogActive() then
            local dialog_id = sampGetCurrentDialogId()
            if flooder_helpers.is_video_card_dialog(dialog_id, dtitle, dtext) then
                flooder_helpers.press_dialog_enter(dialog_id)
                flooder_helpers.start_buy_loop(dialog_id)
            end
        end
    else
        flooder_helpers.stop_loop()
        flooder_runtime.buying = false
    end
end

local function setPedCollisionState(disabled)
    local state = not disabled
    for _, handle in ipairs(getAllChars()) do
        if handle ~= PLAYER_PED and doesCharExist(handle) then
            setCharCollision(handle, state)
        end
    end
end

local collision_runtime = { active = false, last_update = 0.0, interval = CONST.COLLISION_INTERVAL }

local function disable_keyspoof_with_notice(msg_color)
    if chat_keyspoof.mode then
        chat_keyspoof.mode = nil
        chat_keyspoof.char_count = 0
        notifications:show(msg_color.text, msg_color.color)
    end
end

local function handle_autoprobiv_hotkeys()
    local hk = autoprobiv
    local bindings = {
        { key = hk.hotkey_all,     msg = u8"àâòî-ïðîáèâ", action = run_autoprobiv },
        { key = hk.hotkey_time,    msg = u8"/time",       action = probiv_actions.time },
        { key = hk.hotkey_id,      msg = u8"/id",         action = probiv_actions.id },
        { key = hk.hotkey_captcha, msg = u8"êàï÷à",       action = probiv_actions.captcha },
    }
    for _, b in ipairs(bindings) do
        if b.key and b.key > 0 and isKeyJustPressed(b.key) then
            disable_keyspoof_with_notice({ text = u8"KeySpoof âûêëþ÷åí (çàïóùåí " .. b.msg .. ")", color = theme_colors.notification.warning() })
            b.action()
            return
        end
    end
end

local function handle_chat_keyspoof_hotkeys()
    local ks = chat_keyspoof
    if ks._wm_toggled then
        ks._wm_toggled = false
        return
    end
    local function is_printable_vk(vk)
        if not vk or vk <= 0 then return false end
        if vk >= 0x30 and vk <= 0x39 then return true end  -- 0-9
        if vk >= 0x41 and vk <= 0x5A then return true end  -- A-Z
        if vk >= 0x60 and vk <= 0x69 then return true end  -- Numpad 0-9
        if vk == 0x20 then return true end                 -- Space
        if vk >= 0xBA and vk <= 0xC0 then return true end  -- OEM punctuation
        if vk >= 0xDB and vk <= 0xDF then return true end  -- OEM brackets/quote
        return false
    end
    local function toggle(mode, key_vk)
        if ks.mode == mode then
            ks.mode, ks.char_count = nil, 0
            chat_keyspoof_clear_errors()
        else
            ks.mode, ks.char_count = mode, 0
            if is_printable_vk(key_vk) then
                ks.suppress_next_char = true
            end
            generate_keyspoof_error_plan()
        end
    end
    
    local bindings = {
        { key = ks.hotkey_time, mode = "time" },
        { key = ks.hotkey_id,   mode = "id" },
    }
    for _, b in ipairs(bindings) do
        if b.key and b.key > 0 and isKeyJustPressed(b.key) then
            toggle(b.mode, b.key)
            return
        end
    end
    
    if ks.hotkey_captcha and ks.hotkey_captcha > 0 and isKeyJustPressed(ks.hotkey_captcha) then
        if ks.mode == "captcha" then
            toggle("captcha", ks.hotkey_captcha)
        elseif (captcha_state.get_remembered_for_probiv() or "") ~= "" then
            toggle("captcha", ks.hotkey_captcha)
        end
    end
end

local function handle_misc_hotkeys()
    local bindings = {
        { key = flooder_hotkey,   block_chat = true,  block_dialog = false, action = function() setup_flooder(not flooder_enabled[0]) end },
        { key = collision_hotkey, block_chat = true,  block_dialog = true,  action = function() collision_toggle[0] = not collision_toggle[0] end },
    }
    for _, b in ipairs(bindings) do
        if b.key and b.key > 0 and isKeyJustPressed(b.key) then
            if b.block_chat and sampIsChatInputActive() then break end
            if b.block_dialog and sampIsDialogActive() then break end
            b.action()
            return
        end
    end
end

local function reset_captcha_session(profile_key)
    for i = S_CONST.TD_CLEAR_START, S_CONST.TD_CLEAR_END do _G[i..'td'] = nil end
    captcha_td_ids, white_box_tds, dark_box_tds, dark_numbers = {}, {}, {}, {}
    numbers = {
        {x1 = 0, y1 = 0, x2 = 0, y2 = 0},
        {x1 = 0, y1 = 0, x2 = 0, y2 = 0},
        {x1 = 0, y1 = 0, x2 = 0, y2 = 0},
        {x1 = 0, y1 = 0, x2 = 0, y2 = 0},
        {x1 = 0, y1 = 0, x2 = 0, y2 = 0}
    }
    sorted = false
    kolvokapchi = 0
    local key = profile_key or "server"
    keyspoof_tails[key] = ""
    reset_profile_mistake_state(key)
    captcha_state.reset(key)
    state.reset_keyspoof(key)
end

function dots_create()
    if not numbers or #numbers < 5 then dots = {}; return end
    dots = {
        {{x = numbers[1].x1 + 3, y = numbers[1].y1 + numbers[1].y2 / 4}, {x = numbers[1].x1 + numbers[1].x2 / 2, y = numbers[1].y1 + 3}, {x = numbers[1].x1 + numbers[1].x2 - 3, y = numbers[1].y1 + numbers[1].y2 / 4}, {x = numbers[1].x1 + numbers[1].x2 / 2, y = numbers[1].y1 + numbers[1].y2 / 2 - 1}, {x = numbers[1].x1 + 3, y = numbers[1].y1 + numbers[1].y2 / 4 * 3 - 6}, {x = numbers[1].x1 + numbers[1].x2 / 2, y = numbers[1].y1 + numbers[1].y2 - 6}, {x = numbers[1].x1 + numbers[1].x2 - 3, y = numbers[1].y1 + numbers[1].y2 / 4 * 3 - 6}},
        {{x = numbers[2].x1 + 3, y = numbers[2].y1 + numbers[2].y2 / 4}, {x = numbers[2].x1 + numbers[2].x2 / 2, y = numbers[2].y1 + 3}, {x = numbers[2].x1 + numbers[2].x2 - 3, y = numbers[2].y1 + numbers[2].y2 / 4}, {x = numbers[2].x1 + numbers[2].x2 / 2, y = numbers[2].y1 + numbers[2].y2 / 2 - 1}, {x = numbers[2].x1 + 3, y = numbers[2].y1 + numbers[2].y2 / 4 * 3 - 6}, {x = numbers[2].x1 + numbers[2].x2 / 2, y = numbers[2].y1 + numbers[2].y2 - 6}, {x = numbers[2].x1 + numbers[2].x2 - 3, y = numbers[2].y1 + numbers[2].y2 / 4 * 3 - 6}},
        {{x = numbers[3].x1 + 3, y = numbers[3].y1 + numbers[3].y2 / 4}, {x = numbers[3].x1 + numbers[3].x2 / 2, y = numbers[3].y1 + 3}, {x = numbers[3].x1 + numbers[3].x2 - 3, y = numbers[3].y1 + numbers[3].y2 / 4}, {x = numbers[3].x1 + numbers[3].x2 / 2, y = numbers[3].y1 + numbers[3].y2 / 2 - 1}, {x = numbers[3].x1 + 3, y = numbers[3].y1 + numbers[3].y2 / 4 * 3 - 6}, {x = numbers[3].x1 + numbers[3].x2 / 2, y = numbers[3].y1 + numbers[3].y2 - 6}, {x = numbers[3].x1 + numbers[3].x2 - 3, y = numbers[3].y1 + numbers[3].y2 / 4 * 3 - 6}},
        {{x = numbers[4].x1 + 3, y = numbers[4].y1 + numbers[4].y2 / 4}, {x = numbers[4].x1 + numbers[4].x2 / 2, y = numbers[4].y1 + 3}, {x = numbers[4].x1 + numbers[4].x2 - 3, y = numbers[4].y1 + numbers[4].y2 / 4}, {x = numbers[4].x1 + numbers[4].x2 / 2, y = numbers[4].y1 + numbers[4].y2 / 2 - 1}, {x = numbers[4].x1 + 3, y = numbers[4].y1 + numbers[4].y2 / 4 * 3 - 6}, {x = numbers[4].x1 + numbers[4].x2 / 2, y = numbers[4].y1 + numbers[4].y2 - 6}, {x = numbers[4].x1 + numbers[4].x2 - 3, y = numbers[4].y1 + numbers[4].y2 / 4 * 3 - 6}},
        {{x = numbers[5].x1 + 3, y = numbers[5].y1 + numbers[5].y2 / 4}, {x = numbers[5].x1 + numbers[5].x2 / 2, y = numbers[5].y1 + 3}, {x = numbers[5].x1 + numbers[5].x2 - 3, y = numbers[5].y1 + numbers[5].y2 / 4}, {x = numbers[5].x1 + numbers[5].x2 / 2, y = numbers[5].y1 + numbers[5].y2 / 2 - 1}, {x = numbers[5].x1 + 3, y = numbers[5].y1 + numbers[5].y2 / 4 * 3 - 6}, {x = numbers[5].x1 + numbers[5].x2 / 2, y = numbers[5].y1 + numbers[5].y2 - 6}, {x = numbers[5].x1 + numbers[5].x2 - 3, y = numbers[5].y1 + numbers[5].y2 / 4 * 3 - 6}}
    }
    dots_res = {{false,false,false,false,false,false,false},{false,false,false,false,false,false,false},{false,false,false,false,false,false,false},{false,false,false,false,false,false,false},{false,false,false,false,false,false,false}}
end

function check_cap(mousex, mousey)
    local mouse_id, dark_id, result = 0, 0, false
    for k, v in pairs(white_box_tds) do
        local tx1, ty1 = sampTextdrawGetPos(v)
        local _,_,sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(v)
        local tx2, ty2 = convertGameScreenCoordsToWindowScreenCoords(tx1 + sizeX, ty1 + sizeY)
        tx1, ty1 = convertGameScreenCoordsToWindowScreenCoords(tx1, ty1)
        if mousex >= tx1 and mousey >= ty1 and mousex <= tx2 and mousey <= ty2 then mouse_id = v end
    end
    if mouse_id ~= 0 then 
        for k, v in pairs(dark_numbers) do 
            local tx2, ty2 = convertGameScreenCoordsToWindowScreenCoords(v.x1 + v.x2, v.y1 + v.y2)
            local tx1, ty1 = convertGameScreenCoordsToWindowScreenCoords(v.x1, v.y1)
            if mousex >= tx1 and mousey >= ty1 and mousex <= tx2 and mousey <= ty2 then dark_id = v.id end
        end
    else result = true end
    if mouse_id ~= 0 and dark_id ~= 0 then if mouse_id > dark_id then result = false else result = true end end
    return result
end


function bringFloatTo(current, target, speed, dt)
    return utils.lerp(current, target, speed, dt)
end

function imgui.LinkColorToConfig()
    return imgui.ImVec4(col_accent[0], col_accent[1], col_accent[2], 1.0), 
           imgui.ImVec4(col_bg[0], col_bg[1], col_bg[2], window_alpha[0]) 
end

function imgui.HandleTooltip(text)
    if not renderWindow[0] then
        reset_tooltip_state()
        return
    end
    if imgui.IsItemHovered() then
        anims.tooltip_text = text
        anims.tooltip_alpha = bringFloatTo(anims.tooltip_alpha, 1.0, 10, imgui.GetIO().DeltaTime)
    end
end

function imgui.RenderTooltip()
    if not renderWindow[0] then
        reset_tooltip_state()
        return
    end
    if anims.tooltip_alpha > 0.01 then
        if not imgui.IsAnyItemHovered() then
             anims.tooltip_alpha = bringFloatTo(anims.tooltip_alpha, 0.0, 10, imgui.GetIO().DeltaTime)
        end
        if anims.tooltip_alpha > 0.01 then
            local p = imgui.GetIO().MousePos
            local dl = imgui.GetForegroundDrawList()
            local text = u8(anims.tooltip_text)
            local txt_size = imgui.CalcTextSize(text)
            local pad, offset = 8, 15
            local tooltip_alpha = math.max(0.0, math.min(1.0, anims.tooltip_alpha * 1.35))
            local bg_col = U32(imgui.ImVec4(0.1, 0.1, 0.12, tooltip_alpha))
            local border_col = U32(imgui.ImVec4(col_accent[0], col_accent[1], col_accent[2], tooltip_alpha))
            local text_col = U32(imgui.ImVec4(1, 1, 1, tooltip_alpha))
            dl:AddRectFilled(imgui.ImVec2(p.x + offset, p.y + offset), imgui.ImVec2(p.x + offset + txt_size.x + pad*2, p.y + offset + txt_size.y + pad*2), bg_col, 5)
            dl:AddRect(imgui.ImVec2(p.x + offset, p.y + offset), imgui.ImVec2(p.x + offset + txt_size.x + pad*2, p.y + offset + txt_size.y + pad*2), border_col, 5)
            dl:AddText(imgui.ImVec2(p.x + offset + pad, p.y + offset + pad), text_col, text)
        end
    end
end

function render_toggle_block(defs)
    for _, def in ipairs(defs) do
        local prev = def.ptr[0]
        imgui.CustomToggle(def.label, def.ptr, def.desc)
        if def.on_change and prev ~= def.ptr[0] then
            def.on_change(def.ptr[0])
        end
        if def.after then def.after() end
    end
end

ui_render = {
    color_dim = nil
}

function ui_render.get_dim_color()
    if not ui_render.color_dim then
        ui_render.color_dim = imgui.ImVec4(1, 1, 1, 0.6)
    end
    return ui_render.color_dim
end

function ui_render.radio_group(target_ptr, options, spacing)
    local gap = spacing or 0
    for idx, def in ipairs(options) do
        if imgui.CustomRadioButton(def.label, target_ptr[0] == def.value, def.desc) then
            target_ptr[0] = def.value
        end
        if def.after then def.after() end
        if gap > 0 and idx < #options then
            imgui.Dummy(scale_imvec2(0, gap))
        end
    end
end

function ui_render.slider_group(entries, default_color)
    local color = default_color or ui_render.get_dim_color()
    for _, def in ipairs(entries) do
        if def.condition and not def.condition() then goto continue end
        if def.space_before then imgui.Dummy(scale_imvec2(0, def.space_before)) end
        imgui.TextColored(def.color or color, u8(def.label))
        imgui.CustomSlider(def.id, def.ptr, def.min, def.max, def.suffix or "", def.desc)
        if def.after then def.after() end
        ::continue::
    end
end

function ui_render.keybind_group(defs, width)
    local item_width = width or scale_value(140)
    imgui.PushItemWidth(item_width)
    for _, def in ipairs(defs) do
        local opts = def.opts or { id = def.id, allow_clear = def.allow_clear ~= false, description = def.desc }
        local handler = def.setter
        if not handler and def.category then
            handler = function(k) set_hotkey(def.category, def.action, k) end
        end
        if handler then
            imgui.CustomKeybind(def.label, def.ptr, handler, opts)
        end
    end
    imgui.PopItemWidth()
end


flooder_helpers.render_tabs_row = function()
    local fade = current_fade_alpha or 1.0
    imgui.Dummy(scale_imvec2(0, 5))
    for idx, descriptor in ipairs(PROFILE_TABS) do
        if idx > 1 then imgui.SameLine() end
        local selected = (profile_tab[0] == idx)
        local label = string.format("%s##profile_tab_%d", descriptor.label, idx)
        if selected then
            local accent = imgui.ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.9 * fade)
            imgui.PushStyleColor(imgui.Col.Button, accent)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, accent)
            imgui.PushStyleColor(imgui.Col.ButtonActive, accent)
        end
        if imgui.Button(label, scale_imvec2(190, 32)) then
            profile_tab[0] = idx
        end
        if selected then
            imgui.PopStyleColor(3)
        end
    end
    imgui.Dummy(scale_imvec2(0, 10))
end

flooder_helpers.get_profile_for_dialog = function(dialog_id)
    if is_active_training_dialog(dialog_id) then
        return profiles.training, "training"
    end
    return profiles.server, "server"
end

flooder_helpers.trim_keyspoof_tail = function(profile_key)
    local required = math.max(0, kolvokapchi - CAPTCHA_LENGTH)
    local tail = keyspoof_tails[profile_key] or ""
    if #tail > required then
        keyspoof_tails[profile_key] = tail:sub(1, required)
    end
end


profile_helpers = flooder_helpers


flooder_helpers.snow_fx = {}

flooder_helpers.snow_fx.randf = utils.randf

flooder_helpers.snow_fx.to_imvec2_buffer = function(points)
    local count = #points
    if count < 3 then return nil, 0 end
    local buffer = ffi.new("ImVec2[?]", count)
    for i = 0, count - 1 do
        local point = points[i + 1]
        buffer[i].x = point.x
        buffer[i].y = point.y
    end
    return buffer, count
end

flooder_helpers.snow_fx.reset_snowflake = function(pool, idx, bounds, opts)
    local flake = pool[idx] or {}
    flake.x = bounds.x + flooder_helpers.snow_fx.randf(-bounds.w * 0.1, bounds.w * 1.1)
    flake.y = bounds.y - flooder_helpers.snow_fx.randf(0, bounds.h * 0.3)
    flake.speed = flooder_helpers.snow_fx.randf(opts.speed_min, opts.speed_max)
    flake.size = flooder_helpers.snow_fx.randf(opts.size_min, opts.size_max)
    flake.phase = flooder_helpers.snow_fx.randf(0, math.pi * 2)
    pool[idx] = flake
    return flake
end

flooder_helpers.snow_fx.render_snow_layer = function(pool, draw_list, bounds, opts, dt)
    for i = 1, opts.count do
        local flake = pool[i]
        if not flake then
            flake = flooder_helpers.snow_fx.reset_snowflake(pool, i, bounds, opts)
        end
        local drift = math.sin((os.clock() * opts.drift_speed) + flake.phase) * opts.drift_strength
        flake.x = flake.x + drift * dt * 60
        flake.y = flake.y + flake.speed * dt
        if flake.y > bounds.y + bounds.h + 30 or flake.x < bounds.x - 40 or flake.x > bounds.x + bounds.w + 40 then
            flake = flooder_helpers.snow_fx.reset_snowflake(pool, i, bounds, opts)
        end
        pool[i] = flake
        draw_list:AddCircleFilled(imgui.ImVec2(flake.x, flake.y), flake.size, opts.color)
    end
end

flooder_helpers.snow_fx.render_winter_drifts = function(draw_list, win_pos, win_size, alpha)
    local fade = alpha or 1.0
    local color = U32(imgui.ImVec4(1, 1, 1, 0.18 * fade))
    local bottom_y = win_pos.y + win_size.y - scale_value(4)
    local lumps = {
        { x = win_pos.x + scale_value(24), y = bottom_y, width = scale_value(120), height = scale_value(22), direction = -1 },
        { x = win_pos.x + win_size.x - scale_value(180), y = bottom_y + scale_value(3), width = scale_value(150), height = scale_value(17), direction = -1 },
        { x = win_pos.x + win_size.x * 0.3, y = bottom_y - scale_value(2), width = scale_value(95), height = scale_value(15), direction = -1 }
    }

    local segments = 6
    for _, drift in ipairs(lumps) do
        local points = {}
        for i = 0, segments do
            local t = i / segments
            local x = drift.x + drift.width * t
            local wave = math.sin(t * math.pi) * drift.height
            local y = drift.y + (wave * drift.direction)
            points[#points + 1] = imgui.ImVec2(x, y)
        end
        points[#points + 1] = imgui.ImVec2(drift.x + drift.width, drift.y)
        points[#points + 1] = imgui.ImVec2(drift.x, drift.y)
        local poly_buffer, poly_count = flooder_helpers.snow_fx.to_imvec2_buffer(points)
        if poly_buffer then
            draw_list:AddConvexPolyFilled(poly_buffer, poly_count, color)
        end
    end
end


snow_fx = flooder_helpers.snow_fx


function imgui.CustomSidebarButton(label, tab_id, description)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    local w, h = scale_value(190), scale_value(45)
    anims.sidebar_states = anims.sidebar_states or {}
    local state = anims.sidebar_states[label]
    if not state then
        state = { bg = 0.0, height = 0.0, flash = 0.0, active = false, seed = math.random() * math.pi * 2 }
        if current_tab[0] == tab_id then
            state.bg = 1.0
            state.height = 1.0
            state.active = true
        end
        anims.sidebar_states[label] = state
    end

    imgui.InvisibleButton(label, scale_imvec2(w, h))
    if imgui.IsItemClicked() then current_tab[0] = tab_id end
    imgui.HandleTooltip(description)
    local hovered = imgui.IsItemHovered()
    local is_selected = (current_tab[0] == tab_id)
    if is_selected and not state.active then
        state.height = 0.0
        state.flash = 1.0
    end
    state.active = is_selected

    local delta = imgui.GetIO().DeltaTime
    local target_bg = is_selected and 1.0 or (hovered and 0.25 or 0.0)
    state.bg = bringFloatTo(state.bg, target_bg, 12, delta)
    local target_height = is_selected and 1.0 or 0.0
    state.height = bringFloatTo(state.height, target_height, 10, delta)
    if state.flash > 0 then
        state.flash = math.max(0, state.flash - delta * 1.6)
    end
    
    local accent, bg = imgui.LinkColorToConfig()
    local fade = current_fade_alpha or 1.0
    if state.bg > 0.01 then
        local r, g, b = bg.x, bg.y, bg.z
        local bg_color = imgui.ImVec4(r + (accent.x-r)*0.15, g + (accent.y-g)*0.05, b + (accent.z-b)*0.15, state.bg * 0.8 * fade)
        dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), U32(bg_color), scale_value(5))
    end
    
    if state.height > 0.01 then
        local margin = scale_value(10)
        local bar_height = (h - margin * 2) * state.height
        local bar_y = p.y + (h - bar_height) / 2
        local flash = state.flash > 0 and (0.5 + 0.5 * math.sin(os.clock() * 18 + state.seed)) * state.flash or 0
        local bar_alpha = math.min(1.0, 0.85 + flash * 0.5) * fade
        dl:AddRectFilled(
            imgui.ImVec2(p.x, bar_y),
            imgui.ImVec2(p.x + scale_value(4), bar_y + bar_height),
            U32(imgui.ImVec4(accent.x, accent.y, accent.z, bar_alpha)),
            scale_value(2)
        )
    end
    
    local text_col = U32(imgui.ImVec4(1, 1, 1, (0.45 + (state.bg * 0.55)) * fade))
    local text_size = imgui.CalcTextSize(u8(label))
    dl:AddText(imgui.ImVec2(p.x + scale_value(20), p.y + (h - text_size.y)/2), text_col, u8(label))
end

function imgui.CustomToggle(label, bool_ptr, description)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    local w, h = scale_value(44), scale_value(22)
    local radius = h / 2
    local fade = current_fade_alpha or 1.0
    
    if not anims.toggles[label] then anims.toggles[label] = bool_ptr[0] and 1.0 or 0.0 end
    local target = bool_ptr[0] and 1.0 or 0.0
    anims.toggles[label] = bringFloatTo(anims.toggles[label], target, 15, imgui.GetIO().DeltaTime)
    local anim = anims.toggles[label]
    
    imgui.InvisibleButton(label, scale_imvec2(w, h))
    if imgui.IsItemClicked() then bool_ptr[0] = not bool_ptr[0] end
    imgui.HandleTooltip(description)
    
    local accent, _ = imgui.LinkColorToConfig()
    local off_r, off_g, off_b = 48/255, 48/255, 69/255
    local cur_r = off_r + (accent.x - off_r) * anim
    local cur_g = off_g + (accent.y - off_g) * anim
    local cur_b = off_b + (accent.z - off_b) * anim
    
    dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), U32(imgui.ImVec4(cur_r, cur_g, cur_b, fade)), radius)
    dl:AddRect(p, imgui.ImVec2(p.x + w, p.y + h), U32(imgui.ImVec4(1,1,1,0.2 * fade)), radius, 15, 1.5 * ui_scale)
    
    local knob_x = p.x + radius + (w - h) * anim
    dl:AddCircleFilled(imgui.ImVec2(knob_x, p.y + radius), radius - scale_value(3), U32(imgui.ImVec4(1,1,1,fade)))
    
    
    local text_y = p.y + (h / 2) - (imgui.CalcTextSize(u8(label)).y / 2)
    local dl_fg = imgui.GetWindowDrawList()
    dl_fg:AddText(imgui.ImVec2(p.x + w + scale_value(10), text_y), U32(imgui.ImVec4(1,1,1,0.9 * fade)), u8(label))
    
    
    imgui.SameLine()
    imgui.Dummy(imgui.ImVec2(scale_value(10) + imgui.CalcTextSize(u8(label)).x, 0))
    imgui.Dummy(scale_imvec2(0, 5))
end

function imgui.CustomSlider(label, int_ptr, min, max, suffix, description)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    local w, h = scale_value(330), scale_value(24)
    local val = int_ptr[0]
    local fade = current_fade_alpha or 1.0
    
    imgui.InvisibleButton(label, scale_imvec2(w, h + scale_value(20)))
    if imgui.IsItemActive() then
        local mx = imgui.GetIO().MousePos.x
        local norm = (mx - p.x) / w
        if norm < 0 then norm = 0 elseif norm > 1 then norm = 1 end
        int_ptr[0] = math.floor(min + norm * (max - min))
    end
    imgui.HandleTooltip(description)
    
    local ratio = (val - min) / (max - min)
    local accent, _ = imgui.LinkColorToConfig()
    
    local rounding = scale_value(4)
    dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), U32(imgui.ImVec4(0,0,0,0.3 * fade)), rounding)
    dl:AddRect(p, imgui.ImVec2(p.x + w, p.y + h), U32(imgui.ImVec4(accent.x, accent.y, accent.z, 0.3 * fade)), rounding)
    
    local grab_w = scale_value(10)
    local grab_x = p.x + (w - grab_w) * ratio
    dl:AddRectFilled(imgui.ImVec2(grab_x, p.y + scale_value(2)), imgui.ImVec2(grab_x + grab_w, p.y + h - scale_value(2)), U32(imgui.ImVec4(accent.x, accent.y, accent.z, fade)), scale_value(2))
    
    local val_str = tostring(val) .. (suffix or "")
    local txt_sz = imgui.CalcTextSize(val_str)
    dl:AddText(imgui.ImVec2(p.x + (w - txt_sz.x)/2, p.y + (h - txt_sz.y)/2), U32(imgui.ImVec4(1,1,1,fade)), val_str)
    
    imgui.Dummy(scale_imvec2(0, 5))
end

function imgui.CustomRadioButton(label, selected, description)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    local size = scale_value(20)
    local fade = current_fade_alpha or 1.0
    
    if imgui.InvisibleButton(label, scale_imvec2(300, size + scale_value(5))) then return true end
    imgui.HandleTooltip(description)
    
    local accent, _ = imgui.LinkColorToConfig()
    local center = imgui.ImVec2(p.x + size/2, p.y + size/2)
    
    local col_stroke = selected and U32(imgui.ImVec4(accent.x, accent.y, accent.z, fade)) or U32(imgui.ImVec4(0.5, 0.5, 0.5, fade))
    dl:AddCircle(center, scale_value(9), col_stroke, 12, 2.0 * ui_scale)
    if selected then dl:AddCircleFilled(center, scale_value(5), U32(imgui.ImVec4(accent.x, accent.y, accent.z, fade)), 12) end
    
    local text_col = selected and U32(imgui.ImVec4(1, 1, 1, fade)) or U32(imgui.ImVec4(0.7, 0.7, 0.7, fade))
    dl:AddText(imgui.ImVec2(p.x + size + scale_value(10), p.y - scale_value(2)), text_col, u8(label))
    return false
end

function imgui.CustomKeybind(label, current_key, setter, opts)
    opts = opts or {}
    local id = opts.id or label
    local capturing = keybind_capture.active and keybind_capture.id == id
    local fade = current_fade_alpha or 1.0
    local keyName
    if capturing then
        keyName = "[...]"
    elseif current_key and current_key > 0 then
        keyName = vkeys.id_to_name(current_key) or string.format("VK_%d", current_key)
    else
        keyName = u8"Íå çàäàíî"
    end
    local btn_w = scale_value(opts.width or 120)
    local btn_h = scale_value(25)
    local btn_label = keyName .. "##" .. id
    if imgui.Button(btn_label, scale_imvec2(btn_w, btn_h)) then
        begin_key_capture(id, setter)
    end
    imgui.HandleTooltip(opts.description or string.format("Íàçíà÷èòü êëàâèøó äëÿ '%s'", label))
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(1,1,1,0.7 * fade), u8(label))
    if opts.allow_clear then
        imgui.SameLine()
        if imgui.SmallButton(u8"Ñáðîñ##clear_" .. id) then
            setter(0)
        end
    end
end

INFO_CHANGELOG_ENTRIES = {
    {
        version = "BETA 0.5",
        date = "06.03.2026",
        channel = "Ñòèëè òðåíèíãîâ êàï÷è",
        summary = "Äîáàâëåí âûáîð ìåæäó ñòèëÿìè òðåíèíãà êàï÷è. Ñïàëèòüñÿ íà îïðå ñòàëî åù¸ ñëîæíåå. :)",
        changes = {
            { where = "Ñòèëü òðåíèíãà êàï÷è", how = "Òåïåðü ìîæíî â ïàðó êëèêîâ ïîìåíÿòü âèä òðåíèíãà!" },
            { where = "Îáíîâëåíèå èíôî", how = "Ìåíþøêà â êîòîðîé âû ñåé÷àñ ÷èòàåòå òåêñò - îáíîâëåíà." },
            { where = "Ïî ìåëî÷è", how = "Òåïåðü âû ìîæåòå âêëþ÷èòü è íàñòðîèòü êîìàíäó äëÿ îòêðûòèÿ ìåíþ ñîôòà è îòêðûòèÿ òðåíèðîâî÷íîé êàï÷è. Èñïðàâëåíû íåêîòîðûå ïðîáëåìû." }
        }
    },
    {
        version = "BETA 0.4",
        date = "04.01.2026",
        channel = "Âûõîä áåòû",
        summary = "Ñêðèïò âûøåë íà áëàñòõàêå â âèäå áåòû.",
        changes = {
            { where = "ÀÕÊ", how = "ÀÕÊ ñ ìåòîäàìè ôîìèêóñà, ñîâìåù¸ííîå ñ ìàñêàìè." },
            { where = "Òðåíèíã", how = "Îäèí èç ñàìûõ ïîïóëÿðíûõ òðåíèíãîâ êàï÷è ñîâìåù¸í ñî çäåøíèì ÀÕÊ." },
            { where = "Àâòî-ïðîáèâ", how = "Àâòî-ïðîáèâ ñðàçó â 2 ðåæèìàõ: KeySpoof è Delay. Ïîäðîáíåéøèå íàñòðîêè." }
        }
    }
}

frame_refs = {
    imgui = imgui,
    u8 = u8,
    math = math,
    os = os,
    thisScript = thisScript,
    SaveConfig = SaveConfig,
    setMenuState = setMenuState,
    
    new_profile_name_buffer = new_profile_name_buffer,
    rename_profile_buffer = rename_profile_buffer,
    rename_popup_slot = rename_popup_slot,
    
    renderWindow = renderWindow,
    current_tab = current_tab,
    profile_tab = profile_tab,
    profiles = profiles,
    anims = anims,
    window_state = window_state,
    
    enable_blur = enable_blur,
    blur_strength = blur_strength,
    rgb_enabled = rgb_enabled,
    rgb_speed = rgb_speed,
    rgb_brightness = rgb_brightness,
    rgb_thickness = rgb_thickness,
    rgb_rounding = rgb_rounding,
    winter_mode = winter_mode,
    snow_count = snow_count,
    snow_speed = snow_speed,
    snow_sway = snow_sway,
    snow_alpha = snow_alpha,
    col_accent = col_accent,
    window_alpha = window_alpha,
    
    scale_value = scale_value,
    scale_imvec2 = scale_imvec2,
    ui_scale = ui_scale,
    BASE_WINDOW_WIDTH = BASE_WINDOW_WIDTH,
    BASE_WINDOW_HEIGHT = BASE_WINDOW_HEIGHT,
    MIN_UI_SCALE = MIN_UI_SCALE,
    MAX_UI_SCALE = MAX_UI_SCALE,
    BASE_FONT_SCALE = BASE_FONT_SCALE,
    
    winter_fx = winter_fx,
    render_snow_layer = snow_fx.render_snow_layer,
    render_winter_drifts = snow_fx.render_winter_drifts,
    
    macro_ui = macro_ui,
    auto_spread_active = macro_ui.auto_spread_active,
    auto_spread_ms = macro_ui.auto_spread_ms,
    auto_type_speed = macro_ui.auto_type_speed,
    auto_type_speed_spread = macro_ui.auto_type_speed_spread,
    auto_errors_enabled = macro_ui.auto_errors_enabled,
    auto_error_chance = macro_ui.auto_error_chance,
    auto_error_fail_chance = macro_ui.auto_error_fail_chance,
    auto_delay_start = macro_ui.auto_delay_start,
    auto_delay_enter = macro_ui.auto_delay_enter,
    auto_delay_enter_spread = macro_ui.auto_delay_enter_spread,
    auto_cmd_min = macro_ui.auto_cmd_min,
    auto_cmd_max = macro_ui.auto_cmd_max,
    test_mode = macro_ui.test_mode,
    auto_chat = macro_ui.auto_chat,
    auto_time = macro_ui.auto_time,
    auto_id = macro_ui.auto_id,
    
    automation_hotkeys = automation_hotkeys,
    autoprobiv = autoprobiv,
    
    collision_toggle = collision_toggle,
    aSave = aSave,
    flooder_enabled = flooder_enabled,
    flooder_delay = flooder_delay,
    
    get_rainbow = get_rainbow,
    bringFloatTo = bringFloatTo,
    U32 = U32,
    get_profile_by_tab = get_profile_by_tab,
    get_captcha_set_keys = get_captcha_set_keys,
    get_captcha_set_label = get_captcha_set_label,
    set_captcha_set_label = set_captcha_set_label,
    create_new_captcha_set = create_new_captcha_set,
    delete_captcha_set = delete_captcha_set,
    apply_captcha_set = apply_captcha_set,
    save_active_captcha_set = save_active_captcha_set,
    copy_profile_timings = copy_profile_timings,
    set_hotkey = set_hotkey,
    setup_flooder = setup_flooder,
    
    config = config,
    ahk_config_name = ahk_config_name,
    cheat_code_buffer = cheat_code_buffer,
    cheat_code_active = cheat_code_active,
    menu_cheat_enabled = menu_cheat_enabled,
    menu_command_enabled = menu_command_enabled,
    menu_command_buffer = menu_command_buffer,
    refresh_menu_command_registration = refresh_menu_command_registration,
    normalize_menu_command = normalize_menu_command,
    collision_hotkey = collision_hotkey,
    flooder_hotkey = flooder_hotkey,
    
    inicfg = inicfg,
    notifications = notifications,
    theme_colors = theme_colors,
    ui_render = ui_render,
    profile_helpers = profile_helpers,
    render_toggle_block = render_toggle_block,
    PROFILE_TABS = PROFILE_TABS,
    ffi = ffi,
    vkeys = vkeys
}

_G.UI = frame_refs

imgui.OnFrame(function()
    return _G.UI.renderWindow[0] or ((_G.UI.window_state.fade_alpha or 0) > 0.01)
end, function(player)
    local ui = _G.UI
    local imgui = ui.imgui
    local u8 = ui.u8
    local math = ui.math
    local os = ui.os
    local thisScript = ui.thisScript
    local SaveConfig = ui.SaveConfig
    local setMenuState = ui.setMenuState
    local new_profile_name_buffer = ui.new_profile_name_buffer
    local rename_profile_buffer = ui.rename_profile_buffer
    local renderWindow = ui.renderWindow
    local window_state = ui.window_state
    local bringFloatTo = ui.bringFloatTo
    local get_rainbow = ui.get_rainbow
    local U32 = ui.U32
    local rgb_enabled = ui.rgb_enabled
    local rgb_speed = ui.rgb_speed
    local rgb_brightness = ui.rgb_brightness
    local rgb_thickness = ui.rgb_thickness
    local rgb_rounding = ui.rgb_rounding
    local enable_blur = ui.enable_blur
    local blur_strength = ui.blur_strength
    local col_accent = ui.col_accent
    local window_alpha = ui.window_alpha
    local winter_mode = ui.winter_mode
    local snow_count = ui.snow_count
    local snow_speed = ui.snow_speed
    local snow_sway = ui.snow_sway
    local snow_alpha = ui.snow_alpha
    local winter_fx = ui.winter_fx
    local render_snow_layer = ui.render_snow_layer
    local render_winter_drifts = ui.render_winter_drifts
    local scale_value = ui.scale_value
    local scale_imvec2 = ui.scale_imvec2
    local BASE_WINDOW_WIDTH = ui.BASE_WINDOW_WIDTH
    local BASE_WINDOW_HEIGHT = ui.BASE_WINDOW_HEIGHT
    local MIN_UI_SCALE = ui.MIN_UI_SCALE
    local MAX_UI_SCALE = ui.MAX_UI_SCALE
    local BASE_FONT_SCALE = ui.BASE_FONT_SCALE
    local anims = ui.anims
    local current_tab = ui.current_tab
    local profiles = ui.profiles
    local profile_tab = ui.profile_tab
    local config = ui.config
    local inicfg = ui.inicfg
    local ahk_config_name = ui.ahk_config_name
    local notifications = ui.notifications
    local theme_colors = ui.theme_colors
    local ui_render = ui.ui_render
    local profile_helpers = ui.profile_helpers
    local render_toggle_block = ui.render_toggle_block
    local get_profile_by_tab = ui.get_profile_by_tab
    local get_captcha_set_keys = ui.get_captcha_set_keys
    local get_captcha_set_label = ui.get_captcha_set_label
    local set_captcha_set_label = ui.set_captcha_set_label
    local create_new_captcha_set = ui.create_new_captcha_set
    local delete_captcha_set = ui.delete_captcha_set
    local apply_captcha_set = ui.apply_captcha_set
    local copy_profile_timings = ui.copy_profile_timings
    local set_hotkey = ui.set_hotkey
    local setup_flooder = ui.setup_flooder
    local collision_toggle = ui.collision_toggle
    local collision_hotkey = ui.collision_hotkey
    local flooder_enabled = ui.flooder_enabled
    local flooder_hotkey = ui.flooder_hotkey
    local flooder_delay = ui.flooder_delay
    local cheat_code_buffer = ui.cheat_code_buffer
    local menu_cheat_enabled = ui.menu_cheat_enabled
    local menu_command_enabled = ui.menu_command_enabled
    local menu_command_buffer = ui.menu_command_buffer
    local refresh_menu_command_registration = ui.refresh_menu_command_registration
    local normalize_menu_command = ui.normalize_menu_command
    local autoprobiv = ui.autoprobiv
    local aSave = ui.aSave
    local ffi = ui.ffi
    local cheat_code_value = ui.cheat_code_active
    
    player.HideCursor = not renderWindow[0]
    
    
    if renderWindow[0] and not window_state.prev_active then
        window_state.just_opened = true
    end
    window_state.prev_active = renderWindow[0]
    
    local io = imgui.GetIO()
    local dt = io.DeltaTime
    local anim_dt = math.max(0.0001, math.min(dt, 0.05))
    local desired_alpha = renderWindow[0] and 1.0 or 0.0
    window_state.target_alpha = window_state.target_alpha or desired_alpha
    if window_state.target_alpha ~= desired_alpha then
        window_state.target_alpha = desired_alpha
    end
    local fade_alpha = window_state.fade_alpha or 0.0
    local fade_speed = renderWindow[0] and 10 or 6
    fade_alpha = bringFloatTo(fade_alpha, window_state.target_alpha, fade_speed, anim_dt)
    window_state.fade_alpha = fade_alpha
    if not renderWindow[0] and fade_alpha <= 0.01 then
        window_state.fade_alpha = 0.0
        current_fade_alpha = 0.0
        return
    end
    fade_alpha = math.max(0.0, math.min(1.0, fade_alpha))
    current_fade_alpha = fade_alpha  
    local accent, bg_col = imgui.LinkColorToConfig()
    bg_col.w = bg_col.w * fade_alpha
    
    
    local rgb
    if rgb_enabled[0] then
        local speed = rgb_speed[0] / 10.0
        local brightness = rgb_brightness[0] / 100.0
        rgb = get_rainbow(speed, 1.0, brightness)
    else
        rgb = accent
    end
    
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, fade_alpha)
    imgui.PushStyleColor(imgui.Col.WindowBg, bg_col)
    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.1, 0.1, 0.15, fade_alpha))
    
    
    local btn_col = imgui.ImVec4(accent.x * 0.6, accent.y * 0.6, accent.z * 0.6, 0.5)
    local btn_hov = imgui.ImVec4(accent.x * 0.8, accent.y * 0.8, accent.z * 0.8, 0.7)
    local btn_act = imgui.ImVec4(accent.x, accent.y, accent.z, 0.9)
    imgui.PushStyleColor(imgui.Col.Button, btn_col)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, btn_hov)
    imgui.PushStyleColor(imgui.Col.ButtonActive, btn_act)
    imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(accent.x * 0.4, accent.y * 0.4, accent.z * 0.4, 0.5))
    imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(accent.x * 0.6, accent.y * 0.6, accent.z * 0.6, 0.7))
    imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(accent.x * 0.8, accent.y * 0.8, accent.z * 0.8, 0.9))
    imgui.PushStyleColor(imgui.Col.CheckMark, accent)
    imgui.PushStyleColor(imgui.Col.SliderGrab, accent)
    imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(accent.x * 1.2, accent.y * 1.2, accent.z * 1.2, 1.0))
    
    
    local win_rounding = rgb_rounding[0]
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(5.0, 7.0))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, win_rounding)
    
    local display_size = io.DisplaySize
    local draw_bg = imgui.GetBackgroundDrawList()
    
    if enable_blur[0] and fade_alpha > 0.01 then
        local blur_alpha = (blur_strength[0] / 100.0) * fade_alpha
        
        
        draw_bg:AddRectFilled(imgui.ImVec2(0,0), display_size, U32(imgui.ImVec4(0.02, 0.02, 0.05, blur_alpha * 0.7)))
        
        draw_bg:AddRectFilled(imgui.ImVec2(0,0), display_size, U32(imgui.ImVec4(0.05, 0.05, 0.1, blur_alpha * 0.3)))
        
        local accent_r, accent_g, accent_b = col_accent[0], col_accent[1], col_accent[2]
        draw_bg:AddRectFilled(imgui.ImVec2(0,0), display_size, U32(imgui.ImVec4(accent_r * 0.1, accent_g * 0.1, accent_b * 0.1, blur_alpha * 0.15)))
    end
    
    local snow_density = math.max(5, snow_count[0])
    local snow_speed_value = math.max(5, snow_speed[0])
    local snow_sway_value = math.max(0, snow_sway[0])
    local snow_alpha_norm = math.max(5, math.min(100, snow_alpha[0])) / 100.0

    if winter_mode[0] and fade_alpha > 0.01 then
        local bg_count = math.max(5, math.floor(snow_density * 0.65))
        local speed_min = math.max(8, snow_speed_value * 0.5)
        local speed_max = math.max(speed_min + 5, snow_speed_value * 1.15)
        render_snow_layer(
            winter_fx.bg,
            draw_bg,
            { x = 0, y = 0, w = display_size.x, h = display_size.y },
            {
                count = bg_count,
                size_min = 1.1,
                size_max = 2.5,
                speed_min = speed_min,
                speed_max = speed_max,
                drift_speed = 1.4,
                drift_strength = snow_sway_value,
                color = U32(imgui.ImVec4(1, 1, 1, snow_alpha_norm * 0.55 * fade_alpha))
            },
            dt
        )
    end
    
    imgui.SetNextWindowPos(imgui.ImVec2(display_size.x * 0.5, display_size.y * 0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(BASE_WINDOW_WIDTH, BASE_WINDOW_HEIGHT), imgui.Cond.FirstUseEver)
    local min_size = imgui.ImVec2(BASE_WINDOW_WIDTH * 0.8, BASE_WINDOW_HEIGHT * 0.85)
    local max_size = imgui.ImVec2(BASE_WINDOW_WIDTH * 2.0, BASE_WINDOW_HEIGHT * 2.0)
    imgui.SetNextWindowSizeConstraints(min_size, max_size)
    
    
    if window_state.just_opened then
        imgui.SetNextWindowFocus()
        window_state.just_opened = false
    end
    
    imgui.Begin("Krankmode PIZDA EDITION", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoBringToFrontOnFocus)
    
    local win_pos = imgui.GetWindowPos()
    local win_size = imgui.GetWindowSize()
    local scale_x = win_size.x / BASE_WINDOW_WIDTH
    local scale_y = win_size.y / BASE_WINDOW_HEIGHT
    local target_scale
    if scale_x < 1.0 or scale_y < 1.0 then
        target_scale = math.min(scale_x, scale_y)
    else
        target_scale = math.max(scale_x, scale_y)
    end
    ui.ui_scale = math.max(MIN_UI_SCALE, math.min(MAX_UI_SCALE, target_scale))
    local ui_scale = ui.ui_scale
    imgui.SetWindowFontScale(BASE_FONT_SCALE * ui_scale)
    local control_rounding = math.max(2.0, 5.0 * ui_scale)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, control_rounding)

    local win_w = win_size.x
    local win_h = win_size.y
    local sidebar_width = scale_value(220)
    local sidebar_min = scale_value(180)
    local sidebar_max = math.max(sidebar_min, win_w - scale_value(240))
    sidebar_width = math.max(sidebar_min, math.min(sidebar_width, sidebar_max))
    local dl = imgui.GetForegroundDrawList()
    
    
    local x1, y1 = win_pos.x, win_pos.y
    local x2, y2 = win_pos.x + win_w, win_pos.y + win_h
    local rounding = rgb_rounding[0]  
    local thickness = rgb_thickness[0] / 10.0  
    
    
    
    local corners_all = 15  
    local corners_left = 5  
    
    
    
    local glow_layers = math.max(2, math.floor(thickness) + 1)
    for i = glow_layers, 1, -1 do
        local glow_alpha = (0.3 / i) * fade_alpha
        local glow_col = U32(imgui.ImVec4(rgb.x, rgb.y, rgb.z, glow_alpha))
        local glow_round = rounding + i * 0.5
        dl:AddRect(
            imgui.ImVec2(x1 - i, y1 - i), 
            imgui.ImVec2(x2 + i, y2 + i), 
            glow_col, 
            glow_round,
            corners_all,
            math.max(1, i * 0.8)
        )
    end
    
    
    local main_col = U32(imgui.ImVec4(rgb.x, rgb.y, rgb.z, fade_alpha))
    dl:AddRect(imgui.ImVec2(x1, y1), imgui.ImVec2(x2, y2), main_col, rounding, corners_all, thickness)
    
    
    local dl_win = imgui.GetWindowDrawList()
        if winter_mode[0] and fade_alpha > 0.01 then
            local dl_overlay = imgui.GetForegroundDrawList()
            local ui_count = math.max(5, math.floor(snow_density * 0.4))
            local ui_speed_min = math.max(6, snow_speed_value * 0.45)
            local ui_speed_max = math.max(ui_speed_min + 4, snow_speed_value)
            render_snow_layer(
                winter_fx.ui,
                dl_overlay,
                { x = win_pos.x, y = win_pos.y, w = win_w, h = win_h },
                {
                    count = ui_count,
                    size_min = scale_value(1.0),
                    size_max = scale_value(2.2),
                    speed_min = ui_speed_min,
                    speed_max = ui_speed_max,
                    drift_speed = 2.0,
                    drift_strength = snow_sway_value * 0.8,
                    color = U32(imgui.ImVec4(1, 1, 1, snow_alpha_norm * 0.85 * fade_alpha))
                },
                dt
            )
            render_winter_drifts(dl_overlay, win_pos, win_size, fade_alpha)
        end
    
    local sidebar_bg_color = imgui.ImVec4(col_bg[0] * 0.5, col_bg[1] * 0.5, col_bg[2] * 0.5, 0.4 * fade_alpha)
    dl_win:AddRectFilled(win_pos, imgui.ImVec2(win_pos.x + sidebar_width, win_pos.y + win_h), U32(sidebar_bg_color), rounding, corners_left)
    dl_win:AddLine(imgui.ImVec2(win_pos.x + sidebar_width, win_pos.y), imgui.ImVec2(win_pos.x + sidebar_width, win_pos.y + win_h), U32(imgui.ImVec4(1,1,1,0.05 * fade_alpha)))
    
    
    local p = imgui.GetCursorScreenPos()
    
    imgui.Columns(2, "MainCols", false)
    imgui.SetColumnOffset(1, sidebar_width)
    
    
    imgui.BeginGroup()
        imgui.Dummy(scale_imvec2(0, 15))
        imgui.SetCursorPosX(scale_value(20))
        imgui.PushStyleColor(imgui.Col.Text, rgb)
        imgui.SetWindowFontScale(1.3)
        imgui.Text("by@krankmode -PIZDA EDITION-")
        imgui.PopStyleColor()
        imgui.SetWindowFontScale(1.1)
        
        imgui.Dummy(scale_imvec2(0, 30))
        
        imgui.CustomSidebarButton("Îñíîâíîå", 1, "Ãëàâíûå íàñòðîéêè.")
        imgui.CustomSidebarButton("Òàéìèíãè", 2, "Íàñòðîéêà ââîäà êàï÷è.")
        imgui.CustomSidebarButton("Àâòî-Ïðîáèâ", 3, "Àâòîìàòè÷åñêèé ïðîáèâ ïîñëå êàï÷è.")
        imgui.CustomSidebarButton("Íàñòðîéêè", 4, "Âèçóàëüíûå íàñòðîéêè ìåíþ.")
        imgui.CustomSidebarButton("Èíôî", 5, "Èíôîðìàöèÿ î ñêðèïòå è àâòîðå.")
        imgui.CustomSidebarButton("PIZDA", 6, "ïèçäà åáàíàÿ")
        
        local bot_y = win_h - scale_value(100)
        imgui.SetCursorPosY(bot_y)
        imgui.SetCursorPosX(scale_value(20))
        if imgui.Button(u8"Ñîõðàíèòü", scale_imvec2(180, 35)) then SaveConfig() end
        imgui.HandleTooltip("Ñîõðàíèòü âñå òåêóùèå íàñòðîéêè")
        
        imgui.SetCursorPosX(scale_value(20))
        imgui.SetCursorPosY(bot_y + scale_value(45))
        if imgui.Button(u8"Ïåðåçàãðóçêà", scale_imvec2(180, 35)) then
            setMenuState(false)
            thisScript():reload()
        end
        imgui.HandleTooltip("Ïåðåçàãðóçèòü ñêðèïò")
    imgui.EndGroup()
    
    imgui.NextColumn()
    
    
    imgui.BeginChild("ContentFrame", imgui.ImVec2(0, 0), false, imgui.WindowFlags.NoBackground)
        imgui.SetScrollX(0)
        imgui.Dummy(scale_imvec2(0, 20))
        imgui.SetCursorPosX(scale_value(10))
        
        if anims.last_tab ~= current_tab[0] then
            anims.tab_alpha = 0.0
            anims.last_tab = current_tab[0]
        end
        anims.tab_alpha = bringFloatTo(anims.tab_alpha, 1.0, 8, anim_dt)
        local content_alpha = math.max(0.0, math.min(1.0, anims.tab_alpha * fade_alpha))
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, content_alpha)
        
        if current_tab[0] == 1 then 
            profile_helpers.render_tabs_row()
            
            imgui.BeginChild("MainTabScroll", imgui.ImVec2(0, -5), false, imgui.WindowFlags.NoBackground)
            local active_profile = get_profile_by_tab()
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÐÅÆÈÌ ÐÀÁÎÒÛ ÀÕÊ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 15))
            
            ui_render.radio_group(active_profile.mode, {
                { label = "Îòêëþ÷åíî", value = 0, desc = "Âû ñàìè ââîäèòå êàï÷ó." },
                { label = "Delay", value = 1, desc = "Ñêðèïò ââåäåò êàï÷ó ñàì." },
                { label = "Key Spoof", value = 2, desc = "Æìèòå ëþáûå öèôðû - ñêðèïò ââåäåò ïðàâèëüíûå." }
            }, 5)
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÏÐÎ×ÈÅ ÔÓÍÊÖÈÈ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.PushItemWidth(scale_value(150))
            imgui.InputText("##cheatcode", cheat_code_buffer, 32)
            
            if imgui.IsItemDeactivated() then
                local raw_input = ffi.string(cheat_code_buffer)
                
                local cleaned = raw_input:gsub("%s", ""):gsub("[^%w]", ""):upper()
                if #cleaned > 24 then cleaned = cleaned:sub(1, 24) end
                
                if #cleaned >= 2 then
                    ui.cheat_code_active = cleaned
                    cheat_code_active = cleaned
                    cheat_code_value = cleaned
                    config.input.cheat_code = cleaned
                    cfg_module.save({ silent = true })
                else
                    notifications:show(u8"×èò-êîä äîëæåí ñîäåðæàòü ìèíèìóì 2 ñèìâîëà!", theme_colors.notification.error())
                end
                
                ffi.fill(cheat_code_buffer, 32, 0)
                ffi.copy(cheat_code_buffer, cheat_code_value)
            end
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(1,1,1,1.0), u8"×èò-êîä")
            imgui.HandleTooltip("Êîä äëÿ îòêðûòèÿ ýòîãî ìåíþ ÷åðåç ïîñëåäîâàòåëüíûé ââîä.")

            imgui.PushItemWidth(scale_value(150))
            imgui.InputText("##menu_command", menu_command_buffer, 32)
            if imgui.IsItemDeactivated() then
                local cleaned_command = normalize_menu_command(ffi.string(menu_command_buffer))
                config.input.menu_command = cleaned_command
                ffi.fill(menu_command_buffer, 32, 0)
                ffi.copy(menu_command_buffer, cleaned_command)
                refresh_menu_command_registration({ save_on_change = false })
                cfg_module.save({ silent = true })
            end
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(1,1,1,1.0), u8"Êîìàíäà äëÿ îòêðûòèÿ ýòîãî ìåíþ")
            imgui.HandleTooltip("Ââåäèòå êîìàíäó áåç '/'. Îíà áóäåò îòêðûâàòü ýòî ìåíþ ïðè âêëþ÷åííîì òóìáëåðå âûøå.")

            imgui.PushItemWidth(scale_value(150))
            imgui.InputText("##training_toggle_command", training_toggle_command_buffer, 32)
            if imgui.IsItemDeactivated() then
                local cleaned_training_command = normalize_training_toggle_command(ffi.string(training_toggle_command_buffer))
                config.input.training_toggle_command = cleaned_training_command
                ffi.fill(training_toggle_command_buffer, 32, 0)
                ffi.copy(training_toggle_command_buffer, cleaned_training_command)
                refresh_training_toggle_command({ save_on_change = false })
                refresh_menu_command_registration({ save_on_change = false })
                cfg_module.save({ silent = true })
            end
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(1,1,1,1.0), u8"Êîìàíäà òðåíèíãà")
            imgui.HandleTooltip("Ââåäèòå êîìàíäó áåç '/'. Îíà âêëþ÷àåò èëè âûêëþ÷àåò ðåæèì òðåíèíãà äëÿ áèíäà (ïî óìîë÷àíèþ ontr).")

            imgui.Dummy(scale_imvec2(0, 14))

            local prev_menu_cheat_enabled = menu_cheat_enabled[0]
            imgui.CustomToggle("Îòêðûòèå ìåíþ ïî ÷èò-êîäó", menu_cheat_enabled, "Âêëþ÷àåò èëè îòêëþ÷àåò îòêðûòèå ìåíþ ÷åðåç ÷èò-êîä.")
            if prev_menu_cheat_enabled ~= menu_cheat_enabled[0] then
                if not menu_cheat_enabled[0] and not menu_command_enabled[0] then
                    menu_command_enabled[0] = true
                end
                config.input.menu_cheat_enabled = menu_cheat_enabled[0]
                config.input.menu_command_enabled = menu_command_enabled[0]
                refresh_menu_command_registration({ save_on_change = false })
                cfg_module.save({ silent = true })
            end

            local prev_menu_command_enabled = menu_command_enabled[0]
            imgui.CustomToggle("Îòêðûòèå ìåíþ ïî êîìàíäå", menu_command_enabled, "Âêëþ÷àåò èëè îòêëþ÷àåò îòêðûòèå ìåíþ ÷åðåç ÷àò-êîìàíäó.")
            if prev_menu_command_enabled ~= menu_command_enabled[0] then
                if not menu_command_enabled[0] and not menu_cheat_enabled[0] then
                    menu_cheat_enabled[0] = true
                end
                config.input.menu_command_enabled = menu_command_enabled[0]
                config.input.menu_cheat_enabled = menu_cheat_enabled[0]
                refresh_menu_command_registration({ save_on_change = false })
                cfg_module.save({ silent = true })
            end

            local prev_requires_training_command = training_bind_requires_command[0]
            imgui.CustomToggle(
                "Òðåáîâàòü êîìàíäó äëÿ áèíäà òðåíèíãà",
                training_bind_requires_command,
                "Åñëè âêëþ÷åíî, áèíä òðåíèíãà ðàáîòàåò òîëüêî ïîñëå êîìàíäû. Äëÿ ñòèëåé Shapez è koreec helper ýòî îãðàíè÷åíèå îòêëþ÷àåòñÿ àâòîìàòè÷åñêè."
            )
            if prev_requires_training_command ~= training_bind_requires_command[0] then
                config.input.training_bind_requires_command = training_bind_requires_command[0]
                refresh_training_toggle_command({ save_on_change = false })
                cfg_module.save({ silent = true })
            end

            imgui.Dummy(scale_imvec2(0, 10))
            imgui.TextColored(imgui.ImVec4(1,1,1,1.0), u8"Ñòèëü òðåíèíãà êàï÷è:")
            imgui.PushItemWidth(scale_value(250))
            local style_indices = {}
            for k, _ in pairs(state.training_styles) do
                style_indices[#style_indices + 1] = k
            end
            table.sort(style_indices)
            local current_style = config.input.training_style or 0
            local preview_style = state.training_styles[current_style] and state.training_styles[current_style].name or state.training_styles[0].name
            if imgui.BeginCombo(u8"##training_style_combo", ui_utf8(preview_style)) then
                for _, idx in ipairs(style_indices) do
                    local selected = (idx == current_style)
                    if imgui.Selectable(ui_utf8(state.training_styles[idx].name), selected) then
                        config.input.training_style = idx
                        current_style = idx
                        refresh_training_toggle_command({ save_on_change = false })
                        cfg_module.save({ silent = true })
                    end
                    if selected then
                        imgui.SetItemDefaultFocus()
                    end
                end
                imgui.EndCombo()
            end
            imgui.PopItemWidth()
            imgui.HandleTooltip("Âûáåðèòå ñòèëü òðåíèíãà: îôîðìëåíèå êàï÷è, äèàëîã è ñîîáùåíèÿ â ÷àòå.")

            imgui.TextColored(imgui.ImVec4(1.0, 0.85, 0.45, 0.95), u8"Âàæíî: Ïðè âûáîðå Shapez èëè koreec helper - âàì ÍÅ íóæíî ââîäèòü êîìàíäó \nïåðåä àêòèâàöèåé òðåíèíãà êàï÷è.")
            imgui.TextColored(imgui.ImVec4(1.0, 0.85, 0.45, 0.95), u8"Âàæíî: Åñëè âû ìåíÿåòå ñòèëü òðåíèíãà, çíàéòå, ÷òî ëó÷øå áóäåò ïîìåíÿòü \nòàê-æå è íàçâàíèå ôàéëà, ÷òî áû àäìèíû íå ñïàëèëè âàñ ïî íàçâàíèþ ñîôòà â êîíñîëè.")

            imgui.Dummy(scale_imvec2(0, 10))
            imgui.CustomKeybind("Àêòèâàöèÿ òðåíèíãà", config.input.hotkey, function(key)
                config.input.hotkey = key
                cfg_module.save({ silent = true })
            end, { id = "training_hotkey", description = "Êëàâèøà, îòêðûâàþùàÿ ìåíþ òðåíèðîâêè." })

            imgui.Dummy(scale_imvec2(0, 10))            
            imgui.Separator()            
            imgui.Dummy(scale_imvec2(0, 10))

            render_toggle_block({
                { label = "Àâòî-Enter íà ñåðâåðíóþ êàï÷ó", ptr = profiles.server.auto_enter, desc = "Àâòîìàòè÷åñêè îòïðàâëÿòü êàï÷ó íà ñåðâåðíîì äèàëîãå." },
                { label = "Àâòî-Enter íà òðåíèíã êàï÷è", ptr = profiles.training.auto_enter, desc = "Àâòîìàòè÷åñêè îòïðàâëÿòü êàï÷ó â òðåíàæ¸ðå." },
                { label = "Îãðàíè÷åíèå ñèìâîëîâ Key Spoof", ptr = active_profile.keyspoof_allow_extra, desc = "Îãðàíè÷èâàåò ââîä äî 5 öèôð â ðåæèìå Key Spoof." },
                { label = "Îòêëþ÷àòü êîëëèçèè èãðîêîâ", ptr = collision_toggle, desc = "Îòêëþ÷àåò ñòîëêíîâåíèÿ ñ äðóãèìè èãðîêàìè ïîáëèçîñòè." }
            })
            imgui.CustomKeybind("Áèíä êîëëèçèè", collision_hotkey, function(k) set_hotkey("collision", nil, k) end, { id = "collision_hotkey", allow_clear = true, description = "Êëàâèøà äëÿ àêòèâàöèè êîëëèçèè." })
            imgui.Dummy(scale_imvec2(0, 10))
            render_toggle_block({
                {
                    label = "Àêòèâèðîâàòü ôëóä CEF",
                    ptr = flooder_enabled,
                    desc = "Ôëóäåð äëÿ áûñòðîãî îòêðûòèÿ êàï÷è íà âèäåîêàðòàõ.",
                    on_change = function(state)
                        if isSampAvailable() then
                            setup_flooder(state)
                        end
                    end
                }
            })
            imgui.CustomKeybind("Áèíä ôëóäåðà", flooder_hotkey, function(k) set_hotkey("flooder", nil, k) end, { id = "flooder_hotkey", allow_clear = true, description = "Ãîðÿ÷àÿ êëàâèøà äëÿ áûñòðîãî âêëþ÷åíèÿ/âûêëþ÷åíèÿ ôëóäåðà." })
            imgui.CustomSlider("Èíòåðâàë ôëóäà", flooder_delay, 10, 1000, " ms", "Çàäåðæêà ìåæäó îòïðàâêàìè çàïðîñîâ íà îòêðûòèå êàï÷è.")
            imgui.SetCursorPosY(imgui.GetCursorPosY() - scale_value(40))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.85, 0.45, 0.95))
            imgui.TextWrapped(u8"Âàæíî: Ñòàâüòå íå íèæå 30 ÌÑ. Ïðè ñëèøêîì íèçêîì çíà÷åíèè âîçìîæåí âðåìåííûé áàí IP.")
            imgui.PopStyleColor()

            imgui.Dummy(scale_imvec2(0, 10))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ýòî êîíåö. Äàëüøå ëèñòàòü íåêóäà.")
            imgui.EndChild() 
            
        elseif current_tab[0] == 2 then 
            profile_helpers.render_tabs_row()
            
            imgui.BeginChild("DelaysTabScroll", imgui.ImVec2(0, -5), false, imgui.WindowFlags.NoBackground)
            local active_profile = get_profile_by_tab()
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÏÐÎÔÈËÈ ÒÀÉÌÈÍÃÎÂ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            local active_set_key = config.active_captcha_set or get_captcha_set_keys()[1]
            imgui.PushItemWidth(scale_value(200))
            if imgui.BeginCombo("##captcha_set_combo", ui_utf8(get_captcha_set_label(active_set_key))) then
                for _, slot_key in ipairs(get_captcha_set_keys()) do
                    local selected = slot_key == active_set_key
                    if imgui.Selectable(ui_utf8(get_captcha_set_label(slot_key)), selected) then
                        apply_captcha_set(slot_key)
                        active_set_key = slot_key
                    end
                end
                imgui.EndCombo()
            end
            imgui.PopItemWidth()
            
            imgui.Dummy(scale_imvec2(0, 8))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Áûñòðûé ïåðåíîñ òàéìèíãîâ")
            if imgui.Button(u8"Ñåðâåð -> Òðåíèíã", scale_imvec2(190, 28)) then
                copy_profile_timings("server", "training")
            end
            imgui.SameLine()
            if imgui.Button(u8"Òðåíèíã -> Ñåðâåð", scale_imvec2(190, 28)) then
                copy_profile_timings("training", "server")
            end
            imgui.Dummy(scale_imvec2(0, 15))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÇÀÄÅÐÆÊÈ ÊÀÏ×È")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 15))
            
            local delay_entries = {
                { label = "Ðåàêöèÿ íà ïîÿâëåíèå êàï÷è (äî 1-ãî ñèìâîëà):", id = "##var1", ptr = active_profile.var1, min = 0, max = 1000, suffix = " ms", desc = "Ïàóçà ïîñëå îòêðûòèÿ êàï÷è ïåðåä ïåðâûì ñèìâîëîì." },
                { label = "Èíòåðâàë ìåæäó 1-ì è 2-ì ñèìâîëîì:", id = "##var2", ptr = active_profile.var2, min = 0, max = 500, suffix = " ms", desc = "Ïàóçà ìåæäó 1 è 2 ñèìâîëîì." },
                { label = "Èíòåðâàë ìåæäó 2-ì è 3-ì ñèìâîëîì:", id = "##var3", ptr = active_profile.var3, min = 0, max = 500, suffix = " ms", desc = "Ïàóçà ìåæäó 2 è 3 ñèìâîëîì." },
                { label = "Èíòåðâàë ìåæäó 3-ì è 4-ì ñèìâîëîì:", id = "##var4", ptr = active_profile.var4, min = 0, max = 500, suffix = " ms", desc = "Ïàóçà ìåæäó 3 è 4 ñèìâîëîì." },
                { label = "Èíòåðâàë ìåæäó 4-ì è 5-ì ñèìâîëîì:", id = "##var5", ptr = active_profile.var5, min = 0, max = 500, suffix = " ms", desc = "Ïàóçà ïåðåä ïîñëåäíèì ñèìâîëîì." },
                { label = "Çàäåðæêà ïåðåä îòïðàâêîé (Enter):", id = "##var6", ptr = active_profile.var6, min = 0, max = 500, suffix = " ms", desc = "Ïàóçà ïåðåä íàæàòèåì Enter" },
                { label = "Äîï. çàäåðæêà ïðè îäèíàêîâûõ öèôðàõ:", id = "##repeat_delay", ptr = active_profile.repeat_delay, min = 0, max = 300, suffix = " ms", desc = "Äîáàâëÿåòñÿ, åñëè ñëåäóþùàÿ öèôðà ñîâïàäàåò ñ ïðåäûäóùåé." }
            }
            ui_render.slider_group(delay_entries, ui_render.color_dim)
            
            
            local base_sum = active_profile.var1[0] + active_profile.var2[0] + active_profile.var3[0] + active_profile.var4[0] + active_profile.var5[0] + (active_profile.auto_enter[0] and active_profile.var6[0] or 0)
            imgui.Dummy(scale_imvec2(0, 5))
            if active_profile.random_delay[0] then
                local randomness = active_profile.spread_appearance[0] + (active_profile.spread_between[0] * 4) + (active_profile.auto_enter[0] and active_profile.spread_enter[0] or 0)
                imgui.TextColored(accent, string.format(u8"Èòîãîâàÿ çàäåðæêà: %d ìñ (Äèàïàçîí: %d - %d ìñ)", base_sum, math.max(0, base_sum - randomness), base_sum + randomness))
            else
                imgui.TextColored(accent, string.format(u8"Èòîãîâàÿ çàäåðæêà: %d ìñ", base_sum))
            end
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÏÎÐÎÃ ÐÀÑÑÒÎßÍÈß ÊËÀÂÈØ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 15))
            
            imgui.CustomToggle("Ïîðîã ðàññòîÿíèÿ êëàâèø", active_profile.smart_active, "Ìåíÿåò çàäåðæêó â çàâèñèìîñòè îò ðàññòîÿíèÿ ìåæäó öèôðàìè.")
            
            if active_profile.smart_active[0] then
                ui_render.slider_group({
                    { label = "Ïîðîã áëèçêîé êëàâèøè:", id = "##smart_threshold", ptr = active_profile.smart_threshold, min = 1, max = 9, suffix = "", desc = "Åñëè ðàçíèöà öèôð áîëüøå ïîðîãà, òîãäà öèôðà - äàëüíÿÿ, èíà÷å - áëèçêàÿ." },
                    { label = "Äîï. çàäåðæêà åñëè êëàâèøè äàëåêî:", id = "##smart_far", ptr = active_profile.smart_far, min = 0, max = 200, suffix = " ms", desc = "Çàäåðæêà áóäåò äîáàâëåíà êëàâèøå, êîòîðàÿ äàëüøå ÷åì ïîðîã." },
                    { label = "Äîï. çàäåðæêà åñëè êëàâèøè ðÿäîì:", id = "##smart_close", ptr = active_profile.smart_close, min = 0, max = 200, suffix = " ms", desc = "Çàäåðæêà áóäåò äîáàâëåíà êëàâèøå, êîòîðàÿ áëèæå ÷åì ïîðîã." }
                }, ui_render.color_dim)
            end
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÐÀÍÄÎÌÈÇÀÖÈß")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            imgui.CustomToggle("Ðàíäîìèçàöèÿ", active_profile.random_delay, "Âêëþ÷èòü ðàçáðîñ íà òàéìèíãè.")
            if active_profile.random_delay[0] then
                imgui.Dummy(scale_imvec2(0, 10))
                ui_render.slider_group({
                    { label = "Ïîÿâëåíèå êàï÷è:", id = "##spread_appearance", ptr = active_profile.spread_appearance, min = 0, max = 200, suffix = " ms", desc = "Ñëó÷àéíàÿ çàäåðæêà ïåðåä ïåðâûì ñèìâîëîì." },
                    { label = "Èíòåðâàëû ìåæäó ñèìâîëàìè:", id = "##spread_between", ptr = active_profile.spread_between, min = 0, max = 200, suffix = " ms", desc = "Ïðèìåíÿåòñÿ êî âñåì ïðîìåæóòî÷íûì ïàóçàì(êî âñåì ñèìâîëàì)." },
                    { label = "Îòïðàâêà Enter:", id = "##spread_enter", ptr = active_profile.spread_enter, min = 0, max = 200, suffix = " ms", desc = "Îòêëîíåíèå ïåðåä àâòî-enter'îì." }
                }, ui_render.color_dim)
            end

            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÈÌÈÒÀÖÈß ÎØÈÁÎÊ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            imgui.CustomToggle("Âêëþ÷èòü èìèòàöèþ îøèáîê", active_profile.mistake_enabled, "Àêòèâèðóåò ñïåöèàëüíî äîïóùåííûå îøèáêè â àâòî-ââîäå.")
            if active_profile.mistake_enabled[0] then
                imgui.Dummy(scale_imvec2(0, 10))
                local slider_id = string.format("##mistake_chance_%d", profile_tab[0])
                local fix_id = string.format("##mistake_fix_%d", profile_tab[0])
                local bs_id = string.format("##mistake_bs_%d", profile_tab[0])
                local corr_id = string.format("##mistake_corr_%d", profile_tab[0])
                ui_render.slider_group({
                    { label = "Øàíñ äîïóñòèòü îøèáêó:", id = slider_id, ptr = active_profile.mistake_chance, min = 0, max = 100, suffix = " %", desc = "Âåðîÿòíîñòü íà÷àòü öåïî÷êó îøèáîê.\nÏîêà âûïàäàåò - ïðîäîëæàåì îøèáàòüñÿ." },
                    { label = "Øàíñ èñïðàâèòü îøèáêó:", id = fix_id, ptr = active_profile.mistake_fix_chance, min = 0, max = 100, suffix = " %", desc = "Âåðîÿòíîñòü çàìåòèòü è èñïðàâèòü ñîçäàííóþ îøèáêó (backspace + ïðàâèëüíûé ñèìâîë)" },
                    { label = "Çàäåðæêà äî Backspace:", id = bs_id, ptr = active_profile.mistake_backspace_delay, min = 20, max = 500, suffix = " ms", desc = "Ïàóçà ïåðåä íàæàòèåì backspace (èìèòàöèÿ âðåìåíè íà îñîçíàíèå îøèáêè)" },
                    { label = "Çàäåðæêà äî èñïðàâëåíèÿ:", id = corr_id, ptr = active_profile.mistake_correct_delay, min = 20, max = 500, suffix = " ms", desc = "Ïàóçà ïîñëå backspace ïåðåä ââîäîì ïðàâèëüíîãî ñèìâîëà" }
                }, ui_render.color_dim)
            end 
            imgui.TextColored(imgui.ImVec4(1,1,1,0.5), u8"Ýòî êîíåö. Äàëüøå ëèñòàòü íåêóäà.")
            imgui.EndChild() 
            
        elseif current_tab[0] == 3 then 
            
            imgui.Dummy(scale_imvec2(0, 5))
            for idx, tab_label in ipairs({u8"Íàñòðîéêè", u8"Ãîðÿ÷èå êëàâèøè"}) do
                if idx > 1 then imgui.SameLine() end
                local selected = (autoprobiv_tab[0] == idx)
                local label = string.format("%s##autoprobiv_tab_%d", tab_label, idx)
                if selected then
                    local accent = imgui.ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.9)
                    imgui.PushStyleColor(imgui.Col.Button, accent)
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, accent)
                    imgui.PushStyleColor(imgui.Col.ButtonActive, accent)
                end
                if imgui.Button(label, scale_imvec2(190, 32)) then
                    autoprobiv_tab[0] = idx
                end
                if selected then
                    imgui.PopStyleColor(3)
                end
            end
            imgui.Dummy(scale_imvec2(0, 10))
            
            if autoprobiv_tab[0] == 1 then  
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÀÂÒÎ-ÏÐÎÁÈÂ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 15))
            
            imgui.CustomToggle("Àâòî-ïðîáèâ ïîñëå êàï÷è", autoprobiv.enabled, "Àâòîìàòè÷åñêè çàïóñêàòü ïðîáèâ ïîñëå óñïåøíîãî ââîäà êàï÷è.")
            if autoprobiv.enabled[0] then
                imgui.CustomToggle("Ðàáîòà â òðåíèíãå", autoprobiv.allow_training, "Ðàçðåøèòü àâòîïðîáèâ ïîñëå òðåíèíãîâîé êàï÷è.")
                
                imgui.Dummy(scale_imvec2(0, 10))
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ïîñëåäîâàòåëüíîñòü êîìàíä:")
                local sequence_list = parse_probiv_sequence()
                local seq_labels = { time = u8"/time", id = u8"/id [ìîé ID]", captcha = u8"Êàï÷à" }
                imgui.Dummy(scale_imvec2(0, 5))
                imgui.BeginGroup()
                for idx, token in ipairs(sequence_list) do
                    local label = seq_labels[token] or token
                    imgui.TextColored(imgui.ImVec4(1,1,1,0.8), string.format(u8"%d) %s", idx, label))
                    imgui.SameLine()
                    if idx > 1 then
                        if imgui.SmallButton(string.format(u8"^##seq_up_%d", idx)) then
                            sequence_list[idx], sequence_list[idx-1] = sequence_list[idx-1], sequence_list[idx]
                            set_autoprobiv_sequence(sequence_list)
                        end
                    else
                        imgui.Dummy(scale_imvec2(16, 0))
                    end
                    imgui.SameLine()
                    if idx < #sequence_list then
                        if imgui.SmallButton(string.format(u8"v##seq_down_%d", idx)) then
                            sequence_list[idx], sequence_list[idx+1] = sequence_list[idx+1], sequence_list[idx]
                            set_autoprobiv_sequence(sequence_list)
                        end
                    end
                end
                imgui.EndGroup()
            
            imgui.Dummy(scale_imvec2(0, 10))
            imgui.CustomToggle("Îòïðàâëÿòü /time", autoprobiv.do_time, "Âêëþ÷èòü îòïðàâêó /time ïðè ïðîáèâå.")
            if autoprobiv.do_time[0] then
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(60))
                imgui.DragInt("##time_count", autoprobiv.time_count, 0.1, 1, 10, "%d")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.TextDisabled(u8"ðàç(à)")
            end
            
            imgui.CustomToggle("Îòïðàâëÿòü /id", autoprobiv.do_id, "Îòïðàâèòü /id ñ âàøèì ñåðâåðíûì ID.")
            if autoprobiv.do_id[0] then
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(60))
                imgui.DragInt("##id_count", autoprobiv.id_count, 0.1, 1, 10, "%d")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.TextDisabled(u8"ðàç(à)")
            end
            
            imgui.CustomToggle("Îòïðàâëÿòü êàï÷ó", autoprobiv.do_captcha, "Îòïðàâèòü ïîñëåäíþþ ââåä¸ííóþ êàï÷ó â ÷àò.")
            if autoprobiv.do_captcha[0] then
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(60))
                imgui.DragInt("##captcha_count", autoprobiv.captcha_count, 0.1, 1, 10, "%d")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.TextDisabled(u8"ðàç(à)")
            end
            
            
            imgui.Dummy(scale_imvec2(0, 5))
            local remembered_captcha = captcha_state.get_remembered_for_probiv()
            if remembered_captcha and #remembered_captcha > 0 then
                imgui.TextColored(imgui.ImVec4(0.4, 1, 0.4, 0.8), u8"Ïîñëåäíÿÿ êàï÷à: " .. remembered_captcha)
            else
                imgui.TextColored(imgui.ImVec4(1, 0.5, 0.5, 0.6), u8"Êàï÷à åù¸ íå ââåäåíà")
            end
            end  
            
            imgui.Dummy(scale_imvec2(0, 15))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÀÂÒÎ-ENTER ÄËß ÏÐÎÁÈÂÀ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 5))
            
            imgui.CustomToggle("Àâòî-Enter (Delay)", autoprobiv.auto_enter, "Àâòîìàòè÷åñêè îòïðàâëÿòü ñîîáùåíèå ïîñëå ââîäà â ðåæèìå Delay.\nÅñëè âûêëþ÷åíî - òåêñò îñòàíåòñÿ â ÷àòå áåç îòïðàâêè.")
            if autoprobiv.auto_enter[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Çàäåðæêà ïåðåä Enter (Delay):")
                imgui.CustomSlider("##human_send_delay", autoprobiv.human_send_delay, 0, 1000, " ms", "Ïàóçà ïîñëå ââîäà ïîñëåäíåãî ñèìâîëà ïåðåä íàæàòèåì Enter.")
            end
            
            imgui.Dummy(scale_imvec2(0, 5))
            imgui.CustomToggle("Àâòî-Enter (KeySpoof)", chat_keyspoof.auto_enter, "Àâòîìàòè÷åñêè îòïðàâëÿòü ñîîáùåíèå ïðè ââîäå íóæíîãî êîëè÷åñòâà ñèìâîëîâ.")
            if chat_keyspoof.auto_enter[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Çàäåðæêà ïåðåä Enter (KeySpoof):")
                imgui.CustomSlider("##keyspoof_delay", chat_keyspoof.auto_enter_delay, 0, 500, " ms", "Çàäåðæêà ïåðåä àâòîìàòè÷åñêîé îòïðàâêîé ñîîáùåíèÿ.")
            end
            
            imgui.Dummy(scale_imvec2(0, 5))
            imgui.CustomToggle("Ðàíäîìèçàöèÿ çàäåðæêè Enter", chat_keyspoof.auto_enter_spread_enabled, "Âêëþ÷èòü ñëó÷àéíóþ ïîãðåøíîñòü çàäåðæêè äëÿ îáîèõ ðåæèìîâ (Delay è KeySpoof).")
            if chat_keyspoof.auto_enter_spread_enabled[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ðàçáðîñ çàäåðæêè:")
                imgui.CustomSlider("##enter_spread", chat_keyspoof.auto_enter_spread, 0, 200, " ms", "Ñëó÷àéíàÿ ïîãðåøíîñòü çàäåðæêè (±) äëÿ Delay è KeySpoof.")
            end

            
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÇÀÄÅÐÆÊÈ ÏÐÎÁÈÂÀ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            local probiv_delay_entries = {
                { label = "Ïàóçà ïîñëå çàêðûòèÿ êàï÷è:", id = "##probiv_delay_start", ptr = autoprobiv.delay_before_start, min = 0, max = 2000, suffix = " ms", desc = "Ïàóçà ïîñëå ââîäà êàï÷è ïåðåä ïåðâîé êîìàíäîé ïðîáèâà." },
                { label = "Çàäåðæêà ïåðåä ïåðâûì ñèìâîëîì:", id = "##probiv_open_delay", ptr = autoprobiv.human_open_delay, min = 0, max = 1000, suffix = " ms", desc = "Ïàóçà ïîñëå îòêðûòèÿ ÷àòà ïåðåä ââîäîì ïåðâîãî ñèìâîëà." },
                { label = "Ñêîðîñòü ïå÷àòè ñèìâîëîâ:", id = "##human_char_delay", ptr = autoprobiv.human_char_delay, min = 0, max = 250, suffix = " ms", desc = "Áàçîâàÿ çàäåðæêà ìåæäó ââîäîì êàæäîãî ñèìâîëà." },
                { label = "Ìèí. ïàóçà ìåæäó êîìàíäàìè:", id = "##probiv_delay_min", ptr = autoprobiv.delay_min, min = 10, max = 2000, suffix = " ms", desc = "Ìèíèìàëüíàÿ ñëó÷àéíàÿ ïàóçà ìåæäó êîìàíäàìè." },
                { label = "Ìàêñ. ïàóçà ìåæäó êîìàíäàìè:", id = "##probiv_delay_max", ptr = autoprobiv.delay_max, min = 10, max = 2000, suffix = " ms", desc = "Ìàêñèìàëüíàÿ ñëó÷àéíàÿ ïàóçà ìåæäó êîìàíäàìè." }
            }
            ui_render.slider_group(probiv_delay_entries, ui_render.color_dim)

                        

            local avg_cmd_delay = (autoprobiv.delay_min[0] + autoprobiv.delay_max[0]) / 2
            local total_delay = autoprobiv.delay_before_start[0]
            local commands_count = 0
            if autoprobiv.do_time[0] then 
                commands_count = commands_count + 1
                total_delay = total_delay + (autoprobiv.time_count[0] - 1) * autoprobiv.delay_time[0]
            end
            if autoprobiv.do_id[0] then 
                commands_count = commands_count + 1
                total_delay = total_delay + (autoprobiv.id_count[0] - 1) * autoprobiv.delay_id[0]
            end
            if autoprobiv.do_captcha[0] then 
                commands_count = commands_count + 1
                total_delay = total_delay + (autoprobiv.captcha_count[0] - 1) * autoprobiv.delay_captcha[0]
            end
            if commands_count > 1 then
                total_delay = total_delay + (commands_count - 1) * avg_cmd_delay
            end
            
            imgui.Dummy(scale_imvec2(0, 5))
            local min_total = autoprobiv.delay_before_start[0]
            local max_total = autoprobiv.delay_before_start[0]
            if commands_count > 1 then
                min_total = min_total + (commands_count - 1) * autoprobiv.delay_min[0]
                max_total = max_total + (commands_count - 1) * autoprobiv.delay_max[0]
            end
            imgui.TextColored(accent, string.format(u8"Ïðèìåðíàÿ çàäåðæêà: %d - %d ìñ", min_total, max_total))
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÐÀÍÄÎÌÈÇÀÖÈß")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.CustomToggle("Ñëó÷àéíîå îòêëîíåíèå òàéìèíãîâ", autoprobiv.delay_random, "Äîáàâèòü äîïîëíèòåëüíûé ñëó÷àéíûé ðàçáðîñ êî âñåì çàäåðæêàì.")
            if autoprobiv.delay_random[0] then
                imgui.Dummy(scale_imvec2(0, 10))
                ui_render.slider_group({
                    { label = "Ðàçáðîñ ïàóç ìåæäó êîìàíäàìè:", id = "##probiv_delay_spread", ptr = autoprobiv.delay_random_spread, min = 0, max = 100, suffix = " ms", desc = "Ñëó÷àéíîå îòêëîíåíèå ± îò áàçîâûõ çàäåðæåê ìåæäó êîìàíäàìè." },
                    { label = "Ðàçáðîñ çàäåðæêè ïåðåä ïåðâûì ñèìâîëîì:", id = "##human_open_spread", ptr = autoprobiv.human_open_spread, min = 0, max = 500, suffix = " ms", desc = "Ñëó÷àéíîå îòêëîíåíèå ± ïåðåä ââîäîì ïåðâîãî ñèìâîëà â ÷àòå." },
                    { label = "Ðàçáðîñ ñêîðîñòè ïå÷àòè:", id = "##human_char_spread", ptr = autoprobiv.human_char_spread, min = 0, max = 250, suffix = " ms", desc = "Ñëó÷àéíîå îòêëîíåíèå ± îò áàçîâîé çàäåðæêè ìåæäó ñèìâîëàìè." }
                }, ui_render.color_dim)
            end
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÈÌÈÒÀÖÈß ÎØÈÁÎÊ Â ÏÐÎÁÈÂÅ (DELAY)")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.CustomToggle("Èìèòèðîâàòü ñëó÷àéíûå îøèáêè", autoprobiv.human_errors_enabled, "Èíîãäà ââîäèòü îøèáî÷íûå ñèìâîëû (ñîñåäíèå êëàâèøè) è èñïðàâëÿòü èõ.\nÄåëàåò ââîä áîëåå ÷åëîâå÷åñêèì.")
            if autoprobiv.human_errors_enabled[0] then
                imgui.Dummy(scale_imvec2(0, 10))
                ui_render.slider_group({
                    { label = "Âåðîÿòíîñòü äîïóñòèìîé îøèáêè:", id = "##human_error_chance", ptr = autoprobiv.human_error_chance, min = 0, max = 100, suffix = " %", desc = "Âåðîÿòíîñòü äîïóñòèòü îïå÷àòêó ïðè ââîäå ñîîáùåíèÿ.\nÅñëè ñðàáîòàåò - áóäåò 1-4 îïå÷àòêè â ñîîáùåíèè." },
                    { label = "Øàíñ íå èñïðàâëÿòü îøèáêó:", id = "##human_error_fail", ptr = autoprobiv.human_error_fail_chance, min = 0, max = 100, suffix = " %", desc = "Âåðîÿòíîñòü îñòàâèòü îïå÷àòêó áåç èñïðàâëåíèÿ.\n0% = âñåãäà èñïðàâëÿåò, 100% = íèêîãäà íå èñïðàâëÿåò." }
                }, ui_render.color_dim)
            end
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÈÌÈÒÀÖÈß ÎØÈÁÎÊ Â ÏÐÎÁÈÂÅ (KEYSPOOF)")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            imgui.CustomToggle("Èìèòèðîâàòü îøèáêè (KeySpoof)", chat_keyspoof.errors_enabled, "Èíîãäà ïîêàçûâàòü îøèáî÷íûé ñèìâîë ïåðåä ïðàâèëüíûì.\nÄåëàåò ââîä áîëåå ÷åëîâå÷åñêèì.")
            if chat_keyspoof.errors_enabled[0] then
                imgui.Dummy(scale_imvec2(0, 5))
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Âåðîÿòíîñòü îøèáêè:")
                imgui.CustomSlider("##keyspoof_error_chance", chat_keyspoof.error_chance, 0, 100, " %", "Âåðîÿòíîñòü äîïóñòèòü îïå÷àòêó íà êàæäûé ñèìâîë.")
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Øàíñ íå èñïðàâëÿòü:")
                imgui.CustomSlider("##keyspoof_error_fail", chat_keyspoof.error_fail_chance, 0, 100, " %", "Âåðîÿòíîñòü îñòàâèòü îïå÷àòêó áåç èñïðàâëåíèÿ.\n0%% = âñåãäà èñïðàâëÿåò, 100%% = íèêîãäà.")
            end
            
            imgui.Dummy(scale_imvec2(0, 10))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.5), u8"Ýòî êîíåö. Äàëüøå ëèñòàòü íåêóäà.")
            
            elseif autoprobiv_tab[0] == 2 then  
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÃÎÐß×ÈÅ ÊËÀÂÈØÈ ÀÂÒÎ-ÏÐÎÁÈÂÀ (DELAY)")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            local probiv_keybinds = {
                { label = "Àâòî-ïðîáèâ (âñå)", ptr = autoprobiv.hotkey_all, category = "autoprobiv", action = "all", id = "autoprobiv_hotkey_all", desc = "Çàïóñê ïîëíîé ïîñëåäîâàòåëüíîñòè ïðîáèâà." },
                { label = "Êàï÷à", ptr = autoprobiv.hotkey_captcha, category = "autoprobiv", action = "captcha", id = "autoprobiv_hotkey_captcha", desc = "Îòïðàâèòü ïîñëåäíþþ êàï÷ó." },
                { label = "/time", ptr = autoprobiv.hotkey_time, category = "autoprobiv", action = "time", id = "autoprobiv_hotkey_time", desc = "Îòïðàâèòü /time." },
                { label = "/id [ìîé ID]", ptr = autoprobiv.hotkey_id, category = "autoprobiv", action = "id", id = "autoprobiv_hotkey_id", desc = "Îòïðàâèòü /id ñ âàøèì ID." }
            }
            ui_render.keybind_group(probiv_keybinds, scale_value(140))
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÃÎÐß×ÈÅ ÊËÀÂÈØÈ KEYSPOOF")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            local keyspoof_keybinds = {
                {
                    label = "KeySpoof êàï÷à",
                    ptr = chat_keyspoof.hotkey_captcha,
                    id = "chat_keyspoof_captcha",
                    desc = "Àêòèâèðóåò keyspoof äëÿ ïîñëåäíåé êàï÷è â ÷àòå.",
                    setter = function(k)
                        chat_keyspoof.hotkey_captcha = k
                        config.chat_keyspoof.hotkey_captcha = k
                    end
                },
                {
                    label = "KeySpoof /time",
                    ptr = chat_keyspoof.hotkey_time,
                    id = "chat_keyspoof_time",
                    desc = "Àêòèâèðóåò keyspoof äëÿ /time â ÷àòå.",
                    setter = function(k)
                        chat_keyspoof.hotkey_time = k
                        config.chat_keyspoof.hotkey_time = k
                    end
                },
                {
                    label = "KeySpoof /id",
                    ptr = chat_keyspoof.hotkey_id,
                    id = "chat_keyspoof_id",
                    desc = "Àêòèâèðóåò keyspoof äëÿ /id â ÷àòå.",
                    setter = function(k)
                        chat_keyspoof.hotkey_id = k
                        config.chat_keyspoof.hotkey_id = k
                    end
                }
            }
            ui_render.keybind_group(keyspoof_keybinds, scale_value(140))
            
            if chat_keyspoof.mode then
                imgui.Dummy(scale_imvec2(0, 10))
                imgui.TextColored(imgui.ImVec4(0.4, 1, 0.4, 1), u8"Àêòèâíûé ðåæèì KeySpoof: " .. chat_keyspoof.mode)
            end
            
            imgui.Dummy(scale_imvec2(0, 10))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.5), u8"Ýòî êîíåö. Äàëüøå ëèñòàòü íåêóäà.")
            
            end  
            
        elseif current_tab[0] == 4 then 
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÓÏÐÀÂËÅÍÈÅ ÏÐÎÔÈËßÌÈ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            local active_set_key = config.active_captcha_set or get_captcha_set_keys()[1]
            imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Òåêóùèé ïðîôèëü:")
            imgui.PushItemWidth(scale_value(200))
            if imgui.BeginCombo("##settings_captcha_set_combo", ui_utf8(get_captcha_set_label(active_set_key))) then
                for _, slot_key in ipairs(get_captcha_set_keys()) do
                    local selected = slot_key == active_set_key
                    if imgui.Selectable(ui_utf8(get_captcha_set_label(slot_key) .. "##settings"), selected) then
                        apply_captcha_set(slot_key)
                        active_set_key = slot_key
                    end
                end
                imgui.EndCombo()
            end
            imgui.PopItemWidth()
            
            imgui.Dummy(scale_imvec2(0, 5))
            if imgui.Button(u8"+ Ñîçäàòü íîâûé", scale_imvec2(150, 28)) then
                ffi.fill(new_profile_name_buffer, 64, 0)
                imgui.OpenPopup(u8"Íîâûé ïðîôèëü")
            end
            imgui.SameLine()
            if imgui.Button(u8"Ïåðåèìåíîâàòü", scale_imvec2(130, 28)) then
                ui.rename_popup_slot = active_set_key
                ffi.fill(rename_profile_buffer, 64, 0)
                local current_label = get_captcha_set_label(active_set_key)
                ffi.copy(rename_profile_buffer, ui_utf8(current_label))
                imgui.OpenPopup(u8"Ïåðåèìåíîâàòü ïðîôèëü")
            end
            imgui.SameLine()
            if #get_captcha_set_keys() > 1 then
                if imgui.Button(u8"Óäàëèòü", scale_imvec2(100, 28)) then
                    delete_captcha_set(active_set_key)
                    active_set_key = config.active_captcha_set
                    apply_captcha_set(active_set_key)
                end
            else
                imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
                imgui.Button(u8"Óäàëèòü", scale_imvec2(100, 28))
                imgui.PopStyleVar()
            end
            
            
            if imgui.BeginPopupModal(u8"Íîâûé ïðîôèëü", nil, imgui.WindowFlags.AlwaysAutoResize) then
                imgui.Text(u8"Ââåäèòå íàçâàíèå:")
                imgui.PushItemWidth(scale_value(200))
                imgui.InputText("##new_profile_name", new_profile_name_buffer, 64)
                imgui.PopItemWidth()
                imgui.Dummy(scale_imvec2(0, 10))
                if imgui.Button(u8"Ñîçäàòü", scale_imvec2(100, 28)) then
                    local name = u8:decode(ffi.string(new_profile_name_buffer))
                    if #name > 0 then
                        local new_key = create_new_captcha_set(name)
                        apply_captcha_set(new_key)
                    end
                    imgui.CloseCurrentPopup()
                end
                imgui.SameLine()
                if imgui.Button(u8"Îòìåíà", scale_imvec2(100, 28)) then
                    imgui.CloseCurrentPopup()
                end
                imgui.EndPopup()
            end
            
            
            if imgui.BeginPopupModal(u8"Ïåðåèìåíîâàòü ïðîôèëü", nil, imgui.WindowFlags.AlwaysAutoResize) then
                imgui.Text(u8"Íîâîå íàçâàíèå:")
                imgui.PushItemWidth(scale_value(200))
                imgui.InputText("##rename_profile_name", rename_profile_buffer, 64)
                imgui.PopItemWidth()
                imgui.Dummy(scale_imvec2(0, 10))
                if imgui.Button(u8"Ñîõðàíèòü", scale_imvec2(100, 28)) then
                    local new_name = u8:decode(ffi.string(rename_profile_buffer))
                    if #new_name > 0 and ui.rename_popup_slot then
                        set_captcha_set_label(ui.rename_popup_slot, new_name)
                        SaveConfig({ silent = true })
                    end
                    ui.rename_popup_slot = nil
                    imgui.CloseCurrentPopup()
                end
                imgui.SameLine()
                if imgui.Button(u8"Îòìåíà", scale_imvec2(100, 28)) then
                    ui.rename_popup_slot = nil
                    imgui.CloseCurrentPopup()
                end
                imgui.EndPopup()
            end
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÔÓÍÊÖÈÈ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.CustomToggle("Àâòî-Ñîõðàíåíèå", aSave, "Ñîõðàíÿòü íàñòðîéêè ïðè âûõîäå èç èãðû.")
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÐÅÄÀÊÒÎÐ ÒÅÌÛ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.CustomToggle("Çàòåìíåíèå ôîíà", enable_blur, "Çàòåìíåíèå ýêðàíà ïðè îòêðûòîì ìåíþ.")
            if enable_blur[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Èíòåíñèâíîñòü çàòåìíåíèÿ:")
                imgui.CustomSlider("##blur_strength", blur_strength, 10, 100, "%", "Èíòåíñèâíîñòü çàòåìíåíèÿ.")
            end
            imgui.CustomToggle("Çèìíèé ðåæèì", winter_mode, "Äîáàâëÿåò ñíåã è ñóãðîáû âîêðóã ìåíþ.")
            if winter_mode[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ïëîòíîñòü ñíåãà:")
                imgui.CustomSlider("##snow_count", snow_count, 20, 1500, "", "Êîëè÷åñòâî ñíåæèíîê íà ýêðàíå.")

                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ñêîðîñòü ïàäåíèÿ:")
                imgui.CustomSlider("##snow_speed", snow_speed, 10, 120, "", "Ñðåäíÿÿ ñêîðîñòü ïàäåíèÿ ñíåãà.")

                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ïîêà÷èâàíèå:")
                imgui.CustomSlider("##snow_sway", snow_sway, 0, 30, "", "Àìïëèòóäà ãîðèçîíòàëüíîãî ñíîñà ñíåæèíîê.")

                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ïðîçðà÷íîñòü ñíåãà:")
                imgui.CustomSlider("##snow_alpha", snow_alpha, 10, 100, "%", "Èíòåíñèâíîñòü âèäèìîñòè ñíåæèíîê.")
            end
            imgui.Text(u8"Ïðîçðà÷íîñòü ìåíþ")
            imgui.PushItemWidth(scale_value(200))
            imgui.SliderFloat("##alpha", window_alpha, 0.1, 1.0, "%.2f")
            imgui.PopItemWidth()
            
            imgui.Dummy(scale_imvec2(0, 5))
            imgui.Text(u8"Îñíîâíîé öâåò")
            imgui.ColorEdit3("##acc", col_accent, imgui.ColorEditFlags.NoInputs)
            imgui.Text(u8"Öâåò ôîíà")
            imgui.ColorEdit3("##bg", col_bg, imgui.ColorEditFlags.NoInputs)
            
            imgui.Dummy(scale_imvec2(0, 20))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"RGB ÏÎÄÑÂÅÒÊÀ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.CustomToggle("RGB ïîäñâåòêà ðàìêè", rgb_enabled, "Àíèìèðîâàííàÿ RGB ïîäñâåòêà ðàìêè îêíà.")
            if rgb_enabled[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ñêîðîñòü àíèìàöèè:")
                imgui.CustomSlider("##rgb_speed", rgb_speed, 5, 100, "", "Ñêîðîñòü ñìåíû öâåòîâ RGB.")
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"ßðêîñòü:")
                imgui.CustomSlider("##rgb_brightness", rgb_brightness, 20, 100, "%", "ßðêîñòü RGB ïîäñâåòêè.")
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Òîëùèíà ðàìêè:")
                imgui.CustomSlider("##rgb_thickness", rgb_thickness, 10, 50, "", "Òîëùèíà RGB ðàìêè.")
                imgui.TextColored(imgui.ImVec4(1,1,1,0.6), u8"Ñêðóãëåíèå óãëîâ:")
                imgui.CustomSlider("##rgb_rounding", rgb_rounding, 0, 30, " px", "Ñêðóãëåíèå óãëîâ ðàìêè.")
            end
            
        elseif current_tab[0] == 5 then 
                local version_value = tostring((thisScript() and thisScript().version) or (config.core and config.core.app_version) or "BETA 0.5")

                imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"Î ÑÊÐÈÏÒÅ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))

            imgui.BeginChild("##info_header_card", imgui.ImVec2(0, scale_value(132)), true)
                imgui.Text("by@krankmode -PIZDA EDITION-")
                    imgui.Text(u8"Àâòîð: Bratanchik1488")
                    imgui.Text(u8("Âåðñèÿ: " .. version_value))
            imgui.EndChild()

            imgui.Dummy(scale_imvec2(0, 10))
                imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÆÓÐÍÀË ÈÇÌÅÍÅÍÈÉ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 8))

            if anims.info_changelog_selected == nil then
                anims.info_changelog_selected = 1
            end
            if anims.info_changelog_selected < 1 or anims.info_changelog_selected > #INFO_CHANGELOG_ENTRIES then
                anims.info_changelog_selected = 1
            end

            local changelog_height = scale_value(300)
            local versions_width = scale_value(220)

            imgui.BeginChild("##changelog_versions", imgui.ImVec2(versions_width, changelog_height), true)
                for idx, release in ipairs(INFO_CHANGELOG_ENTRIES) do
                    local selected_release = (anims.info_changelog_selected == idx)
                    local label = string.format("%s | %s##release_%d", release.version, release.channel, idx)
                    if imgui.Selectable(u8(label), selected_release) then
                        anims.info_changelog_selected = idx
                    end
                    imgui.TextColored(imgui.ImVec4(1,1,1,0.45), u8(release.date))
                    if idx < #INFO_CHANGELOG_ENTRIES then
                        imgui.Separator()
                    end
                end
            imgui.EndChild()

            imgui.SameLine()

            imgui.BeginChild("##changelog_details", imgui.ImVec2(0, changelog_height), true)
                local active_release = INFO_CHANGELOG_ENTRIES[anims.info_changelog_selected] or INFO_CHANGELOG_ENTRIES[1]
                imgui.Text(u8(string.format("%s  |  %s", active_release.version, active_release.channel)))
                imgui.TextColored(imgui.ImVec4(1,1,1,0.55), u8(active_release.date))

                imgui.Dummy(scale_imvec2(0, 6))
                imgui.TextWrapped(u8(active_release.summary))

                imgui.Dummy(scale_imvec2(0, 10))
                imgui.Columns(2, "##changelog_where_how", false)
                imgui.SetColumnOffset(1, scale_value(160))
                imgui.TextColored(imgui.ImVec4(0.75,0.86,1.0,0.95), u8"Ãäå")
                imgui.NextColumn()
                imgui.TextColored(imgui.ImVec4(0.75,0.86,1.0,0.95), u8"Êàê îáíîâëåíî")
                imgui.NextColumn()
                imgui.Separator()

                for _, change in ipairs(active_release.changes) do
                    imgui.TextColored(imgui.ImVec4(1,1,1,0.95), u8(change.where))
                    imgui.NextColumn()
                    imgui.TextWrapped(u8(change.how))
                    imgui.NextColumn()
                    imgui.Separator()
                end
                imgui.Columns(1)
            imgui.EndChild()

            imgui.Dummy(scale_imvec2(0, 8))
        
        elseif current_tab[0] == 6 then
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"PIZDA")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 10))
            
            imgui.CustomToggle(u8"AHK Klava Sinhr", virtual_input_enabled, u8"Ïîäñâåòêà êëàâèø ïðè ââîäå ñêðèïòîì.")
            imgui.Dummy(scale_imvec2(0, 8))
            -- Layout selector combo
            if #ahk_kb_names > 0 then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"Ð Ð°ÑÐºÐ»Ð°Ð´ÐºÐ° ÐºÐ»Ð°Ð²Ð¸Ð°ÑÑÑÑ:")
                imgui.PushItemWidth(scale_value(200))
                if imgui.BeginCombo("##kb_layout", ahk_kb_names[ahk_kb_selected[0] + 1] or u8"ÐÐ²ÑÐ¾") then
                    for i, name in ipairs(ahk_kb_names) do
                        local selected = (ahk_kb_selected[0] == i - 1)
                        if imgui.Selectable(name, selected) then
                            ahk_kb_selected[0] = i - 1
                            klava_vsya[0] = (name:find(u8"ÑÐ¸ÑÑ") == nil)
                        end
                        if selected then imgui.SetItemDefaultFocus() end
                    end
                    imgui.EndCombo()
                end
                imgui.PopItemWidth()
                imgui.Dummy(scale_imvec2(0, 8))
            end
            imgui.CustomToggle(u8"Klava Vsya", klava_vsya, u8"Ïîêàçûâàòü ïîëíóþ êëàâèàòóðó âìåñòî òîëüêî öèôð.")
            imgui.Dummy(scale_imvec2(0, 8))
            imgui.CustomToggle(u8"V Chat", v_chat_enabled, u8"Ïðîáèâ (/time, /id, êàï÷à) ÷åðåç ðåàëüíûé ââîä â ÷àò.\nÒåêñò îñòà¸òñÿ â èñòîðèè ÷àòà.")
            
            imgui.Dummy(scale_imvec2(0, 15))
            imgui.TextColored(imgui.ImVec4(1,1,1,0.4), u8"ÍÀÑÒÐÎÉÊÈ ÂÈÐÒÓÀËÜÍÎÉ ÊËÀÂÈÀÒÓÐÛ")
            imgui.Separator()
            imgui.Dummy(scale_imvec2(0, 8))
            
            -- Çàêðóãëåíèå
            imgui.CustomToggle(u8"Çàêðóãëåíèå êëàâèø", ahk_kb_cfg.rounding, u8"Ñêðóãëÿòü óãëû êëàâèø.")
            imgui.Dummy(scale_imvec2(0, 6))
            
            -- Îáâîäêà
            imgui.CustomToggle(u8"Ïîêàçûâàòü îáâîäêó", ahk_kb_cfg.show_border, u8"Ïîêàçûâàòü ðàìêó âîêðóã êëàâèø.")
            imgui.Dummy(scale_imvec2(0, 6))
            
            -- Ïðîçðà÷íîñòü
            imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"Ïðîçðà÷íîñòü:")
            imgui.PushItemWidth(scale_value(200))
            imgui.CustomSlider("##kb_alpha", ahk_kb_cfg.alpha, 0.1, 1.0, "", "Ïðîçðà÷íîñòü êëàâèø.")
            imgui.PopItemWidth()
            imgui.Dummy(scale_imvec2(0, 6))
            
            -- Ðàçìåð
            imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"Ðàçìåð êëàâèø:")
            imgui.PushItemWidth(scale_value(200))
            imgui.CustomSlider("##kb_size", ahk_kb_cfg.key_size, 0.5, 2.0, "x", "Ìàñøòàá êëàâèø.")
            imgui.PopItemWidth()
            imgui.Dummy(scale_imvec2(0, 6))
            
            -- Öâåò àêòèâíîé êëàâèøè
            imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"Öâåò ïîäñâåòêè:")
            local preset_names = {u8"Ñèíèé", u8"Êðàñíûé", u8"Æ¸ëòûé", u8"Çåë¸íûé", u8"Ôèîëåòîâûé", u8"Ñâîé"}
            for i, name in ipairs(preset_names) do
                local idx = i - 1
                local selected = ahk_kb_cfg.color_preset[0] == idx
                if selected then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.5, 1.0, 1.0))
                end
                if imgui.Button(name, scale_imvec2(60, 22)) then
                    ahk_kb_cfg.color_preset[0] = idx
                end
                if selected then imgui.PopStyleColor() end
                if i < #preset_names then imgui.SameLine() end
            end
            
            -- Ñâîé öâåò
            if ahk_kb_cfg.color_preset[0] == 5 then
                imgui.Dummy(scale_imvec2(0, 6))
                imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"R:")
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(120))
                imgui.CustomSlider("##kb_cr", ahk_kb_cfg.custom_r, 0.0, 1.0, "", "Êðàñíûé.")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"G:")
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(120))
                imgui.CustomSlider("##kb_cg", ahk_kb_cfg.custom_g, 0.0, 1.0, "", "Çåë¸íûé.")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"B:")
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(120))
                imgui.CustomSlider("##kb_cb", ahk_kb_cfg.custom_b, 0.0, 1.0, "", "Ñèíèé.")
                imgui.PopItemWidth()
            end
            
            imgui.Dummy(scale_imvec2(0, 6))
            -- Öâåò ôîíà êëàâèø
            imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"Ôîí êëàâèø (R/G/B):")
            imgui.PushItemWidth(scale_value(120))
            imgui.CustomSlider("##kb_bgr", ahk_kb_cfg.bg_r, 0.0, 1.0, "", "Êðàñíûé ôîíà.")
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.PushItemWidth(scale_value(120))
            imgui.CustomSlider("##kb_bgg", ahk_kb_cfg.bg_g, 0.0, 1.0, "", "Çåë¸íûé ôîíà.")
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.PushItemWidth(scale_value(120))
            imgui.CustomSlider("##kb_bgb", ahk_kb_cfg.bg_b, 0.0, 1.0, "", "Ñèíèé ôîíà.")
            imgui.PopItemWidth()
            
            imgui.Dummy(scale_imvec2(0, 6))
            -- Öâåò îáâîäêè
            if ahk_kb_cfg.show_border[0] then
                imgui.TextColored(imgui.ImVec4(1,1,1,0.7), u8"Îáâîäêà (R/G/B/A):")
                imgui.PushItemWidth(scale_value(100))
                imgui.CustomSlider("##kb_bdr", ahk_kb_cfg.border_r, 0.0, 1.0, "", "Êðàñíûé îáâîäêè.")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(100))
                imgui.CustomSlider("##kb_bdg", ahk_kb_cfg.border_g, 0.0, 1.0, "", "Çåë¸íûé îáâîäêè.")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(100))
                imgui.CustomSlider("##kb_bdb", ahk_kb_cfg.border_b, 0.0, 1.0, "", "Ñèíèé îáâîäêè.")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.PushItemWidth(scale_value(100))
                imgui.CustomSlider("##kb_bda", ahk_kb_cfg.border_alpha, 0.0, 1.0, "", "Ïðîçðà÷íîñòü îáâîäêè.")
                imgui.PopItemWidth()
            end
        end
        
        imgui.PopStyleVar() 
    imgui.EndChild()
    imgui.End()
    imgui.RenderTooltip()
    
    imgui.PopStyleColor(11) 
    imgui.PopStyleVar()    
    imgui.PopStyleVar()    
    imgui.PopStyleVar()    
    imgui.PopStyleVar()    
end)


imgui.OnFrame(function()
    return #notifications.list > 0
end, function(self)
    self.HideCursor = true  
    
    local current_time = os.clock()
    local screen_x, screen_y = getScreenResolution()
    local y_offset = screen_y - 350
    
    imgui.SetNextWindowPos(imgui.ImVec2(screen_x / 2, y_offset), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
    imgui.SetNextWindowBgAlpha(0)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 10))
    
    if imgui.Begin("##notifications_overlay", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoInputs + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoSavedSettings) then
        local to_remove = {}
        for i, notif in ipairs(notifications.list) do
            local elapsed = current_time - notif.start_time
            if elapsed >= notifications.duration then
                table.insert(to_remove, i)
            else
                local alpha = 1.0
                if elapsed > notifications.duration - notifications.fade_time then
                    alpha = (notifications.duration - elapsed) / notifications.fade_time
                elseif elapsed < notifications.fade_time then
                    alpha = elapsed / notifications.fade_time
                end
                
                local col = notif.color
                
                local text_size = imgui.CalcTextSize(notif.text)
                local padding_x = 16
                local padding_y = 8
                local draw_list = imgui.GetForegroundDrawList()
                local cursor_pos = imgui.GetCursorScreenPos()
                
                
                local content_width = imgui.GetWindowContentRegionWidth()
                local offset_x = (content_width - text_size.x) / 2
                local text_pos = imgui.ImVec2(cursor_pos.x + offset_x, cursor_pos.y)
                
                local bg_min = imgui.ImVec2(text_pos.x - padding_x, text_pos.y - padding_y)
                local bg_max = imgui.ImVec2(text_pos.x + text_size.x + padding_x, text_pos.y + text_size.y + padding_y)
                local rounding = (text_size.y + padding_y * 2) / 2  
                draw_list:AddRectFilled(bg_min, bg_max, imgui.GetColorU32Vec4(imgui.ImVec4(0.08, 0.08, 0.1, 0.85 * alpha)), rounding, 0xF)
                draw_list:AddRect(bg_min, bg_max, imgui.GetColorU32Vec4(imgui.ImVec4(col.x, col.y, col.z, 0.5 * alpha)), rounding, 0xF, 2)
                
                
                draw_list:AddText(text_pos, imgui.GetColorU32Vec4(imgui.ImVec4(col.x, col.y, col.z, alpha)), notif.text)
                
                
                imgui.Dummy(imgui.ImVec2(text_size.x, text_size.y + padding_y * 2 + 4))
            end
        end
        
        for i = #to_remove, 1, -1 do
            table.remove(notifications.list, to_remove[i])
        end
        
        imgui.End()
    end
    
    imgui.PopStyleVar(2)
end)

-- Ìèíè-êëàâèàòóðà: öèôðû 0-9 + Enter, ïîêàçûâàåòñÿ êîãäà âêëþ÷åí ÷åêáîêñ
-- Èñïîëüçóåò renderKey èç keyboard[3.1.1] è ðàñêëàäêó "Òîëüêî öèôðû" èç keyboards.json

ahk_kb_data = nil  -- ðàñêëàäêà "Òîëüêî öèôðû"
ahk_kb_data_full = nil  -- ðàñêëàäêà "Áåç NumPad"
ahk_kb_keys = {}   -- ïëîñêèé ñïèñîê âñåõ êëàâèø äëÿ áûñòðîãî äîñòóïà ïî id

-- ñîáñòâåííûå ïåðåìåííûå ñòèëÿ äëÿ renderKey (íå çàâèñèì îò keyboard ñêðèïòà)
ahk_kb_colors = {
    main   = imgui.ImVec4(0.12, 0.12, 0.12, 0.95),
    active = imgui.ImVec4(0.15, 0.45, 1.0,  1.0)
}
ahk_kb_rounding = false

function ahk_renderKey(key)
    if not key then return end
    if not key.time then key.time = -1 end
    local DL = imgui.GetWindowDrawList()
    local cp = imgui.GetCursorScreenPos()
    local sz_x = key.size and key.size.x or 20
    local sz_y = key.size and key.size.y or 20
    local ks = ahk_kb_cfg and ahk_kb_cfg.key_size and ahk_kb_cfg.key_size[0] or 1.0
    local size = imgui.ImVec2(sz_x * ks, sz_y * ks)
    local raw = key.name or ""
    local text = raw:gsub('#.+', '')
    if key.id == 38 then text = "^" end
    if key.id == 40 then text = "v" end
    if key.id == 37 then text = "<" end
    if key.id == 39 then text = ">" end
    if key.id == 8  then text = "<-" end
    local ts = imgui.CalcTextSize(text)
    local a = cp
    local b = imgui.ImVec2(cp.x + size.x, cp.y + size.y)
    local tPos = imgui.ImVec2(a.x + (size.x - ts.x) / 2, a.y + (size.y - ts.y) / 2)
    local is_active = key.time >= os.clock()
    -- öâåò àêòèâíîé êëàâèøè èç ïðåñåòà
    local ar, ag, ab = 0.15, 0.45, 1.0
    if ahk_kb_cfg then
        local p = ahk_kb_cfg.color_preset[0]
        if     p == 0 then ar,ag,ab = 0.15,0.45,1.0
        elseif p == 1 then ar,ag,ab = 1.0, 0.15,0.15
        elseif p == 2 then ar,ag,ab = 1.0, 0.85,0.0
        elseif p == 3 then ar,ag,ab = 0.1, 0.85,0.2
        elseif p == 4 then ar,ag,ab = 0.6, 0.1, 1.0
        elseif p == 5 then ar,ag,ab = ahk_kb_cfg.custom_r[0], ahk_kb_cfg.custom_g[0], ahk_kb_cfg.custom_b[0]
        end
    end
    local alpha = ahk_kb_cfg and ahk_kb_cfg.alpha[0] or 0.95
    local bg_r  = ahk_kb_cfg and ahk_kb_cfg.bg_r[0] or 0.08
    local bg_g  = ahk_kb_cfg and ahk_kb_cfg.bg_g[0] or 0.08
    local bg_b  = ahk_kb_cfg and ahk_kb_cfg.bg_b[0] or 0.08
    local col = is_active
        and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar, ag, ab, alpha))
        or  imgui.ColorConvertFloat4ToU32(imgui.ImVec4(bg_r, bg_g, bg_b, alpha))
    local round = (ahk_kb_cfg and ahk_kb_cfg.rounding[0]) and 4 or 0
    imgui.Dummy(size)
    DL:AddRectFilled(imgui.ImVec2(a.x+1, a.y+1), imgui.ImVec2(b.x-1, b.y-1), col, round)
    if ahk_kb_cfg and ahk_kb_cfg.show_border[0] then
        local ba = ahk_kb_cfg.border_alpha[0]
        local br = ahk_kb_cfg.border_r[0]
        local bg = ahk_kb_cfg.border_g[0]
        local bb = ahk_kb_cfg.border_b[0]
        DL:AddRect(a, b, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(br, bg, bb, ba)), round, _, 1.2)
    end
    DL:AddText(tPos, 0xFFFFFFFF, text)
end

function ahk_kb_load()
    -- èùåì keyboards.json â íåñêîëüêèõ ìåñòàõ
    local paths = {
        getWorkingDirectory() .. "\\config\\keyboards.json",
        getWorkingDirectory() .. "\\keyboards.json",
    }
    local raw = nil
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            raw = f:read("*a")
            f:close()
            break
        end
    end
local _kb_default = "[{\"name\":\"\xc2\xf1\xff \xea\xeb\xe0\xe2\xe8\xe0\xf2\xf3\xf0\xe0\",\"keyboard\":{\"blocks\":[[[{\"name\":\"Esc\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":27},{\"name\":\"F1\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":112},{\"name\":\"F2\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":113},{\"name\":\"F3\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":114},{\"name\":\"F4\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":115},{\"name\":\"F5\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":116},{\"name\":\"F6\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":117},{\"name\":\"F7\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":118},{\"name\":\"F8\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":119},{\"name\":\"F9\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":120},{\"name\":\"F10\",\"time\":-1,\"size\":{\"y\":20,\"x\":24},\"id\":121}],[{\"time\":-1,\"name\":\"`\",\"id\":192},{\"time\":-1,\"name\":\"1\",\"id\":49},{\"time\":-1,\"name\":\"2\",\"id\":50},{\"time\":-1,\"name\":\"3\",\"id\":51},{\"time\":-1,\"name\":\"4\",\"id\":52},{\"time\":-1,\"name\":\"5\",\"id\":53},{\"time\":-1,\"name\":\"6\",\"id\":54},{\"time\":-1,\"name\":\"7\",\"id\":55},{\"time\":-1,\"name\":\"8\",\"id\":56},{\"time\":-1,\"name\":\"9\",\"id\":57},{\"time\":-1,\"name\":\"0\",\"id\":48},{\"time\":-1,\"name\":\"-\",\"id\":189},{\"time\":-1,\"name\":\"+\",\"id\":187},{\"name\":\"\xee\xa8\x9b\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":8}],[{\"name\":\"Tab\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":9},{\"time\":-1,\"name\":\"Q\",\"id\":81},{\"time\":-1,\"name\":\"W\",\"id\":87},{\"time\":-1,\"name\":\"E\",\"id\":69},{\"time\":-1,\"name\":\"R\",\"id\":82},{\"time\":-1,\"name\":\"T\",\"id\":84},{\"time\":-1,\"name\":\"Y\",\"id\":89},{\"time\":-1,\"name\":\"U\",\"id\":85},{\"time\":-1,\"name\":\"I\",\"id\":73},{\"time\":-1,\"name\":\"O\",\"id\":79},{\"time\":-1,\"name\":\"P\",\"id\":80},{\"time\":-1,\"name\":\"[\",\"id\":219},{\"time\":-1,\"name\":\"]\",\"id\":221},{\"time\":-1,\"name\":\"\\\\\",\"id\":220}],[{\"name\":\"Caps\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":20},{\"time\":-1,\"name\":\"A\",\"id\":65},{\"time\":-1,\"name\":\"S\",\"id\":83},{\"time\":-1,\"name\":\"D\",\"id\":68},{\"time\":-1,\"name\":\"F\",\"id\":70},{\"time\":-1,\"name\":\"G\",\"id\":71},{\"time\":-1,\"name\":\"H\",\"id\":72},{\"time\":-1,\"name\":\"J\",\"id\":74},{\"time\":-1,\"name\":\"K\",\"id\":75},{\"time\":-1,\"name\":\"L\",\"id\":76},{\"time\":-1,\"name\":\";\",\"id\":186},{\"time\":-1,\"name\":\"\\\"\",\"id\":222},{\"name\":\"Enter\",\"time\":-1,\"size\":{\"y\":20,\"x\":35},\"id\":13}],[{\"name\":\"LShift\",\"time\":-1,\"size\":{\"y\":20,\"x\":42},\"id\":160},{\"time\":-1,\"name\":\"Z\",\"id\":90},{\"time\":-1,\"name\":\"X\",\"id\":88},{\"time\":-1,\"name\":\"C\",\"id\":67},{\"time\":-1,\"name\":\"V\",\"id\":86},{\"time\":-1,\"name\":\"B\",\"id\":66},{\"time\":-1,\"name\":\"N\",\"id\":78},{\"time\":-1,\"name\":\"M\",\"id\":77},{\"time\":-1,\"name\":\",\",\"id\":188},{\"time\":-1,\"name\":\".\",\"id\":190},{\"time\":-1,\"name\":\"\\/\",\"id\":191},{\"name\":\"RShift\",\"time\":-1,\"size\":{\"y\":20,\"x\":45},\"id\":161}],[{\"name\":\"Ctrl\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":162},{\"name\":\"Win\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":91},{\"name\":\"Alt\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":164},{\"name\":\" \",\"time\":-1,\"size\":{\"y\":20,\"x\":127},\"id\":32},{\"name\":\"Alt\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":165},{\"name\":\"Win\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":92},{\"name\":\"Ctrl\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":163}]],[[{\"name\":\"F11\",\"time\":-1,\"size\":{\"y\":20,\"x\":24},\"id\":122},{\"name\":\"F12\",\"time\":-1,\"size\":{\"y\":20,\"x\":24},\"id\":123}],[{\"name\":\"Ins\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":45},{\"name\":\"HM\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":36},{\"name\":\"PU\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":33}],[{\"name\":\"Del\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":46},{\"name\":\"End\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":35},{\"name\":\"PD\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":34}],{},[{\"time\":-1,\"pos\":2.4,\"name\":\"\xee\xad\xa0\",\"id\":38}],[{\"time\":-1,\"pos\":1.4,\"name\":\"\xee\xad\x9e\",\"id\":37},{\"time\":-1,\"name\":\"\xee\xad\x9d\",\"id\":40},{\"time\":-1,\"name\":\"\xee\xad\x9f\",\"id\":39}]],[[{\"time\":-1,\"name\":\"PS\",\"id\":44},{\"time\":-1,\"name\":\"SL\",\"id\":145},{\"time\":-1,\"name\":\"P\",\"id\":19}],[{\"name\":\"NL\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":144},{\"name\":\"\\/\",\"time\":-1,\"size\":{\"y\":20,\"x\":18},\"id\":111},{\"name\":\"*\",\"time\":-1,\"size\":{\"y\":20,\"x\":18},\"id\":106},{\"time\":-1,\"name\":\"-\",\"id\":109}],[{\"time\":-1,\"name\":\"7\",\"id\":103},{\"time\":-1,\"name\":\"8\",\"id\":104},{\"time\":-1,\"name\":\"9\",\"id\":105},{\"name\":\"+\",\"time\":-1,\"size\":{\"y\":40,\"x\":20},\"id\":107}],[{\"id\":100,\"time\":-1,\"name\":\"4\",\"indent\":{\"y\":0,\"x\":84}},{\"time\":-1,\"name\":\"5\",\"id\":101},{\"time\":-1,\"name\":\"6\",\"id\":102}],[{\"time\":-1,\"name\":\"1\",\"id\":97},{\"time\":-1,\"name\":\"2\",\"id\":98},{\"time\":-1,\"name\":\"3\",\"id\":99},{\"name\":\"E\",\"time\":-1,\"size\":{\"y\":40,\"x\":20},\"id\":13}],[{\"name\":\"0\",\"time\":-1,\"size\":{\"y\":20,\"x\":40},\"id\":96},{\"time\":-1,\"name\":\".\",\"id\":110}]]]}},{\"name\":\"\xc1\xe5\xe7 NumPad\",\"keyboard\":{\"blocks\":[[[{\"name\":\"Esc\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":27},{\"name\":\"F1\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":112},{\"name\":\"F2\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":113},{\"name\":\"F3\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":114},{\"name\":\"F4\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":115},{\"name\":\"F5\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":116},{\"name\":\"F6\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":117},{\"name\":\"F7\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":118},{\"name\":\"F8\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":119},{\"name\":\"F9\",\"time\":-1,\"size\":{\"y\":20,\"x\":22},\"id\":120},{\"name\":\"F10\",\"time\":-1,\"size\":{\"y\":20,\"x\":24},\"id\":121}],[{\"time\":-1,\"name\":\"`\",\"id\":192},{\"time\":-1,\"name\":\"1\",\"id\":49},{\"time\":-1,\"name\":\"2\",\"id\":50},{\"time\":-1,\"name\":\"3\",\"id\":51},{\"time\":-1,\"name\":\"4\",\"id\":52},{\"time\":-1,\"name\":\"5\",\"id\":53},{\"time\":-1,\"name\":\"6\",\"id\":54},{\"time\":-1,\"name\":\"7\",\"id\":55},{\"time\":-1,\"name\":\"8\",\"id\":56},{\"time\":-1,\"name\":\"9\",\"id\":57},{\"time\":-1,\"name\":\"0\",\"id\":48},{\"time\":-1,\"name\":\"-\",\"id\":189},{\"time\":-1,\"name\":\"+\",\"id\":187},{\"name\":\"\xee\xa8\x9b\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":8}],[{\"name\":\"Tab\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":9},{\"time\":-1,\"name\":\"Q\",\"id\":81},{\"time\":-1,\"name\":\"W\",\"id\":87},{\"time\":-1,\"name\":\"E\",\"id\":69},{\"time\":-1,\"name\":\"R\",\"id\":82},{\"time\":-1,\"name\":\"T\",\"id\":84},{\"time\":-1,\"name\":\"Y\",\"id\":89},{\"time\":-1,\"name\":\"U\",\"id\":85},{\"time\":-1,\"name\":\"I\",\"id\":73},{\"time\":-1,\"name\":\"O\",\"id\":79},{\"time\":-1,\"name\":\"P\",\"id\":80},{\"time\":-1,\"name\":\"[\",\"id\":219},{\"time\":-1,\"name\":\"]\",\"id\":221},{\"time\":-1,\"name\":\"\\\\\",\"id\":220}],[{\"name\":\"Caps\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":20},{\"time\":-1,\"name\":\"A\",\"id\":65},{\"time\":-1,\"name\":\"S\",\"id\":83},{\"time\":-1,\"name\":\"D\",\"id\":68},{\"time\":-1,\"name\":\"F\",\"id\":70},{\"time\":-1,\"name\":\"G\",\"id\":71},{\"time\":-1,\"name\":\"H\",\"id\":72},{\"time\":-1,\"name\":\"J\",\"id\":74},{\"time\":-1,\"name\":\"K\",\"id\":75},{\"time\":-1,\"name\":\"L\",\"id\":76},{\"time\":-1,\"name\":\";\",\"id\":186},{\"time\":-1,\"name\":\"\\\"\",\"id\":222},{\"name\":\"Enter\",\"time\":-1,\"size\":{\"y\":20,\"x\":35},\"id\":13}],[{\"name\":\"LShift\",\"time\":-1,\"size\":{\"y\":20,\"x\":40},\"id\":160},{\"time\":-1,\"name\":\"Z\",\"id\":90},{\"time\":-1,\"name\":\"X\",\"id\":88},{\"time\":-1,\"name\":\"C\",\"id\":67},{\"time\":-1,\"name\":\"V\",\"id\":86},{\"time\":-1,\"name\":\"B\",\"id\":66},{\"time\":-1,\"name\":\"N\",\"id\":78},{\"time\":-1,\"name\":\"M\",\"id\":77},{\"time\":-1,\"name\":\",\",\"id\":188},{\"time\":-1,\"name\":\".\",\"id\":190},{\"time\":-1,\"name\":\"\\/\",\"id\":191},{\"name\":\"RShift\",\"time\":-1,\"size\":{\"y\":20,\"x\":45},\"id\":161}],[{\"name\":\"Ctrl\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":162},{\"name\":\"Win\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":91},{\"name\":\"Alt\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":164},{\"name\":\" \",\"time\":-1,\"size\":{\"y\":20,\"x\":128},\"id\":32},{\"name\":\"Alt\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":165},{\"name\":\"Win\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":92},{\"name\":\"Ctrl\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":163}]],[[{\"name\":\"F11\",\"time\":-1,\"size\":{\"y\":20,\"x\":24},\"id\":122},{\"name\":\"F12\",\"time\":-1,\"size\":{\"y\":20,\"x\":24},\"id\":123}],[{\"name\":\"Ins\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":45},{\"name\":\"HM\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":36},{\"name\":\"PU\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":33}],[{\"name\":\"Del\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":46},{\"name\":\"End\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":35},{\"name\":\"PD\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":34}],{},[{\"time\":-1,\"pos\":2.4,\"name\":\"\xee\xad\xa0\",\"id\":38}],[{\"time\":-1,\"pos\":1.4,\"name\":\"\xee\xad\x9e\",\"id\":37},{\"time\":-1,\"name\":\"\xee\xad\x9d\",\"id\":40},{\"time\":-1,\"name\":\"\xee\xad\x9f\",\"id\":39}]]]}},{\"name\":\"\xd2\xee\xeb\xfc\xea\xee \xf6\xe8\xf4\xf0\xfb\",\"keyboard\":{\"blocks\":[[[{\"time\":-1,\"name\":\"1\",\"id\":49},{\"time\":-1,\"name\":\"2\",\"id\":50},{\"time\":-1,\"name\":\"3\",\"id\":51},{\"time\":-1,\"name\":\"4\",\"id\":52},{\"time\":-1,\"name\":\"5\",\"id\":53},{\"time\":-1,\"name\":\"6\",\"id\":54},{\"time\":-1,\"name\":\"7\",\"id\":55},{\"time\":-1,\"name\":\"8\",\"id\":56},{\"time\":-1,\"name\":\"9\",\"id\":57},{\"time\":-1,\"name\":\"0\",\"id\":48}],[{\"time\":-1,\"name\":\"N\",\"id\":78},{\"name\":\" Enter \",\"time\":-1,\"size\":{\"y\":20,\"x\":40},\"id\":13}]]]}},{\"name\":\"\xca\xee\xec\xef\xe0\xea\xf2\xed\xfb\xe5 \xf6\xe8\xf4\xf0\xfb\",\"keyboard\":{\"blocks\":[[[{\"time\":-1,\"name\":\"1\",\"id\":49},{\"time\":-1,\"name\":\"2\",\"id\":50},{\"time\":-1,\"name\":\"3\",\"id\":51}],[{\"time\":-1,\"name\":\"4\",\"id\":52},{\"time\":-1,\"name\":\"5\",\"id\":53},{\"time\":-1,\"name\":\"6\",\"id\":54}],[{\"time\":-1,\"name\":\"7\",\"id\":55},{\"time\":-1,\"name\":\"8\",\"id\":56},{\"time\":-1,\"name\":\"9\",\"id\":57}],[{\"time\":-1,\"name\":\"0\",\"id\":48},{\"time\":-1,\"name\":\"N\",\"id\":78}],[{\"name\":\" Enter \",\"time\":-1,\"size\":{\"y\":20,\"x\":40},\"id\":13}]]]}},{\"name\":\"\xca\xed\xee\xef\xea\xe8 \xf3\xef\xf0\xe0\xe2\xeb\xe5\xed\xe8\xff\",\"keyboard\":{\"blocks\":[[[{\"name\":\"Tab\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":9},{\"time\":-1,\"name\":\"Q\",\"id\":81},{\"time\":-1,\"name\":\"W\",\"id\":87},{\"time\":-1,\"name\":\"E\",\"id\":69},{\"time\":-1,\"name\":\"R\",\"id\":82}],[{\"name\":\"Shift\",\"time\":-1,\"size\":{\"y\":20,\"x\":35},\"id\":16},{\"time\":-1,\"name\":\"A\",\"id\":65},{\"time\":-1,\"name\":\"S\",\"id\":83},{\"time\":-1,\"name\":\"D\",\"id\":68},{\"time\":-1,\"name\":\"C\",\"id\":67}],[{\"name\":\"Ctrl\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":162},{\"name\":\"Alt\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":164},{\"name\":\" \",\"time\":-1,\"size\":{\"y\":20,\"x\":65},\"id\":32}]]]}},{\"name\":\"\xd2\xee\xeb\xfc\xea\xee NumPad\",\"keyboard\":{\"blocks\":[[[{\"time\":-1,\"name\":\"NL\",\"id\":144},{\"time\":-1,\"name\":\"\\/\",\"id\":111},{\"time\":-1,\"name\":\"*\",\"id\":106},{\"time\":-1,\"name\":\"-\",\"id\":109}],[{\"time\":-1,\"name\":\"7\",\"id\":103},{\"time\":-1,\"name\":\"8\",\"id\":104},{\"time\":-1,\"name\":\"9\",\"id\":105},{\"name\":\"+\",\"time\":-1,\"size\":{\"y\":40,\"x\":20},\"id\":107}],[{\"time\":-1,\"name\":\"4\",\"id\":100},{\"time\":-1,\"name\":\"5\",\"id\":101},{\"time\":-1,\"name\":\"6\",\"id\":102}],[{\"time\":-1,\"name\":\"1\",\"id\":97},{\"time\":-1,\"name\":\"2\",\"id\":98},{\"time\":-1,\"name\":\"3\",\"id\":99},{\"name\":\"E\",\"time\":-1,\"size\":{\"y\":40,\"x\":20},\"id\":13}],[{\"name\":\"0\",\"time\":-1,\"size\":{\"y\":20,\"x\":40},\"id\":96},{\"time\":-1,\"name\":\".\",\"id\":110}]]]}},{\"name\":\"\xd1\xe2\xee\xff\",\"keyboard\":{\"blocks\":[[[{\"name\":\"Tab\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":9},{\"time\":-1,\"name\":\"Q\",\"id\":81},{\"time\":-1,\"name\":\"W\",\"id\":87},{\"time\":-1,\"name\":\"E\",\"id\":69},{\"time\":-1,\"name\":\"R\",\"id\":82}],[{\"name\":\"Shift\",\"time\":-1,\"size\":{\"y\":20,\"x\":35},\"id\":16},{\"time\":-1,\"name\":\"A\",\"id\":65},{\"time\":-1,\"name\":\"S\",\"id\":83},{\"time\":-1,\"name\":\"D\",\"id\":68},{\"time\":-1,\"name\":\"C\",\"id\":67}],[{\"name\":\"Ctrl\",\"time\":-1,\"size\":{\"y\":20,\"x\":30},\"id\":162},{\"name\":\"Alt\",\"time\":-1,\"size\":{\"y\":20,\"x\":25},\"id\":164},{\"name\":\" \",\"time\":-1,\"size\":{\"y\":20,\"x\":65},\"id\":32}]]]}}]"
    local _kb_path = getWorkingDirectory() .. "\\config\\keyboards.json"
    if not raw then
        local _dir = getWorkingDirectory() .. "\\config"
        os.execute('mkdir "' .. _dir .. '" 2>nul')
        local _wf = io.open(_kb_path, "wb")
        if _wf then
            _wf:write(_kb_default)
            _wf:close()
            local _rf = io.open(_kb_path, "rb")
            if _rf then raw = _rf:read("*a"); _rf:close() end
        end
    end
    if not raw then return end
    local ok, data = pcall(decodeJson, raw)
    if not ok or type(data) ~= "table" then return end
    -- èùåì íóæíûå ðàñêëàäêè
    for _, kb in ipairs(data) do
        local n = kb.name or ""
        if n == u8"Òîëüêî öèôðû" or n == "Òîëüêî öèôðû" then
            ahk_kb_data = kb
        end
        if n == u8"Áåç NumPad" or n == "Áåç NumPad" then
            ahk_kb_data_full = kb
        end
    end
    if not ahk_kb_data then ahk_kb_data = data[1] end
    if not ahk_kb_data_full then ahk_kb_data_full = ahk_kb_data end
    -- ñòðîèì èíäåêñ êëàâèø ïî id (ïî îáåèì ðàñêëàäêàì)
    ahk_kb_keys = {}
    local function index_kb(kb)
        if not kb or not kb.keyboard or not kb.keyboard.blocks then return end
        for _, block in ipairs(kb.keyboard.blocks) do
            for _, line in ipairs(block) do
                for _, key in ipairs(line) do
                    if key.id then
                        if not ahk_kb_keys[key.id] then
                            ahk_kb_keys[key.id] = key
                        end
                        if not key.time then key.time = -1 end
                    end
                end
            end
        end
    end
    index_kb(ahk_kb_data)
    index_kb(ahk_kb_data_full)
    
    -- store all layouts for selector
    ahk_kb_all = data
    ahk_kb_names = {}
    for i, kb in ipairs(data) do
        local n = kb.name or ("Layout "..i)
        if n:find("[\192-\255]") then n = u8(n) end
        table.insert(ahk_kb_names, n)
    end
end

-- ïîäñâåòèòü êëàâèøó ïî id íà 200ìñ
function VKI.highlight_id(id)
    -- îáíîâëÿåì time âî âñåõ ðàñêëàäêàõ
    if ahk_kb_keys and ahk_kb_keys[id] then
        ahk_kb_keys[id].time = os.clock() + 0.2
    end
    -- òàêæå îáíîâëÿåì â ïîëíîé ðàñêëàäêå åñëè êëàâèøà òàì äðóãîé îáúåêò
    if ahk_kb_data_full and ahk_kb_data_full.keyboard and ahk_kb_data_full.keyboard.blocks then
        for _, block in ipairs(ahk_kb_data_full.keyboard.blocks) do
            for _, line in ipairs(block) do
                for _, key in ipairs(line) do
                    if key.id == id then
                        key.time = os.clock() + 0.2
                    end
                end
            end
        end
    end
    if ahk_kb_data and ahk_kb_data.keyboard and ahk_kb_data.keyboard.blocks then
        for _, block in ipairs(ahk_kb_data.keyboard.blocks) do
            for _, line in ipairs(block) do
                for _, key in ipairs(line) do
                    if key.id == id then
                        key.time = os.clock() + 0.2
                    end
                end
            end
        end
    end
end

imgui.OnFrame(
    function()
        return virtual_input_enabled ~= nil and virtual_input_enabled[0] and not isGamePaused()
    end,
    function(player)
        -- çàãðóæàåì ðàñêëàäêó ïðè ïåðâîì ïîêàçå
        if not ahk_kb_data then ahk_kb_load() end
        if not ahk_kb_data then return end

        -- âûáèðàåì ðàñêëàäêó
        local kb
            if ahk_kb_selected[0] >= 0 and ahk_kb_all[ahk_kb_selected[0] + 1] then
                kb = ahk_kb_all[ahk_kb_selected[0] + 1]
            else
                kb = (klava_vsya and klava_vsya[0] and ahk_kb_data_full) or ahk_kb_data
            end
        if not kb then return end

        player.HideCursor = true

        local sX, sY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(sX - 300, sY - 80), imgui.Cond.FirstUseEver)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(5, 2.4))
        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(2, 2))
        imgui.Begin("##ahk_kb", nil,
            imgui.WindowFlags.NoTitleBar +
            imgui.WindowFlags.NoResize +
            imgui.WindowFlags.AlwaysAutoResize +
            imgui.WindowFlags.NoBringToFrontOnFocus
        )

        local spacing = imgui.GetStyle().ItemSpacing
        for _, block in ipairs(kb.keyboard.blocks) do
            imgui.BeginGroup()
            for _, line in ipairs(block) do
                local y = imgui.GetCursorPosY()
                if #line > 0 then
                    for i, key in ipairs(line) do
                        if not key.time then key.time = -1 end
                        -- â KeySpoof ðåæèìå íå ïîêàçûâàåì ôèçè÷åñêèå íàæàòèÿ
                        local ks_in_dialog = sampIsDialogActive() and (function()
                            local p = profile_helpers and profile_helpers.get_profile_for_dialog and profile_helpers.get_profile_for_dialog(sampGetCurrentDialogId())
                            return p and p.mode and p.mode[0] == 2
                        end)()
                        if not ks_in_dialog and isKeyDown(key.id) then key.time = os.clock() + 0.015 end
                        local pos = key.pos
                        if key.id == 38 then pos = 2.4 end
                        if pos then
                            local x = imgui.GetCursorPosX()
                            imgui.SetCursorPosX((x + 20 * (pos - 1)) + spacing.x * (pos - 1))
                        end
                        ahk_renderKey(key)
                        if i ~= #line then imgui.SameLine() end
                    end
                end
                -- âûñîòà ñòðîêè = âûñîòà êíîïêè (20) + spacing
                local line_h = 20
                if #line > 0 then
                    for _, k in ipairs(line) do
                        if k.size and k.size.y and k.size.y > line_h then line_h = k.size.y end
                    end
                end
                imgui.SetCursorPosY(y + line_h + spacing.y)
            end
            imgui.EndGroup()
            imgui.SameLine()
        end

        imgui.End()
        imgui.PopStyleColor()
        imgui.PopStyleVar(3)
    end
)


function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage(state.get_training_style().loaded, -1)

    refresh_training_toggle_command({ save_on_change = true })
    refresh_menu_command_registration({ save_on_change = true })

    lua_thread.create(function()
        local idle_wait = 50
        while true do
            if detect_server_captcha() then
                wait(0)
            elseif sampIsDialogActive() and not is_active_training_dialog(sampGetCurrentDialogId()) and not sorted then
                wait(0)
            else
                wait(idle_wait)
            end
        end
    end)

    while true do wait(0)
        local chat_active = sampIsChatInputActive()
        local dialog_active = sampIsDialogActive()
        
        if autoprobiv.pending and not autoprobiv.running then
            
            if not chat_active and not dialog_active then
                autoprobiv.pending = false
                run_autoprobiv()
            end
            
        end
        
        
        if keybind_capture.active then
            for i = 1, 255 do
                if isKeyJustPressed(i) then
                    if i == vkeys.VK_ESCAPE then
                        cancel_key_capture()
                    else
                        if keybind_capture.setter then
                            keybind_capture.setter(i)
                        end
                        cancel_key_capture()
                    end
                    break
                end
            end
        else
            handle_misc_hotkeys()
            if not chat_active and not dialog_active then
                handle_chat_keyspoof_hotkeys()
            end
        end

        local chat_is_active = chat_active
        if chat_keyspoof.mode and chat_is_active then
            
            if not chat_keyspoof.chat_was_open then
                chat_keyspoof.chat_was_open = true
                chat_keyspoof.char_count = 0
                chat_keyspoof.pending_send = false
                
                sampSetChatInputText("")
            else
                
                local target_text = get_keyspoof_target_text()
                
                if target_text and #target_text > 0 then
                    local current_time = os.clock() * 1000  
                    
                    
                    if chat_keyspoof.auto_enter[0] then
                        if chat_keyspoof.char_count >= #target_text then
                            
                            if not chat_keyspoof.pending_send then
                                local delay = chat_keyspoof.auto_enter_delay[0]
                                local spread = 0
                                if chat_keyspoof.auto_enter_spread_enabled[0] then
                                    spread = chat_keyspoof.auto_enter_spread[0]
                                end
                                local random_delay = delay
                                if spread > 0 then
                                    random_delay = delay + math.random(-spread, spread)
                                end
                                if random_delay < 0 then random_delay = 0 end
                                chat_keyspoof.send_time = current_time + random_delay
                                chat_keyspoof.pending_send = true
                            elseif current_time >= chat_keyspoof.send_time then
                                
                                local text_to_send = sampGetChatInputText() or target_text
                                if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                                    VKI.highlight("enter")
                                end
                                sampSendChat(text_to_send)
                                sampSetChatInputText("")
                                sampSetChatInputEnabled(false)
                                chat_keyspoof.char_count = 0
                                chat_keyspoof.pending_send = false
                                chat_keyspoof_clear_errors()
                                generate_keyspoof_error_plan()
                            end
                        else
                            
                            chat_keyspoof.pending_send = false
                        end
                    
                    elseif chat_keyspoof.char_count >= #target_text and isKeyJustPressed(vkeys.VK_RETURN) then
                        local text_to_send = sampGetChatInputText() or target_text
                        if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then
                            VKI.highlight("enter")
                        end
                        sampSendChat(text_to_send)
                        sampSetChatInputText("")
                        sampSetChatInputEnabled(false)
                        chat_keyspoof.char_count = 0
                        chat_keyspoof_clear_errors()
                        generate_keyspoof_error_plan()
                    end
                end
            end
        elseif not chat_is_active then
            
            if chat_keyspoof.chat_was_open then
                chat_keyspoof.char_count = 0
                chat_keyspoof.chat_was_open = false
                chat_keyspoof.pending_send = false
                chat_keyspoof.suppress_next_char = false
                chat_keyspoof._wm_toggled = false
                chat_keyspoof_clear_errors()
                
                if chat_keyspoof.mode then
                    generate_keyspoof_error_plan()
                end
            end
        end
        
        
        if not keybind_capture.active and not chat_active and not dialog_active then
            handle_autoprobiv_hotkeys()
        end
        
           
           if not dialog_active and not chat_active and config.input.menu_cheat_enabled ~= false and testCheat(config.input.cheat_code or cheat_code_active) then
               toggle_main_menu_state()
        end

        local active_training_style = get_selected_training_style()
        local style_ignores_training_command = active_training_style and active_training_style.force_bind_without_command
        local command_required_for_bind = (config.input.training_bind_requires_command ~= false) and not style_ignores_training_command
        local training_hotkey_allowed = (not command_required_for_bind) or training_enabled

        local _training_just_opened = false
        if isKeyJustPressed(config.input.hotkey) and training_hotkey_allowed and not training_menu_lock and not dialog_active and not chat_active then
            Training_Show()
            _training_just_opened = true
        end

        local result, button, list, input = false, 0, 0, ""
        if training_state then
            result, button, list, input = sampHasDialogRespond(get_training_dialog_id())
        end
        if result and training_state then
            kolvokapchi = 0
            keyspoof_tails["training"] = ""
            local style_cfg = get_training_style_for_runtime() or state.training_styles[0]
            if button == 1 then
                local resStr = training_str .. '0'
                local time = os.clock() - training_captime
                if input == resStr then
                    sampAddChatMessage(style_cfg.correct(time, resStr, input), -1)
                    if style_cfg.new_record then
                        local record_key = tostring(training_active_style_index or 0)
                        local best_time = training_best_times[record_key]
                        if not best_time or best_time <= 0 or time < best_time then
                            training_best_times[record_key] = time
                            if (training_active_style_index or 0) == 2 and config and config.input then
                                config.input.shapez_best_time = time
                                cfg_module.save({ silent = true })
                            end
                            sampAddChatMessage(style_cfg.new_record(time), -1)
                        end
                    end
                else
                    sampAddChatMessage(style_cfg.wrong(time, resStr, input), -1)
                end
            end
            Training_Clear()
        end
        
        
        
        local dialog_active = sampIsDialogActive()
        local current_dialog_id = dialog_active and sampGetCurrentDialogId() or -1
        local current_profile, current_profile_key = profile_helpers.get_profile_for_dialog(current_dialog_id)

        if dialog_active and not _training_just_opened then
            local _ks_all_keys = {}
            for i = S_CONST.KEY_DIGIT_START, S_CONST.KEY_DIGIT_END do _ks_all_keys[#_ks_all_keys+1] = i end
            for i = vkeys.VK_A, vkeys.VK_Z do _ks_all_keys[#_ks_all_keys+1] = i end
            for i = vkeys.VK_NUMPAD0, vkeys.VK_NUMPAD9 do _ks_all_keys[#_ks_all_keys+1] = i end
            for _, i in ipairs(_ks_all_keys) do
                if isKeyJustPressed(i) then
                    if current_profile.mode[0] == 2 and not current_profile.keyspoof_allow_extra[0] then
                        kolvokapchi = kolvokapchi + 1
                        local _cap_now = tostring(captchaS0 or "") .. tostring(captchaS1 or "") .. tostring(captchaS2 or "") .. tostring(captchaS3 or "") .. tostring(captchaS4 or "")
                        local _digit_show = _cap_now:sub(kolvokapchi, kolvokapchi)
                        if _digit_show ~= "" and virtual_input_enabled ~= nil and virtual_input_enabled[0] then
                            VKI.highlight(_digit_show)
                        end
                        if kolvokapchi > CAPTCHA_LENGTH then
                            keyspoof_tails[current_profile_key] = (keyspoof_tails[current_profile_key] or "") .. string.char(i)
                        end
                    elseif kolvokapchi < CAPTCHA_LENGTH then
                        kolvokapchi = kolvokapchi + 1
                        local _cap_now = tostring(captchaS0 or "") .. tostring(captchaS1 or "") .. tostring(captchaS2 or "") .. tostring(captchaS3 or "") .. tostring(captchaS4 or "")
                        local _digit_show = _cap_now:sub(kolvokapchi, kolvokapchi)
                        if _digit_show ~= "" then
                            VKI.highlight(_digit_show)
                        end
                    end
                    captcha_state.input_char(string.char(i))
                    profile_helpers.trim_keyspoof_tail(current_profile_key)
                end
            end
            if isKeyJustPressed(vkeys.VK_BACK) and kolvokapchi > 0 then
                if current_profile.mode[0] == 2 and not current_profile.keyspoof_allow_extra[0] and kolvokapchi > CAPTCHA_LENGTH then
                    local tail = keyspoof_tails[current_profile_key] or ""
                    keyspoof_tails[current_profile_key] = tail:sub(1, math.max(0, #tail - 1))
                end
                kolvokapchi = kolvokapchi - 1
                captcha_state.input_backspace()
                profile_helpers.trim_keyspoof_tail(current_profile_key)
                VKI.highlight("back")
            end
            if kolvokapchi <= 0 then
                reset_profile_mistake_state(current_profile_key)
            end
        else
            keyspoof_tails[current_profile_key] = ""
            reset_profile_mistake_state(current_profile_key)
        end

        local is_captcha_dialog = (is_active_training_dialog(current_dialog_id) or ((dtitle:find("Ïðîâåðêà íà ðîáîòà") or dtitle:find("Êàï÷à")) and dtext:find("ñèìâîëîâ")))
        local captcha_active = dialog_active and is_captcha_dialog
        if captcha_active and flooder_enabled[0] then
            setup_flooder(false)
        end
        keyspoof_dialog_mode2_active = (current_profile.mode[0] == 2 and is_captcha_dialog == true and dialog_active == true)
        if current_profile.mode[0] == 2 and is_captcha_dialog and sampIsLocalPlayerSpawned() and dialog_active then
            local cap = tostring(captchaS0 or "") .. tostring(captchaS1 or "") .. tostring(captchaS2 or "") .. tostring(captchaS3 or "") .. tostring(captchaS4 or "")
            local digits_to_show = math.max(0, math.min(kolvokapchi, CAPTCHA_LENGTH))
            local tail = keyspoof_tails[current_profile_key] or ""
            local extra_len = math.max(0, math.min(kolvokapchi - CAPTCHA_LENGTH, #tail))
            local extra_text = extra_len > 0 and tail:sub(1, extra_len) or ""
            
            local final_cap, mistake_plan = apply_profile_mistake_plan(current_profile_key, current_profile, cap)
            mistake_plan = mistake_plan or {}
            
            local visible_text = ""
            for pos = 1, digits_to_show do
                local char = final_cap:sub(pos, pos)
                local mistake = mistake_plan[pos]
                if mistake then
                    if mistake.fix then
                        visible_text = visible_text .. char
                    else
                        visible_text = visible_text .. mistake.wrong
                    end
                else
                    visible_text = visible_text .. char
                end
            end
            
            sampSetCurrentDialogEditboxText(visible_text .. extra_text)

            local actual_result = ""
            for pos = 1, math.min(#final_cap, CAPTCHA_LENGTH) do
                local mistake = mistake_plan[pos]
                if mistake and not mistake.fix then
                    actual_result = actual_result .. mistake.wrong
                else
                    actual_result = actual_result .. final_cap:sub(pos, pos)
                end
            end
            
            if kolvokapchi >= CAPTCHA_LENGTH and #actual_result >= CAPTCHA_LENGTH then
                remember_captcha(actual_result, cap)
            end
            
            
            if kolvokapchi >= CAPTCHA_LENGTH and current_profile.auto_enter[0] and not key_spoof_sent then
                local send_cap = actual_result:sub(1, CAPTCHA_LENGTH)
                
                
                if current_profile.keyspoof_allow_extra[0] then
                    sampSetCurrentDialogEditboxText(send_cap)
                end

                key_spoof_sent = true
                lua_thread.create(function()
                    local is_training_dialog_now = is_active_training_dialog(current_dialog_id)
                    wait(50)
                    if (virtual_input_enabled ~= nil) and virtual_input_enabled[0] then VKI.highlight("enter") end
                    sampSendDialogResponse(current_dialog_id, 1, 0, send_cap)
                    sampCloseCurrentDialogWithButton(1)
                    remember_captcha(send_cap, cap)

                    
                    if autoprobiv_allowed(is_training_dialog_now) then
                        wait(50) 
                        autoprobiv.schedule_after_captcha(is_training_dialog_now)
                    end

                    wait(100)
                    key_spoof_sent = false
                end)
            end
        end

        local now = os.clock()
        if collision_toggle[0] then
            if (now - collision_runtime.last_update) >= collision_runtime.interval then
                setPedCollisionState(true)
                collision_runtime.last_update = now
                collision_runtime.active = true
            end
        elseif collision_runtime.active then
            setPedCollisionState(false)
            collision_runtime.active = false
            collision_runtime.last_update = now
        end

        enforce_chat_block()
    end
end

function samp.onSendChat(message)
    if type(message) ~= 'string' then return end

    local normalized_training_command = normalize_training_toggle_command(config.input.training_toggle_command)
    local has_normalization_changes = false
    if normalized_training_command ~= config.input.training_toggle_command then
        config.input.training_toggle_command = normalized_training_command
        ffi.fill(training_toggle_command_buffer, 32, 0)
        ffi.copy(training_toggle_command_buffer, normalized_training_command)
        update_training_chat_command_registration(normalized_training_command, config.input.training_bind_requires_command ~= false)
        has_normalization_changes = true
    end

    local normalized_menu_command = normalize_menu_command(config.input.menu_command, normalized_training_command)
    if normalized_menu_command ~= config.input.menu_command then
        config.input.menu_command = normalized_menu_command
        ffi.fill(menu_command_buffer, 32, 0)
        ffi.copy(menu_command_buffer, normalized_menu_command)
        has_normalization_changes = true
    end

    update_menu_chat_command_registration(normalized_menu_command, config.input.menu_command_enabled ~= false)

    if has_normalization_changes then
        cfg_module.save({ silent = true })
    end

    if config.input.menu_command_enabled == false then return end

    local typed_command, typed_args = message:match("^%s*/([^%s]+)%s*(.-)%s*$")
    if not typed_command then return end
    if typed_args ~= "" then return end

    if typed_command:lower() ~= normalized_menu_command then return end

    toggle_main_menu_state()
    return false
end

function samp.onSendCommand(command)
    if type(command) ~= 'string' then return end
    local text = command
    if text:sub(1, 1) ~= '/' then
        text = '/' .. text
    end
    return samp.onSendChat(text)
end

function samp.onShowTextDraw(id, data)
    _G[id..'td'] = data
    if data.text:find('usebox') or data.text:find('white') then table.insert(captcha_td_ids, id) end
end

function samp.onSendDialogResponse(dialogId, button, listboxId, input)
    local is_training_dialog = is_active_training_dialog(dialogId) or (training_state and dialogId == get_training_dialog_id())
    local profile_key = is_training_dialog and "training" or "server"
    
    if button == 1 and #input == 5 and tonumber(input) then
        local detected_captcha = string.format("%s%s%s%s%s", captchaS0 or "", captchaS1 or "", captchaS2 or "", captchaS3 or "", captchaS4 or "")
        remember_captcha(input, detected_captcha)
        
        autoprobiv.schedule_after_captcha(is_training_dialog)
    end
    reset_captcha_session(profile_key)
end

function samp.onShowDialog(id, style, title, btn1, btn2, text)
    local is_training_dialog = is_active_training_dialog(id) or (training_state and is_training_dialog_signature(id, title, text))
    local profile_key = is_training_dialog and "training" or "server"
    kolvokapchi = 0; dtitle = title; dtext = text; key_spoof_sent = false
    keyspoof_tails[profile_key] = ""
    reset_profile_mistake_state(profile_key)
    
    if profile_key == "server" then
        captchaS0, captchaS1, captchaS2, captchaS3, captchaS4 = nil, nil, nil, nil, nil
    end
    
    captcha_state.start(profile_key, id)

    local is_video_dialog = flooder_helpers.is_video_card_dialog(id, title, text)
    if is_video_dialog and flooder_enabled[0] then
        flooder_helpers.press_dialog_enter(id)
        flooder_helpers.start_buy_loop(id)
    end

    
    
    local is_captcha_dialog = false
    if sampIsLocalPlayerSpawned() and not is_training_dialog then
        local has_symbols_marker = dtext:find("ñèìâîëîâ") or dtext:find("5 ñèìâîëîâ")
        local has_captcha_title = dtitle:find("Ïðîâåðêà íà ðîáîòà") or dtitle:find("Êàï÷à") or dtitle:find("{FFCC99}")
        
        if has_symbols_marker and has_captcha_title then
            is_captcha_dialog = true
        end
    end
    
    if is_captcha_dialog then
        run_ahk_simulation(id, "server")
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() and aSave[0] then SaveConfig({ silent = true }) end
    if Training_Clear then Training_Clear() end
end
