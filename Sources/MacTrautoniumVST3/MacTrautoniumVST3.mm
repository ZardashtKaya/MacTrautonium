#import <Cocoa/Cocoa.h>
#include <atomic>
#include <cstring>
#include <algorithm>

#include "TrautoniumCAPI.h"

#include "pluginterfaces/base/fplatform.h"
#include "pluginterfaces/base/funknown.h"
#include "pluginterfaces/base/ipluginbase.h"
#include "pluginterfaces/vst/ivstcomponent.h"
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/ivstevents.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/vst/vstspeaker.h"
#include "pluginterfaces/gui/iplugview.h"

namespace Steinberg {
    DEF_CLASS_IID (IPluginBase)
    DEF_CLASS_IID (IPluginFactory)
    DEF_CLASS_IID (IPluginFactory2)
    DEF_CLASS_IID (IPluginFactory3)
    DEF_CLASS_IID (FUnknown)
    DEF_CLASS_IID (IPlugView)

    namespace Vst {
        DEF_CLASS_IID (IComponent)
        DEF_CLASS_IID (IAudioProcessor)
        DEF_CLASS_IID (IEditController)
    }
}

using namespace Steinberg;
using namespace Steinberg::Vst;

// Processor UID: "MacTrautoniumPrc"
static const TUID kProcessorUID = {
    0x4D, 0x61, 0x63, 0x54, 0x72, 0x61, 0x75, 0x74, 0x6F, 0x6E, 0x69, 0x75, 0x6D, 0x50, 0x72, 0x63
};

// Controller UID: "MacTrautoniumCtr"
static const TUID kControllerUID = {
    0x4D, 0x61, 0x63, 0x54, 0x72, 0x61, 0x75, 0x74, 0x6F, 0x6E, 0x69, 0x75, 0x6D, 0x43, 0x74, 0x72
};

static inline void copyAsciiToTChar(TChar* dest, const char* src, size_t maxLen = 128) {
    size_t i = 0;
    while (src[i] && i < maxLen - 1) {
        dest[i] = (TChar)src[i];
        i++;
    }
    dest[i] = 0;
}

//------------------------------------------------------------------------
// MacTrautoniumView (NSHostingView container)
//------------------------------------------------------------------------
class MacTrautoniumView : public IPlugView {
protected:
    std::atomic<uint32> mRefCount{1};
    void* mEngineHandle;
    void* mHostedView = nullptr;
    IPlugFrame* mPlugFrame = nullptr;

public:
    MacTrautoniumView(void* engine) : mEngineHandle(engine) {}
    virtual ~MacTrautoniumView() {
        removed();
    }

    uint32 PLUGIN_API addRef() override { return ++mRefCount; }
    uint32 PLUGIN_API release() override {
        uint32 r = --mRefCount;
        if (r == 0) { delete this; return 0; }
        return r;
    }

    tresult PLUGIN_API queryInterface(const TUID _iid, void** obj) override {
        if (FUnknownPrivate::iidEqual(_iid, IPlugView::iid) ||
            FUnknownPrivate::iidEqual(_iid, FUnknown::iid)) {
            addRef();
            *obj = static_cast<IPlugView*>(this);
            return kResultOk;
        }
        *obj = nullptr;
        return kNoInterface;
    }

    tresult PLUGIN_API isPlatformTypeSupported(FIDString type) override {
        if (type && strcmp(type, kPlatformTypeNSView) == 0) {
            return kResultTrue;
        }
        return kResultFalse;
    }

    tresult PLUGIN_API attached(void* parent, FIDString type) override {
        if (parent == nullptr) return kResultFalse;
        @autoreleasepool {
            NSView* parentView = (__bridge NSView*)parent;
            void* viewHandle = trautonium_create_view(mEngineHandle);
            if (!viewHandle) return kResultFalse;

            mHostedView = viewHandle;
            NSView* trautoniumView = (__bridge NSView*)viewHandle;
            [parentView addSubview:trautoniumView];
            [trautoniumView setFrame:parentView.bounds];
            [trautoniumView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            trautonium_set_active_instance(mEngineHandle);
        }
        return kResultOk;
    }

    tresult PLUGIN_API removed() override {
        if (mHostedView) {
            @autoreleasepool {
                trautonium_destroy_view(mHostedView);
                mHostedView = nullptr;
            }
        }
        return kResultOk;
    }

    tresult PLUGIN_API onWheel(float distance) override { return kResultOk; }
    tresult PLUGIN_API onKeyDown(char16 key, int16 keyCode, int16 modifiers) override { return kResultFalse; }
    tresult PLUGIN_API onKeyUp(char16 key, int16 keyCode, int16 modifiers) override { return kResultFalse; }

    tresult PLUGIN_API getSize(ViewRect* size) override {
        if (!size) return kInvalidArgument;
        size->left = 0;
        size->top = 0;
        size->right = 880;
        size->bottom = 600;
        return kResultOk;
    }

    tresult PLUGIN_API onSize(ViewRect* newSize) override {
        if (mHostedView && newSize) {
            @autoreleasepool {
                NSView* v = (__bridge NSView*)mHostedView;
                NSRect r = NSMakeRect(newSize->left, newSize->top, newSize->getWidth(), newSize->getHeight());
                [v setFrame:r];
            }
        }
        return kResultOk;
    }

    tresult PLUGIN_API onFocus(TBool state) override { return kResultOk; }
    tresult PLUGIN_API setFrame(IPlugFrame* frame) override {
        mPlugFrame = frame;
        return kResultOk;
    }
    tresult PLUGIN_API canResize() override { return kResultTrue; }
    tresult PLUGIN_API checkSizeConstraint(ViewRect* rect) override {
        if (!rect) return kInvalidArgument;
        if (rect->getWidth() < 700) rect->right = rect->left + 700;
        if (rect->getHeight() < 500) rect->bottom = rect->top + 500;
        return kResultOk;
    }
};

//------------------------------------------------------------------------
// MacTrautoniumController
//------------------------------------------------------------------------
class MacTrautoniumController : public IEditController {
protected:
    std::atomic<uint32> mRefCount{1};
    void* mEngineHandle;
    IComponentHandler* mComponentHandler = nullptr;

public:
    MacTrautoniumController(void* engine) : mEngineHandle(engine) {}
    virtual ~MacTrautoniumController() {}

    uint32 PLUGIN_API addRef() override { return ++mRefCount; }
    uint32 PLUGIN_API release() override {
        uint32 r = --mRefCount;
        if (r == 0) { delete this; return 0; }
        return r;
    }

    tresult PLUGIN_API queryInterface(const TUID _iid, void** obj) override {
        if (FUnknownPrivate::iidEqual(_iid, IEditController::iid) ||
            FUnknownPrivate::iidEqual(_iid, IPluginBase::iid) ||
            FUnknownPrivate::iidEqual(_iid, FUnknown::iid)) {
            addRef();
            *obj = static_cast<IEditController*>(this);
            return kResultOk;
        }
        *obj = nullptr;
        return kNoInterface;
    }

    tresult PLUGIN_API initialize(FUnknown* context) override { return kResultOk; }
    tresult PLUGIN_API terminate() override { return kResultOk; }

    tresult PLUGIN_API setComponentState(IBStream* state) override { return kResultOk; }
    tresult PLUGIN_API setState(IBStream* state) override { return kResultOk; }
    tresult PLUGIN_API getState(IBStream* state) override { return kResultOk; }

    int32 PLUGIN_API getParameterCount() override { return 13; }

    tresult PLUGIN_API getParameterInfo(int32 paramIndex, ParameterInfo& info) override {
        memset(&info, 0, sizeof(ParameterInfo));
        info.stepCount = 0;
        info.defaultNormalizedValue = 0.5;
        info.flags = ParameterInfo::kCanAutomate;

        switch (paramIndex) {
            case 0:
                info.id = 0;
                copyAsciiToTChar(info.title, "Master Volume");
                copyAsciiToTChar(info.shortTitle, "Volume");
                info.defaultNormalizedValue = 0.8;
                break;
            case 1:
                info.id = 1;
                copyAsciiToTChar(info.title, "Manual 1 Cutoff");
                copyAsciiToTChar(info.shortTitle, "Cutoff 1");
                info.defaultNormalizedValue = 0.45;
                break;
            case 2:
                info.id = 2;
                copyAsciiToTChar(info.title, "Manual 1 Resonance");
                copyAsciiToTChar(info.shortTitle, "Reso 1");
                info.defaultNormalizedValue = 0.15;
                break;
            case 3:
                info.id = 3;
                copyAsciiToTChar(info.title, "Manual 1 Volume");
                copyAsciiToTChar(info.shortTitle, "Vol 1");
                info.defaultNormalizedValue = 0.65;
                break;
            case 9:
                info.id = 9;
                copyAsciiToTChar(info.title, "Echo Mix");
                copyAsciiToTChar(info.shortTitle, "Echo");
                info.defaultNormalizedValue = 0.25;
                break;
            case 11:
                info.id = 11;
                copyAsciiToTChar(info.title, "Reverb Mix");
                copyAsciiToTChar(info.shortTitle, "Reverb");
                info.defaultNormalizedValue = 0.25;
                break;
            case 12:
                info.id = 12;
                copyAsciiToTChar(info.title, "Saturation Drive");
                copyAsciiToTChar(info.shortTitle, "Drive");
                info.defaultNormalizedValue = 0.15;
                break;
            default:
                info.id = paramIndex;
                copyAsciiToTChar(info.title, "Param");
                break;
        }
        return kResultOk;
    }

    tresult PLUGIN_API getParamStringByValue(ParamID id, ParamValue valueNormalized, String128 string) override {
        char buf[32];
        snprintf(buf, sizeof(buf), "%.2f", valueNormalized);
        copyAsciiToTChar(string, buf);
        return kResultOk;
    }

    tresult PLUGIN_API getParamValueByString(ParamID id, TChar* string, ParamValue& valueNormalized) override {
        return kResultFalse;
    }

    ParamValue PLUGIN_API normalizedParamToPlain(ParamID id, ParamValue valueNormalized) override {
        return valueNormalized;
    }
    ParamValue PLUGIN_API plainParamToNormalized(ParamID id, ParamValue plainValue) override {
        return plainValue;
    }
    ParamValue PLUGIN_API getParamNormalized(ParamID id) override {
        return trautonium_get_param(mEngineHandle, (int32_t)id);
    }
    tresult PLUGIN_API setParamNormalized(ParamID id, ParamValue value) override {
        trautonium_set_param(mEngineHandle, (int32_t)id, (float)value);
        return kResultOk;
    }
    tresult PLUGIN_API setComponentHandler(IComponentHandler* handler) override {
        mComponentHandler = handler;
        return kResultOk;
    }

    IPlugView* PLUGIN_API createView(FIDString name) override {
        if (name && strcmp(name, ViewType::kEditor) == 0) {
            MacTrautoniumView* view = new MacTrautoniumView(mEngineHandle);
            return view;
        }
        return nullptr;
    }
};

//------------------------------------------------------------------------
// MacTrautoniumProcessor
//------------------------------------------------------------------------
class MacTrautoniumProcessor : public IComponent, public IAudioProcessor {
protected:
    std::atomic<uint32> mRefCount{1};
    void* mEngineHandle;
    MacTrautoniumController* mController;
    SpeakerArrangement mOutputArrangement = SpeakerArr::kStereo;

public:
    MacTrautoniumProcessor() {
        mEngineHandle = trautonium_create(48000.0);
        mController = new MacTrautoniumController(mEngineHandle);
    }

    virtual ~MacTrautoniumProcessor() {
        if (mController) {
            mController->release();
            mController = nullptr;
        }
        if (mEngineHandle) {
            trautonium_destroy(mEngineHandle);
            mEngineHandle = nullptr;
        }
    }

    uint32 PLUGIN_API addRef() override { return ++mRefCount; }
    uint32 PLUGIN_API release() override {
        uint32 r = --mRefCount;
        if (r == 0) { delete this; return 0; }
        return r;
    }

    tresult PLUGIN_API queryInterface(const TUID _iid, void** obj) override {
        if (FUnknownPrivate::iidEqual(_iid, IComponent::iid) ||
            FUnknownPrivate::iidEqual(_iid, IPluginBase::iid) ||
            FUnknownPrivate::iidEqual(_iid, FUnknown::iid)) {
            addRef();
            *obj = static_cast<IComponent*>(this);
            return kResultOk;
        }
        if (FUnknownPrivate::iidEqual(_iid, IAudioProcessor::iid)) {
            addRef();
            *obj = static_cast<IAudioProcessor*>(this);
            return kResultOk;
        }
        *obj = nullptr;
        return kNoInterface;
    }

    // IPluginBase
    tresult PLUGIN_API initialize(FUnknown* context) override { return kResultOk; }
    tresult PLUGIN_API terminate() override { return kResultOk; }

    // IComponent
    tresult PLUGIN_API getControllerClassId(TUID classId) override {
        memcpy(classId, kControllerUID, sizeof(TUID));
        return kResultOk;
    }
    tresult PLUGIN_API setIoMode(IoMode mode) override { return kResultOk; }

    int32 PLUGIN_API getBusCount(MediaType type, BusDirection dir) override {
        if (type == kAudio && dir == kOutput) return 1;
        if (type == kEvent && dir == kInput) return 1;
        return 0;
    }

    tresult PLUGIN_API getBusInfo(MediaType type, BusDirection dir, int32 index, BusInfo& bus) override {
        if (type == kAudio && dir == kOutput && index == 0) {
            bus.mediaType = kAudio;
            bus.direction = kOutput;
            bus.channelCount = 2;
            copyAsciiToTChar(bus.name, "Stereo Out");
            bus.busType = kMain;
            bus.flags = BusInfo::kDefaultActive;
            return kResultOk;
        }
        if (type == kEvent && dir == kInput && index == 0) {
            bus.mediaType = kEvent;
            bus.direction = kInput;
            bus.channelCount = 16;
            copyAsciiToTChar(bus.name, "MIDI / MPE In");
            bus.busType = kMain;
            bus.flags = BusInfo::kDefaultActive;
            return kResultOk;
        }
        return kInvalidArgument;
    }

    tresult PLUGIN_API getRoutingInfo(RoutingInfo& inInfo, RoutingInfo& outInfo) override {
        return kResultFalse;
    }

    tresult PLUGIN_API activateBus(MediaType type, BusDirection dir, int32 index, TBool state) override {
        return kResultOk;
    }

    tresult PLUGIN_API setActive(TBool state) override {
        if (state && mEngineHandle) {
            trautonium_reset(mEngineHandle);
        }
        return kResultOk;
    }

    tresult PLUGIN_API setState(IBStream* state) override { return kResultOk; }
    tresult PLUGIN_API getState(IBStream* state) override { return kResultOk; }

    // IAudioProcessor
    tresult PLUGIN_API setBusArrangements(SpeakerArrangement* inputs, int32 numIns,
                                          SpeakerArrangement* outputs, int32 numOuts) override {
        if (numOuts > 0 && outputs[0] == SpeakerArr::kStereo) {
            mOutputArrangement = outputs[0];
            return kResultOk;
        }
        return kResultFalse;
    }

    tresult PLUGIN_API getBusArrangement(BusDirection dir, int32 index, SpeakerArrangement& arr) override {
        if (dir == kOutput && index == 0) {
            arr = mOutputArrangement;
            return kResultOk;
        }
        return kInvalidArgument;
    }

    tresult PLUGIN_API canProcessSampleSize(int32 symbolicSampleSize) override {
        return (symbolicSampleSize == kSample32) ? kResultTrue : kResultFalse;
    }

    uint32 PLUGIN_API getLatencySamples() override { return 0; }

    tresult PLUGIN_API setupProcessing(ProcessSetup& setup) override {
        if (mEngineHandle && setup.sampleRate > 0) {
            trautonium_set_sample_rate(mEngineHandle, setup.sampleRate);
        }
        return kResultOk;
    }

    tresult PLUGIN_API setProcessing(TBool state) override { return kResultOk; }

    tresult PLUGIN_API process(ProcessData& data) override {
        if (!mEngineHandle) return kResultFalse;

        // 1. Process Parameter Changes from host automation
        if (data.inputParameterChanges) {
            int32 numParamChanges = data.inputParameterChanges->getParameterCount();
            for (int32 i = 0; i < numParamChanges; ++i) {
                IParamValueQueue* queue = data.inputParameterChanges->getParameterData(i);
                if (queue && queue->getPointCount() > 0) {
                    int32 sampleOffset;
                    ParamValue val;
                    if (queue->getPoint(queue->getPointCount() - 1, sampleOffset, val) == kResultOk) {
                        trautonium_set_param(mEngineHandle, queue->getParameterId(), (float)val);
                    }
                }
            }
        }

        // 2. Process MIDI / MPE Events
        if (data.inputEvents) {
            int32 eventCount = data.inputEvents->getEventCount();
            for (int32 i = 0; i < eventCount; ++i) {
                Event event;
                if (data.inputEvents->getEvent(i, event) == kResultOk) {
                    switch (event.type) {
                        case Event::kNoteOnEvent:
                            trautonium_note_on(mEngineHandle,
                                               event.noteOn.channel + 1,
                                               event.noteOn.pitch,
                                               event.noteOn.velocity);
                            break;
                        case Event::kNoteOffEvent:
                            trautonium_note_off(mEngineHandle,
                                                event.noteOff.channel + 1,
                                                event.noteOff.pitch);
                            break;
                        case Event::kPolyPressureEvent:
                            trautonium_pressure(mEngineHandle,
                                                event.polyPressure.channel + 1,
                                                event.polyPressure.pitch,
                                                event.polyPressure.pressure);
                            break;
                        default:
                            break;
                    }
                }
            }
        }

        // 3. Render Audio
        if (data.numOutputs > 0 && data.outputs[0].numChannels >= 2 && data.numSamples > 0) {
            float* outL = data.outputs[0].channelBuffers32[0];
            float* outR = data.outputs[0].channelBuffers32[1];
            trautonium_render(mEngineHandle, outL, outR, data.numSamples);
        }

        return kResultOk;
    }

    uint32 PLUGIN_API getTailSamples() override { return 48000; }

    MacTrautoniumController* getController() const { return mController; }
};

//------------------------------------------------------------------------
// MacTrautoniumFactory
//------------------------------------------------------------------------
class MacTrautoniumFactory : public IPluginFactory3 {
protected:
    std::atomic<uint32> mRefCount{1};
public:
    MacTrautoniumFactory() {}
    virtual ~MacTrautoniumFactory() {}

    uint32 PLUGIN_API addRef() override { return ++mRefCount; }
    uint32 PLUGIN_API release() override {
        uint32 r = --mRefCount;
        if (r == 0) { delete this; return 0; }
        return r;
    }

    tresult PLUGIN_API queryInterface(const TUID _iid, void** obj) override {
        if (FUnknownPrivate::iidEqual(_iid, IPluginFactory3::iid) ||
            FUnknownPrivate::iidEqual(_iid, IPluginFactory2::iid) ||
            FUnknownPrivate::iidEqual(_iid, IPluginFactory::iid) ||
            FUnknownPrivate::iidEqual(_iid, FUnknown::iid)) {
            addRef();
            *obj = static_cast<IPluginFactory3*>(this);
            return kResultOk;
        }
        *obj = nullptr;
        return kNoInterface;
    }

    tresult PLUGIN_API getFactoryInfo(PFactoryInfo* info) override {
        if (!info) return kInvalidArgument;
        strncpy(info->vendor, "Zard", sizeof(info->vendor) - 1);
        strncpy(info->url, "https://github.com/ZardashtKaya/MacTrautonium", sizeof(info->url) - 1);
        strncpy(info->email, "support@mactrautonium.local", sizeof(info->email) - 1);
        info->flags = PFactoryInfo::kNoFlags;
        return kResultOk;
    }

    int32 PLUGIN_API countClasses() override {
        return 2; // Processor, Controller
    }

    tresult PLUGIN_API getClassInfo(int32 index, PClassInfo* info) override {
        if (!info) return kInvalidArgument;
        if (index == 0) {
            memcpy(info->cid, kProcessorUID, sizeof(TUID));
            info->cardinality = PClassInfo::kManyInstances;
            strncpy(info->category, kVstAudioEffectClass, sizeof(info->category) - 1);
            strncpy(info->name, "MacTrautonium", sizeof(info->name) - 1);
            return kResultOk;
        } else if (index == 1) {
            memcpy(info->cid, kControllerUID, sizeof(TUID));
            info->cardinality = PClassInfo::kManyInstances;
            strncpy(info->category, kVstComponentControllerClass, sizeof(info->category) - 1);
            strncpy(info->name, "MacTrautoniumController", sizeof(info->name) - 1);
            return kResultOk;
        }
        return kInvalidArgument;
    }

    tresult PLUGIN_API getClassInfo2(int32 index, PClassInfo2* info) override {
        if (!info) return kInvalidArgument;
        if (index == 0) {
            memcpy(info->cid, kProcessorUID, sizeof(TUID));
            info->cardinality = PClassInfo::kManyInstances;
            strncpy(info->category, kVstAudioEffectClass, sizeof(info->category) - 1);
            strncpy(info->name, "MacTrautonium", sizeof(info->name) - 1);
            strncpy(info->vendor, "Zard", sizeof(info->vendor) - 1);
            strncpy(info->version, "1.0.0", sizeof(info->version) - 1);
            strncpy(info->sdkVersion, kVstVersionString, sizeof(info->sdkVersion) - 1);
            strncpy(info->subCategories, "Instrument|Synth", sizeof(info->subCategories) - 1);
            return kResultOk;
        } else if (index == 1) {
            memcpy(info->cid, kControllerUID, sizeof(TUID));
            info->cardinality = PClassInfo::kManyInstances;
            strncpy(info->category, kVstComponentControllerClass, sizeof(info->category) - 1);
            strncpy(info->name, "MacTrautoniumController", sizeof(info->name) - 1);
            strncpy(info->vendor, "Zard", sizeof(info->vendor) - 1);
            strncpy(info->version, "1.0.0", sizeof(info->version) - 1);
            strncpy(info->sdkVersion, kVstVersionString, sizeof(info->sdkVersion) - 1);
            strncpy(info->subCategories, "Component Controller", sizeof(info->subCategories) - 1);
            return kResultOk;
        }
        return kInvalidArgument;
    }

    tresult PLUGIN_API getClassInfoUnicode(int32 index, PClassInfoW* info) override {
        return kResultFalse;
    }

    tresult PLUGIN_API setHostContext(FUnknown* context) override {
        return kResultOk;
    }

    tresult PLUGIN_API createInstance(FIDString cid, FIDString _iid, void** obj) override {
        if (!cid || !obj) return kInvalidArgument;

        if (memcmp(cid, kProcessorUID, sizeof(TUID)) == 0) {
            MacTrautoniumProcessor* proc = new MacTrautoniumProcessor();
            tresult res = proc->queryInterface(_iid, obj);
            proc->release();
            return res;
        } else if (memcmp(cid, kControllerUID, sizeof(TUID)) == 0) {
            void* engine = trautonium_create(48000.0);
            MacTrautoniumController* ctrl = new MacTrautoniumController(engine);
            tresult res = ctrl->queryInterface(_iid, obj);
            ctrl->release();
            return res;
        }
        *obj = nullptr;
        return kNoInterface;
    }
};

static MacTrautoniumFactory* gFactory = nullptr;

extern "C" SMTG_EXPORT_SYMBOL IPluginFactory* PLUGIN_API GetPluginFactory() {
    if (!gFactory) {
        gFactory = new MacTrautoniumFactory();
    } else {
        gFactory->addRef();
    }
    return gFactory;
}
