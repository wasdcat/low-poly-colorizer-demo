extends RefCounted

## The languages the demo speaks, and every text it shows in each of them.
##
## The UI is written in English, and its English texts double as message ids:
## Controls translate what they display on their own, code calls tr(). So
## English needs no table, and switching language is one
## TranslationServer.set_locale() call -- everything on screen follows.
##
## Another language is one more entry in [constant LANGUAGES] (with a flag in
## assets/flags/) and one more table in [constant TABLES].

## Code, name (in that language) and flag of each language, in menu order.
const LANGUAGES: Array[Dictionary] = [
	{"code": "en", "name": "English", "flag": preload("res://assets/flags/gb.svg")},
	{"code": "de", "name": "Deutsch", "flag": preload("res://assets/flags/de.svg")},
]

const TABLES := {
	"de": {
		# Panel
		"Demo Game": "Demo-Spiel",
		"Help": "Hilfe",
		"About": "Info",
		"Puzzle": "Würfel",
		"Size": "Größe",
		"Gap": "Abstand",
		"Scramble to Play": "Mischen & Spielen",
		"Undo": "Rückgängig",
		"Reset": "Zurücksetzen",
		"Material/Colors": "Material/Farben",
		"Stickers": "Sticker",
		"Body": "Körper",
		# Color schemes and body looks (their resource names)
		"Classic": "Klassisch",
		"Showroom (mixed presets)": "Showroom (gemischte Presets)",
		"Rainbow": "Regenbogen",
		"Shades (one hue)": "Abstufungen (ein Farbton)",
		"Greyscale (hard)": "Graustufen (schwer)",
		"Random": "Zufällig",
		"Black": "Schwarz",
		"White": "Weiß",
		"Steel": "Stahl",
		# Game
		"Moves": "Züge",
		"Solved!": "Gelöst!",
		"in %d move": "in %d Zug",
		"in %d moves": "in %d Zügen",
		# Help window
		"Controls": "Steuerung",
		"Close": "Schließen",
		"Wheel": "Mausrad",
		"Middle mouse button": "Mittlere Maustaste",
		"Shift": "Umschalt",
		"Ctrl": "Strg",
		"Drag": "Ziehen",
		"Turn the column under the cursor": "Spalte unter dem Mauszeiger drehen",
		"Turn the row under the cursor": "Zeile unter dem Mauszeiger drehen",
		"Turn the face under the cursor": "Seite unter dem Mauszeiger drehen",
		"Orbit the view": "Ansicht drehen",
		"Zoom": "Zoomen",
		"Undo the last turn": "Letzten Zug zurücknehmen",
		"Close window · quit the game": "Fenster schließen · Spiel beenden",
		"The white outline marks the layer the wheel turns next.":
				"Der weiße Rahmen zeigt, welche Ebene das Mausrad als Nächstes dreht.",
		"“Scramble to Play” starts a game: solve the cube in as few moves as you can.":
				"„Mischen & Spielen“ startet ein Spiel: Löse den Würfel mit möglichst wenigen Zügen.",
		# About window
		"What is Low Poly Colorizer?": "Was ist Low Poly Colorizer?",
		"Low Poly Colorizer (LPC) is a Blender extension for painting low-poly models face by face – with colors from one palette texture and PBR presets. All painted faces share a single material, and one click exports materials and shaders to Godot 4.":
				"Low Poly Colorizer (LPC) ist eine Blender-Erweiterung, mit der du Low-Poly-Modelle Fläche für Fläche bemalst – mit Farben aus einer Palettentextur und PBR-Presets. Alle bemalten Flächen teilen sich ein Material, und ein Klick exportiert Materialien und Shader nach Godot 4.",
		"Low Poly Colorizer on GitHub ›": "Low Poly Colorizer auf GitHub ›",
		"About this game": "Über dieses Spiel",
		"Made with Godot 4.8 and Low Poly Colorizer's export for Godot 4. The cube is built at runtime from just two meshes – body and sticker – in any size from 2 to 7.":
				"Erstellt mit Godot 4.8 und dem Godot-4-Export von Low Poly Colorizer. Der Würfel entsteht zur Laufzeit aus nur zwei Meshes – Körper und Sticker – in jeder Größe von 2 bis 7.",
		"Bodies and stickers are colored with the lpc_singlecolor material, which LPC ships with its export from Blender.":
				"Körper und Sticker sind mit dem Material lpc_singlecolor gefärbt, das LPC beim Export aus Blender mitliefert.",
		"One look per mesh: a whole mesh – or a single surface of it – gets one color from the LPC palette and one LPC preset. That's why every sticker here is a node of its own.":
				"Ein Look pro Mesh: Ein ganzes Mesh – oder eine einzelne Surface davon – bekommt eine Farbe aus der LPC-Palette und ein LPC-Preset. Deshalb ist hier jeder Sticker ein eigener Node.",
		"What it's good for: consistency. lpc_singlecolor uses the same palette and presets as lpc_multicolor – so all your own assets are colored from one shared palette, whichever of the two materials they use.":
				"Wozu das gut ist: Konsistenz. lpc_singlecolor nutzt dieselbe Palette und dieselben Presets wie lpc_multicolor – so sind alle eigenen Assets aus einer gemeinsamen Palette gefärbt, egal welches der beiden Materialien sie tragen.",
		"Source code of this game on GitHub ›": "Quellcode dieses Spiels auf GitHub ›",
	},
}


## Hands every table to the TranslationServer. Call once, before the UI is built.
static func install() -> void:
	for code: String in TABLES:
		var translation := Translation.new()
		translation.locale = code
		var table: Dictionary = TABLES[code]
		for message: String in table:
			translation.add_message(message, table[message])
		TranslationServer.add_translation(translation)


## The code of the language showing now: the system's, if the demo speaks it.
static func current() -> String:
	var language := TranslationServer.get_locale().get_slice("_", 0)
	for entry in LANGUAGES:
		if entry.code == language:
			return language
	return LANGUAGES[0].code
