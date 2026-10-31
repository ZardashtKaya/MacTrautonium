#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void* trautonium_create(double sampleRate);
void trautonium_destroy(void* handle);
void trautonium_set_sample_rate(void* handle, double sampleRate);
void trautonium_reset(void* handle);

void trautonium_note_on(void* handle, int32_t channel, int32_t note, float velocity);
void trautonium_note_off(void* handle, int32_t channel, int32_t note);
void trautonium_pitch_bend(void* handle, int32_t channel, int32_t bend14);
void trautonium_pressure(void* handle, int32_t channel, int32_t note, float pressure);
void trautonium_cc(void* handle, int32_t channel, int32_t cc, int32_t value);
void trautonium_all_notes_off(void* handle);

void trautonium_render(void* handle, float* outLeft, float* outRight, int32_t frameCount);
void trautonium_set_param(void* handle, int32_t paramId, float value);
float trautonium_get_param(void* handle, int32_t paramId);

void* trautonium_create_view(void* handle);
void trautonium_destroy_view(void* viewHandle);

#ifdef __cplusplus
}
#endif
