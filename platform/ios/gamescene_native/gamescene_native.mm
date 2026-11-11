// GameScene Studio's iOS plugin (see gamescene_native.h). Mirrors the Android
// plugin: AVAssetWriter for H.264 segments, AVMutableComposition to join them
// with an AAC soundtrack, UIActivityViewController for sharing and the Photos
// library for the gallery. Nothing here uses the network.

#include "gamescene_native.h"

#include "core/config/engine.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#include <atomic>
#include <map>
#include <mutex>
#include <string>

GameSceneNative *GameSceneNative::singleton = nullptr;

static NSString *ns(const String &s) {
	return [NSString stringWithUTF8String:s.utf8().get_data()];
}

static NSURL *file_url(const String &s) {
	return [NSURL fileURLWithPath:ns(s)];
}

// ------------------------------------------------------------------ encoder

struct Segment {
	AVAssetWriter *writer = nil;
	AVAssetWriterInput *input = nil;
	AVAssetWriterInputPixelBufferAdaptor *adaptor = nil;
	int width = 0;
	int height = 0;
	int fps = 30;
	int64_t frames = 0;
};

static std::map<int, Segment> segments;
static int next_segment = 1;

static std::mutex mux_lock;
static std::string mux_status;

bool GameSceneNative::can_encode() {
	return true; // Every iOS device has a hardware H.264 encoder.
}

int GameSceneNative::sdk_int() {
	return (int)[[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
}

int GameSceneNative::enc_open(const String &p_path, int p_width, int p_height, int p_fps, int p_bitrate) {
	NSError *err = nil;
	NSURL *url = file_url(p_path);
	[[NSFileManager defaultManager] removeItemAtURL:url error:nil];
	AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&err];
	if (!writer) {
		return -1;
	}
	int bitrate = p_bitrate > 0 ? p_bitrate : (int)MIN(MAX((int64_t)p_width * p_height * p_fps / 5, 2000000), 40000000);
	NSDictionary *settings = @{
		AVVideoCodecKey : AVVideoCodecTypeH264,
		AVVideoWidthKey : @(p_width),
		AVVideoHeightKey : @(p_height),
		AVVideoCompressionPropertiesKey : @{
			AVVideoAverageBitRateKey : @(bitrate),
			AVVideoMaxKeyFrameIntervalKey : @(p_fps),
			AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel,
			AVVideoAllowFrameReorderingKey : @NO,
		},
		AVVideoColorPropertiesKey : @{
			AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_709_2,
			AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
			AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_709_2,
		},
	};
	AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
	input.expectsMediaDataInRealTime = NO;
	NSDictionary *attrs = @{
		(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
		(id)kCVPixelBufferWidthKey : @(p_width),
		(id)kCVPixelBufferHeightKey : @(p_height),
	};
	AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:attrs];
	if (![writer canAddInput:input]) {
		return -1;
	}
	[writer addInput:input];
	if (![writer startWriting]) {
		return -1;
	}
	[writer startSessionAtSourceTime:kCMTimeZero];
	Segment s;
	s.writer = writer;
	s.input = input;
	s.adaptor = adaptor;
	s.width = p_width;
	s.height = p_height;
	s.fps = MAX(1, p_fps);
	int id = next_segment++;
	segments[id] = s;
	return id;
}

bool GameSceneNative::enc_frame(int p_id, const PackedByteArray &p_rgba) {
	auto it = segments.find(p_id);
	if (it == segments.end()) {
		return false;
	}
	Segment &s = it->second;
	if (p_rgba.size() < s.width * s.height * 4) {
		return false;
	}
	// Wait (briefly) for the encoder to take more.
	for (int i = 0; i < 500 && !s.input.readyForMoreMediaData; i++) {
		[NSThread sleepForTimeInterval:0.01];
	}
	if (!s.input.readyForMoreMediaData || s.adaptor.pixelBufferPool == nil) {
		return false;
	}
	CVPixelBufferRef pb = nullptr;
	if (CVPixelBufferPoolCreatePixelBuffer(nullptr, s.adaptor.pixelBufferPool, &pb) != kCVReturnSuccess) {
		return false;
	}
	CVPixelBufferLockBaseAddress(pb, 0);
	uint8_t *dst = (uint8_t *)CVPixelBufferGetBaseAddress(pb);
	size_t stride = CVPixelBufferGetBytesPerRow(pb);
	const uint8_t *src = p_rgba.ptr();
	for (int y = 0; y < s.height; y++) {
		const uint8_t *in = src + (size_t)y * s.width * 4;
		uint8_t *out = dst + y * stride;
		for (int x = 0; x < s.width; x++) {
			out[0] = in[2];
			out[1] = in[1];
			out[2] = in[0];
			out[3] = 255;
			in += 4;
			out += 4;
		}
	}
	CVPixelBufferUnlockBaseAddress(pb, 0);
	BOOL ok = [s.adaptor appendPixelBuffer:pb withPresentationTime:CMTimeMake(s.frames, s.fps)];
	CVPixelBufferRelease(pb);
	s.frames++;
	return ok;
}

bool GameSceneNative::enc_close(int p_id) {
	auto it = segments.find(p_id);
	if (it == segments.end()) {
		return false;
	}
	Segment s = it->second;
	segments.erase(it);
	[s.input markAsFinished];
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	[s.writer endSessionAtSourceTime:CMTimeMake(s.frames, s.fps)];
	[s.writer finishWritingWithCompletionHandler:^{
		dispatch_semaphore_signal(done);
	}];
	dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
	return s.writer.status == AVAssetWriterStatusCompleted && s.frames > 0;
}

// ------------------------------------------------------------------ joining

static void set_mux(const std::string &s) {
	std::lock_guard<std::mutex> g(mux_lock);
	mux_status = s;
}

String GameSceneNative::mux_state() {
	std::lock_guard<std::mutex> g(mux_lock);
	return String::utf8(mux_status.c_str());
}

// Segments are put one after another; the WAV becomes AAC (passthrough can't
// put PCM in an MP4), then everything is written without re-encoding video.
bool GameSceneNative::mux_start(const PackedStringArray &p_segments, const String &p_wav, const String &p_out, int p_fps) {
	if (mux_state() == "running" || p_segments.is_empty()) {
		return false;
	}
	set_mux("running");
	NSMutableArray<NSURL *> *segs = [NSMutableArray array];
	for (int i = 0; i < p_segments.size(); i++) {
		[segs addObject:file_url(p_segments[i])];
	}
	NSURL *wav = p_wav.is_empty() ? nil : file_url(p_wav);
	NSURL *out = file_url(p_out);
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		AVMutableComposition *comp = [AVMutableComposition composition];
		AVMutableCompositionTrack *vt = [comp addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
		CMTime at = kCMTimeZero;
		for (NSURL *u in segs) {
			AVURLAsset *a = [AVURLAsset URLAssetWithURL:u options:@{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES }];
			AVAssetTrack *t = [[a tracksWithMediaType:AVMediaTypeVideo] firstObject];
			if (!t) {
				set_mux("error: a part has no video");
				return;
			}
			NSError *e = nil;
			[vt insertTimeRange:CMTimeRangeMake(kCMTimeZero, a.duration) ofTrack:t atTime:at error:&e];
			if (e) {
				set_mux(std::string("error: ") + e.localizedDescription.UTF8String);
				return;
			}
			at = CMTimeAdd(at, a.duration);
		}
		if (wav) {
			// WAV -> M4A (AAC) first.
			NSURL *m4a = [[wav URLByDeletingPathExtension] URLByAppendingPathExtension:@"m4a"];
			[[NSFileManager defaultManager] removeItemAtURL:m4a error:nil];
			AVAssetExportSession *ae = [AVAssetExportSession exportSessionWithAsset:[AVURLAsset URLAssetWithURL:wav options:nil] presetName:AVAssetExportPresetAppleM4A];
			ae.outputURL = m4a;
			ae.outputFileType = AVFileTypeAppleM4A;
			dispatch_semaphore_t done = dispatch_semaphore_create(0);
			[ae exportAsynchronouslyWithCompletionHandler:^{
				dispatch_semaphore_signal(done);
			}];
			dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
			if (ae.status == AVAssetExportSessionStatusCompleted) {
				AVURLAsset *aa = [AVURLAsset URLAssetWithURL:m4a options:@{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES }];
				AVAssetTrack *t = [[aa tracksWithMediaType:AVMediaTypeAudio] firstObject];
				if (t) {
					AVMutableCompositionTrack *at2 = [comp addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
					CMTime len = CMTimeMinimum(aa.duration, at);
					[at2 insertTimeRange:CMTimeRangeMake(kCMTimeZero, len) ofTrack:t atTime:kCMTimeZero error:nil];
				}
			}
		}
		[[NSFileManager defaultManager] removeItemAtURL:out error:nil];
		AVAssetExportSession *ex = [AVAssetExportSession exportSessionWithAsset:comp presetName:AVAssetExportPresetPassthrough];
		ex.outputURL = out;
		ex.outputFileType = AVFileTypeMPEG4;
		ex.shouldOptimizeForNetworkUse = YES;
		dispatch_semaphore_t done = dispatch_semaphore_create(0);
		[ex exportAsynchronouslyWithCompletionHandler:^{
			dispatch_semaphore_signal(done);
		}];
		dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
		if (ex.status == AVAssetExportSessionStatusCompleted) {
			set_mux("ok");
		} else {
			set_mux(std::string("error: ") + (ex.error ? ex.error.localizedDescription.UTF8String : "export failed"));
		}
	});
	return true;
}

// ------------------------------------------------------------------ share, gallery

static UIViewController *top_controller() {
	UIWindow *win = nil;
	for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
		if ([sc isKindOfClass:[UIWindowScene class]]) {
			for (UIWindow *w in ((UIWindowScene *)sc).windows) {
				if (w.isKeyWindow) {
					win = w;
				}
			}
		}
	}
	UIViewController *vc = win.rootViewController;
	while (vc.presentedViewController) {
		vc = vc.presentedViewController;
	}
	return vc;
}

bool GameSceneNative::share(const PackedStringArray &p_paths, const String &p_title) {
	NSMutableArray *items = [NSMutableArray array];
	for (int i = 0; i < p_paths.size(); i++) {
		[items addObject:file_url(p_paths[i])];
	}
	if (items.count == 0) {
		return false;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *vc = top_controller();
		if (!vc) {
			return;
		}
		UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
		// iPad: anchor the popover in the middle of the screen.
		avc.popoverPresentationController.sourceView = vc.view;
		avc.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 1, 1);
		avc.popoverPresentationController.permittedArrowDirections = 0;
		[vc presentViewController:avc animated:YES completion:nil];
	});
	return true;
}

// Saves to Photos (asks for "add only" access the first time). Albums need
// read access, so files go to the library itself. Returns at once.
String GameSceneNative::save_to_gallery(const String &p_path, const String &p_album) {
	NSURL *url = file_url(p_path);
	NSString *ext = url.pathExtension.lowercaseString;
	BOOL video = [@[ @"mp4", @"mov", @"m4v" ] containsObject:ext];
	BOOL image = [@[ @"png", @"jpg", @"jpeg" ] containsObject:ext];
	if (!video && !image) {
		return "";
	}
	[PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
										   handler:^(PHAuthorizationStatus status) {
											   if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
												   return;
											   }
											   [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
												   if (video) {
													   [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
												   } else {
													   [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
												   }
											   }
																		 completionHandler:nil];
										   }];
	return "photos";
}

// iOS hands opened documents to the app delegate, which a plugin can't hook
// without changing the engine; projects open through "Open a file" instead.
String GameSceneNative::take_opened_file() {
	return "";
}

bool GameSceneNative::video_thumbnail(const String &p_path, const String &p_out, int p_width) {
	AVURLAsset *a = [AVURLAsset URLAssetWithURL:file_url(p_path) options:nil];
	AVAssetImageGenerator *g = [AVAssetImageGenerator assetImageGeneratorWithAsset:a];
	g.appliesPreferredTrackTransform = YES;
	g.maximumSize = CGSizeMake(p_width, 0);
	NSError *e = nil;
	CGImageRef img = [g copyCGImageAtTime:CMTimeMake(1, 2) actualTime:nil error:&e];
	if (!img) {
		return false;
	}
	NSData *png = UIImagePNGRepresentation([UIImage imageWithCGImage:img]);
	CGImageRelease(img);
	return [png writeToURL:file_url(p_out) atomically:YES];
}

// ------------------------------------------------------------------ binding

void GameSceneNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("sdk_int"), &GameSceneNative::sdk_int);
	ClassDB::bind_method(D_METHOD("can_encode"), &GameSceneNative::can_encode);
	ClassDB::bind_method(D_METHOD("enc_open", "path", "width", "height", "fps", "bitrate"), &GameSceneNative::enc_open);
	ClassDB::bind_method(D_METHOD("enc_frame", "id", "rgba"), &GameSceneNative::enc_frame);
	ClassDB::bind_method(D_METHOD("enc_close", "id"), &GameSceneNative::enc_close);
	ClassDB::bind_method(D_METHOD("mux_start", "segments", "wav", "out", "fps"), &GameSceneNative::mux_start);
	ClassDB::bind_method(D_METHOD("mux_state"), &GameSceneNative::mux_state);
	ClassDB::bind_method(D_METHOD("share", "paths", "title"), &GameSceneNative::share);
	ClassDB::bind_method(D_METHOD("save_to_gallery", "path", "album"), &GameSceneNative::save_to_gallery);
	ClassDB::bind_method(D_METHOD("take_opened_file"), &GameSceneNative::take_opened_file);
	ClassDB::bind_method(D_METHOD("video_thumbnail", "path", "out", "width"), &GameSceneNative::video_thumbnail);
	ADD_SIGNAL(MethodInfo("file_opened", PropertyInfo(Variant::STRING, "path")));
}

GameSceneNative::GameSceneNative() {
	singleton = this;
}

GameSceneNative::~GameSceneNative() {
	singleton = nullptr;
}

static GameSceneNative *instance = nullptr;

void gamescene_native_init() {
	instance = memnew(GameSceneNative);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GameSceneNative", instance));
}

void gamescene_native_deinit() {
	if (instance) {
		memdelete(instance);
		instance = nullptr;
	}
}
