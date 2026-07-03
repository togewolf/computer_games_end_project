extends Node
class_name VoiceManager

signal voice_command_received(effect_name: String)

var udp_server := PacketPeerUDP.new()
const UDP_PORT = 4242
var voice_engine_pid = 0

func _ready():
	if udp_server.bind(UDP_PORT) == OK:
		print("🎙️ VoiceManager: Listening for UDP packets on port %d..." % UDP_PORT)
	else:
		printerr("🎙️ VoiceManager: Failed to bind UDP port! Is the port already in use?")
		
	# Start the python engine automatically (only in exported game)
	if not OS.has_feature("editor"):
		start_voice_engine()

func _process(_delta):
	# Listen for incoming voice casts over UDP
	while udp_server.get_available_packet_count() > 0:
		var packet_string = udp_server.get_packet().get_string_from_utf8()
		print("🎙️ VoiceManager: Received packet -> ", packet_string)
		voice_command_received.emit(packet_string)

func start_voice_engine():
	var executable_path = OS.get_executable_path().get_base_dir() + "/voice_engine/voice_bridge.exe"
	voice_engine_pid = OS.create_process(executable_path, [])
	print("🎙️ Started Voice Engine with PID: ", voice_engine_pid)

func _exit_tree():
	if voice_engine_pid > 0:
		print("🎙️ Closing background voice engine...")
		OS.kill(voice_engine_pid)
