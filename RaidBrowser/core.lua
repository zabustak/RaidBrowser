-- Register addon
raid_browser = LibStub('AceAddon-3.0'):NewAddon('RaidBrowser', 'AceConsole-3.0')

--[[ Parsing and pattern matching ]]--
-- Whitespace separator
local sep = '[%s-_,.\/<>)(]';

-- Kleene closure of sep.
local csep = sep..'*';

-- Positive closure of sep.
local psep = sep..'+';

local metachar = '¿';

local function make_meta(text)
	return metachar .. text .. metachar;
end

local meta_role = make_meta('role');
local meta_roles = make_meta('roles');
local meta_raid = make_meta('raid');
local meta_gs = make_meta('gs');
local meta_achieve = make_meta('achiev')

-- Raid patterns template for a raid with 2 difficulties and 2 sizes
local raid_patterns_template = {
	hc = {
		'<raid>' .. csep .. '<size>' .. csep .. 'm?a?n?' .. csep .. 'hc?' .. sep,
		sep..'hc?' .. csep .. '<raid>' .. csep .. '<size>' .. sep,
		'<raid>' .. csep .. 'hc?' .. csep .. '<size>' .. sep,
		sep .. '<size>' .. csep .. '<raid>' .. sep,
		'^<size>' .. csep .. '<raid>' .. sep,
		
		'<fullraid>' .. csep .. '<size>' .. sep .. 'm?a?n?' .. csep .. 'hc?' .. sep,
		sep..'hc?' .. csep .. '<fullraid>' .. csep .. '<size>' .. sep,
		'<fullraid>' .. csep .. 'hc?' .. csep .. '<size>' .. sep,
	},
	
	nm = {
		'<raid>' .. csep .. '<size>' .. csep .. 'm?a?n?' .. csep .. 'nm?' .. sep,
		sep..'nm?' .. csep .. '<raid>' .. csep .. '<size>' .. sep,
		'<raid>' .. csep .. 'nm?' .. csep .. '<size>' .. sep,
		'<raid>' .. csep .. '<size>',
		sep .. '<size>' .. csep .. '<raid>' .. sep,
		'^<size>' .. csep .. '<raid>' .. sep,
		
		'<fullraid>' .. csep .. '<size>' .. csep .. 'm?a?n?' .. csep .. 'nm?' .. sep,
		sep..'nm?' .. csep .. '<fullraid>' .. csep .. '<size>' .. sep,
		'<fullraid>' .. csep .. 'nm?' .. csep .. '<size>' .. sep,
		'<fullraid>' .. csep .. '<size>' .. sep,
	},
	
	simple = {
		'<raid>' .. csep .. '<size>' .. csep .. 'm[an][an]',
		'<raid>' .. csep .. '<size>' .. sep,
		'^<size>' .. csep .. 'm?a?n?' .. csep .. '<raid>' .. sep,
		sep .. '<size>' .. csep .. 'm?a?n?' .. csep .. '<raid>' .. sep,
	},
};

local function create_pattern_from_template(raid_name_pattern, size, difficulty, full_raid_name)
	if not raid_name_pattern or not size or not difficulty or not full_raid_name then
		return;
	end
	
	full_raid_name = full_raid_name:lower();
	
	if size == 10 then
		size = '1[0o]';
	elseif size == 40 then
		size = '4[0p]';
	end
	
	-- Replace placeholders with the specified raid info
	return std.algorithm.transform(raid_patterns_template[difficulty], function(pattern)
		pattern = pattern:gsub('<fullraid>', full_raid_name);
        pattern = pattern:gsub('<raid>', raid_name_pattern);
        pattern = pattern:gsub('<size>', size);
        return pattern;
	end);
end
			
local raid_list = {
	-- Note: The order of each raid is deliberate.
	-- Heroic raids are checked first, since NM raids will have the default 'icc10' pattern. 
	-- Be careful about changing the order of the raids below
	{
		name = 'icc25rep',
		instance_name = 'Icecrown Citadel',
		size = 25,
		patterns = {
			'icc'..csep..'25'..csep..'m?a?n?'..csep..'repu?t?a?t?i?o?n?'..csep..'',
			'icc'..csep..'repu?t?a?t?i?o?n?'..csep..'25'..csep..'m?a?n?',
		}
	},
	
	{
		name = 'icc10rep',
		instance_name = 'Icecrown Citadel',
		size = 10,
		patterns = {
			'icc'..csep..'10'..csep..'m?a?n?'..csep..'repu?t?a?t?i?o?n?'..csep..'',
			'icc'..csep..'repu?t?a?t?i?o?n?'..csep..'10',
			'icc'..csep..'repu?t?a?t?i?o?n?',
		}
	},
	
	{
		name = 'icc10hc',
		instance_name = 'Icecrown Citadel',
		size = 10,
		patterns = create_pattern_from_template('icc', 10, 'hc', 'Icecrown Citadel'),
	},

	{
		name = 'icc25hc',
		instance_name = 'Icecrown Citadel',
		size = 25,
		patterns = create_pattern_from_template('icc', 25, 'hc', 'Icecrown Citadel'),
	},

	{
		name = 'icc10nm',
		instance_name = 'Icecrown Citadel',
		size = 10,
		patterns = create_pattern_from_template('icc', 10, 'nm', 'Icecrown Citadel'),
	},

	{
		name = 'icc25nm',
		instance_name = 'Icecrown Citadel',
		size = 25,
		patterns = create_pattern_from_template('icc', 25, 'nm', 'Icecrown Citadel'),
	},

	{
		name = 'toc10hc',
		instance_name = 'Trial of the Crusader',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 10, 'hc', 'Trial of the Crusader'),
			{ 
				'togc'..csep..'10',
				--'%[call of the grand crusade %(10 player%)%]'
			} -- Trial of the grand crusader (togc) refers to heroic toc
		),
	},

	{
		name = 'toc25hc',
		instance_name = 'Trial of the Crusader',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 25, 'hc', 'Trial of the Crusader'),
			{ 
				'togc'..csep..'25',
				--'%[call of the grand crusade %(25 player%)%]'
			} -- Trial of the grand crusader (togc) refers to heroic toc
		),
	},

	{
		name = 'toc10nm',
		instance_name = 'Trial of the Crusader',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 10, 'nm', 'Trial of the Crusader'),
			{ '%[call of the crusade %(10 player%)%]' }
		),
	},

	{
		name = 'toc25nm',
		instance_name = 'Trial of the Crusader',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 25, 'nm', 'Trial of the Crusader'),
			{ '%[call of the crusade %(25 player%)%]' }
		),
	},
	
	{
		name = 'rs10hc',
		instance_name = 'The Ruby Sanctum',
		size = 10,
		patterns = create_pattern_from_template('rs', 10, 'hc', 'ruby sanctum'),
	},

	{
		name = 'rs25hc',
		instance_name = 'The Ruby Sanctum',
		size = 25,
		patterns = create_pattern_from_template('rs', 25, 'hc', 'ruby sanctum'),
	},

	{
		name = 'rs10nm',
		instance_name = 'The Ruby Sanctum',
		size = 10,
		patterns = create_pattern_from_template('rs', 10, 'nm', 'ruby sanctum'),
	},

	{
		name = 'rs25nm',
		instance_name = 'The Ruby Sanctum',
		size = 25,
		patterns = create_pattern_from_template('rs', 25, 'nm', 'ruby sanctum'),
	},
	
	{
		name = 'voa10',
		instance_name = 'Vault of Archavon',
		size = 10,
		patterns = create_pattern_from_template('voa', 10, 'simple', 'Vault of Archavon'),
	},
	
	{
		name = 'voa25',
		instance_name = 'Vault of Archavon',
		size = 25,
		patterns = create_pattern_from_template('voa', 25, 'simple', 'Vault of Archavon'),
	},
		
	{
		name = 'ulduar10',
		instance_name = 'Ulduar',
		size = 10,
		patterns = {
			'ull?a?d[au]?[au]?r?'..csep..'10',
		},
	},
	
	{
		name = 'ulduar25',
		instance_name = 'Ulduar',
		size = 25,
		patterns = {
			'ull?a?d[au]?[au]?r?'..csep..'25',
		}
	},
	
	{
		name = 'os10',
		instance_name = 'The Obsidian Sanctum',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('os', 10, 'simple', 'The Obsidian Sanctum'),
			{ '%[sartharion must die!]' }
		),
	},
	
	{
		name = 'os25',
		instance_name = 'The Obsidian Sanctum',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('os', 25, 'simple', 'The Obsidian Sanctum'),
			{ '%[sartharion must die!]' }
		),
	},
	
	{
		name = 'naxx10',
		instance_name = 'Naxxramas',
		size = 10,
		patterns = {
			'naxx?r?a?m?m?a?s?'..csep..'10',
			'naxx'..sep..'weekly',
			'patchwerk'..sep..'must'..sep..'die!',
		},
	},
	
	{
		name = 'naxx25',
		instance_name = 'Naxxramas',
		size = 25,
		patterns = {
			'naxx?r?a?m?m?a?s?'..csep..'25',
		},
	},
	
	{
		name = 'onyxia25',
		instance_name = 'Onyxia\'s Lair',
		size = 25,
		patterns = {
			'onyx?i?a?'..csep..'25'
		},
	},
	
	{
		name = 'onyxia10',
		instance_name = 'Onyxia\'s Lair',
		size = 10,
		patterns = {
			'onyx?i?a?'..csep..'10'
		},
	},
	
	{
		name = 'karazhan',
		instance_name = 'Karazhan',
		size = 10,
		patterns = {
			'karaz?h?a?n?'..csep..'1?0?', -- karazhan 
		},
	},
	
	{
		name = 'molten core',
		instance_name = 'Molten Core',
		size = 40,
		patterns = {
			'molte?n'..csep..'core?',
			'[%s-_,.%^]+mc'..csep..'4?0?[%s-_,.$]+',
		},
	},
	
	{
		name = 'eoe10',
		instance_name = 'The Eye of Eternity',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('eoe', 10, 'simple', 'The Eye of Eternity'),
			{ '%[malygos must die!]' }
		),
	},
	
	{
		name = 'eoe25',
		instance_name = 'The Eye of Eternity',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('eoe', 25, 'simple', 'The Eye of Eternity'),
			{ '%[malygos must die!]' }
		),
	},
	
	--
	--
	--[[{
		name = '
	},]]--
	
	{
		name = 'black temple',
		instance_name = 'The Black Temple',
		size = 25,
		patterns = {
			'black'..csep..'temple',
			'[%s-_,.]+bt'..csep..'25[%s-_,.]+',
		},
	},
	
	{
		name = 'aq40',
		instance_name = 'Ahn\'Qiraj Temple',
		size = 40,
		patterns = {
			'temple?'..csep..'of?'..csep..'ahn\'?'..csep..'qiraj',
			sep..'*aq'..csep..'40'..csep..'',
		},
	},
	
	{
		name = 'aq20',
		instance_name = 'Ruins of Ahn\'Qiraj',
		size = 20,
		patterns = {
			'ruins?'..csep..'of?'..csep..'ahn\'?'..csep..'qiraj',
			sep..'*aq'..csep..'20'..csep..'',
		},
	},
}

local role_patterns = {	
	dps = {
		'[0-9]*'..csep..'dps',
		
		-- melee dps
		'[0-9]*'..csep..'m[dp][dp]s',
		'[0-9]*'..csep..'rogue',
		'[0-9]*'..csep..'kitt?y?',
		'[0-9]*'..csep..'cat'..sep,
		'[0-9]*'..csep..'feral'..csep..'cat'..sep,
		'[0-9]*'..csep..'feral'..sep,
		'[0-9]*'..csep..'ret'..csep..'pal[al]?[dy]?i?n?',
		
		-- ranged dps
		'[0-9]*'..csep..'r[dp][dp]s',
		'[0-9]*'..csep..'w?a?r?lock',
		'[0-9]*'..csep..'spri?e?st',
		'[0-9]*'..csep..'elem?e?n?t?a?l?',
		'[0-9]*'..csep..'mage',
		'[0-9]*'..csep..'boo?mm?y?k?i?n?',
		'[0-9]*'..csep..'hunte?r?s?',
	},
	
	healer = {
		'[0-9]*'..csep..'h[ea]*l[ers]*', -- LF healer
		'[0-9]*'..csep..'re?s?t?o?'..csep..'d[ru][ud][iu]d?', -- LF rdruid/rdudu
		'[0-9]*'..csep..'tree', 			   -- LF tree
		'[0-9]*'..csep..'re?s?t?o?'..csep..'shamm?y?', -- LF rsham
		'[0-9]*'..csep..'di?s?c?o?'..csep..'pri?e?st', -- disc priest
		'[0-9]*'..csep..'ho?l?l?y?'..csep..'pala',	   -- LF hpala
	},
	
	tank = {
		'[0-9]*'..csep..'t[a]?nk[s]?',	 -- NEED TANKS
		'[0-9]*'..csep..'tn?[a]?k[s]?',  -- Need TNAK
		sep .. '[mo]t' .. sep,		 	 -- Need MT/OT
		'[0-9]*'..csep..'b[ea]*rs?',
		'[0-9]*'..csep..'prot'..csep..'pal[al]?[dy]?i?n?',
	},
}

local gearscore_patterns = {
	'[1-6]'..csep..'k[0-9]+',
	'[1-6][.,][0-9]',
	'[1-6]'..csep..'k'..csep..'%+',
	'[1-6]'..csep..'k'..sep,
	'%+?'..csep..'[1-6]'..csep..'k'..sep,
	'[1-6][0-9][0-9][0-9]',
	'[1-6]%+',
}

local guild_recruitment_patterns = {
	'recrui?ti?n?g?',
	'we'..csep..'raid',
	'we'..csep..'are'..csep..'raidi?n?g?',
	'[<({-][%a%s]+[-})>]'..csep..'is'..csep..'a?', -- (<GuildName> is a) pve guild looking for
	'is'..csep..'[%a%s]*playe?rs?',
	'[0-9][0-9][pa]m'..csep..'st', -- we raid (12pm set)
	'autorecruit',
	'raid'..csep..'time',
	'active'..csep..'raiders?',
	'is'..csep..'a'..csep..'[%a]*'..csep..'[pvep][pvep][pvep]'..csep..'guild',
	'lf'..sep..'members',
};

local wts_message_patterns = {
	'wts'..sep,
	'selling'..sep,
};

local lfg_message_patterns = {
	'l[fg][fg]?' .. csep .. meta_raid,
	'inv' .. csep .. 'for' .. meta_raid,
}

local lfm_patterns = {
	
	'need' .. csep .. meta_role,
	'need' .. csep .. 'all' .. sep,
	
	'seek' .. csep .. meta_role,
	'seek' .. csep .. 'all' .. sep,
	
	'lf[0-9]*' .. csep .. meta_role,
	'looking' .. csep .. 'for' .. csep .. '[0-9]*' .. meta_role,
	'lfm?' .. csep .. '.*for' .. meta_raid,
	
	'[0-9]*' .. csep .. meta_role .. 'for' .. csep .. meta_raid,
	meta_raid .. csep .. '/?wh*i*s*p*e*r*' .. sep,
	'/?wh*i*s*p*e*r*' .. csep .. 'me' .. csep .. meta_raid,
	
	meta_raid .. csep .. meta_roles .. csep .. meta_gs,
	meta_raid .. 'need' .. csep .. '[0-9]*' .. meta_raid,
}

local function is_lfm_message(message)
	return std.algorithm.find_if(lfm_patterns, function(pattern)
		return string.find(message, pattern);
	end);
end

local function is_guild_recruitment(message)
	return std.algorithm.find_if(guild_recruitment_patterns, function(pattern)
		return string.find(message, pattern);
	end);
end

local function is_wts_message(message)
	return std.algorithm.find_if(wts_message_patterns, function(pattern)
		return message:find(pattern);
	end);
end

local function is_lfg_message(parsed_message)
	return std.algorithm.find_if(lfg_message_patterns, function(pattern)
		return parsed_message:find(pattern);
	end);
end

local function parse_achievement_text(message)
	return message:gsub('|c.*|r', meta_achieve);
end

-- Basic http pattern matching for streaming sites and etc.
local function remove_http_links(message)
	local http_pattern = 'https?://*[%a]*.[%a]*.[%a]*/?[%a%-%%0-9_]*/?';
	return message:gsub(http_pattern, '');
end
	
local function find_roles(roles, message, role)	
	local found = std.algorithm.find_if(role_patterns[role], function(pattern)
		local m, result = message:gsub(pattern, meta_role);
		
		if result > 0 then 
			message = m;
			return true;
		end;
		
		return false;
	end)
	
	if found then table.insert(roles, role) end
	return roles, message;
end

local function format_gs_string(gs)
	local formatted = gs:gsub(sep .. '*%+?', ''); -- Trim whitespace
	formatted = formatted:gsub('k', '')
	formatted = formatted:gsub(sep, '.');
	gs = tonumber(formatted);

	-- Convert ex: 5800 into 5.8 for display
	if gs  > 1000 then
		gs  = gs /1000;
		
	-- Convert 57.0 into 5.7
	elseif gs > 100 then
		gs = gs / 100;
		
	-- Convert 57.0 into 5.7
	elseif gs > 10 then
		gs = gs / 10;
	end

	return string.format('%.1f', gs);
end

local function find_gs_req(message)
	for _, pattern in pairs(gearscore_patterns) do
		local gs_start, gs_end = message:find(pattern)
		
		if gs_start and gs_end then
			local gs_text = message:sub(gs_start, gs_end);

			-- Extract gs and replace it with the gearscore nonterminal
			return 
				format_gs_string(gs_text), 
				message:gsub(gs_text, meta_gs)
		end
	end
	
	return nil, message;
end

local function find_raid_info(message)	
	for _, r in ipairs(raid_list) do
	
		local index = std.algorithm.find_if(r.patterns, function(pattern)
			local m, result = string.gsub(message, pattern, meta_raid);
			
			if result > 0 then 
				message = m;
				return true;
			end;
			
			return false;
		end);
		
		if index then 
			return r, message 
		end;
	end
	
	return nil;
end

function raid_browser.parse_roles(message)
	local role_begin = message:find(meta_role)
	local role_end = message:reverse():find(meta_role:reverse());

	return message:sub(role_begin, #message - role_end + 1);
end

function raid_browser.parse_message(message)
	if not message then return end;
	message = message:lower();
	message = remove_http_links(message);
	
	-- Stop if it's a guild recruit/wts message
	if is_guild_recruitment(message) or is_wts_message(message) then
		return;
	end
		
	-- Get the raid_info from the message
	local raid_info, message = find_raid_info(message);
	if not raid_info then return end
	
	message = parse_achievement_text(message);
	
	-- Get any roles that are needed
	local roles = {};
	
	if not message:find('lfm? all ') and not message:find('need all ') then 
		roles, message = find_roles(roles, message, 'dps');
		roles, message = find_roles(roles, message, 'tank');
		roles, message = find_roles(roles, message, 'healer');
	end
	
	--message = parse_roles(message);

	-- If there is only an LFM message, then it is assumed that all roles are needed
	if #roles == 0 then
		roles = {'dps', 'tank', 'healer' }
	end

	-- Search for a gearscore requirement.
	local gs, message = find_gs_req(message);
	
	-- Exclude any lfg messages that are not definite lfm messages
	if not is_lfm_message(message) then
		return 
	end
	
	return message, raid_info, roles, gs or ' ';
end

function raid_browser.raid_info(message)
	local raid_info, roles, gs;
	
	message, raid_info, roles, gs = raid_browser.parse_message(message);
	return raid_info, roles, gs or ' ';
end

--[[ Event handlers and listeners ]]--
lfm_channel_listeners = {
	['CHAT_MSG_CHANNEL'] = {},
	['CHAT_MSG_YELL'] = {},
};

local channel_listeners = {};

local function is_lfm_channel(channel)
	return channel == 'CHAT_MSG_CHANNEL' or channel == 'CHAT_MSG_YELL';
end

local function event_handler(self, event, message, sender)
	if is_lfm_channel(event) then
		local raid_info, roles, gs = raid_browser.raid_info(message)
		if raid_info and roles and gs then
			
			-- Put the sender in the table of active raids
			raid_browser.lfm_messages[sender] = { 
				raid_info = raid_info, 
				roles = roles, 
				gs = gs, 
				time = time(), 
				message = message
			};
			
			raid_browser.gui.update_list();
		end
	end
end

local function refresh_lfm_messages()
	-- Requesting lock info each time a tooltip is produced creates a lot of lag.
	-- This is a better alternative
	RequestRaidInfo();
	
	for name, info in pairs(raid_browser.lfm_messages) do
		-- If the last message from the sender was too long ago, then
		-- remove his raid from lfm_messages.
		if time() - info.time > raid_browser.expiry_time then
			raid_browser.lfm_messages[name] = nil;
		end
	end
end

function raid_browser:OnEnable()
	raid_browser:Print('loaded. Type /rb to toggle the raid browser.')
	
	if not raid_browser_character_current_raidset then
		raid_browser_character_current_raidset = 'Active';
	end
	
	if not raid_browser_character_raidsets then
		raid_browser_character_raidsets = {
			primary = {},
			secondary = {},
		};
	end

	-- LFM messages expire after 60 seconds
	raid_browser.expiry_time = 60;

	raid_browser.lfm_messages = {}
	raid_browser.timer = raid_browser.set_timer(10, refresh_lfm_messages, true)
	for channel, listener in pairs(lfm_channel_listeners) do
		channel_listeners[i] = raid_browser.add_event_listener(channel, event_handler)
	end
	
	raid_browser.gui.raidset.initialize();
end

function raid_browser:OnDisable()
	for channel, listener in pairs(lfm_channel_listeners) do
		raid_browser.remove_event_listener(channel, listener)
	end
	
	raid_browser.kill_timer(raid_browser.timer)
end