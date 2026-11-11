// GameScene Studio's iOS plugin: the singleton "GameSceneNative", with the
// same methods as the Android plugin (see src/io/native.gd). Not built yet:
// see platform/ios/README.md.

#pragma once

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/variant.h"

class GameSceneNative : public Object {
	GDCLASS(GameSceneNative, Object);

	static GameSceneNative *singleton;

protected:
	static void _bind_methods();

public:
	static GameSceneNative *get_singleton() { return singleton; }

	int sdk_int();
	bool can_encode();
	int enc_open(const String &p_path, int p_width, int p_height, int p_fps, int p_bitrate);
	bool enc_frame(int p_id, const PackedByteArray &p_rgba);
	bool enc_close(int p_id);
	bool mux_start(const PackedStringArray &p_segments, const String &p_wav, const String &p_out, int p_fps);
	String mux_state();
	bool share(const PackedStringArray &p_paths, const String &p_title);
	String save_to_gallery(const String &p_path, const String &p_album);
	String take_opened_file();
	bool video_thumbnail(const String &p_path, const String &p_out, int p_width);

	GameSceneNative();
	~GameSceneNative();
};

void gamescene_native_init();
void gamescene_native_deinit();
