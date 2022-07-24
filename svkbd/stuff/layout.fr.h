#define KEYS 63
static Key keys_fr[KEYS] = {
	{ "&", "1", XK_ampersand, 1 },
	{ "é", "2~", XK_eacute, 1 },
	{ "\"", "3#", XK_quotedbl, 1 },
	{ "'", "4{", XK_apostrophe, 1 },
	{ "(", "5[", XK_parenleft, 1 },
	{ "-", "6|", XK_minus, 1 },
	{ "é", "7`", XK_egrave, 1 },
	{ "_", "8\\", XK_underscore, 1 },
	{ "ç", "9^", XK_cedilla, 1 },
	{ "à", "0@", XK_agrave, 1 },
	{ ")", "°]", XK_parenright, 1 },
	{ "=", "+}", XK_equal, 1 },
	{ "<-", 0, XK_BackSpace, 2 },
	{ 0 }, /* New row */
	{ "-", ">|", XK_Tab, 1 },
	{ "a", "A", XK_a, 1 },
	{ "z", "Z", XK_z, 1 },
	{ "e", "E€", XK_e, 1 },
	{ "r", "R", XK_r, 1 },
	{ "t", "T", XK_t, 1 },
	{ "y", "Y", XK_y, 1 },
	{ "u", "U", XK_u, 1 },
	{ "i", "I", XK_i, 1 },
	{ "o", "O", XK_o, 1 },
	{ "p", "P", XK_p, 1 },
	{ "^", "", XK_dead_circumflex, 1 },
	{ "$", "£¤", XK_dollar, 1 },
	{ "Return", 0, XK_Return, 3 },
	{ 0 }, /* New row */
	{ 0, 0, XK_Caps_Lock, 2 },
	{ "q", "Q", XK_q, 1 },
	{ "s", "S", XK_s, 1 },
	{ "d", "D", XK_d, 1 },
	{ "f", "F", XK_f, 1 },
	{ "g", "G", XK_g, 1 },
	{ "h", "H", XK_h, 1 },
	{ "j", "J", XK_j, 1 },
	{ "k", "K", XK_k, 1 },
	{ "l", "L", XK_l, 1 },
	{ "m", "M", XK_m, 1 },
	{ "ù", "%", XK_ugrave, 1 },
	{ "*", "µ", XK_multiply, 1 },
	{ "\\", "|", XK_backslash, 1 },
	{ 0 }, /* New row */
	{ 0, 0, XK_Shift_L, 2 },
	{ "w", "W", XK_w, 1 },
	{ "x", "X", XK_x, 1 },
	{ "c", "C", XK_c, 1 },
	{ "v", "V", XK_v, 1 },
	{ "b", "B", XK_b, 1 },
	{ "n", "N", XK_n, 1 },
	{ ",", "?", XK_comma, 1 },
	{ ";", ".", XK_semicolon, 1 },
	{ ":", "/", XK_colon, 1 },
	{ "!", "§", XK_exclam, 1 },
	{ 0, 0, XK_Shift_R, 2 },
	{ 0 }, /* New row */
	{ "Ctrl", 0, XK_Control_L, 2 },
	{ "Alt", 0, XK_Alt_L, 2 },
	{ "", 0, XK_space, 5 },
	{ "Alt", 0, XK_Alt_R, 2 },
	{ "Ctrl", 0, XK_Control_R, 2 },
	{ "[X]", 0, XK_Cancel, 1},
};

Buttonmod buttonmods[] = {
	{ XK_Shift_L, Button2 },
	{ XK_Alt_L, Button3 },
};

#define OVERLAYS 1
static Key overlay[OVERLAYS] = {
	{ 0, 0, XK_Cancel },
};

#define LAYERS 1
static char* layer_names[LAYERS] = {
	"fr",
};

static Key* available_layers[LAYERS] = {
	keys_fr,
};

