addon.name      = 'ashitamove';
addon.author    = 'EflfK';
addon.version   = '0.1.4';
addon.desc      = 'Display-only native menu detection and Spectral Focus modal coordination for Ashita v4.';
addon.link      = 'https://github.com/EflfK/ashitamove';

require('common');

local chat = require('chat');
local ffi = require('ffi');

pcall(ffi.cdef, [[
    typedef struct ashitamove_modal_event_t {
        uint32_t version;
        uint32_t active;
        char menu_name[32];
    } ashitamove_modal_event_t;
]]);

local MODAL_PATTERNS = {
    'loot', 'comyn', 'comment',
    'mount', 'emote', 'magselec', 'jobcselu',
    'mogdoor', 'chatctrl', 'arealist', 'maplist', 'gmtell', 'merityn', 'roomlist',
    'fep', 'rmlo2', 'shopbuy', 'guildsho', 'shopmain', 'shopsell', 'abiselec',
    'mogext', 'myroom', 'storage', 'mogpost', 'jobchang',
};

local state = {
    menu_pointer = 0,
    name = '',
    modal = false,
    debug = false,
    last_poll = 0,
    last_publish = 0,
};

local function log_info(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function log_error(message)
    print(chat.header(addon.name):append(chat.error(message)));
end

local function resolve_menu_pointer()
    local pointer = AshitaCore:GetPointerManager():Get('menu');
    if (pointer ~= nil and pointer ~= 0) then
        pointer = ashita.memory.read_uint32(pointer);
    else
        pointer = ashita.memory.find('FFXiMain.dll', 0,
            '8B480C85C974??8B510885D274??3B05', 16, 0);
        if (pointer ~= nil and pointer ~= 0) then
            pointer = ashita.memory.read_uint32(pointer);
        end
    end
    state.menu_pointer = pointer or 0;
    return state.menu_pointer ~= 0;
end

local function current_menu_name()
    if (state.menu_pointer == 0 and not resolve_menu_pointer()) then
        return '';
    end

    local ok, name = pcall(function ()
        local menu = ashita.memory.read_uint32(state.menu_pointer);
        if (menu == 0) then return ''; end
        local name_block = ashita.memory.read_uint32(menu + 0x04);
        if (name_block == 0) then return ''; end
        return ashita.memory.read_string(name_block + 0x46, 16);
    end);
    if (not ok or name == nil) then return ''; end

    name = name:gsub('\x00', '');
    return name:match('^%s*(.-)%s*$') or '';
end

local function is_modal_menu(name)
    if (name == '') then return false; end
    local lower = name:lower();
    for _, pattern in ipairs(MODAL_PATTERNS) do
        if (lower:find(pattern, 1, true) ~= nil) then
            return true;
        end
    end
    return false;
end

local function copy_event_string(buffer, value, max_length)
    value = tostring(value or '');
    local length = math.min(#value, max_length);
    ffi.fill(buffer, max_length + 1, 0);
    if (length > 0) then
        ffi.copy(buffer, value, length);
    end
end

local function publish_state()
    _G.SpectralFocus = _G.SpectralFocus or {};
    _G.SpectralFocus.menu = _G.SpectralFocus.menu or {};
    _G.SpectralFocus.menu.active = state.name ~= '';
    _G.SpectralFocus.menu.modal = state.modal;
    _G.SpectralFocus.menu.name = state.name;
    _G.SpectralFocus.menu.updated_at = os.clock();

    local payload = ffi.new('ashitamove_modal_event_t');
    payload.version = 1;
    payload.active = state.modal and 1 or 0;
    copy_event_string(payload.menu_name, state.name, 31);
    local data = ffi.string(payload, ffi.sizeof(payload)):totable();
    AshitaCore:GetPluginManager():RaiseEvent('ashitamove_modal_v1', data);
    state.last_publish = os.clock();
end

local function update_menu_state()
    local name = current_menu_name();
    if (name == state.name) then return; end

    state.name = name;
    state.modal = is_modal_menu(name);
    publish_state();

    if (state.debug) then
        log_info(('Menu: %s; modal: %s.'):fmt(
            state.name ~= '' and state.name or '(closed)',
            state.modal and 'yes' or 'no'));
    end
end

local function print_status()
    update_menu_state();
    publish_state();
    log_info(('Menu: %s; modal: %s; debug: %s.'):fmt(
        state.name ~= '' and state.name or '(closed)',
        state.modal and 'yes' or 'no',
        state.debug and 'on' or 'off'));
end

ashita.events.register('load', 'load_cb', function ()
    if (not resolve_menu_pointer()) then
        log_error('Could not resolve the native menu pointer.');
        return;
    end
    update_menu_state();
    publish_state();
    log_info('Loaded in display-only mode. Use /amove status or /amove debug on.');
    log_info(('Focused menu: %s; modal: %s.'):fmt(
        state.name ~= '' and state.name or '(closed)',
        state.modal and 'yes' or 'no'));
end);

ashita.events.register('plugin_event', 'plugin_event_cb', function (e)
    if (e.name == 'ashitamove_modal_query_v1') then
        publish_state();
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    state.name = '';
    state.modal = false;
    publish_state();
    if (_G.SpectralFocus ~= nil and _G.SpectralFocus.menu ~= nil) then
        _G.SpectralFocus.menu.active = false;
        _G.SpectralFocus.menu.modal = false;
        _G.SpectralFocus.menu.name = '';
        _G.SpectralFocus.menu.updated_at = os.clock();
    end
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0) then return; end
    local root = tostring(args[1]):lower();
    if (root ~= '/amove' and root ~= '/ashitamove') then return; end

    e.blocked = true;
    local command = tostring(args[2] or 'status'):lower();
    if (command == 'status') then
        print_status();
    elseif (command == 'debug') then
        local value = tostring(args[3] or ''):lower();
        if (value == 'on') then
            state.debug = true;
            log_info('Menu transition logging enabled.');
            print_status();
        elseif (value == 'off') then
            state.debug = false;
            log_info('Menu transition logging disabled.');
        else
            log_error('Usage: /amove debug on|off');
        end
    else
        log_info('Commands: /amove status | /amove debug on|off');
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    local now = os.clock();
    if ((now - state.last_poll) < 0.05) then return; end
    state.last_poll = now;
    update_menu_state();
    if ((now - state.last_publish) >= 0.5) then
        publish_state();
    end
end);
