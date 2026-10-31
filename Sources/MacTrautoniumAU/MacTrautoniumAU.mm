#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#include <vector>
#include <algorithm>
#include <cmath>

#include "TrautoniumCAPI.h"

#define kMacTrautoniumProperty_EngineHandle 65535

//------------------------------------------------------------------------
// Cocoa View Factory
//------------------------------------------------------------------------
@interface MacTrautoniumAUCocoaViewFactory : NSObject <AUCocoaUIBase>
@end

@implementation MacTrautoniumAUCocoaViewFactory

- (unsigned)interfaceVersion {
    return 0;
}

- (NSString *)description {
    return @"MacTrautonium View";
}

- (NSView *)uiViewForAudioUnit:(AudioUnit)inAudioUnit withSize:(NSSize)inPreferredSize {
    UInt32 size = sizeof(void*);
    void* engine = nullptr;
    OSStatus err = AudioUnitGetProperty(inAudioUnit, kMacTrautoniumProperty_EngineHandle, kAudioUnitScope_Global, 0, &engine, &size);
    if (err != noErr || !engine) return nil;

    NSView* v = (__bridge_transfer NSView*)trautonium_create_view(engine);
    return v;
}

@end

//------------------------------------------------------------------------
// Internal AU State
//------------------------------------------------------------------------
struct PropListener {
    AudioUnitPropertyID prop;
    AudioUnitPropertyListenerProc proc;
    void* userData;
};

struct RenderNotifier {
    AURenderCallback proc;
    void* userData;
};

struct MacTrautoniumAUState {
    void* engine = nullptr;
    AudioComponentInstance ci = nullptr;
    AudioStreamBasicDescription outputFormat;
    Float64 sampleRate = 44100.0;
    UInt32 maxFramesPerSlice = 4096;
    UInt32 bypass = 0;
    SInt32 currentPresetNumber = 0;
    NSString* currentPresetName = @"Default";
    bool isInitialized = false;

    std::vector<PropListener> propListeners;
    std::vector<RenderNotifier> renderNotifiers;

    MacTrautoniumAUState(AudioComponentInstance instance) : ci(instance) {
        memset(&outputFormat, 0, sizeof(outputFormat));
        outputFormat.mSampleRate = 44100.0;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
        outputFormat.mBytesPerPacket = 4;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mBytesPerFrame = 4;
        outputFormat.mChannelsPerFrame = 2;
        outputFormat.mBitsPerChannel = 32;

        engine = trautonium_create(44100.0);
    }

    ~MacTrautoniumAUState() {
        if (engine) {
            trautonium_destroy(engine);
            engine = nullptr;
        }
    }

    void notifyPropertyChanged(AudioUnitPropertyID prop, AudioUnitScope scope, AudioUnitElement elem) {
        for (const auto& l : propListeners) {
            if (l.prop == prop && l.proc) {
                l.proc(l.userData, ci, prop, scope, elem);
            }
        }
    }
};

struct MacTrautoniumPlugInInstance {
    AudioComponentPlugInInterface interface;
    MacTrautoniumAUState* state = nullptr;
};

static inline MacTrautoniumAUState* GetState(void* self) {
    auto* inst = static_cast<MacTrautoniumPlugInInstance*>(self);
    return inst ? inst->state : nullptr;
}

//------------------------------------------------------------------------
// AudioUnit Dispatch Functions
//------------------------------------------------------------------------
static OSStatus AU_Initialize(void *self) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    s->isInitialized = true;
    trautonium_set_sample_rate(s->engine, s->sampleRate);
    return noErr;
}

static OSStatus AU_Uninitialize(void *self) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    s->isInitialized = false;
    return noErr;
}

static OSStatus AU_Reset(void *self, AudioUnitScope inScope, AudioUnitElement inElement) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    trautonium_reset(s->engine);
    return noErr;
}

static OSStatus AU_GetPropertyInfo(void *self, AudioUnitPropertyID prop, AudioUnitScope scope,
                                  AudioUnitElement elem, UInt32 *outDataSize, Boolean *outWritable) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;

    switch (prop) {
        case kAudioUnitProperty_ClassInfo:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(CFPropertyListRef);
            if (outWritable) *outWritable = true;
            return noErr;
        case kAudioUnitProperty_SupportedNumChannels:
            if (outDataSize) *outDataSize = sizeof(AUChannelInfo);
            if (outWritable) *outWritable = false;
            return noErr;
        case kAudioUnitProperty_StreamFormat:
            if (scope != kAudioUnitScope_Output) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(AudioStreamBasicDescription);
            if (outWritable) *outWritable = true;
            return noErr;
        case kAudioUnitProperty_ElementCount:
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = false;
            return noErr;
        case kAudioUnitProperty_Latency:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(Float64);
            if (outWritable) *outWritable = false;
            return noErr;
        case kAudioUnitProperty_TailTime:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(Float64);
            if (outWritable) *outWritable = false;
            return noErr;
        case kAudioUnitProperty_BypassEffect:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = true;
            return noErr;
        case kAudioUnitProperty_MaximumFramesPerSlice:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = true;
            return noErr;
        case kAudioUnitProperty_PresentPreset:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(AUPreset);
            if (outWritable) *outWritable = true;
            return noErr;
        case kAudioUnitProperty_CocoaUI:
            if (outDataSize) *outDataSize = sizeof(AudioUnitCocoaViewInfo);
            if (outWritable) *outWritable = false;
            return noErr;
        case kAudioUnitProperty_ParameterList:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = 13 * sizeof(AudioUnitParameterID);
            if (outWritable) *outWritable = false;
            return noErr;
        case kAudioUnitProperty_ParameterInfo:
            if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (outDataSize) *outDataSize = sizeof(AudioUnitParameterInfo);
            if (outWritable) *outWritable = false;
            return noErr;
        case kMacTrautoniumProperty_EngineHandle:
            if (outDataSize) *outDataSize = sizeof(void*);
            if (outWritable) *outWritable = false;
            return noErr;
        default:
            return kAudioUnitErr_InvalidProperty;
    }
}

static OSStatus AU_GetProperty(void *self, AudioUnitPropertyID inID, AudioUnitScope inScope,
                              AudioUnitElement inElement, void *outData, UInt32 *ioDataSize) {
    auto* s = GetState(self);
    if (!s || !outData || !ioDataSize) return kAudio_ParamError;

    switch (inID) {
        case kAudioUnitProperty_ClassInfo: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            NSDictionary* dict = @{
                @"version": @1,
                @"type": @((uint32_t)kAudioUnitType_MusicDevice),
                @"subtype": @((uint32_t)'mxtr'),
                @"manufacturer": @((uint32_t)'Zard'),
                @"name": @"MacTrautonium",
                @"preset-id": @(s->currentPresetNumber),
                @"preset-name": (s->currentPresetName ? s->currentPresetName : @"Default")
            };
            *static_cast<CFPropertyListRef*>(outData) = (__bridge_retained CFPropertyListRef)dict;
            *ioDataSize = sizeof(CFPropertyListRef);
            return noErr;
        }
        case kAudioUnitProperty_SupportedNumChannels: {
            if (*ioDataSize < sizeof(AUChannelInfo)) return kAudioUnitErr_InvalidPropertyValue;
            AUChannelInfo* info = static_cast<AUChannelInfo*>(outData);
            info->inChannels = 0;
            info->outChannels = 2;
            *ioDataSize = sizeof(AUChannelInfo);
            return noErr;
        }
        case kAudioUnitProperty_StreamFormat: {
            if (inScope != kAudioUnitScope_Output) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(AudioStreamBasicDescription)) return kAudioUnitErr_InvalidPropertyValue;
            memcpy(outData, &s->outputFormat, sizeof(AudioStreamBasicDescription));
            *ioDataSize = sizeof(AudioStreamBasicDescription);
            return noErr;
        }
        case kAudioUnitProperty_ElementCount: {
            if (*ioDataSize < sizeof(UInt32)) return kAudioUnitErr_InvalidPropertyValue;
            UInt32* count = static_cast<UInt32*>(outData);
            if (inScope == kAudioUnitScope_Input) *count = 0;
            else if (inScope == kAudioUnitScope_Output) *count = 1;
            else *count = 1;
            *ioDataSize = sizeof(UInt32);
            return noErr;
        }
        case kAudioUnitProperty_Latency: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(Float64)) return kAudioUnitErr_InvalidPropertyValue;
            *static_cast<Float64*>(outData) = 0.0;
            *ioDataSize = sizeof(Float64);
            return noErr;
        }
        case kAudioUnitProperty_TailTime: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(Float64)) return kAudioUnitErr_InvalidPropertyValue;
            *static_cast<Float64*>(outData) = 1.0;
            *ioDataSize = sizeof(Float64);
            return noErr;
        }
        case kAudioUnitProperty_BypassEffect: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(UInt32)) return kAudioUnitErr_InvalidPropertyValue;
            *static_cast<UInt32*>(outData) = s->bypass;
            *ioDataSize = sizeof(UInt32);
            return noErr;
        }
        case kAudioUnitProperty_MaximumFramesPerSlice: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(UInt32)) return kAudioUnitErr_InvalidPropertyValue;
            *static_cast<UInt32*>(outData) = s->maxFramesPerSlice;
            *ioDataSize = sizeof(UInt32);
            return noErr;
        }
        case kAudioUnitProperty_PresentPreset: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(AUPreset)) return kAudioUnitErr_InvalidPropertyValue;
            AUPreset* p = static_cast<AUPreset*>(outData);
            p->presetNumber = s->currentPresetNumber;
            p->presetName = (__bridge_retained CFStringRef)(s->currentPresetName ? s->currentPresetName : @"Default");
            *ioDataSize = sizeof(AUPreset);
            return noErr;
        }
        case kAudioUnitProperty_CocoaUI: {
            if (*ioDataSize < sizeof(AudioUnitCocoaViewInfo)) return kAudioUnitErr_InvalidPropertyValue;
            AudioUnitCocoaViewInfo* info = static_cast<AudioUnitCocoaViewInfo*>(outData);
            NSBundle* bundle = [NSBundle bundleForClass:[MacTrautoniumAUCocoaViewFactory class]];
            info->mCocoaAUViewBundleLocation = (__bridge_retained CFURLRef)[bundle bundleURL];
            info->mCocoaAUViewClass[0] = (__bridge_retained CFStringRef)@"MacTrautoniumAUCocoaViewFactory";
            *ioDataSize = sizeof(AudioUnitCocoaViewInfo);
            return noErr;
        }
        case kAudioUnitProperty_ParameterList: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            UInt32 params[13] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
            UInt32 numBytes = sizeof(params);
            if (*ioDataSize < numBytes) numBytes = *ioDataSize;
            memcpy(outData, params, numBytes);
            *ioDataSize = numBytes;
            return noErr;
        }
        case kAudioUnitProperty_ParameterInfo: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (*ioDataSize < sizeof(AudioUnitParameterInfo)) return kAudioUnitErr_InvalidPropertyValue;
            AudioUnitParameterInfo* info = static_cast<AudioUnitParameterInfo*>(outData);
            memset(info, 0, sizeof(AudioUnitParameterInfo));
            info->flags = kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_HasCFNameString;

            switch (inElement) {
                case 0:
                    strlcpy(info->name, "Master Volume", sizeof(info->name));
                    info->cfNameString = CFSTR("Master Volume");
                    info->unit = kAudioUnitParameterUnit_LinearGain;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.8;
                    break;
                case 1:
                    strlcpy(info->name, "Manual 1 Cutoff", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 1 Cutoff");
                    info->unit = kAudioUnitParameterUnit_Hertz;
                    info->minValue = 20.0; info->maxValue = 20000.0; info->defaultValue = 1800.0;
                    break;
                case 2:
                    strlcpy(info->name, "Manual 1 Resonance", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 1 Resonance");
                    info->unit = kAudioUnitParameterUnit_Generic;
                    info->minValue = 0.0; info->maxValue = 0.95; info->defaultValue = 0.15;
                    break;
                case 3:
                    strlcpy(info->name, "Manual 1 Volume", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 1 Volume");
                    info->unit = kAudioUnitParameterUnit_LinearGain;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.65;
                    break;
                case 4:
                    strlcpy(info->name, "Manual 1 Vowel", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 1 Vowel");
                    info->unit = kAudioUnitParameterUnit_Indexed;
                    info->minValue = -1.0; info->maxValue = 4.0; info->defaultValue = -1.0;
                    break;
                case 5:
                    strlcpy(info->name, "Manual 1 Register", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 1 Register");
                    info->unit = kAudioUnitParameterUnit_Indexed;
                    info->minValue = 0.0; info->maxValue = 2.0; info->defaultValue = 1.0;
                    break;
                case 6:
                    strlcpy(info->name, "Manual 2 Cutoff", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 2 Cutoff");
                    info->unit = kAudioUnitParameterUnit_Hertz;
                    info->minValue = 20.0; info->maxValue = 20000.0; info->defaultValue = 1800.0;
                    break;
                case 7:
                    strlcpy(info->name, "Manual 2 Resonance", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 2 Resonance");
                    info->unit = kAudioUnitParameterUnit_Generic;
                    info->minValue = 0.0; info->maxValue = 0.95; info->defaultValue = 0.15;
                    break;
                case 8:
                    strlcpy(info->name, "Manual 2 Volume", sizeof(info->name));
                    info->cfNameString = CFSTR("Manual 2 Volume");
                    info->unit = kAudioUnitParameterUnit_LinearGain;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.65;
                    break;
                case 9:
                    strlcpy(info->name, "Echo Mix", sizeof(info->name));
                    info->cfNameString = CFSTR("Echo Mix");
                    info->unit = kAudioUnitParameterUnit_Percent;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.25;
                    break;
                case 10:
                    strlcpy(info->name, "Echo Time", sizeof(info->name));
                    info->cfNameString = CFSTR("Echo Time");
                    info->unit = kAudioUnitParameterUnit_Milliseconds;
                    info->minValue = 50.0; info->maxValue = 1200.0; info->defaultValue = 350.0;
                    break;
                case 11:
                    strlcpy(info->name, "Reverb Mix", sizeof(info->name));
                    info->cfNameString = CFSTR("Reverb Mix");
                    info->unit = kAudioUnitParameterUnit_Percent;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.25;
                    break;
                case 12:
                    strlcpy(info->name, "Saturation", sizeof(info->name));
                    info->cfNameString = CFSTR("Saturation");
                    info->unit = kAudioUnitParameterUnit_Percent;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.15;
                    break;
                default:
                    strlcpy(info->name, "Parameter", sizeof(info->name));
                    info->cfNameString = CFSTR("Parameter");
                    info->unit = kAudioUnitParameterUnit_Generic;
                    info->minValue = 0.0; info->maxValue = 1.0; info->defaultValue = 0.5;
                    break;
            }
            *ioDataSize = sizeof(AudioUnitParameterInfo);
            return noErr;
        }
        case kMacTrautoniumProperty_EngineHandle: {
            if (*ioDataSize < sizeof(void*)) return kAudioUnitErr_InvalidPropertyValue;
            *static_cast<void**>(outData) = s->engine;
            *ioDataSize = sizeof(void*);
            return noErr;
        }
        default:
            return kAudioUnitErr_InvalidProperty;
    }
}

static OSStatus AU_SetProperty(void *self, AudioUnitPropertyID inID, AudioUnitScope inScope,
                              AudioUnitElement inElement, const void *inData, UInt32 inDataSize) {
    auto* s = GetState(self);
    if (!s || !inData) return kAudio_ParamError;

    switch (inID) {
        case kAudioUnitProperty_StreamFormat: {
            if (inScope != kAudioUnitScope_Output) return kAudioUnitErr_InvalidScope;
            if (inDataSize < sizeof(AudioStreamBasicDescription)) return kAudioUnitErr_InvalidPropertyValue;
            const auto* asbd = static_cast<const AudioStreamBasicDescription*>(inData);
            if (asbd->mChannelsPerFrame != 2) {
                return kAudioUnitErr_FormatNotSupported;
            }
            if (asbd->mSampleRate > 0) {
                s->sampleRate = asbd->mSampleRate;
                s->outputFormat.mSampleRate = asbd->mSampleRate;
                trautonium_set_sample_rate(s->engine, asbd->mSampleRate);
            }
            return noErr;
        }
        case kAudioUnitProperty_ClassInfo: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (inDataSize < sizeof(CFPropertyListRef)) return kAudioUnitErr_InvalidPropertyValue;
            CFPropertyListRef plist = *static_cast<const CFPropertyListRef*>(inData);
            if (plist && CFGetTypeID(plist) == CFDictionaryGetTypeID()) {
                NSDictionary* dict = (__bridge NSDictionary*)plist;
                if ([dict objectForKey:@"preset-name"]) {
                    s->currentPresetName = [dict[@"preset-name"] copy];
                }
                if ([dict objectForKey:@"preset-id"]) {
                    s->currentPresetNumber = [dict[@"preset-id"] intValue];
                }
            }
            return noErr;
        }
        case kAudioUnitProperty_MaximumFramesPerSlice: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (inDataSize < sizeof(UInt32)) return kAudioUnitErr_InvalidPropertyValue;
            s->maxFramesPerSlice = *static_cast<const UInt32*>(inData);
            s->notifyPropertyChanged(kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0);
            return noErr;
        }
        case kAudioUnitProperty_BypassEffect: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (inDataSize < sizeof(UInt32)) return kAudioUnitErr_InvalidPropertyValue;
            s->bypass = *static_cast<const UInt32*>(inData);
            s->notifyPropertyChanged(kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0);
            return noErr;
        }
        case kAudioUnitProperty_PresentPreset: {
            if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
            if (inDataSize < sizeof(AUPreset)) return kAudioUnitErr_InvalidPropertyValue;
            const auto* p = static_cast<const AUPreset*>(inData);
            s->currentPresetNumber = p->presetNumber;
            if (p->presetName) {
                s->currentPresetName = [(__bridge NSString*)p->presetName copy];
            }
            s->notifyPropertyChanged(kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0);
            return noErr;
        }
        default:
            return kAudioUnitErr_InvalidProperty;
    }
}

static OSStatus AU_GetParameter(void *self, AudioUnitParameterID inID, AudioUnitScope inScope,
                                AudioUnitElement inElement, AudioUnitParameterValue *outValue) {
    auto* s = GetState(self);
    if (!s || !outValue) return kAudio_ParamError;
    if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
    *outValue = trautonium_get_param(s->engine, (int32_t)inID);
    return noErr;
}

static OSStatus AU_SetParameter(void *self, AudioUnitParameterID inID, AudioUnitScope inScope,
                                AudioUnitElement inElement, AudioUnitParameterValue inValue, UInt32 inBufferOffsetInFrames) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    if (inScope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
    trautonium_set_param(s->engine, (int32_t)inID, (float)inValue);
    return noErr;
}

static OSStatus AU_AddPropertyListener(void *self, AudioUnitPropertyID prop, AudioUnitPropertyListenerProc proc, void *userData) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    s->propListeners.push_back({ prop, proc, userData });
    return noErr;
}

static OSStatus AU_RemovePropertyListenerWithUserData(void *self, AudioUnitPropertyID prop, AudioUnitPropertyListenerProc proc, void *userData) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    auto it = std::remove_if(s->propListeners.begin(), s->propListeners.end(), [&](const PropListener& l) {
        return l.prop == prop && l.proc == proc && (userData == nullptr || l.userData == userData);
    });
    s->propListeners.erase(it, s->propListeners.end());
    return noErr;
}

static OSStatus AU_RemovePropertyListener(void *self, AudioUnitPropertyID prop, AudioUnitPropertyListenerProc proc) {
    return AU_RemovePropertyListenerWithUserData(self, prop, proc, nullptr);
}

static OSStatus AU_AddRenderNotify(void *self, AURenderCallback proc, void *userData) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    s->renderNotifiers.push_back({ proc, userData });
    return noErr;
}

static OSStatus AU_RemoveRenderNotify(void *self, AURenderCallback proc, void *userData) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    auto it = std::remove_if(s->renderNotifiers.begin(), s->renderNotifiers.end(), [&](const RenderNotifier& n) {
        return n.proc == proc && (userData == nullptr || n.userData == userData);
    });
    s->renderNotifiers.erase(it, s->renderNotifiers.end());
    return noErr;
}

static OSStatus AU_ScheduleParameters(void *self, const AudioUnitParameterEvent *events, UInt32 numEvents) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;
    for (UInt32 i = 0; i < numEvents; ++i) {
        if (events[i].eventType == kParameterEvent_Immediate) {
            trautonium_set_param(s->engine, events[i].parameter, events[i].eventValues.immediate.value);
        } else if (events[i].eventType == kParameterEvent_Ramped) {
            trautonium_set_param(s->engine, events[i].parameter, events[i].eventValues.ramp.endValue);
        }
    }
    return noErr;
}

static OSStatus AU_Render(void *self, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp,
                          UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    auto* s = GetState(self);
    if (!s || !ioData) return kAudio_ParamError;

    if (inNumberFrames > s->maxFramesPerSlice) {
        return kAudioUnitErr_TooManyFramesToProcess; // -10874
    }

    // Call PreRender Notifiers
    for (const auto& n : s->renderNotifiers) {
        AudioUnitRenderActionFlags flags = kAudioUnitRenderAction_PreRender;
        n.proc(n.userData, &flags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
    }

    if (ioData->mNumberBuffers >= 2 && ioData->mBuffers[0].mData && ioData->mBuffers[1].mData) {
        float* outL = static_cast<float*>(ioData->mBuffers[0].mData);
        float* outR = static_cast<float*>(ioData->mBuffers[1].mData);
        if (s->bypass) {
            memset(outL, 0, inNumberFrames * sizeof(float));
            memset(outR, 0, inNumberFrames * sizeof(float));
        } else {
            trautonium_render(s->engine, outL, outR, (int32_t)inNumberFrames);
        }
    } else if (ioData->mNumberBuffers == 1 && ioData->mBuffers[0].mData) {
        float* dst = static_cast<float*>(ioData->mBuffers[0].mData);
        if (s->bypass) {
            memset(dst, 0, inNumberFrames * 2 * sizeof(float));
        } else {
            std::vector<float> tempL(inNumberFrames);
            std::vector<float> tempR(inNumberFrames);
            trautonium_render(s->engine, tempL.data(), tempR.data(), (int32_t)inNumberFrames);
            for (UInt32 i = 0; i < inNumberFrames; ++i) {
                dst[i * 2] = tempL[i];
                dst[i * 2 + 1] = tempR[i];
            }
        }
    }

    // Call PostRender Notifiers
    for (const auto& n : s->renderNotifiers) {
        AudioUnitRenderActionFlags flags = kAudioUnitRenderAction_PostRender;
        n.proc(n.userData, &flags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
    }

    return noErr;
}

static OSStatus MD_MIDIEvent(void *self, UInt32 inStatus, UInt32 inData1, UInt32 inData2, UInt32 inOffsetSampleFrame) {
    auto* s = GetState(self);
    if (!s) return kAudio_ParamError;

    UInt32 msgType = inStatus & 0xF0;
    int channel = (inStatus & 0x0F) + 1;

    switch (msgType) {
        case 0x90: // Note On
            if (inData2 > 0) {
                trautonium_note_on(s->engine, channel, inData1, (float)inData2 / 127.0f);
            } else {
                trautonium_note_off(s->engine, channel, inData1);
            }
            break;
        case 0x80: // Note Off
            trautonium_note_off(s->engine, channel, inData1);
            break;
        case 0xE0: { // Pitch Bend
            int bend14 = (int)(inData1 | (inData2 << 7));
            trautonium_pitch_bend(s->engine, channel, bend14);
            break;
        }
        case 0xD0: { // Channel Pressure
            float press = (float)inData1 / 127.0f;
            trautonium_pressure(s->engine, channel, -1, press);
            break;
        }
        case 0xA0: { // Poly Aftertouch
            float press = (float)inData2 / 127.0f;
            trautonium_pressure(s->engine, channel, inData1, press);
            break;
        }
        case 0xB0: // Control Change
            trautonium_cc(s->engine, channel, inData1, inData2);
            break;
        default:
            break;
    }
    return noErr;
}

static OSStatus MD_StartNote(void *self, MusicDeviceInstrumentID inInstrument, MusicDeviceGroupID inGroupID,
                             NoteInstanceID *outNoteInstanceID, UInt32 inOffsetSampleFrame, const MusicDeviceNoteParams *inParams) {
    if (outNoteInstanceID) *outNoteInstanceID = 1;
    return noErr;
}

static OSStatus MD_StopNote(void *self, MusicDeviceGroupID inGroupID, NoteInstanceID inNoteInstanceID, UInt32 inOffsetSampleFrame) {
    return noErr;
}

//------------------------------------------------------------------------
// AudioComponent Plugin Interface & Factory
//------------------------------------------------------------------------
static OSStatus AU_Open(void *self, AudioComponentInstance mInstance) {
    auto* inst = static_cast<MacTrautoniumPlugInInstance*>(self);
    if (inst) {
        inst->state = new MacTrautoniumAUState(mInstance);
    }
    return noErr;
}

static OSStatus AU_Close(void *self) {
    auto* inst = static_cast<MacTrautoniumPlugInInstance*>(self);
    if (inst) {
        if (inst->state) {
            delete inst->state;
            inst->state = nullptr;
        }
        delete inst;
    }
    return noErr;
}

static AudioComponentMethod AU_Lookup(SInt16 selector) {
    switch (selector) {
        case kAudioUnitInitializeSelect: return (AudioComponentMethod)AU_Initialize;
        case kAudioUnitUninitializeSelect: return (AudioComponentMethod)AU_Uninitialize;
        case kAudioUnitGetPropertyInfoSelect: return (AudioComponentMethod)AU_GetPropertyInfo;
        case kAudioUnitGetPropertySelect: return (AudioComponentMethod)AU_GetProperty;
        case kAudioUnitSetPropertySelect: return (AudioComponentMethod)AU_SetProperty;
        case kAudioUnitGetParameterSelect: return (AudioComponentMethod)AU_GetParameter;
        case kAudioUnitSetParameterSelect: return (AudioComponentMethod)AU_SetParameter;
        case kAudioUnitScheduleParametersSelect: return (AudioComponentMethod)AU_ScheduleParameters;
        case kAudioUnitResetSelect: return (AudioComponentMethod)AU_Reset;
        case kAudioUnitRenderSelect: return (AudioComponentMethod)AU_Render;
        case kAudioUnitAddPropertyListenerSelect: return (AudioComponentMethod)AU_AddPropertyListener;
        case kAudioUnitRemovePropertyListenerSelect: return (AudioComponentMethod)AU_RemovePropertyListener;
        case kAudioUnitRemovePropertyListenerWithUserDataSelect: return (AudioComponentMethod)AU_RemovePropertyListenerWithUserData;
        case kAudioUnitAddRenderNotifySelect: return (AudioComponentMethod)AU_AddRenderNotify;
        case kAudioUnitRemoveRenderNotifySelect: return (AudioComponentMethod)AU_RemoveRenderNotify;
        case kMusicDeviceMIDIEventSelect: return (AudioComponentMethod)MD_MIDIEvent;
        case kMusicDeviceStartNoteSelect: return (AudioComponentMethod)MD_StartNote;
        case kMusicDeviceStopNoteSelect: return (AudioComponentMethod)MD_StopNote;
        default: return nullptr;
    }
}

extern "C" AudioComponentPlugInInterface* MacTrautoniumAUFactory(const AudioComponentDescription *inDesc) {
    auto* inst = new MacTrautoniumPlugInInstance();
    inst->interface.Open = AU_Open;
    inst->interface.Close = AU_Close;
    inst->interface.Lookup = AU_Lookup;
    inst->interface.reserved = nullptr;
    inst->state = nullptr;
    return reinterpret_cast<AudioComponentPlugInInterface*>(inst);
}
