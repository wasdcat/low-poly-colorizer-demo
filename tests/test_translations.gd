extends "res://tests/test_case.gd"

## The demo's languages: every one complete enough to ship.

const Translations := preload("res://scripts/translations.gd")
const DemoUi := preload("res://scripts/demo_ui.gd")


func test_every_language_has_a_flag_and_a_table() -> void:
	for entry in Translations.LANGUAGES:
		check(entry.flag is Texture2D, "flag of " + entry.code)
		if entry.code != "en":  # English texts are the message ids
			check(Translations.TABLES.has(entry.code), "table for " + entry.code)
	for code: String in Translations.TABLES:
		check(Translations.LANGUAGES.any(func(entry: Dictionary) -> bool: return entry.code == code),
				"menu entry for the %s table" % code)


func test_no_translation_is_empty() -> void:
	for code: String in Translations.TABLES:
		var table: Dictionary = Translations.TABLES[code]
		for message: String in table:
			check(not String(table[message]).strip_edges().is_empty(), "%s: %s" % [code, message])


func test_help_and_about_texts_are_translated() -> void:
	var texts: Array[String] = []
	for row in DemoUi.CONTROLS:
		texts.append(row[1])
	texts.append_array(DemoUi.GAME_FACTS)
	for code: String in Translations.TABLES:
		var table: Dictionary = Translations.TABLES[code]
		for text in texts:
			check(table.has(text), "%s lacks: %s" % [code, text])
