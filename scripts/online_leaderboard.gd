class_name OnlineLeaderboard
extends Node
## Global Time Trial best-lap ranking (one board per track) on the HighScore API
## (https://api-leaderboard.qulyubis.biz.id, open source: github.com/Resaqulyubi/api-highscore-leaderboard).
##
## The API ranks HIGHER scores first and keeps each player's best (MAX) score, so a lap time is
## sent as  score = SCORE_BASE - lap_ms  (a faster lap = a bigger score). Example: 1:02.345 ->
## 10000000 - 62345 = 9937655. Only real new personal-best laps are sent (see race.gd).
## Note: like any client-side game key, these keys are public, so the ranking is "for fun".
## The boards (game ids 22-24) were registered for this game and cannot be deleted via the API.

signal top_loaded(track_id: String, entries: Array, error: String)
signal submitted(ok: bool, message: String)

const API_URL := "https://api-leaderboard.qulyubis.biz.id/api/v1"
const SCORE_BASE := 10000000
const BOARDS := {
	"rookie_ring": {"game_id": 22, "api_key": "game_z728d1JZmPTl7xn1RgA10RQjHqy4dlv0FfgajNde4wg"},
	"sepang": {"game_id": 23, "api_key": "game_V_L7jjhLORpKGK3ZzPoTvHQaxyzPXh9p2ffQHACFT8o"},
	"monza": {"game_id": 24, "api_key": "game_5erIohXBAmNuxl81BivkFHhPTkVgDajf18artpg-ej8"},
}
## Tests can point the client at a local mock server.
static var api_url_override := ""


static func has_board(track_id: String) -> bool:
	return BOARDS.has(track_id)


static func lap_to_score(t: float) -> int:
	return clampi(SCORE_BASE - int(round(t * 1000.0)), 0, SCORE_BASE)


static func score_to_lap(score: int) -> float:
	return (SCORE_BASE - score) / 1000.0


## Player names allowed by the API: letters, numbers, spaces, - _ . @ (max 50).
static func clean_name(n: String) -> String:
	var re := RegEx.new()
	re.compile("[^A-Za-z0-9 _.@-]")
	return re.sub(n, "", true).strip_edges().left(20)


func _url() -> String:
	return api_url_override if api_url_override != "" else API_URL


## Loads the top `limit` laps -> top_loaded(track_id, [{"name", "time"}...], error).
func fetch_top(track_id: String, limit: int = 5) -> void:
	if not has_board(track_id):
		top_loaded.emit(track_id, [], "no board")
		return
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			top_loaded.emit(track_id, [], "offline" if result != HTTPRequest.RESULT_SUCCESS else "error %d" % code)
			return
		var json := JSON.new()
		var data = json.data if json.parse(body.get_string_from_utf8()) == OK else null
		var out := []
		if data is Dictionary and data.get("entries") is Array:
			for e in data["entries"]:
				out.append({"name": str(e.get("player_name", "?")), "time": score_to_lap(int(e.get("score", 0)))})
		top_loaded.emit(track_id, out, ""))
	var err := http.request("%s/leaderboard?limit=%d" % [_url(), limit], ["X-API-Key: " + BOARDS[track_id]["api_key"]])
	if err != OK:
		http.queue_free()
		top_loaded.emit(track_id, [], "request failed")


## Sends a lap time (seconds) -> submitted(ok, message).
func submit_lap(track_id: String, player_name: String, t: float) -> void:
	var n := clean_name(player_name)
	if not has_board(track_id) or n == "" or t <= 0.0:
		submitted.emit(false, "not sent")
		return
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h, _b):
		http.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201)
		submitted.emit(ok, "sent" if ok else ("offline" if result != HTTPRequest.RESULT_SUCCESS else "error %d" % code)))
	var body := JSON.stringify({
		"player_name": n,
		"score": lap_to_score(t),
		"game_metadata": {"lap_ms": int(round(t * 1000.0)), "track": track_id,
			"version": str(ProjectSettings.get_setting("application/config/version", ""))},
	})
	var headers := ["Content-Type: application/json", "X-API-Key: " + BOARDS[track_id]["api_key"]]
	var err := http.request(_url() + "/scores", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		submitted.emit(false, "request failed")
